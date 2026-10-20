use emf_ffi::*;
use std::{ptr, slice};

fn record(function: u16, body: &[u8]) -> Vec<u8> {
    assert_eq!(body.len() % 2, 0);
    let mut bytes = ((body.len() as u32 + 6) / 2).to_le_bytes().to_vec();
    bytes.extend_from_slice(&function.to_le_bytes());
    bytes.extend_from_slice(body);
    bytes
}
fn source(records: &[Vec<u8>], tail: &[u8]) -> Vec<u8> {
    let mut bytes = vec![1, 0, 9, 0, 0, 3];
    bytes.extend_from_slice(
        &(9 + records.iter().map(|r| r.len() as u32 / 2).sum::<u32>()).to_le_bytes(),
    );
    bytes.extend_from_slice(&2u16.to_le_bytes());
    bytes.extend_from_slice(
        &records
            .iter()
            .map(|r| r.len() as u32 / 2)
            .max()
            .unwrap_or(0)
            .to_le_bytes(),
    );
    bytes.extend_from_slice(&0u16.to_le_bytes());
    for r in records {
        bytes.extend_from_slice(r);
    }
    bytes.extend_from_slice(tail);
    bytes
}
unsafe fn parse(bytes: &[u8]) -> *mut WmfDocument {
    let mut doc = ptr::null_mut();
    assert_eq!(
        emf_wmf_parse(
            bytes.as_ptr(),
            bytes.len() as u64,
            ptr::null(),
            &mut doc,
            ptr::null_mut()
        ),
        EMF_OK
    );
    doc
}
unsafe fn snapshot(doc: *const WmfDocument) -> Vec<u8> {
    let mut buffer = ptr::null_mut();
    assert_eq!(
        emf_wmf_document_snapshot(doc, &mut buffer, ptr::null_mut()),
        EMF_OK
    );
    // The buffer remains valid after the document is freed.
    emf_wmf_document_free(doc.cast_mut());
    let mut data = ptr::null();
    let mut length = 0;
    assert_eq!(emf_buffer_view(buffer, &mut data, &mut length), EMF_OK);
    let bytes = slice::from_raw_parts(data, length as usize).to_vec();
    emf_buffer_free(buffer);
    assert_eq!(&bytes[..4], b"WMFS");
    assert_eq!(u32_at(&bytes, 4), 1);
    assert_eq!(u64_at(&bytes, 8), bytes.len() as u64);
    bytes
}
fn u32_at(bytes: &[u8], offset: usize) -> u32 {
    u32::from_le_bytes(bytes[offset..offset + 4].try_into().unwrap())
}
fn u64_at(bytes: &[u8], offset: usize) -> u64 {
    u64::from_le_bytes(bytes[offset..offset + 8].try_into().unwrap())
}
fn payloads(bytes: &[u8]) -> Vec<(u32, u32, Vec<u8>)> {
    let mut offset = 120;
    (0..u64_at(bytes, 16))
        .map(|index| {
            assert_eq!(u64_at(bytes, offset), index);
            let len = u64_at(bytes, offset + 32) as usize;
            let item = (
                u32_at(bytes, offset + 24),
                u32_at(bytes, offset + 28),
                bytes[offset + 40..offset + 40 + len].to_vec(),
            );
            offset += 40 + len;
            item
        })
        .collect()
}
#[test]
fn typed_values_and_opaque_records_have_independent_owned_payloads() {
    let records = [
        record(0x0214, &[0xff, 0xff, 0, 0x80]),
        record(0x0324, &[2, 0, 1, 0, 0xff, 0xff, 0, 0x80, 0xff, 0x7f]),
        record(0x02fa, &[1, 0, 0xfe, 0xff, 3, 0, 0x12, 0x34, 0x56, 0x78]),
        record(0x001e, &[]), // SaveDC has an empty typed payload.
        record(0x7777, &[0x80, 0xff]),
        record(0, &[]),
    ];
    let input = source(&records, b"tail\0");
    let bytes = unsafe { snapshot(parse(&input)) };
    let values = payloads(&bytes);
    assert_eq!(
        values.iter().map(|v| v.1).collect::<Vec<_>>(),
        [2, 3, 4, 13, 0, 1]
    );
    assert_eq!(
        values[0].2,
        [-1i32, -32768]
            .iter()
            .flat_map(|v| v.to_le_bytes())
            .collect::<Vec<_>>()
    );
    assert_eq!(u64_at(&values[1].2, 0), 2);
    assert_eq!(u32_at(&values[1].2, 20), u32::MAX);
    assert_eq!(u32_at(&values[2].2, 4), (-2i32) as u32);
    assert_eq!(u32_at(&values[2].2, 12), 0x78563412);
    assert_eq!(&bytes[bytes.len() - 5..], b"tail\0");
    assert_eq!(u64_at(&bytes, 40), input.len() as u64);
}
#[test]
fn scalar_state_fields_are_unsigned_in_wire_order_with_complete_source_spans() {
    let cases: [(u16, &[u8], &[u32]); 12] = [
        (0xab01, &[0x12, 0x34, 0x56, 0xf8], &[0xf8563412]),
        (0xcd02, &[0x01, 0x80], &[0x8001]),
        (0xef03, &[0xff, 0xff], &[0xffff]),
        (0x0131, &[0xef, 0xcd, 0xab, 0x89], &[0x89abcdef]),
        (0x0106, &[0x02, 0x80], &[0x8002]),
        (0x0104, &[0x03, 0x80], &[0x8003]),
        (0x0107, &[0x04, 0x80], &[0x8004]),
        (0x012e, &[0x05, 0x80], &[0x8005]),
        (0x0108, &[0xfe, 0xff], &[0xfffe]),
        (0x0209, &[0x98, 0x76, 0x54, 0xf2], &[0xf2547698]),
        (0x020a, &[0x01, 0x80, 0xfe, 0xff], &[0x8001, 0xfffe]),
        (0x0149, &[0x02, 0x80, 0xfd, 0xff], &[0x8002, 0xfffd]),
    ];
    let suffix = [0xde, 0xad, 0xbe, 0xef];
    let mut records: Vec<_> = cases
        .iter()
        .map(|(function, prefix, _)| {
            let mut body = prefix.to_vec();
            body.extend_from_slice(&suffix);
            record(*function, &body)
        })
        .collect();
    records.push(record(0, &[]));
    let input = source(&records, b"tail");
    unsafe {
        let doc = parse(&input);
        let mut buffer = ptr::null_mut();
        assert_eq!(emf_wmf_serialize(doc, &mut buffer, ptr::null_mut()), EMF_OK);
        let mut data = ptr::null();
        let mut length = 0;
        assert_eq!(emf_buffer_view(buffer, &mut data, &mut length), EMF_OK);
        assert_eq!(slice::from_raw_parts(data, length as usize), input);
        emf_buffer_free(buffer);

        let bytes = snapshot(doc);
        let values = payloads(&bytes);
        let mut descriptor = 120;
        let mut source_offset = 18;
        for (index, (function, prefix, expected)) in cases.iter().enumerate() {
            assert_eq!(values[index].0, u32::from(*function));
            assert_eq!(values[index].1, 6);
            assert_eq!(
                values[index].2,
                expected
                    .iter()
                    .flat_map(|n| n.to_le_bytes())
                    .collect::<Vec<_>>()
            );
            let offset = u64_at(&bytes, descriptor + 8) as usize;
            let length = u64_at(&bytes, descriptor + 16) as usize;
            assert_eq!(offset, source_offset);
            assert_eq!(length, 6 + prefix.len() + suffix.len());
            assert_eq!(&input[offset..offset + length], records[index]);
            assert_eq!(&input[offset + 6 + prefix.len()..offset + length], suffix);
            descriptor += 40 + values[index].2.len();
            source_offset += length;
        }
        assert_eq!(values[12], (0, 1, vec![]));
        assert_eq!(u64_at(&bytes, descriptor + 8), source_offset as u64);
        assert_eq!(&bytes[bytes.len() - 4..], b"tail");
    }
}

