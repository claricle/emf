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
        record(0x0103, &[8, 0]), // Rust knows this state record, Ruby keeps it opaque.
        record(0x7777, &[0x80, 0xff]),
        record(0, &[]),
    ];
    let input = source(&records, b"tail\0");
    let bytes = unsafe { snapshot(parse(&input)) };
    let values = payloads(&bytes);
    assert_eq!(
        values.iter().map(|v| v.1).collect::<Vec<_>>(),
        [2, 3, 4, 0, 0, 1]
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
            assert_eq!(payloads(&bytes), [(0x0940, 0, vec![]), (0, 1, vec![])]);
            assert_eq!(u64_at(&bytes, 128), 18); // DIB source offset.
            assert_eq!(u64_at(&bytes, 136), 6 + body.len() as u64);
            assert_eq!(&bytes[bytes.len() - 5..], b"tail\0");
            if version == 0x0100 {
                let offset = 120 + 80; // Both record payloads are empty.
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
