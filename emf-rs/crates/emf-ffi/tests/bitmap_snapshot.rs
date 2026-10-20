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

const LAYOUTS: [(u32, usize, usize, Option<usize>, u32); 10] = [
    (76, 100, 84, None, 94),
    (77, 108, 84, None, 95),
    (78, 128, 84, Some(112), 96),
    (79, 140, 96, Some(124), 97),
    (80, 76, 48, None, 98),
    (81, 80, 48, None, 99),
    (93, 32, 16, None, 100),
    (94, 32, 16, None, 101),
    (114, 108, 84, None, 102),
    (116, 108, 84, None, 103),
];
fn fixture(kind: u32, fixed: usize, source: usize, mask: Option<usize>, layout: u32) -> Vec<u8> {
    let mut b = words(
        &(0..fixed / 4)
            .map(|i| 0xffffff00 + i as u32)
            .collect::<Vec<_>>(),
    );
    b[..8].copy_from_slice(&words(&[kind, fixed as u32]));
    let pointers = [Some(source), Some(source + 8), mask, mask.map(|m| m + 8)];
    for offset in pointers.into_iter().flatten() {
        b[offset..offset + 8].fill(0);
    }
    if layout != 2 {
        let order: &[usize] = if mask.is_some() {
            &[3, 1, 2, 0]
        } else {
            &[1, 0]
        };
        for (n, &index) in order.iter().enumerate() {
            b.extend_from_slice(if n == 0 { b"gap" } else { b"?" });
            let offset = pointers[index].unwrap();
            let size = if layout == 0 { 4 } else { 0 };
            let position = b.len() as u32;
            b[offset..offset + 8].copy_from_slice(&words(&[position, size]));
            if size != 0 {
                b.extend_from_slice(&[index as u8, 0x80, 0xff, 0]);
            }
        }
    }
    b.extend_from_slice(b"TAIL");
    while b.len() % 4 != 0 {
        b.push(0);
    }
    let size = b.len() as u32;
    b[4..8].copy_from_slice(&size.to_le_bytes());
    b
}
fn input(record: &[u8]) -> Vec<u8> {
    let mut b = vec![0; 88];
    b[..8].copy_from_slice(&words(&[1, 88]));
    b[40..44].copy_from_slice(&0x464d4520u32.to_le_bytes());
    b.extend_from_slice(record);
    b
}
#[test]
fn owned_bitmap_snapshots_preserve_semantic_fields_float_bits_buffer_order_and_gaps() {
    let envelope = 56 + 112 + 88;
    for (kind, fixed, source, mask, family) in LAYOUTS {
        for layout in 0..3 {
            let record = fixture(kind, fixed, source, mask, layout);
            let bytes = snapshot(input(&record));
            assert_eq!(
                word(&bytes, envelope + 28),
                family,
                "kind {kind}, layout {layout}"
            );
            let end = [Some(source), Some(source + 8), mask, mask.map(|m| m + 8)]
                .into_iter()
                .flatten()
                .map(|offset| word(&record, offset) as usize + word(&record, offset + 4) as usize)
                .max()
                .unwrap()
                .max(fixed);
            assert_eq!(wide(&bytes, envelope + 32) as usize, end - 8);
            assert_eq!(&bytes[envelope + 40..], &record[8..end]);
        }
    }
}
#[test]
fn invalid_bitmap_buffer_offsets_stay_raw_for_every_family() {
    for (kind, fixed, source, mask, _) in LAYOUTS {
        let mut record = fixture(kind, fixed, source, mask, 0);
        record[source..source + 4].copy_from_slice(&4u32.to_le_bytes());
        let bytes = snapshot(input(&record));
        assert_eq!(word(&bytes, 56 + 112 + 88 + 28), 0);
        assert_eq!(wide(&bytes, 32), 1);
    }
}