#[test]
fn font_fields_and_raw_face_name_preserve_source_suffix_and_advisory_function() {
    let signed = [i16::MIN, i16::MAX, -1, 0, -12345];
    let unsigned = [0x80u8, 0xff, 0xfe, 0x81, 0x82, 0x83, 0x84, 0xf5];
    let face_name = [
        b'F', b'o', b'n', b't', 0, 0xff, 0x80, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
        16, 17, 18, 19, 20, 21, 22, 23, 24, 0xfe,
    ];
    let suffix = [0xde, 0xad, 0xbe, 0xef];
    let mut body: Vec<_> = signed.iter().flat_map(|n| n.to_le_bytes()).collect();
    body.extend_from_slice(&unsigned);
    body.extend_from_slice(&face_name);
    body.extend_from_slice(&suffix);
    let records = [
        record(0x02fb, &body),
        record(0xa7fb, &body), // The high function byte is advisory.
        record(0x001e, &[]),   // SaveDC has an empty typed payload.
        record(0x7777, &[0x80, 0xff]),
        record(0x02fb, &[0; 48]), // A short font is malformed and remains opaque.
        record(0, &[]),
    ];
    let input = source(&records, b"tail\0");
    unsafe {
        let doc = parse(&input);
        let mut buffer = ptr::null_mut();
        assert_eq!(emf_wmf_serialize(doc, &mut buffer, ptr::null_mut()), EMF_OK);
        let mut data = ptr::null();
        let mut length = 0;
        assert_eq!(emf_buffer_view(buffer, &mut data, &mut length), EMF_OK);
        assert_eq!(slice::from_raw_parts(data, length as usize), input);
        emf_buffer_free(buffer);

        let bytes = snapshot(doc);
        let values = payloads(&bytes);
        let mut expected: Vec<_> = signed
            .iter()
            .flat_map(|n| i32::from(*n).to_le_bytes())
            .collect();
        expected.extend(unsigned.iter().flat_map(|n| u32::from(*n).to_le_bytes()));
        expected.extend_from_slice(&face_name);
        assert_eq!(expected.len(), 84);
        for (index, function) in [0x02fb, 0xa7fb].into_iter().enumerate() {
            assert_eq!(values[index], (function, 7, expected.clone()));
            assert_eq!(&values[index].2[52..], &face_name);
        }
        assert_eq!(values[2], (0x001e, 13, vec![]));
        assert_eq!(values[3], (0x7777, 0, vec![]));
        assert_eq!(values[4], (0x02fb, 0, vec![]));
        assert_eq!(values[5], (0, 1, vec![]));

        let mut descriptor = 120;
        let mut source_offset = 18;
        for (index, original) in records.iter().enumerate() {
            let offset = u64_at(&bytes, descriptor + 8) as usize;
            let length = u64_at(&bytes, descriptor + 16) as usize;
            assert_eq!(offset, source_offset);
            assert_eq!(length, original.len());
            assert_eq!(&input[offset..offset + length], original);
            if index < 2 {
                assert_eq!(&input[offset + 56..offset + length], &suffix);
            }
            descriptor += 40 + values[index].2.len();
            source_offset += length;
        }
        assert_eq!(u64_at(&bytes, 40), input.len() as u64);
        assert_eq!(&bytes[bytes.len() - 5..], b"tail\0");
    }
}

#[test]
fn dc_state_records_receive_normalized_payloads() {
    let records = [
        record(0x001e, &[]),           // SaveDC.
        record(0x0127, &[0xff, 0xff]), // RestoreDC.
        record(0x0105, &[0xde, 0xad]), // Reserved SetRelAbs.
        record(0, &[]),
    ];
    let bytes = unsafe { snapshot(parse(&source(&records, b""))) };
    let values = payloads(&bytes);
    assert_eq!(values[0], (0x001e, 13, vec![]));
    assert_eq!(values[1], (0x0127, 13, (-1i32).to_le_bytes().to_vec()));
    assert_eq!(values[2], (0x0105, 13, vec![]));
    assert_eq!(values[3], (0, 1, vec![]));
}

