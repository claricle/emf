use emf_ffi::*;
use std::{mem::size_of, ptr, slice};

fn u32_at(bytes: &[u8], at: usize) -> u32 {
    u32::from_le_bytes(bytes[at..at + 4].try_into().unwrap())
}
fn u64_at(bytes: &[u8], at: usize) -> u64 {
    u64::from_le_bytes(bytes[at..at + 8].try_into().unwrap())
}
fn options(max_output_bytes: u64) -> EmfPlusSnapshotOptions {
    EmfPlusSnapshotOptions {
        struct_size: size_of::<EmfPlusSnapshotOptions>() as u32,
        version: EMF_PLUS_SNAPSHOT_VERSION,
        max_output_bytes,
    }
}
fn frame(kind: u16, flags: u16, body: &[u8], padding: &[u8]) -> Vec<u8> {
    let mut bytes = Vec::new();
    bytes.extend_from_slice(&kind.to_le_bytes());
    bytes.extend_from_slice(&flags.to_le_bytes());
    bytes.extend_from_slice(&((12 + body.len() + padding.len()) as u32).to_le_bytes());
    bytes.extend_from_slice(&(body.len() as u32).to_le_bytes());
    bytes.extend_from_slice(body);
    bytes.extend_from_slice(padding);
    bytes
}
fn input(segments: &[&[u8]]) -> Vec<u8> {
    let mut bytes = vec![0; 88];
    bytes[..4].copy_from_slice(&1u32.to_le_bytes());
    bytes[4..8].copy_from_slice(&88u32.to_le_bytes());
    bytes[40..44].copy_from_slice(&0x464d4520u32.to_le_bytes());
    for segment in segments {
        let len = 16 + segment.len();
        let size = (len + 3) & !3;
        for word in [70, size as u32, (4 + segment.len()) as u32] {
            bytes.extend_from_slice(&word.to_le_bytes());
        }
        bytes.extend_from_slice(b"EMF+");
        bytes.extend_from_slice(segment);
        bytes.resize(bytes.len() + size - len, 0xa5);
    }
    bytes
}
unsafe fn parse(bytes: &[u8]) -> *mut EmfDocument {
    let mut doc = ptr::null_mut();
    assert_eq!(
        emf_parse(
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
unsafe fn view(buffer: *mut EmfBuffer) -> Vec<u8> {
    let mut data = ptr::null();
    let mut len = 0;
    assert_eq!(emf_buffer_view(buffer, &mut data, &mut len), EMF_OK);
    let bytes = slice::from_raw_parts(data, len as usize).to_vec();
    emf_buffer_free(buffer);
    bytes
}
unsafe fn snapshot(doc: *mut EmfDocument) -> Vec<u8> {
    let mut buffer = ptr::null_mut();
    assert_eq!(
        emf_document_emf_plus_snapshot_v1(
            doc,
            &options(1 << 20),
            ptr::null(),
            &mut buffer,
            ptr::null_mut()
        ),
        EMF_OK
    );
    view(buffer)
}

#[test]
fn split_frames_keep_source_ranges_values_unknown_bytes_and_outer_snapshot() {
    let clear = frame(0x4009, 0x8000, &0x80ff0033u32.to_le_bytes(), &[]);
    let opaque = frame(0x7fff, 0x1234, b"raw!", b"PAD!");
    let mut logical = clear.clone();
    logical.extend_from_slice(&opaque);
    // A header and an opaque body both cross segments; empty segment is retained.
    let bytes = input(&[&[], &logical[..7], &logical[7..30], &[], &logical[30..]]);
    unsafe {
        let doc = parse(&bytes);
        let mut old_before = ptr::null_mut();
        assert_eq!(
            emf_document_snapshot(doc, &mut old_before, ptr::null_mut()),
            EMF_OK
        );
        let old_before = view(old_before);
        assert_eq!(u32_at(&old_before, 4), 2);
        assert_eq!(emf_abi_version(), 1);
        let nested = snapshot(doc);
        assert_eq!(&nested[..4], b"EPSN");
        assert_eq!(u32_at(&nested, 4), 1);
        assert_eq!(u64_at(&nested, 8), nested.len() as u64);
        assert_eq!(u64_at(&nested, 16), 5);
        assert_eq!(u64_at(&nested, 24), 2);
        assert_eq!(u64_at(&nested, 32), 0);
        let mut offset = 0;
        for (i, length) in [0, 7, 23, 0, 6].into_iter().enumerate() {
            let at = 40 + i * 32;
            assert_eq!(u64_at(&nested, at), i as u64);
            assert_eq!(u64_at(&nested, at + 8), offset);
            assert_eq!(u64_at(&nested, at + 16), length);
            assert_eq!(u64_at(&nested, at + 24), 4);
            offset += length;
        }
        let first = 40 + 5 * 32;
        assert_eq!(u64_at(&nested, first + 8), 0);
        assert_eq!(u64_at(&nested, first + 16), 1);
        assert_eq!(u64_at(&nested, first + 24), 2);
        assert_eq!(u32_at(&nested, first + 32), 0x80004009);
        assert_eq!(u32_at(&nested, first + 36), 16);
        assert_eq!(u32_at(&nested, first + 40), 4);
        assert_eq!(u32_at(&nested, first + 44), 3);
        assert_eq!(u64_at(&nested, first + 48), 4);
        assert_eq!(&nested[first + 64..first + 80], clear);
        assert_eq!(u32_at(&nested, first + 80), 0x80ff0033);
        let second = first + 84;
        assert_eq!(u64_at(&nested, second), 1);
        assert_eq!(u64_at(&nested, second + 8), 16);
        assert_eq!(u64_at(&nested, second + 16), 2);
        assert_eq!(u64_at(&nested, second + 24), 4);
        assert_eq!(u32_at(&nested, second + 44), 0);
        assert_eq!(u64_at(&nested, second + 48), 0);
        assert_eq!(&nested[second + 64..], opaque);
        let mut old_after = ptr::null_mut();
        assert_eq!(
            emf_document_snapshot(doc, &mut old_after, ptr::null_mut()),
            EMF_OK
        );
        assert_eq!(view(old_after), old_before);
        let mut serialized = ptr::null_mut();
        assert_eq!(emf_serialize(doc, &mut serialized, ptr::null_mut()), EMF_OK);
        assert_eq!(view(serialized), bytes);
        // Returned storage is independent of the source handle.
        let mut owned = ptr::null_mut();
        assert_eq!(
            emf_document_emf_plus_snapshot_v1(
                doc,
                &options(1 << 20),
                ptr::null(),
                &mut owned,
                ptr::null_mut()
            ),
            EMF_OK
        );
        emf_document_free(doc);
        assert_eq!(view(owned), nested);
    }
}

#[test]
fn empty_and_corrupt_nested_streams_have_explicit_outcomes() {
    unsafe {
        for segments in [vec![], vec![&b""[..]]] {
            let doc = parse(&input(&segments));
            let bytes = snapshot(doc);
            assert_eq!(u64_at(&bytes, 16), segments.len() as u64);
            assert_eq!(u64_at(&bytes, 24), 0);
            assert_eq!(bytes.len(), 40 + segments.len() * 32);
            emf_document_free(doc);
        }
        for bad in [b"short".to_vec(), frame(0x4009, 0, b"", &[])] {
            let doc = parse(&input(&[&bad]));
            let mut buffer = ptr::NonNull::dangling().as_ptr();
            let mut error = ptr::null_mut();
            assert_eq!(
                emf_document_emf_plus_snapshot_v1(
                    doc,
                    &options(10000),
                    ptr::null(),
                    &mut buffer,
                    &mut error
                ),
                EMF_FORMAT_ERROR
            );
            assert!(buffer.is_null());
            assert!(!error.is_null());
            emf_error_free(error);
            emf_buffer_free(buffer);
            emf_document_free(doc);
        }
    }
}

#[test]
fn rejects_nulls_metadata_and_resource_limits_and_cleans_outputs() {
    unsafe {
        let doc = parse(&input(&[&frame(0x4009, 0, &[1, 2, 3, 4], &[])]));
        let expected = snapshot(doc);
        for supplied in [
            options(expected.len() as u64 - 1),
            EmfPlusSnapshotOptions {
                version: 2,
                ..options(10000)
            },
            EmfPlusSnapshotOptions {
                struct_size: 0,
                ..options(10000)
            },
        ] {
            let mut buffer = ptr::NonNull::dangling().as_ptr();
            let mut error = ptr::null_mut();
            let expected_status = if supplied.version == 1 && supplied.struct_size == 16 {
                EMF_LIMIT_EXCEEDED
            } else {
                EMF_INVALID_ARGUMENT
            };
            assert_eq!(
                emf_document_emf_plus_snapshot_v1(
                    doc,
                    &supplied,
                    ptr::null(),
                    &mut buffer,
                    &mut error
                ),
                expected_status
            );
            assert!(buffer.is_null());
            assert!(!error.is_null());
            emf_error_free(error);
        }
        let mut buffer = ptr::null_mut();
        assert_eq!(
            emf_document_emf_plus_snapshot_v1(
                doc,
                &options(expected.len() as u64),
                ptr::null(),
                &mut buffer,
                ptr::null_mut()
            ),
            EMF_OK
        );
        assert_eq!(view(buffer), expected);
        assert_eq!(
            emf_document_emf_plus_snapshot_v1(
                ptr::null(),
                &options(10000),
                ptr::null(),
                &mut buffer,
                ptr::null_mut()
            ),
            EMF_INVALID_ARGUMENT
        );
        assert!(buffer.is_null());
        assert_eq!(
            emf_document_emf_plus_snapshot_v1(
                doc,
                ptr::null(),
                ptr::null(),
                &mut buffer,
                ptr::null_mut()
            ),
            EMF_INVALID_ARGUMENT
        );
        assert_eq!(
            emf_document_emf_plus_snapshot_v1(
                doc,
                &options(10000),
                ptr::null(),
                ptr::null_mut(),
                ptr::null_mut()
            ),
            EMF_INVALID_ARGUMENT
        );
        let mut limits = EmfLimits {
            struct_size: size_of::<EmfLimits>() as u32,
            version: 1,
            max_input_bytes: 10000,
            max_record_bytes: 10000,
            max_records: 0,
            max_allocated_bytes: 100000,
            max_work_units: 100000,
        };
        for (field, status) in [
            (0, EMF_LIMIT_EXCEEDED),
            (1, EMF_INVALID_ARGUMENT),
            (2, EMF_INVALID_ARGUMENT),
        ] {
            if field == 1 {
                limits.version = 2;
            }
            if field == 2 {
                limits.version = 1;
                limits.struct_size = 0;
            }
            assert_eq!(
                emf_document_emf_plus_snapshot_v1(
                    doc,
                    &options(10000),
                    &limits,
                    &mut buffer,
                    ptr::null_mut()
                ),
                status
            );
            assert!(buffer.is_null());
        }
        limits.struct_size = size_of::<EmfLimits>() as u32;
        limits.max_records = 100;
        limits.max_allocated_bytes = 0;
        assert_eq!(
            emf_document_emf_plus_snapshot_v1(
                doc,
                &options(10000),
                &limits,
                &mut buffer,
                ptr::null_mut()
            ),
            EMF_LIMIT_EXCEEDED
        );
        assert!(buffer.is_null());
        emf_buffer_free(ptr::null_mut());
        emf_error_free(ptr::null_mut());
        emf_document_free(doc);
    }
}

#[test]
fn fixed_typed_families_preserve_word_bits_and_pending_families_keep_raw_frames() {
    let fixed = [
        (0x4001, 1, 16),
        (0x4002, 2, 0),
        (0x4009, 3, 4),
        (0x401d, 4, 8),
        (0x4025, 5, 4),
        (0x4027, 6, 36),
        (0x402a, 7, 24),
        (0x402d, 8, 8),
        (0x402f, 9, 4),
        (0x4032, 10, 16),
    ];
    let mut cases = Vec::new();
    for (kind, tag, len) in fixed {
        let body: Vec<u8> = [0x7fc12345u32, 0x80000000, u32::MAX]
            .into_iter()
            .cycle()
            .flat_map(u32::to_le_bytes)
            .take(len)
            .collect();
        cases.push((frame(kind, 0xabcd, &body, &[]), tag, body));
    }
    let mut effect = vec![
        0xa4, 0x80, 0x3c, 0x63, 0x43, 0x18, 0x2b, 0x48, 0x9e, 0xf2, 0xbe, 0x28, 0x34, 0xc5, 0xfd,
        0xd4,
    ];
    effect.extend(
        [8u32, 0x7fc12345, u32::MAX]
            .into_iter()
            .flat_map(u32::to_le_bytes),
    );
    let brush: Vec<u8> = [0xdbc01002u32, 0, 0x80ff0033]
        .into_iter()
        .flat_map(u32::to_le_bytes)
        .collect();
    for (kind, flags, tag, body) in [
        (0x400f, 0, 0x101, vec![0; 16]),
        (0x401c, 0, 0x102, vec![0; 28]),
        (0x4038, 0, 0x103, effect),
        (0x4039, 0xfffe, 0x104, vec![0; 36]),
        (0x4008, 0x0101, 0x105, brush),
    ] {
        cases.push((frame(kind, flags, &body, &[]), tag, Vec::new()));
    }
    let logical: Vec<u8> = cases
        .iter()
        .flat_map(|(raw, _, _)| raw.iter().copied())
        .collect();
    unsafe {
        let doc = parse(&input(&[&logical]));
        let bytes = snapshot(doc);
        assert_eq!(u64_at(&bytes, 24), cases.len() as u64);
        let mut at = 72;
        for (raw, tag, typed) in cases {
            assert_eq!(u32_at(&bytes, at + 44), tag);
            assert_eq!(u64_at(&bytes, at + 48), typed.len() as u64);
            assert_eq!(u64_at(&bytes, at + 56), raw.len() as u64);
            assert_eq!(&bytes[at + 64..at + 64 + raw.len()], raw);
            at += 64 + raw.len();
            assert_eq!(&bytes[at..at + typed.len()], typed);
            at += typed.len();
        }
        assert_eq!(at, bytes.len());
        emf_document_free(doc);
    }
}
