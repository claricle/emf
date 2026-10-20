use emf_ffi::*;
use std::{ptr, slice};

fn word(bytes: &[u8], offset: usize) -> u32 {
    u32::from_le_bytes(bytes[offset..offset + 4].try_into().unwrap())
}
fn wide(bytes: &[u8], offset: usize) -> u64 {
    u64::from_le_bytes(bytes[offset..offset + 8].try_into().unwrap())
}
fn words(values: &[u32]) -> Vec<u8> {
    values.iter().flat_map(|v| v.to_le_bytes()).collect()
}
fn input(kind: u32, entries: &[u8]) -> Vec<u8> {
    let mut bytes = vec![0; 88];
    bytes[..8].copy_from_slice(&words(&[1, 88]));
    bytes[40..44].copy_from_slice(&0x464d4520u32.to_le_bytes());
    let mut payload = match kind {
        48 => words(&[0x8000000f]),
        49 => {
            let mut payload = words(&[0x87654321]);
            payload.extend_from_slice(&0xfedcu16.to_le_bytes());
            payload.extend_from_slice(&((entries.len() / 4) as u16).to_le_bytes());
            payload
        }
        50 => words(&[0x87654321, u32::MAX, (entries.len() / 4) as u32]),
        51 => words(&[0x87654321, u32::MAX]),
        52 => Vec::new(),
        _ => unreachable!(),
    };
    if kind == 49 || kind == 50 {
        payload.extend_from_slice(entries);
    }
    bytes.extend_from_slice(&words(&[kind, 12 + payload.len() as u32]));
    bytes.extend_from_slice(&payload);
    bytes.extend_from_slice(b"TAIL");
    bytes
}

// The owned buffer survives both its input and parsed document.
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

#[test]
fn owned_palette_snapshots_expose_raw_channels_and_unsigned_scalars() {
    let envelope = 56 + 112 + 88;
    let entries = [1, 2, 255, 128, 254, 3, 0, 255];
    for kind in 48..=52 {
        let bytes = snapshot(input(kind, &entries));
        assert_eq!(word(&bytes, envelope + 24), kind);
        assert_eq!(word(&bytes, envelope + 28), kind + 34);
        let payload = &bytes[envelope + 40..];
        assert_eq!(wide(&bytes, envelope + 32) as usize, payload.len());
        match kind {
            48 => assert_eq!(payload, words(&[0x8000000f])),
            49 | 50 => {
                assert_eq!(word(payload, 0), 0x87654321);
                assert_eq!(word(payload, 4), if kind == 49 { 0xfedc } else { u32::MAX });
                assert_eq!(wide(payload, 8), 2);
                assert_eq!(&payload[16..], &entries);
            }
            51 => assert_eq!(payload, words(&[0x87654321, u32::MAX])),
            52 => assert!(payload.is_empty()),
            _ => unreachable!(),
        }
    }
}

#[test]
fn empty_palette_arrays_have_explicit_zero_counts() {
    let envelope = 56 + 112 + 88;
    for kind in [49, 50] {
        let bytes = snapshot(input(kind, &[]));
        assert_eq!(word(&bytes, envelope + 28), kind + 34);
        assert_eq!(wide(&bytes, envelope + 32), 16);
        assert_eq!(wide(&bytes, envelope + 48), 0);
    }
}

#[test]
fn malformed_palette_counts_stay_raw_with_diagnostics() {
    let envelope = 56 + 112 + 88;
    for kind in [49, 50] {
        let mut input = input(kind, &[]);
        if kind == 49 {
            input[102..104].copy_from_slice(&u16::MAX.to_le_bytes());
        } else {
            input[104..108].copy_from_slice(&u32::MAX.to_le_bytes());
        }
        let bytes = snapshot(input);
        assert_eq!(wide(&bytes, 24), 1);
        assert_eq!(wide(&bytes, 32), 1);
        assert_eq!(word(&bytes, envelope + 28), 0);
        assert_eq!(wide(&bytes, envelope + 32), 0);
    }
}