#[test]
fn text_rectangle_padding_spacing_and_unconsumed_suffix_are_preserved() {
    let text = record(
        0x0a32,
        &[
            0xfe, 0xff, 3, 0, 1, 0, 2, 0, 1, 0, 2, 0, 3, 0, 4, 0, b'X', 0xab, 0xff, 0xff, 0xcd,
            0xef,
        ],
    );
    let bytes = unsafe { snapshot(parse(&source(&[text, record(0, &[])], b""))) };
    let values = payloads(&bytes);
    let p = &values[0].2;
    assert_eq!(values[0].1, 5);
    assert_eq!(u32_at(p, 0), 3);
    assert_eq!(u32_at(p, 4), (-2i32) as u32);
    assert_eq!(
        (u64_at(p, 16), u64_at(p, 24), u64_at(p, 32), u64_at(p, 40)),
        (1, 1, 1, 2)
    );
    assert_eq!(u32_at(p, 56), 1);
    assert_eq!(&p[72..74], &[b'X', 0xab]);
    assert_eq!(u32_at(p, 74), u32::MAX);
    assert_eq!(&p[78..], &[0xcd, 0xef]);
}
#[test]
fn edited_snapshots_use_current_header_spans_and_typed_values() {
    unsafe {
        let doc = parse(&source(
            &[record(0x0103, &[8, 0]), record(0, &[])],
            b"extra",
        ));
        assert_eq!(
            emf_wmf_replace_record(
                doc,
                0,
                0x0214,
                [4, 0, 0xfb, 0xff].as_ptr(),
                4,
                ptr::null_mut()
            ),
            EMF_OK
        );
        let bytes = snapshot(doc);
        let values = payloads(&bytes);
        assert_eq!(u32_at(&bytes, 60), 17); // Rebuilt WMF size in words.
        assert_eq!(u64_at(&bytes, 168 + 8), 28); // EOF offset follows enlarged record.
        assert_eq!(values[0].1, 2);
        assert_eq!(u32_at(&values[0].2, 4), (-5i32) as u32);
        assert_eq!(&bytes[bytes.len() - 5..], b"extra");
    }
}
#[test]
fn malformed_diagnostics_survive_and_null_outputs_are_cleared() {
    unsafe {
        let mut input = source(&[record(0x0214, &[]), record(0, &[])], b"");
        input[4..6].copy_from_slice(&0x101u16.to_le_bytes());
        let bytes = snapshot(parse(&input));
        assert_eq!(u64_at(&bytes, 24), 2);
        let offset = 120 + 80;
        assert_eq!(u32_at(&bytes, offset), 1);
        assert_eq!(u32_at(&bytes, offset + 4), 0);
        assert_eq!(u32_at(&bytes, offset + 12), 0);
        assert_eq!(u64_at(&bytes, offset + 16), 4);
        assert_eq!(u64_at(&bytes, offset + 24), 0x101);
        assert_eq!(u64_at(&bytes, offset + 32), 0);
        assert_eq!(u32_at(&bytes, offset + 40), 10);
        assert_eq!(u32_at(&bytes, offset + 44), 1);
        assert_eq!(u32_at(&bytes, offset + 48), 0x0214);
        assert_eq!(u32_at(&bytes, offset + 52), 0);
        assert_eq!(u64_at(&bytes, offset + 56), 18);
        assert_eq!(u64_at(&bytes, offset + 64), 0);
        assert_eq!(u64_at(&bytes, offset + 72), 0);
        let mut buffer = std::ptr::NonNull::<EmfBuffer>::dangling().as_ptr();
        let mut error = ptr::null_mut();
        assert_eq!(
            emf_wmf_document_snapshot(ptr::null(), &mut buffer, &mut error),
            EMF_INVALID_ARGUMENT
        );
        assert!(buffer.is_null());
        assert!(!error.is_null());
        emf_error_free(error);
        assert_eq!(
            emf_wmf_document_snapshot(ptr::null(), ptr::null_mut(), ptr::null_mut()),
            EMF_INVALID_ARGUMENT
        );
    }
}

#[test]
fn version100_dib_diagnostic_preserves_wire_details_and_source() {
    let mut body = vec![0; 16]; // DIBBITBLT fields precede a valid 1-bit DIB.
    body.extend_from_slice(&[
        12, 0, 0, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 255, 255, 255, 0x80, 0, 0, 0,
    ]);
    for version in [0x0100u16, 0x0300] {
        let mut input = source(&[record(0x0940, &body), record(0, &[])], b"tail\0");
        input[4..6].copy_from_slice(&version.to_le_bytes());
        unsafe {
            let doc = parse(&input);
            let mut buffer = ptr::null_mut();
            assert_eq!(emf_wmf_serialize(doc, &mut buffer, ptr::null_mut()), EMF_OK);
            let mut data = ptr::null();
            let mut length = 0;
            assert_eq!(emf_buffer_view(buffer, &mut data, &mut length), EMF_OK);
            assert_eq!(slice::from_raw_parts(data, length as usize), input);
            emf_buffer_free(buffer);

            let bytes = snapshot(doc);
            assert_eq!(u32_at(&bytes, 56), u32::from(version));
            assert_eq!(u64_at(&bytes, 24), u64::from(version == 0x0100));
            let mut expected = vec![0; 32]; // Eight scalar fields, including reserved.
            expected.extend_from_slice(&1u32.to_le_bytes());
            expected.extend_from_slice(&((body.len() - 16) as u32).to_le_bytes());
            expected.extend_from_slice(&body[16..]);
            let payload_length = expected.len();
            assert_eq!(payloads(&bytes), [(0x0940, 11, expected), (0, 1, vec![])]);
            assert_eq!(u64_at(&bytes, 128), 18); // DIB source offset.
            assert_eq!(u64_at(&bytes, 136), 6 + body.len() as u64);
            assert_eq!(&bytes[bytes.len() - 5..], b"tail\0");
            if version == 0x0100 {
                let offset = 120 + 80 + payload_length;
                assert_eq!(u32_at(&bytes, offset), 12);
                assert_eq!(u32_at(&bytes, offset + 4), 1);
                assert_eq!(u32_at(&bytes, offset + 8), 0x0940);
                assert_eq!(u32_at(&bytes, offset + 12), 0);
                assert_eq!(u64_at(&bytes, offset + 16), 18);
                assert_eq!(u64_at(&bytes, offset + 24), 0x0100);
                assert_eq!(u64_at(&bytes, offset + 32), 0);
            }
        }
    }
}

