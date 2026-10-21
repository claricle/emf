use emf_ffi::*;
use std::{ptr, slice};

unsafe fn rejection(bytes: &[u8]) -> Vec<u8> {
    let mut buffer = ptr::null_mut();
    assert_eq!(
        emf_wmf_rejection(
            bytes.as_ptr(),
            bytes.len() as u64,
            200 * 1024 * 1024,
            1_000_000,
            &mut buffer,
            ptr::null_mut()
        ),
        0
    );
    let (mut data, mut length) = (ptr::null(), 0u64);
    assert_eq!(emf_buffer_view(buffer, &mut data, &mut length), 0);
    let copy = slice::from_raw_parts(data, length as usize).to_vec();
    emf_buffer_free(buffer);
    copy
}

fn word(bytes: &[u8], at: usize) -> u32 {
    u32::from_le_bytes(bytes[at..at + 4].try_into().unwrap())
}

#[test]
fn reports_the_first_rejection_without_a_document() {
    // A one-record metafile whose only record, a MoveTo, has the wrong length.
    let mut input = vec![1, 0, 9, 0, 0, 3, 19, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0];
    input.extend_from_slice(&[7, 0, 0, 0, 0x14, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
    input.extend_from_slice(&[3, 0, 0, 0, 0, 0]);
    let found = unsafe { rejection(&input) };
    assert_eq!(found.len(), 48);
    assert_eq!(&found[..4], b"WMFR");
    // version, present, codec Fixed (5), reason 501, has offset, has function, function 0x14
    let words: Vec<u32> = (1..8).map(|n| word(&found, n * 4)).collect();
    assert_eq!(words, [1, 1, 5, 501, 1, 1, 0x14]);
    assert_eq!(u64::from_le_bytes(found[32..40].try_into().unwrap()), 18);
    assert_eq!(u64::from_le_bytes(found[40..48].try_into().unwrap()), 0);
}

#[test]
fn accepted_input_and_garbage_answer_without_error() {
    let accepted = [
        1, 0, 9, 0, 0, 3, 12, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0,
    ];
    let found = unsafe { rejection(&accepted) };
    assert_eq!(found.len(), 48);
    assert_eq!(word(&found, 8), 0, "present");
    // Not a WMF at all: a whole-input rejection with no offset.
    let found = unsafe { rejection(&[]) };
    assert_eq!(
        (word(&found, 8), word(&found, 16), word(&found, 20)),
        (1, 301, 0)
    );
}

#[test]
fn null_output_is_an_error_not_a_crash() {
    let status =
        unsafe { emf_wmf_rejection(ptr::null(), 0, 1, 1, ptr::null_mut(), ptr::null_mut()) };
    assert_ne!(status, 0);
}
