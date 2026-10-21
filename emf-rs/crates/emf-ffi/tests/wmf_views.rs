use emf_ffi::*;
use std::{ptr, slice};

fn record(function: u16, body: &[u8]) -> Vec<u8> {
    assert_eq!(body.len() % 2, 0);
    let mut bytes = ((body.len() as u32 + 6) / 2).to_le_bytes().to_vec();
    bytes.extend_from_slice(&function.to_le_bytes());
    bytes.extend_from_slice(body);
    bytes
}
fn source(records: &[Vec<u8>]) -> Vec<u8> {
    let mut all = records.to_vec();
    all.push(record(0, &[]));
    let mut bytes = vec![1, 0, 9, 0, 0, 3];
    bytes.extend_from_slice(
        &(9 + all.iter().map(|r| r.len() as u32 / 2).sum::<u32>()).to_le_bytes(),
    );
    bytes.extend_from_slice(&2u16.to_le_bytes());
    bytes.extend_from_slice(
        &all.iter()
            .map(|r| r.len() as u32 / 2)
            .max()
            .unwrap()
            .to_le_bytes(),
    );
    bytes.extend_from_slice(&0u16.to_le_bytes());
    for r in &all {
        bytes.extend_from_slice(r);
    }
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
unsafe fn take(status: i32, buffer: *mut EmfBuffer) -> Vec<u8> {
    assert_eq!(status, EMF_OK);
    let (mut data, mut length) = (ptr::null(), 0);
    assert_eq!(emf_buffer_view(buffer, &mut data, &mut length), EMF_OK);
    let bytes = slice::from_raw_parts(data, length as usize).to_vec();
    emf_buffer_free(buffer);
    bytes
}
unsafe fn view(doc: *const WmfDocument, index: u64) -> Vec<u8> {
    let mut buffer = ptr::null_mut();
    let status = emf_wmf_record_view(doc, index, ptr::null(), &mut buffer, ptr::null_mut());
    take(status, buffer)
}
unsafe fn embedded(doc: *const WmfDocument) -> Vec<u8> {
    let mut buffer = ptr::null_mut();
    let status = emf_wmf_embedded_emf(doc, ptr::null(), &mut buffer, ptr::null_mut());
    take(status, buffer)
}
fn escape(subtype: u16, data: &[u8]) -> Vec<u8> {
    let mut body = subtype.to_le_bytes().to_vec();
    body.extend_from_slice(&(data.len() as u16).to_le_bytes());
    body.extend_from_slice(data);
    if data.len() % 2 == 1 {
        body.push(0xA5);
    }
    record(0x0626, &body)
}
fn header(entries: u32) -> Vec<u8> {
    let mut bytes = b"WMFV".to_vec();
    bytes.extend_from_slice(&1u32.to_le_bytes());
    bytes.extend_from_slice(&entries.to_le_bytes());
    bytes
}

#[test]
fn bitmap_views_are_tagged_and_malformed_interiors_are_empty() {
    let rop = [0x98, 0xBA, 0xDC, 0xFE];
    let coords = [0u8; 12];
    let bitmap16: Vec<u8> = [0i16, 1, 1, 2]
        .iter()
        .flat_map(|n| n.to_le_bytes())
        .chain([1, 1, 0xAB, 0xCD])
        .collect();
    let present = [&rop[..], &coords, &bitmap16].concat();
    let absent = [&rop[..], &coords[..8], &[0xFE, 0xCA], &coords[8..]].concat();
    let junk = [&rop[..], &coords, b"junk"].concat();
    let bytes = source(&[
        record(0x0922, &present),
        record(0x0922, &absent),
        record(0x0922, &junk),
    ]);
    unsafe {
        let doc = parse(&bytes);
        let mut expected = header(1);
        expected.extend_from_slice(&2u32.to_le_bytes());
        for n in [0i32, 1, 1, 2, 1, 1] {
            expected.extend_from_slice(&n.to_le_bytes());
        }
        expected.extend_from_slice(&2u64.to_le_bytes());
        expected.extend_from_slice(&[0xAB, 0xCD]);
        expected.extend_from_slice(&0u64.to_le_bytes());
        assert_eq!(view(doc, 0), expected);
        let mut absent_view = header(1);
        absent_view.extend_from_slice(&1u32.to_le_bytes());
        assert_eq!(view(doc, 1), absent_view);
        assert_eq!(view(doc, 2), header(0));
        assert_eq!(view(doc, 3), header(0), "EOF has no view");
        emf_wmf_document_free(doc);
    }
}

#[test]
fn escape_views_carry_codes_and_exact_bytes() {
    let mut passthrough = 0xAABBCCDDu32.to_le_bytes().to_vec();
    passthrough.extend_from_slice(&[3, 0]);
    passthrough.extend_from_slice(b"xyz");
    let bytes = source(&[
        escape(0x0015, &(-2i32).to_le_bytes()),
        escape(0x0013, b"abc"),
        escape(0x11D8, &passthrough),
        escape(0x7777, b"ab"),
    ]);
    unsafe {
        let doc = parse(&bytes);
        let mut fixed = header(1);
        fixed.extend_from_slice(&4u32.to_le_bytes());
        fixed.extend_from_slice(&0x15u32.to_le_bytes());
        fixed.extend_from_slice(&1u64.to_le_bytes());
        fixed.extend_from_slice(&(-2i64).to_le_bytes());
        assert_eq!(view(doc, 0), fixed);
        let mut counted = header(1);
        counted.extend_from_slice(&5u32.to_le_bytes());
        counted.extend_from_slice(&0x13u32.to_le_bytes());
        counted.extend_from_slice(&3u64.to_le_bytes());
        counted.extend_from_slice(b"abc");
        assert_eq!(view(doc, 1), counted);
        let mut spcl = header(1);
        spcl.extend_from_slice(&6u32.to_le_bytes());
        spcl.extend_from_slice(&0xAABBCCDDu32.to_le_bytes());
        spcl.extend_from_slice(&3u64.to_le_bytes());
        spcl.extend_from_slice(b"xyz");
        assert_eq!(view(doc, 2), spcl);
        assert_eq!(view(doc, 3), header(0));
        emf_wmf_document_free(doc);
    }
}

#[test]
fn embedded_emf_segment_errors_and_sequences_are_reported() {
    let mut metadata = Vec::new();
    for n in [0x4346_4D57u32, 1, 0x0001_0000] {
        metadata.extend_from_slice(&n.to_le_bytes());
    }
    metadata.extend_from_slice(&0u16.to_le_bytes());
    for n in [0u32, 1, 4, 0, 4] {
        metadata.extend_from_slice(&n.to_le_bytes());
    }
    let mut data = metadata.clone();
    data.extend_from_slice(b"abcd");
    let mut bad = data.clone();
    bad[0] = 0;
    let bytes = source(&[escape(0x000F, &data), escape(0x000F, &bad)]);
    unsafe {
        let doc = parse(&bytes);
        let first = view(doc, 0);
        assert_eq!(&first[..12], &header(1)[..]);
        assert_eq!(u32::from_le_bytes(first[12..16].try_into().unwrap()), 7);
        let mut error = header(1);
        error.extend_from_slice(&8u32.to_le_bytes());
        error.extend_from_slice(&4u32.to_le_bytes());
        assert_eq!(view(doc, 1), error);
        let sequences = embedded(doc);
        let u64_at = |at: usize| u64::from_le_bytes(sequences[at..at + 8].try_into().unwrap());
        let u32_at = |at: usize| u32::from_le_bytes(sequences[at..at + 4].try_into().unwrap());
        assert_eq!(&sequences[..4], b"WMFE");
        assert_eq!(
            u64_at(8),
            2,
            "a complete run ends before the failing escape"
        );
        assert_eq!((u64_at(16), u64_at(24), u32_at(32)), (0, 1, 1));
        // First sequence: version, checksum, valid flag, length 4 and bytes, then sequence two.
        let second = 36 + 12 + 8 + 4;
        assert_eq!((u64_at(second), u64_at(second + 8)), (1, 1));
        assert_eq!(
            (u32_at(second + 16), u32_at(second + 20)),
            (0, 4),
            "CommentIdentifier"
        );
        emf_wmf_document_free(doc);
    }
}

#[test]
fn invalid_arguments_are_status_errors() {
    let bytes = source(&[escape(0x0013, b"ab")]);
    unsafe {
        let doc = parse(&bytes);
        let mut buffer = ptr::null_mut();
        assert_ne!(
            emf_wmf_record_view(doc, 99, ptr::null(), &mut buffer, ptr::null_mut()),
            EMF_OK
        );
        assert!(buffer.is_null());
        assert_ne!(
            emf_wmf_record_view(ptr::null(), 0, ptr::null(), &mut buffer, ptr::null_mut()),
            EMF_OK
        );
        assert_ne!(
            emf_wmf_embedded_emf(doc, ptr::null(), ptr::null_mut(), ptr::null_mut()),
            EMF_OK
        );
        emf_wmf_document_free(doc);
    }
}