#[test]
fn palette_fields_are_unsigned_in_wire_order_and_preserve_complete_source_spans() {
    let cases: [(u16, &[u8], &[u32]); 10] = [
        (
            0x00f7,
            &[0, 3, 2, 0, 0xff, 0x80, 0, 0xfe, 1, 2, 3, 4],
            &[0x0300, 2, 0xff, 0x80, 0, 0xfe, 1, 2, 3, 4],
        ),
        (
            0xab37,
            &[0xff, 0xff, 1, 0, 0x81, 0x82, 0x83, 0xff],
            &[0xffff, 1, 0x81, 0x82, 0x83, 0xff],
        ),
        (
            0xcd36,
            &[0, 0x80, 1, 0, 0xfe, 0xfd, 0xfc, 0xfb],
            &[0x8000, 1, 0xfe, 0xfd, 0xfc, 0xfb],
        ),
        (0xeff7, &[0xff, 0xff, 0, 0], &[0xffff, 0]),
        (0x0037, &[0, 0x80, 0, 0], &[0x8000, 0]),
        (0x0036, &[0, 0, 0, 0], &[0, 0]),
        (0xab34, &[0xff, 0xff], &[0xffff]),
        (0xcd39, &[0xff, 0xff], &[0xffff]),
        (0xef35, &[], &[]),
        (0x0035, &[], &[]),
    ];
    let suffix = [0xde, 0xad, 0xbe, 0xef];
    let mut records: Vec<_> = cases
        .iter()
        .map(|(function, prefix, _)| {
            let mut body = prefix.to_vec();
            body.extend_from_slice(&suffix);
            record(*function, &body)
        })
        .collect();
    // Malformed arrays/scalars and unrelated states remain opaque.
    records.extend([
        record(0x00f7, &[0, 3]),
        record(0x0037, &[0, 0, 2, 0, 1, 2, 3, 4]),
        record(0x0036, &[0, 0, 0xff, 0xff]),
        record(0x0234, &[]),
        record(0x0139, &[]),
        record(0x001e, &[]),
        record(0x7777, &[0x80, 0xff]),
        record(0, &[]),
    ]);
    let input = source(&records, b"palette-tail\0");
    unsafe {
        let doc = parse(&input);
        let mut buffer = ptr::null_mut();
        assert_eq!(emf_wmf_serialize(doc, &mut buffer, ptr::null_mut()), EMF_OK);
        let mut data = ptr::null();
        let mut length = 0;
        assert_eq!(emf_buffer_view(buffer, &mut data, &mut length), EMF_OK);
        assert_eq!(slice::from_raw_parts(data, length as usize), input);
        emf_buffer_free(buffer);

        let bytes = snapshot(doc);
        let values = payloads(&bytes);
        for (index, (function, _, expected)) in cases.iter().enumerate() {
            assert_eq!(
                values[index],
                (
                    u32::from(*function),
                    8,
                    expected.iter().flat_map(|n| n.to_le_bytes()).collect()
                )
            );
        }
        for value in &values[cases.len()..values.len() - 1] {
            assert_eq!(value.1, if value.0 == 0x001e { 13 } else { 0 });
            assert!(value.2.is_empty());
        }
        assert_eq!(values.last().unwrap(), &(0, 1, vec![]));
        let mut descriptor = 120;
        let mut source_offset = 18;
        for (index, original) in records.iter().enumerate() {
            let offset = u64_at(&bytes, descriptor + 8) as usize;
            let length = u64_at(&bytes, descriptor + 16) as usize;
            assert_eq!(offset, source_offset);
            assert_eq!(length, original.len());
            assert_eq!(&input[offset..offset + length], original);
            if index < cases.len() {
                assert_eq!(
                    &input[offset + 6 + cases[index].1.len()..offset + length],
                    suffix
                );
            }
            descriptor += 40 + values[index].2.len();
            source_offset += length;
        }
        assert_eq!(u64_at(&bytes, 40), input.len() as u64);
        assert_eq!(&bytes[bytes.len() - 13..], b"palette-tail\0");
    }
}

#[test]
fn palette_entry_count_reaches_unsigned_wire_maximum() {
    let mut body = vec![0xff, 0xff, 0xff, 0xff];
    for index in 0..u16::MAX {
        body.extend_from_slice(&[index as u8, (index >> 8) as u8, 0x80, 0xff]);
    }
    let input = source(&[record(0x00f7, &body), record(0, &[])], b"");
    let bytes = unsafe { snapshot(parse(&input)) };
    let values = payloads(&bytes);
    let payload = &values[0].2;
    assert_eq!(values[0].1, 8);
    assert_eq!(payload.len(), 8 + 16 * usize::from(u16::MAX));
    assert_eq!(u32_at(payload, 0), 0xffff);
    assert_eq!(u32_at(payload, 4), 0xffff);
    for index in 0..usize::from(u16::MAX) {
        let offset = 8 + 16 * index;
        assert_eq!(u32_at(payload, offset), (index & 0xff) as u32);
        assert_eq!(u32_at(payload, offset + 4), (index >> 8) as u32);
        assert_eq!(u32_at(payload, offset + 8), 0x80);
        assert_eq!(u32_at(payload, offset + 12), 0xff);
    }
    assert_eq!(values[1], (0, 1, vec![]));
}

fn region_words(values: &[u16]) -> Vec<u8> {
    values.iter().flat_map(|v| v.to_le_bytes()).collect()
}

fn nested_region_body() -> Vec<u8> {
    // Header22 + scan12 + scan16 + empty scan8 = 58 bytes.
    region_words(&[
        0xffff, 6, 0xffff, 0xffff, 58, 3, 4, 0x8000, 0xffff, 0x7fff, 0, 2, 0x8000, 0xffff, 0x8001,
        0xffff, 2, 4, 0, 0x7fff, 0, 1, 0xfffe, 0xffff, 4, 0, 0xffff, 0x8000, 0,
    ])
}

