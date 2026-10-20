use emf_ffi::*;
use std::{ptr, slice};

fn u32_at(bytes: &[u8], offset: usize) -> u32 {
    u32::from_le_bytes(bytes[offset..offset + 4].try_into().unwrap())
}
fn u64_at(bytes: &[u8], offset: usize) -> u64 {
    u64::from_le_bytes(bytes[offset..offset + 8].try_into().unwrap())
}
fn words(values: &[u32]) -> Vec<u8> {
    values.iter().flat_map(|v| v.to_le_bytes()).collect()
}

// Exercise the public ownership boundary: document and input die before inspection.
fn snapshot(input: Vec<u8>) -> Vec<u8> {
    unsafe {
        let mut document = ptr::null_mut();
        let mut buffer = ptr::null_mut();
        assert_eq!(
            emf_parse(
                input.as_ptr(),
                input.len() as u64,
                ptr::null(),
                &mut document,
                ptr::null_mut()
            ),
            EMF_OK
        );
        assert_eq!(
            emf_document_snapshot(document, &mut buffer, ptr::null_mut()),
            EMF_OK
        );
        emf_document_free(document);
        drop(input);
        let mut data = ptr::null();
        let mut len = 0;
        assert_eq!(emf_buffer_view(buffer, &mut data, &mut len), EMF_OK);
        let result = slice::from_raw_parts(data, len as usize).to_vec();
        emf_buffer_free(buffer);
        result
    }
}

fn input_record(
    styles: &[u32],
    info: Option<&[u8]>,
    bits: Option<&[u8]>,
    bits_first: bool,
) -> Vec<u8> {
    let mut input = vec![0; 88];
    input[..8].copy_from_slice(&words(&[1, 88]));
    input[40..44].copy_from_slice(&0x464d4520u32.to_le_bytes());
    let mut record = words(&[
        95,
        0,
        0x80000001,
        0,
        0,
        0,
        0,
        u32::MAX,
        0x80000000,
        0xfffffffe,
        0xfedcba98,
        u32::MAX,
        styles.len() as u32,
    ]);
    record.extend_from_slice(&words(styles));
    for is_bits in [bits_first, !bits_first] {
        if let Some(data) = if is_bits { bits } else { info } {
            record.extend_from_slice(b"GAP!");
            let offset = record.len() as u32;
            let field = if is_bits { 20 } else { 12 };
            record[field..field + 4].copy_from_slice(&offset.to_le_bytes());
            record[field + 4..field + 8].copy_from_slice(&(data.len() as u32).to_le_bytes());
            record.extend_from_slice(data);
        }
    }
    record.extend_from_slice(b"TAIL");
    let len = record.len() as u32;
    record[4..8].copy_from_slice(&len.to_le_bytes());
    input.extend_from_slice(&record);
    input
}

#[test]
fn extended_pen_owned_snapshot_retains_semantics_presence_order_and_gaps() {
    let envelope = 56 + 112 + 88;
    for bits_first in [false, true] {
        let bytes = snapshot(input_record(
            &[0, u32::MAX, 7],
            Some(b"INFO"),
            Some(b"BITS"),
            bits_first,
        ));
        assert_eq!(u32_at(&bytes, 4), 2);
        assert_eq!(emf_abi_version(), 1);
        assert_eq!(u32_at(&bytes, envelope + 24), 95);
        assert_eq!(u32_at(&bytes, envelope + 28), 81);
        assert_eq!(u64_at(&bytes, envelope + 32), 104);
        let payload = &bytes[envelope + 40..envelope + 144];
        assert_eq!(
            &payload[..24],
            words(&[
                0x80000001,
                u32::MAX,
                0x80000000,
                0xfffffffe,
                0xfedcba98,
                u32::MAX
            ])
        );
        assert_eq!(u64_at(payload, 24), 3);
        assert_eq!(u32_at(payload, 32), 1);
        assert_eq!(u32_at(payload, 36), 1);
        assert_eq!(u32_at(payload, 40), u32::from(bits_first));
        for offset in [44, 52, 60, 68] {
            assert_eq!(u64_at(payload, offset), 4);
        }
        assert_eq!(&payload[76..88], words(&[0, u32::MAX, 7]));
        assert_eq!(&payload[88..], b"INFOBITSGAP!GAP!");
    }
}

#[test]
fn snapshot_distinguishes_absent_and_empty_bitmaps_without_styles() {
    let envelope = 56 + 112 + 88;
    for (info, bits) in [
        (None, None),
        (Some(&b""[..]), None),
        (None, Some(&b""[..])),
        (Some(&b""[..]), Some(&b""[..])),
    ] {
        let bytes = snapshot(input_record(&[], info, bits, false));
        assert_eq!(u32_at(&bytes, envelope + 28), 81);
        let payload = &bytes[envelope + 40..];
        assert_eq!(u64_at(payload, 24), 0);
        assert_eq!(u32_at(payload, 32), u32::from(info.is_some()));
        assert_eq!(u32_at(payload, 36), u32::from(bits.is_some()));
        assert_eq!(u64_at(payload, 44), 0);
        assert_eq!(u64_at(payload, 52), 0);
        assert_eq!(u64_at(payload, 60), if info.is_some() { 4 } else { 0 });
        assert_eq!(u64_at(payload, 68), if bits.is_some() { 4 } else { 0 });
    }
}

#[test]
fn malformed_extended_pen_becomes_raw_with_diagnostic() {
    let mut input = input_record(&[], Some(b"INFO"), None, false);
    input[88 + 12..88 + 16].copy_from_slice(&1u32.to_le_bytes());
    let bytes = snapshot(input);
    let envelope = 56 + 112 + 88;
    assert_eq!(u64_at(&bytes, 24), 1); // Record count.
    assert_eq!(u64_at(&bytes, 32), 1); // Diagnostic count.
    assert_eq!(u32_at(&bytes, envelope + 28), 0);
    assert_eq!(u64_at(&bytes, envelope + 32), 0);
}
