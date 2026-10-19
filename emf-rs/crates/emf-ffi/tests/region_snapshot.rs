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

#[test]
fn all_region_families_snapshot_semantics_and_opaque_region_bytes() {
    for kind in 71..=75 {
        let mut input = vec![0; 88];
        input[..8].copy_from_slice(&words(&[1, 88]));
        input[40..44].copy_from_slice(&0x464d4520u32.to_le_bytes());
        let mut region = words(&[
            32,
            u32::MAX,
            1,
            16,
            1,
            2,
            3,
            4,
            0x80000000,
            6,
            0x7fffffff,
            8,
        ]);
        region.extend_from_slice(b"IN!!");
        let mut record = words(&[kind, 0]);
        if kind != 75 {
            record.extend_from_slice(&words(&[9, 10, 11, 12]));
        }
        record.extend_from_slice(&(region.len() as u32).to_le_bytes());
        if kind == 75 {
            record.extend_from_slice(&u32::MAX.to_le_bytes());
        }
        if kind == 71 || kind == 72 {
            record.extend_from_slice(&0x80000001u32.to_le_bytes());
        }
        if kind == 72 {
            record.extend_from_slice(&words(&[0xffffffff, 14]));
        }
        record.extend_from_slice(&region);
        record.extend_from_slice(b"OUT!");
        let len = record.len() as u32;
        record[4..8].copy_from_slice(&len.to_le_bytes());
        input.extend_from_slice(&record);
        let bytes = snapshot(input);
        let envelope = 56 + 112 + 88;
        assert_eq!(u32_at(&bytes, 4), 2); // Schema unchanged; 74/75 remain text families.
        assert_eq!(u32_at(&bytes, envelope + 24), kind);
        assert_eq!(u32_at(&bytes, envelope + 28), kind + 5);
        let fixed = match kind {
            71 => 20,
            72 => 28,
            73 | 74 => 16,
            _ => 8,
        };
        let payload = &bytes[envelope + 40..];
        if kind == 71 || kind == 72 {
            assert_eq!(u32_at(payload, 16), 0x80000001);
        }
        if kind == 72 {
            assert_eq!(u32_at(payload, 20), 0xffffffff);
        }
        if kind == 75 {
            assert_eq!(u32_at(payload, 0), u32::MAX);
            assert_eq!(u32_at(payload, 4), 1);
        }
        assert_eq!(u64_at(&bytes, envelope + 32), (fixed + 56) as u64);
        let data = &payload[fixed..fixed + 56];
        assert_eq!(u32_at(data, 0), u32::MAX);
        assert_eq!(u64_at(data, 20), 1);
        assert_eq!(u64_at(data, 28), 4);
        assert_eq!(u32_at(data, 36), 0x80000000);
        assert_eq!(u32_at(data, 44), 0x7fffffff);
        assert_eq!(&data[52..], b"IN!!");
    }
}

#[test]
fn clipping_reset_snapshot_has_no_region() {
    let mut input = vec![0; 88];
    input[..8].copy_from_slice(&words(&[1, 88]));
    input[40..44].copy_from_slice(&0x464d4520u32.to_le_bytes());
    input.extend_from_slice(&words(&[75, 20, 0, 5]));
    input.extend_from_slice(b"PAD!");
    let bytes = snapshot(input);
    let envelope = 56 + 112 + 88;
    assert_eq!(u32_at(&bytes, envelope + 28), 80);
    assert_eq!(u64_at(&bytes, envelope + 32), 8);
    assert_eq!(&bytes[envelope + 40..envelope + 48], words(&[5, 0]));
}