#[test]
fn region_and_clipping_fields_preserve_nested_wire_order_and_source_spans() {
    let cases: Vec<(u16, Vec<u8>, Vec<u32>)> = vec![
        (
            0x7fff,
            nested_region_body(),
            vec![
                0xffff,
                u32::MAX,
                (-32768i32) as u32,
                u32::MAX,
                32767,
                0,
                3,
                0x8000,
                0xffff,
                1,
                0x8001,
                0xffff,
                0,
                0x7fff,
                2,
                0,
                1,
                0xfffe,
                0xffff,
                0xffff,
                0x8000,
                0,
            ],
        ),
        (
            0xab28,
            region_words(&[0xffff, 0x8000]),
            vec![0xffff, 0x8000],
        ),
        (
            0xcd29,
            region_words(&[0x8001, 0xffff, 0x8000, 0x7fff]),
            vec![0x8001, 0xffff, (-32768i32) as u32, 32767],
        ),
        (0xef2a, region_words(&[0xffff]), vec![0xffff]),
        (0x002b, region_words(&[0x8000]), vec![0x8000]),
        (0xab2c, region_words(&[0xffff]), vec![0xffff]),
        (
            0xcd20,
            region_words(&[0x8000, 0x7fff]),
            vec![(-32768i32) as u32, 32767],
        ),
        (
            0xef15,
            region_words(&[0x8000, 0xffff, 0x7fff, 0]),
            vec![(-32768i32) as u32, u32::MAX, 32767, 0],
        ),
        (
            0x0016,
            region_words(&[0x7fff, 0, 0xffff, 0x8000]),
            vec![32767, 0, u32::MAX, (-32768i32) as u32],
        ),
        (
            0x00ff,
            region_words(&[0, 6, 0, 0, 22, 0, 0, 0, 0, 0, 0]),
            vec![0, 0, 0, 0, 0, 0, 0],
        ),
    ];
    let suffix = [0xde, 0xad, 0xbe, 0xef];
    let mut records: Vec<_> = cases
        .iter()
        .map(|(function, prefix, _)| {
            let mut body = prefix.clone();
            body.extend_from_slice(&suffix);
            record(*function, &body)
        })
        .collect();
    records.extend([
        record(0x001e, &[]),
        record(0x7777, &[0x80, 0xff]),
        record(0, &[]),
    ]);
    let input = source(&records, b"region-tail\0");
    unsafe {
        let doc = parse(&input);
        let mut buffer = ptr::null_mut();
        assert_eq!(emf_wmf_serialize(doc, &mut buffer, ptr::null_mut()), EMF_OK);
        let mut data = ptr::null();
        let mut length = 0;
        assert_eq!(emf_buffer_view(buffer, &mut data, &mut length), EMF_OK);
        assert_eq!(slice::from_raw_parts(data, length as usize), input);
        emf_buffer_free(buffer);
        let bytes = snapshot(doc);
        let values = payloads(&bytes);
        for (index, (function, _, expected)) in cases.iter().enumerate() {
            assert_eq!(
                values[index],
                (
                    u32::from(*function),
                    9,
                    expected.iter().flat_map(|n| n.to_le_bytes()).collect()
                )
            );
        }
        assert_eq!(values[cases.len()], (0x001e, 13, vec![]));
        assert_eq!(values[cases.len() + 1], (0x7777, 0, vec![]));
        assert_eq!(values.last().unwrap(), &(0, 1, vec![]));
        let mut descriptor = 120;
        let mut source_offset = 18;
        for (index, original) in records.iter().enumerate() {
            let offset = u64_at(&bytes, descriptor + 8) as usize;
            let length = u64_at(&bytes, descriptor + 16) as usize;
            assert_eq!(offset, source_offset);
            assert_eq!(length, original.len());
            assert_eq!(&input[offset..offset + length], original);
            if index < cases.len() {
                assert_eq!(
                    &input[offset + 6 + cases[index].1.len()..offset + length],
                    suffix
                );
            }
            descriptor += 40 + values[index].2.len();
            source_offset += length;
        }
        assert_eq!(u64_at(&bytes, 40), input.len() as u64);
        assert_eq!(&bytes[bytes.len() - 12..], b"region-tail\0");
    }
}

#[test]
fn region_nested_counts_reach_signed_wire_size_boundary() {
    // Largest single scan and largest scan array that fit signed RegionSize.
    for (scans, lines) in [(1u16, 8184u16), (4093, 0)] {
        let points = lines * 2;
        let mut body = region_words(&[
            0xffff, 6, 0xffff, 0xffff, 32766, scans, points, 0x8000, 0xffff, 0x7fff, 0,
        ]);
        let mut expected = vec![
            0xffff,
            u32::MAX,
            (-32768i32) as u32,
            u32::MAX,
            32767,
            0,
            u32::from(scans),
        ];
        for _ in 0..scans {
            body.extend(region_words(&[points, 0x8000, 0xffff]));
            expected.extend([0x8000, 0xffff, u32::from(lines)]);
            for line in 0..lines {
                body.extend(region_words(&[line, 0xffff]));
                expected.extend([u32::from(line), 0xffff]);
            }
            body.extend_from_slice(&points.to_le_bytes());
        }
        assert_eq!(body.len(), 32766);
        body.extend_from_slice(&[0xaa, 0xbb]);
        let input = source(&[record(0x06ff, &body), record(0, &[])], b"");
        let bytes = unsafe { snapshot(parse(&input)) };
        let values = payloads(&bytes);
        assert_eq!((values[0].0, values[0].1), (0x06ff, 9));
        assert_eq!(values[0].2.len(), expected.len() * 4);
        for (index, value) in expected.iter().enumerate() {
            assert_eq!(u32_at(&values[0].2, index * 4), *value, "field {index}");
        }
        assert_eq!(values[1], (0, 1, vec![]));
        assert_eq!(u64_at(&bytes, 136), (body.len() + 6) as u64);
    }
}

#[test]
fn malformed_region_and_clipping_records_stay_opaque_without_hiding_eof() {
    let mut records = Vec::new();
    for (offset, value) in [
        (2, 5u16),
        (8, 21),
        (8, 56),
        (8, 60),
        (8, 0x8000),
        (10, 0xffff),
        (10, 4),
        (12, 2),
        (12, 0x8000),
        (22, 3),
        (22, 200),
        (32, 4),
    ] {
        let mut body = nested_region_body();
        body[offset..offset + 2].copy_from_slice(&value.to_le_bytes());
        records.push(record(0xabff, &body));
    }
    for (function, size) in [
        (0x06ff, 20),
        (0x0228, 2),
        (0x0429, 6),
        (0x012a, 0),
        (0x012b, 0),
        (0x012c, 0),
        (0x0220, 2),
        (0x0415, 6),
        (0x0416, 6),
    ] {
        records.push(record(function, &vec![0; size]));
    }
    records.push(record(0, &[]));
    let input = source(&records, b"tail");
    let bytes = unsafe { snapshot(parse(&input)) };
    let values = payloads(&bytes);
    for value in &values[..values.len() - 1] {
        assert_eq!(value.1, 0);
        assert!(value.2.is_empty());
    }
    assert_eq!(values.last().unwrap(), &(0, 1, vec![]));
    assert_eq!(&bytes[bytes.len() - 4..], b"tail");
}

