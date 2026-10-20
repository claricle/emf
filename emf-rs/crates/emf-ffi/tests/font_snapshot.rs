use emf_ffi::*;
use std::{ptr, slice};

fn words(values: &[u32]) -> Vec<u8> {
    values
        .iter()
        .flat_map(|value| value.to_le_bytes())
        .collect()
}

#[test]
fn owned_font_snapshot_preserves_variants_and_complete_semantic_fields() {
    for size in [92usize, 96, 320, 364] {
        let mut font = vec![0u8; size];
        font[..4].copy_from_slice(&i32::MIN.to_le_bytes());
        font[20..28].copy_from_slice(&[0xff, 2, 3, 4, 5, 6, 7, 8]);
        font[28..32].copy_from_slice(&[0, 0xd8, 0xff, 0xff]);
        if size == 320 {
            font[284..].fill(0xa5);
        }
        if size == 364 {
            font[348..352].copy_from_slice(&0x08007664u32.to_le_bytes());
            font[352..356].copy_from_slice(&2u32.to_le_bytes());
            font[356..360].copy_from_slice(&i32::MIN.to_le_bytes());
            font[360..364].copy_from_slice(&i32::MAX.to_le_bytes());
        }
        let mut input = vec![0u8; 88];
        input[..8].copy_from_slice(&words(&[1, 88]));
        input[40..44].copy_from_slice(&0x464d4520u32.to_le_bytes());
        input.extend(words(&[82, (size + 12) as u32, 0x80000001]));
        input.extend_from_slice(&font);
        input.extend(words(&[14, 20, 0, 0, 20]));
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
            let bytes = slice::from_raw_parts(data, len as usize);
            let record = 56 + 112 + 88;
            assert_eq!(&bytes[record + 24..record + 32], words(&[82, 90]));
            let payload_size = if size == 96 { 320 } else { size };
            assert_eq!(
                u64::from_le_bytes(bytes[record + 32..record + 40].try_into().unwrap()),
                (16 + payload_size) as u64
            );
            let payload = &bytes[record + 40..record + 56 + payload_size];
            let kind = if size == 92 {
                0
            } else if size <= 320 {
                1
            } else {
                2
            };
            assert_eq!(&payload[..8], words(&[0x80000001, kind]));
            assert_eq!(
                u64::from_le_bytes(payload[8..16].try_into().unwrap()),
                size as u64
            );
            assert_eq!(&payload[16..16 + size], &font);
            assert!(payload[16 + size..].iter().all(|value| *value == 0));
            emf_buffer_free(buffer);
        }
    }
}
