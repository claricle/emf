use emf_ffi::*;
use std::{ptr, slice};

fn u32_at(bytes: &[u8], offset: usize) -> u32 {
    u32::from_le_bytes(bytes[offset..offset + 4].try_into().unwrap())
}

fn u64_at(bytes: &[u8], offset: usize) -> u64 {
    u64::from_le_bytes(bytes[offset..offset + 8].try_into().unwrap())
}

#[test]
fn extended_text_snapshot_owns_code_units_float_bits_and_layout() {
    for (kind, units) in [(83u32, vec![0x80, 0xff]), (84, vec![0, 0xd8, 0xff, 0xff])] {
        let mut input = vec![0; 88];
        input[..4].copy_from_slice(&1u32.to_le_bytes());
        input[4..8].copy_from_slice(&88u32.to_le_bytes());
        input[40..44].copy_from_slice(&0x464d4520u32.to_le_bytes());
        let mut record = Vec::new();
        // ETO_NO_RECT | ETO_PDY, Dx before string; arbitrary gap bytes.
        for value in [
            kind, 0, 0x80000000, 2, 3, 4, 2, 0x7fc01234, 0x80000000, 0xffffffff, 0x7fffffff, 2, 88,
            0x2100, 64,
        ] {
            record.extend_from_slice(&value.to_le_bytes());
        }
        record.extend_from_slice(b"GAP!");
        for value in [0xffffffffu32, 0x80000000, 17, 29] {
            record.extend_from_slice(&value.to_le_bytes());
        }
        record.extend_from_slice(b"gap!pad!");
        record.extend_from_slice(&units);
        while record.len() % 4 != 0 {
            record.push(0xa5);
        }
        let size = record.len() as u32;
        record[4..8].copy_from_slice(&size.to_le_bytes());
        input.extend_from_slice(&record);
        let mut document = ptr::null_mut();
        let mut snapshot = ptr::null_mut();
        unsafe {
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
                emf_document_snapshot(document, &mut snapshot, ptr::null_mut()),
                EMF_OK
            );
            emf_document_free(document);
            let mut data = ptr::null();
            let mut len = 0;
            assert_eq!(emf_buffer_view(snapshot, &mut data, &mut len), EMF_OK);
            let bytes = slice::from_raw_parts(data, len as usize);
            assert_eq!(u32_at(bytes, 4), 2);
            let record_offset = 56 + 112 + 88;
            assert_eq!(u32_at(bytes, record_offset + 24), kind);
            assert_eq!(u32_at(bytes, record_offset + 28), kind - 9);
            let p = &bytes[record_offset + 40..];
            assert_eq!(u32_at(p, 0), 0x80000000);
            assert_eq!(u32_at(p, 20), 0x7fc01234);
            assert_eq!(u32_at(p, 24), 0x80000000);
            assert_eq!(u32_at(p, 40), 0);
            assert_eq!(u64_at(p, 60), 2);
            assert_eq!(u32_at(p, 68), 1);
            assert_eq!(u64_at(p, 72), 4);
            assert_eq!(u32_at(p, 80), 1);
            assert_eq!(u32_at(p, 84), 1);
            assert_eq!(u64_at(p, 88), 8);
            assert_eq!(u64_at(p, 96), 4);
            assert_eq!(&p[104..104 + units.len()], units);
            assert_eq!(
                &p[104 + units.len() + 16..104 + units.len() + 28],
                b"gap!pad!GAP!"
            );
            assert_eq!(
                u64_at(bytes, record_offset + 32),
                (132 + units.len()) as u64
            );
            emf_buffer_free(snapshot);
        }
    }
}