fn pattern_brush_body(width: i16, height: i16, stride: i16, bpp: u8) -> Vec<u8> {
    let mut body: Vec<_> = [i16::MIN, width, height, stride]
        .iter()
        .flat_map(|n| n.to_le_bytes())
        .collect();
    body.extend_from_slice(&[1, bpp, 0, 0xff, 0x80, 0x7f]);
    body.extend(0x80..0x92);
    let length = (width as usize * usize::from(bpp)).div_ceil(16) * 2 * height as usize;
    body.extend((0..length).map(|n| n as u8));
    body
}

#[test]
fn pattern_brush_payloads_preserve_signed_headers_raw_fields_and_source_suffix() {
    let suffix = [0xde, 0xad, 0xbe, 0xef];
    let mut cases = Vec::new();
    for (width, height, stride, bpp) in [
        (1, 1, i16::MIN, 255),
        (i16::MAX, 1, -1, 1),
        (1, i16::MAX, 0, 1),
    ] {
        let mut body = pattern_brush_body(width, height, stride, bpp);
        let mut expected: Vec<_> = [i16::MIN, width, height, stride]
            .iter()
            .flat_map(|n| (*n as i32).to_le_bytes())
            .collect();
        expected.extend_from_slice(&1u32.to_le_bytes());
        expected.extend_from_slice(&u32::from(bpp).to_le_bytes());
        expected.extend_from_slice(&body[10..32]);
        expected.extend_from_slice(&((body.len() - 32) as u32).to_le_bytes());
        expected.extend_from_slice(&body[32..]);
        body.extend_from_slice(&suffix);
        cases.push((0xa7f9, body, expected));
    }
    for (style, usage) in [(3u16, u16::MAX), (u16::MAX, 2), (5, 1), (6, 0)] {
        let target = [0, 0xff, 0x80, 0, 0xfe, 0xff]; // Malformed DIB remains raw and typed.
        let mut body: Vec<_> = [style, usage]
            .iter()
            .flat_map(|n| n.to_le_bytes())
            .collect();
        body.extend_from_slice(&target);
        let mut expected: Vec<_> = [u32::from(style), u32::from(usage), target.len() as u32]
            .iter()
            .flat_map(|n| n.to_le_bytes())
            .collect();
        expected.extend_from_slice(&target);
        cases.push((0xab42, body, expected));
    }
    let mut records: Vec<_> = cases
        .iter()
        .map(|(function, body, _)| record(*function, body))
        .collect();
    records.push(record(0x7777, &[0x80, 0xff]));
    records.push(record(0, &[]));
    let input = source(&records, b"tail\0");
    unsafe {
        let doc = parse(&input);
        let mut buffer = ptr::null_mut();
        assert_eq!(emf_wmf_serialize(doc, &mut buffer, ptr::null_mut()), EMF_OK);
        let mut data = ptr::null();
        let mut length = 0;
        assert_eq!(emf_buffer_view(buffer, &mut data, &mut length), EMF_OK);
        assert_eq!(slice::from_raw_parts(data, length as usize), input);
        emf_buffer_free(buffer);
        let bytes = snapshot(doc);
        let values = payloads(&bytes);
        let mut descriptor = 120;
        let mut source_offset = 18;
        for (index, (function, body, expected)) in cases.iter().enumerate() {
            assert_eq!(values[index], (u32::from(*function), 10, expected.clone()));
            assert_eq!(u64_at(&bytes, descriptor + 8), source_offset as u64);
            assert_eq!(u64_at(&bytes, descriptor + 16), (body.len() + 6) as u64);
            assert_eq!(
                &input[source_offset..source_offset + body.len() + 6],
                records[index]
            );
            if function & 0xff == 0xf9 {
                assert_eq!(&body[body.len() - 4..], suffix);
                assert_eq!(expected.len(), 50 + body.len() - 32 - suffix.len());
            }
            descriptor += 40 + expected.len();
            source_offset += body.len() + 6;
        }
        assert_eq!(values[cases.len()], (0x7777, 0, vec![]));
        assert_eq!(values[cases.len() + 1], (0, 1, vec![]));
        assert_eq!(u64_at(&bytes, 40), input.len() as u64);
        assert_eq!(&bytes[bytes.len() - 5..], b"tail\0");
    }
}

#[test]
fn malformed_pattern_brush_headers_remain_opaque_with_complete_spans() {
    let valid = pattern_brush_body(1, 1, -1, 1);
    let mut records = Vec::new();
    for (offset, word) in [(2, 0u16), (2, 0x8000), (4, 0), (4, 0xffff)] {
        let mut body = valid.clone();
        body[offset..offset + 2].copy_from_slice(&word.to_le_bytes());
        records.push(record(0x01f9, &body));
    }
    for (offset, byte) in [(8, 0), (8, 2), (9, 0)] {
        let mut body = valid.clone();
        body[offset] = byte;
        records.push(record(0x01f9, &body));
    }
    records.push(record(0x01f9, &valid[..30]));
    records.push(record(0x01f9, &valid[..32]));
    records.push(record(0x0142, &[0, 0]));
    records.push(record(0x0142, &[3, 0, 0xff, 0xff]));
    records.push(record(0x0142, &[5, 0, 3, 0, 0, 0]));
    records.push(record(0, &[]));
    let input = source(&records, b"tail");
    let bytes = unsafe { snapshot(parse(&input)) };
    let values = payloads(&bytes);
    let mut offset = 18;
    for (index, value) in values[..values.len() - 1].iter().enumerate() {
        assert_eq!(value.1, 0);
        assert!(value.2.is_empty());
        assert_eq!(u64_at(&bytes, 120 + 40 * index + 8), offset as u64);
        assert_eq!(
            u64_at(&bytes, 120 + 40 * index + 16),
            records[index].len() as u64
        );
        assert_eq!(
            &input[offset..offset + records[index].len()],
            records[index]
        );
        offset += records[index].len();
    }
    assert_eq!(values.last().unwrap(), &(0, 1, vec![]));
    assert_eq!(&bytes[bytes.len() - 4..], b"tail");
}

