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

fn input(mode: u32) -> Vec<u8> {
    let mut bytes = vec![0; 88];
    bytes[..8].copy_from_slice(&words(&[1, 88]));
    bytes[40..44].copy_from_slice(&0x464d4520u32.to_le_bytes());
    bytes.extend_from_slice(&words(&[118, 100, u32::MAX, 2, 3, 4, 3, 1, mode]));
    for i in 0..3 {
        bytes.extend_from_slice(&words(&[u32::MAX - i, i, 0xabcd1234, 0xffff8000]));
    }
    bytes.extend_from_slice(&words(&[0, 1, if mode == 2 { 2 } else { 0xdeadbeef }]));
    bytes.extend_from_slice(b"TAIL");
    bytes
}
#[test]
fn owned_gradient_snapshot_exports_signed_vertices_channels_mesh_and_padding() {
    let envelope = 56 + 112 + 88;
    for mode in 0..=2 {
        let input = input(mode);
        let bytes = snapshot(input.clone());
        assert_eq!(word(&bytes, envelope + 28), 93);
        assert_eq!(wide(&bytes, envelope + 32), 96);
        let payload = &bytes[envelope + 40..];
        assert_eq!(&payload[..16], &input[96..112]);
        assert_eq!(word(payload, 16), mode);
        assert_eq!(wide(payload, 20), 3);
        assert_eq!(wide(payload, 28), 1);
        assert_eq!(&payload[36..], &input[124..184]);
        assert!(!payload.ends_with(b"TAIL"));
    }
}
#[test]
fn invalid_gradient_indices_remain_raw() {
    let mut input = input(2);
    input[172..176].copy_from_slice(&3u32.to_le_bytes());
    let bytes = snapshot(input);
    assert_eq!(word(&bytes, 56 + 112 + 88 + 28), 0);
    assert_eq!(wide(&bytes, 32), 1);
}