fn bitmap_case(kind: u16, present: bool) -> (u16, Vec<u8>, Vec<u8>) {
    let signed = [i16::MIN, i16::MAX, -1, 0, -12345, 12345, -2, 2];
    let image = [0, 0xff, 0x80, 0, 0xfe, 0xff]; // Raw malformed interiors stay typed.
    let mut body = Vec::new();
    let mut words = Vec::new();
    if kind == 0x33 {
        for n in [u16::MAX, 0x8000, 0, 0xfffe, 1, 0x8001, 2, 0xfffd, 3] {
            body.extend_from_slice(&n.to_le_bytes());
            words.push(u32::from(n));
        }
    } else {
        body.extend_from_slice(&u32::MAX.to_le_bytes());
        words.push(u32::MAX);
        if kind == 0x43 {
            body.extend_from_slice(&u16::MAX.to_le_bytes());
            words.push(u32::from(u16::MAX));
        }
        let geometry = if matches!(kind, 0x22 | 0x40) {
            &signed[..6]
        } else {
            &signed[..]
        };
        for (index, n) in geometry.iter().enumerate() {
            if !present && index == geometry.len() - 4 {
                body.extend_from_slice(&u16::MAX.to_le_bytes());
            }
            body.extend_from_slice(&n.to_le_bytes());
            words.push(*n as i32 as u32);
        }
        if matches!(kind, 0x22 | 0x40 | 0x23 | 0x41) {
            words.push(if present { 0 } else { u32::from(u16::MAX) });
        }
    }
    words.push(u32::from(present));
    words.push(if present { image.len() as u32 } else { 0 });
    let mut expected: Vec<_> = words.iter().flat_map(|n| n.to_le_bytes()).collect();
    if present {
        body.extend_from_slice(&image);
        expected.extend_from_slice(&image);
    } else {
        body.extend_from_slice(&[0xde, 0xad, 0xbe, 0xef]);
    }
    let function = if present {
        0xa700 | kind
    } else {
        ((body.len() as u16 / 2) << 8) | kind
    };
    (function, body, expected)
}

#[test]
fn bitmap_headers_preserve_signed_unsigned_fields_presence_raw_images_and_source_suffix() {
    let mut cases = Vec::new();
    for kind in [0x22, 0x40, 0x23, 0x41, 0x33, 0x43] {
        cases.push(bitmap_case(kind, true));
        if !matches!(kind, 0x33 | 0x43) {
            cases.push(bitmap_case(kind, false));
        }
    }
    let mut records: Vec<_> = cases
        .iter()
        .map(|(function, body, _)| record(*function, body))
        .collect();
    records.push(record(0x7777, &[0x80, 0xff]));
    records.push(record(0, &[]));
    let input = source(&records, b"tail\0");
    unsafe {
        let doc = parse(&input);
        let mut buffer = ptr::null_mut();
        assert_eq!(emf_wmf_serialize(doc, &mut buffer, ptr::null_mut()), EMF_OK);
        let mut data = ptr::null();
        let mut length = 0;
        assert_eq!(emf_buffer_view(buffer, &mut data, &mut length), EMF_OK);
        assert_eq!(slice::from_raw_parts(data, length as usize), input);
        emf_buffer_free(buffer);
        let bytes = snapshot(doc);
        let values = payloads(&bytes);
        let mut descriptor = 120;
        let mut offset = 18;
        for (index, (function, body, expected)) in cases.iter().enumerate() {
            assert_eq!(values[index], (u32::from(*function), 11, expected.clone()));
            assert_eq!(u64_at(&bytes, descriptor + 8), offset as u64);
            assert_eq!(u64_at(&bytes, descriptor + 16), records[index].len() as u64);
            assert_eq!(
                &input[offset..offset + records[index].len()],
                records[index]
            );
            assert_eq!(&input[offset + 6..offset + records[index].len()], body);
            descriptor += 40 + expected.len();
            offset += records[index].len();
        }
        assert_eq!(values[cases.len()], (0x7777, 0, vec![]));
        assert_eq!(values[cases.len() + 1], (0, 1, vec![]));
        assert_eq!(u64_at(&bytes, 40), input.len() as u64);
        assert_eq!(&bytes[bytes.len() - 5..], b"tail\0");
    }
}

#[test]
fn bitmap_function_high_byte_controls_optional_presence_and_suffix_boundary() {
    for kind in [0x22, 0x40, 0x23, 0x41] {
        let (function, body, expected) = bitmap_case(kind, false);
        let records = [
            record(function, &body),
            record(0xa700 | kind, &body),
            record(0, &[]),
        ];
        let bytes = unsafe { snapshot(parse(&source(&records, &[]))) };
        let values = payloads(&bytes);
        assert_eq!(values[0], (u32::from(function), 11, expected));
        assert_eq!(values[1].1, 11);
        let (presence, prefix) = if matches!(kind, 0x22 | 0x40) {
            (32, 16)
        } else {
            (40, 20)
        };
        assert_eq!(u32_at(&values[0].2, presence), 0);
        assert_eq!(u32_at(&values[0].2, presence + 4), 0);
        assert_eq!(u32_at(&values[1].2, presence - 4), 0); // Present form has no reserved wire word.
        assert_eq!(u32_at(&values[1].2, presence), 1);
        assert_eq!(
            u32_at(&values[1].2, presence + 4),
            (body.len() - prefix) as u32
        );
        assert_eq!(&values[1].2[presence + 8..], &body[prefix..]);
    }
}

#[test]
fn bitmap_truncated_headers_and_empty_required_images_remain_opaque() {
    let mut records = Vec::new();
    for (kind, prefix) in [
        (0x22, 16),
        (0x40, 16),
        (0x23, 20),
        (0x41, 20),
        (0x33, 18),
        (0x43, 22),
    ] {
        let (_, body, _) = bitmap_case(kind, true);
        records.push(record(0xa700 | kind, &body[..prefix - 2]));
        records.push(record(0xa700 | kind, &body[..prefix]));
    }
    records.push(record(0, &[]));
    let input = source(&records, b"tail");
    let bytes = unsafe { snapshot(parse(&input)) };
    let values = payloads(&bytes);
    let mut offset = 18;
    for (index, value) in values[..values.len() - 1].iter().enumerate() {
        assert_eq!(value.1, 0);
        assert!(value.2.is_empty());
        assert_eq!(u64_at(&bytes, 120 + index * 40 + 8), offset as u64);
        assert_eq!(
            u64_at(&bytes, 120 + index * 40 + 16),
            records[index].len() as u64
        );
        offset += records[index].len();
    }
    assert_eq!(values.last().unwrap(), &(0, 1, vec![]));
    assert_eq!(&bytes[bytes.len() - 4..], b"tail");
}

#[test]
fn remaining_geometry_dc_and_escape_preserve_normalized_values_and_source_spans() {
    let signed = vec![(-32768i32) as u32, u32::MAX, 32767, 0];
    let mut cases = vec![
        (
            0xab10,
            region_words(&[0x8000, 0xffff, 0x7fff, 0]),
            12,
            signed.clone(),
        ),
        (
            0xcd12,
            region_words(&[0x8000, 0xffff, 0x7fff, 0]),
            12,
            signed.clone(),
        ),
        (
            0xef19,
            region_words(&[0xffff, 0xffff, 0x8000, 0x7fff]),
            12,
            vec![u32::MAX, (-32768i32) as u32, 32767],
        ),
        (
            0xab1f,
            region_words(&[0xffff, 0x8000, 0xffff, 0x8000]),
            12,
            vec![0x8000ffff, u32::MAX, (-32768i32) as u32],
        ),
        (
            0xcd48,
            region_words(&[1, 0xffff, 0x8000, 0x8000, 0xffff]),
            12,
            vec![1, 0x8000ffff, (-32768i32) as u32, u32::MAX],
        ),
        (
            0xef48,
            region_words(&[0, 0, 0, 0x7fff, 0]),
            12,
            vec![0, 0, 32767, 0],
        ),
        (
            0xab1d,
            region_words(&[0xffff, 0xffff, 0x8000, 0xffff, 0x7fff, 0]),
            12,
            [vec![u32::MAX], signed].concat(),
        ),
        (0xcd1e, vec![], 13, vec![]),
        (
            0xef27,
            region_words(&[0x8000]),
            13,
            vec![(-32768i32) as u32],
        ),
        (0xab27, region_words(&[0x7fff]), 13, vec![32767]),
        (0xcd05, vec![], 13, vec![]),
    ]
    .into_iter()
    .map(|(f, body, family, words)| {
        (
            f,
            body,
            family,
            words
                .iter()
                .flat_map(|n| n.to_le_bytes())
                .collect::<Vec<_>>(),
        )
    })
    .collect::<Vec<_>>();
    // Unknown subfunctions and malformed subtype interiors remain inert raw data.
    for data in [
        vec![],
        vec![0, 0xff],
        vec![0, 0xff, 0x80],
        vec![0xff; 65535],
    ] {
        let mut body = region_words(&[0xffff, data.len() as u16]);
        body.extend_from_slice(&data);
        if data.len() % 2 != 0 {
            body.push(0xa7);
        }
        let mut expected = 0xffffu32.to_le_bytes().to_vec();
        expected.extend_from_slice(&(data.len() as u64).to_le_bytes());
        expected.extend_from_slice(&data);
        cases.push((0xef26, body, 13, expected));
    }
    let suffix = [0xde, 0xad, 0xbe, 0xef];
    let mut records = cases
        .iter()
        .map(|(f, body, _, _)| {
            let mut body = body.clone();
            body.extend_from_slice(&suffix);
            record(*f, &body)
        })
        .collect::<Vec<_>>();
    records.extend([record(0x7777, &[0x80, 0xff]), record(0, &[])]);
    let input = source(&records, b"remaining-tail\0");
    unsafe {
        let doc = parse(&input);
        let mut buffer = ptr::null_mut();
        assert_eq!(emf_wmf_serialize(doc, &mut buffer, ptr::null_mut()), EMF_OK);
        let mut data = ptr::null();
        let mut length = 0;
        assert_eq!(emf_buffer_view(buffer, &mut data, &mut length), EMF_OK);
        assert_eq!(slice::from_raw_parts(data, length as usize), input);
        emf_buffer_free(buffer);
        let bytes = snapshot(doc);
        let values = payloads(&bytes);
        let mut descriptor = 120;
        let mut offset = 18;
        for (index, (f, body, family, expected)) in cases.iter().enumerate() {
            assert_eq!(values[index], (u32::from(*f), *family, expected.clone()));
            assert_eq!(u64_at(&bytes, descriptor + 8), offset as u64);
            assert_eq!(u64_at(&bytes, descriptor + 16), records[index].len() as u64);
            assert_eq!(
                &input[offset..offset + records[index].len()],
                records[index]
            );
            assert_eq!(
                &input[offset + 6 + body.len()..offset + records[index].len()],
                suffix
            );
            descriptor += 40 + expected.len();
            offset += records[index].len();
        }
        assert_eq!(values[cases.len()], (0x7777, 0, vec![]));
        assert_eq!(values.last().unwrap(), &(0, 1, vec![]));
        assert_eq!(&bytes[bytes.len() - 15..], b"remaining-tail\0");
    }
}

#[test]
fn remaining_malformed_records_stay_opaque_and_leave_following_records_visible() {
    let mut records = Vec::new();
    for (function, minimum) in [
        (0x0410, 8),
        (0x0412, 8),
        (0x0419, 8),
        (0x041f, 8),
        (0x0548, 10),
        (0x061d, 12),
        (0x0127, 2),
    ] {
        for size in (0..minimum).step_by(2) {
            records.push(record(function, &vec![0; size]));
        }
    }
    records.push(record(0x0548, &region_words(&[2, 0, 0, 0, 0])));
    for body in [
        vec![],
        region_words(&[0xffff]),
        region_words(&[0xffff, 3]),
        region_words(&[0xffff, 3, 0x80ff]),
        region_words(&[0xffff, 0xffff, 0, 0]),
    ] {
        records.push(record(0xab26, &body));
    }
    records.extend([record(0x001e, &[]), record(0, &[])]);
    let input = source(&records, b"tail");
    let bytes = unsafe { snapshot(parse(&input)) };
    let values = payloads(&bytes);
    let mut offset = 18;
    for (index, value) in values[..values.len() - 2].iter().enumerate() {
        assert_eq!(
            *value,
            (
                u32::from(u16::from_le_bytes(records[index][4..6].try_into().unwrap())),
                0,
                vec![]
            )
        );
        assert_eq!(u64_at(&bytes, 120 + index * 40 + 8), offset as u64);
        assert_eq!(
            u64_at(&bytes, 120 + index * 40 + 16),
            records[index].len() as u64
        );
        offset += records[index].len();
    }
    assert_eq!(values[values.len() - 2], (0x001e, 13, vec![]));
    assert_eq!(values.last().unwrap(), &(0, 1, vec![]));
    assert_eq!(&bytes[bytes.len() - 4..], b"tail");
}
