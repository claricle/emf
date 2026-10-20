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
fn fixed_typed_families_preserve_word_bits_and_complex_families_keep_raw_frames() {
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
        let typed = match kind {
            0x400f => words(&[2, 0, 0, 0, 0, 0, 0, 0]),
            0x401c => words(&[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
            0x4038 => {
                let mut typed = words(&[1]);
                typed.extend(&body[..16]);
                typed.extend(words(&[0x7fc12345, u32::MAX]));
                typed
            }
            0x4039 => words(&[0; 16]),
            0x4008 => {
                let mut typed = object_prefix(cases.len(), cases.len(), None, true);
                typed.extend(words(&[1, 1, 1, 0xdbc01002, 0x80ff0033]));
                typed
            }
            _ => Vec::new(),
        };
        cases.push((frame(kind, flags, &body, &[]), tag, typed));
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

fn words(values: &[u32]) -> Vec<u8> {
    values.iter().flat_map(|n| n.to_le_bytes()).collect()
}
fn count(bytes: &mut Vec<u8>, n: u64) {
    bytes.extend(n.to_le_bytes());
}

#[test]
fn normalized_drawing_and_text_cover_operations_encodings_arrays_and_presence() {
    let mut cases = Vec::new();
    let bits = [0x7fc12345, 0x80000000, 0x3f800000, u32::MAX];
    let rect = words(&bits);
    let mut normalized_rect = words(&[0]);
    normalized_rect.extend(&rect);
    for kind in 0x400a..=0x401b {
        let brush = matches!(kind, 0x400a | 0x400c | 0x400e | 0x4010 | 0x4016);
        let mut body = if brush { words(&[0x80ff0033]) } else { vec![] };
        let optional_brush = [u32::from(brush), if brush { 0x80ff0033 } else { 0 }];
        let mut expected;
        match kind {
            0x400a | 0x400b => {
                body.extend(words(&[2]));
                body.extend(&rect);
                body.extend(&rect);
                expected = words(&[1]);
                expected.extend(words(&optional_brush));
                count(&mut expected, 2);
                expected.extend(&normalized_rect);
                expected.extend(&normalized_rect);
            }
            0x400e | 0x400f => {
                body.extend(&rect);
                expected = words(&[2]);
                expected.extend(words(&optional_brush));
                expected.extend(&normalized_rect);
            }
            0x4010..=0x4012 => {
                body.extend(words(&bits[..2]));
                body.extend(&rect);
                expected = words(&[3]);
                expected.extend(words(&optional_brush));
                expected.extend(words(&bits[..2]));
                expected.extend(&normalized_rect);
            }
            0x4013..=0x4015 => {
                body.extend(words(&[0xfedcba98]));
                expected = words(&[8, 0xfedcba98]);
            }
            0x401a => {
                body.extend(words(&[9, u32::MAX]));
                body.extend(&rect);
                body.extend(&rect);
                expected = words(&[6, 9, u32::MAX]);
                expected.extend(&rect);
                expected.extend(&normalized_rect);
            }
            _ => {
                let image = kind == 0x401b;
                let curve = matches!(kind, 0x4016..=0x4018);
                if image {
                    body.extend(words(&[9, u32::MAX]));
                    body.extend(&rect);
                }
                if curve {
                    body.extend(words(&[bits[0]]));
                }
                if kind == 0x4018 {
                    body.extend(words(&[1, 2]));
                }
                let n = if kind == 0x4019 { 4 } else { 3 };
                body.extend(words(&[n]));
                for _ in 0..n {
                    body.extend(words(&bits[..2]));
                }
                expected = words(&[if image {
                    7
                } else if curve {
                    5
                } else {
                    4
                }]);
                if image {
                    expected.extend(words(&[9, u32::MAX]));
                    expected.extend(&rect);
                } else {
                    expected.extend(words(&optional_brush));
                }
                if curve {
                    expected.extend(words(&[
                        bits[0],
                        u32::from(kind == 0x4018),
                        if kind == 0x4018 { 1 } else { 0 },
                        if kind == 0x4018 { 2 } else { 0 },
                    ]));
                }
                expected.extend(words(&[0]));
                count(&mut expected, n as u64);
                for _ in 0..n {
                    expected.extend(words(&bits[..2]));
                }
                count(&mut expected, 0);
            }
        }
        cases.push((frame(kind, 0, &body, &[]), expected));
    }
    // Integer rectangles are sign extended; relative widths and deltas remain explicit.
    let shorts: Vec<u8> = [i16::MIN, -1, 0, i16::MAX]
        .into_iter()
        .flat_map(i16::to_le_bytes)
        .collect();
    cases.push((
        frame(0x400f, 0x4000, &shorts, &[]),
        words(&[2, 0, 0, 1, 0xffff8000, u32::MAX, 0, 32767]),
    ));
    let mut body = words(&[2]);
    body.extend(&shorts);
    let mut typed = words(&[4, 0, 0, 1]);
    count(&mut typed, 2);
    typed.extend(words(&[0xffff8000, u32::MAX, 0, 32767]));
    count(&mut typed, 0);
    cases.push((frame(0x400d, 0x4000, &body, &[]), typed));
    let mut body = words(&[2]);
    body.extend([0x7f, 0x80, 1, 0xc0, 0, 0x3f, 0xa5, 0xb6]);
    let mut typed = words(&[4, 0, 0, 2]);
    count(&mut typed, 2);
    typed.extend(words(&[7, u32::MAX, 15, 1, 15, 0xffffc000, 7, 63]));
    count(&mut typed, 2);
    typed.extend([0xa5, 0xb6]);
    cases.push((frame(0x400d, 0x0800, &body, &[]), typed));
    // Raw UTF-16 code units include an unpaired surrogate; no decoding or replacement.
    let mut body = words(&[7, 8, 3]);
    body.extend(&rect);
    body.extend([0, 0xd8, 65, 0, 0xff, 0xff, 0xa5, 0xb6]);
    let mut typed = words(&[1, 7, 8]);
    typed.extend(&rect);
    count(&mut typed, 3);
    typed.extend([0, 0xd8, 65, 0, 0xff, 0xff]);
    count(&mut typed, 2);
    typed.extend([0xa5, 0xb6]);
    cases.push((frame(0x401c, 0x8000, &body, &[]), typed));
    for (options, n, present) in [
        (0, 2, false),
        (4, 2, true),
        (4, 1, true),
        (4, 0, true),
        (0, 0, false),
    ] {
        let positions = if options == 4 && n > 0 { 1 } else { n };
        let mut body = words(&[7, options, u32::from(present), n]);
        let mut typed = words(&[2, 7, options]);
        count(&mut typed, n as u64);
        for _ in 0..n {
            body.extend([0, 0xd8]);
            typed.extend([0, 0xd8]);
        }
        count(&mut typed, positions as u64);
        for _ in 0..positions {
            body.extend(words(&bits[..2]));
            typed.extend(words(&bits[..2]));
        }
        typed.extend(words(&[u32::from(present)]));
        if present {
            let matrix = words(&[bits[0], bits[1], 1, 2, 3, 4]);
            body.extend(&matrix);
            typed.extend(matrix);
        }
        let padding: &[u8] = if n % 2 == 1 { &[0xa5, 0xb6] } else { &[] };
        body.extend(padding);
        count(&mut typed, padding.len() as u64);
        typed.extend(padding);
        cases.push((frame(0x4036, 0, &body, &[]), typed));
    }
    let logical: Vec<u8> = cases
        .iter()
        .flat_map(|(raw, _)| raw.iter().copied())
        .collect();
    unsafe {
        // Split a variable body, and preserve all original bytes after the read.
        let original = input(&[&logical[..19], &logical[19..]]);
        let doc = parse(&original);
        let bytes = snapshot(doc);
        let mut at = 104;
        for (raw, typed) in cases {
            assert_eq!(u64_at(&bytes, at + 48), typed.len() as u64);
            assert_eq!(&bytes[at + 64..at + 64 + raw.len()], raw);
            at += 64 + raw.len();
            assert_eq!(&bytes[at..at + typed.len()], typed);
            at += typed.len();
        }
        assert_eq!(at, bytes.len());
        let mut output = ptr::null_mut();
        assert_eq!(
            emf_document_emf_plus_snapshot_v1(
                doc,
                &options(bytes.len() as u64 - 1),
                ptr::null(),
                &mut output,
                ptr::null_mut()
            ),
            EMF_LIMIT_EXCEEDED
        );
        assert!(output.is_null());
        assert_eq!(
            emf_document_emf_plus_snapshot_v1(
                doc,
                &options(bytes.len() as u64),
                ptr::null(),
                &mut output,
                ptr::null_mut()
            ),
            EMF_OK
        );
        assert_eq!(view(output), bytes);
        assert_eq!(emf_serialize(doc, &mut output, ptr::null_mut()), EMF_OK);
        assert_eq!(view(output), original);
        emf_document_free(doc);
    }
}

#[test]
fn normalized_effects_preserve_all_subtypes_guid_bits_counts_and_unknown_buffers() {
    use emf_core::emf_plus::Effect;
    // GUID selection uses core's public identity; expected payloads are built from
    // explicit wire values independently of the FFI encoder.
    let effects = [
        Effect::Blur {
            radius: 0,
            expand_edge: 0,
        },
        Effect::BrightnessContrast {
            brightness: 0,
            contrast: 0,
        },
        Effect::ColorBalance {
            cyan_red: 0,
            magenta_green: 0,
            yellow_blue: 0,
        },
        Effect::ColorCurve {
            adjustment: 0,
            channel: 0,
            intensity: 0,
        },
        Effect::ColorLookupTable { tables: vec![] },
        Effect::ColorMatrix { matrix: [0; 25] },
        Effect::HueSaturationLightness {
            hue: 0,
            saturation: 0,
            lightness: 0,
        },
        Effect::Levels {
            highlight: 0,
            midtone: 0,
            shadow: 0,
        },
        Effect::RedEyeCorrection { areas: vec![] },
        Effect::Sharpen {
            radius: 0,
            amount: 0,
        },
        Effect::Tint { hue: 0, amount: 0 },
        Effect::Unknown {
            guid: [0xa5; 16],
            buffer: vec![],
        },
    ];
    let bits = [0x80000000, 0x7fc12345, u32::MAX];
    let mut cases = Vec::new();
    for (index, effect) in effects.iter().enumerate() {
        let subtype = if index == 11 { 0 } else { index as u32 + 1 };
        let mut typed = words(&[subtype]);
        let guid = effect.guid();
        typed.extend(guid);
        let parameters = match subtype {
            1 | 2 | 10 | 11 => words(&bits[..2]),
            3 | 4 | 7 | 8 => words(&bits),
            5 => (0..1024).map(|i| (i / 256 * 37 + i % 256) as u8).collect(),
            6 => (0..25).flat_map(|i| bits[i % 3].to_le_bytes()).collect(),
            9 => words(&[2, u32::MAX, 0x80000000, 3, 4, 9, 8, 7, 6]),
            0 => vec![0xff, 0, 0x80, 0x7f, 1, 2, 3, 4],
            _ => unreachable!(),
        };
        match subtype {
            5 => {
                count(&mut typed, 4);
                typed.extend(&parameters);
            }
            9 => {
                count(&mut typed, 2);
                typed.extend(&parameters[4..]);
            }
            0 => {
                count(&mut typed, parameters.len() as u64);
                typed.extend(&parameters);
            }
            _ => typed.extend(&parameters),
        }
        let mut body = guid.to_vec();
        body.extend(words(&[parameters.len() as u32]));
        body.extend(parameters);
        cases.push((frame(0x4038, 0xa5fe, &body, b"PAD!"), 0x103, typed));
    }
    // Empty variable arrays retain explicit zero counts.
    for (effect, parameters, subtype) in [
        (Effect::RedEyeCorrection { areas: vec![] }, words(&[0]), 9),
        (
            Effect::Unknown {
                guid: [0x5a; 16],
                buffer: vec![],
            },
            vec![],
            0,
        ),
    ] {
        let guid = effect.guid();
        let mut body = guid.to_vec();
        body.extend(words(&[parameters.len() as u32]));
        body.extend(parameters);
        let mut typed = words(&[subtype]);
        typed.extend(guid);
        count(&mut typed, 0);
        cases.push((frame(0x4038, 0, &body, &[]), 0x103, typed));
    }
    assert_normalized_cases(cases);
}

#[test]
fn normalized_tsgraphics_expands_scalars_and_distinguishes_optional_empty_palette() {
    let transform = [0x80000000, 0x7fc12345, u32::MAX, 1, 2, 3];
    let mut cases = Vec::new();
    for palette in [None, Some(vec![]), Some(vec![0x80ff0033, 0x00010203])] {
        let mut body = vec![0xff, 0x80, 0x7f, 0xfe];
        body.extend((-32768i16).to_le_bytes());
        body.extend(32767i16.to_le_bytes());
        body.extend(65535u16.to_le_bytes());
        body.extend([0xa5, 0xb6]);
        body.extend(words(&transform));
        let mut typed = words(&[0xff, 0x80, 0x7f, 0xfe, 0xffff8000, 32767, 65535, 0xa5, 0xb6]);
        typed.extend(words(&transform));
        typed.extend(words(&[u32::from(palette.is_some())]));
        let flags = 0xfffe | u16::from(palette.is_some());
        if let Some(entries) = palette {
            body.extend(words(&[0xfedcba98, entries.len() as u32]));
            body.extend(words(&entries));
            typed.extend(words(&[0xfedcba98]));
            count(&mut typed, entries.len() as u64);
            typed.extend(words(&entries));
        }
        cases.push((frame(0x4039, flags, &body, b"RAW!"), 0x104, typed));
    }
    // Unsupported core record types keep their raw payloads.
    cases.push((frame(0x7fff, 0xbeef, b"raw!", &[]), 0, vec![]));
    assert_normalized_cases(cases);
}

fn assert_normalized_cases(cases: Vec<(Vec<u8>, u32, Vec<u8>)>) {
    let logical: Vec<u8> = cases
        .iter()
        .flat_map(|(raw, _, _)| raw.iter().copied())
        .collect();
    unsafe {
        let original = input(&[&logical[..19], &logical[19..]]);
        let doc = parse(&original);
        let bytes = snapshot(doc);
        let mut at = 104;
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
        let mut output = ptr::NonNull::dangling().as_ptr();
        assert_eq!(
            emf_document_emf_plus_snapshot_v1(
                doc,
                &options(bytes.len() as u64 - 1),
                ptr::null(),
                &mut output,
                ptr::null_mut()
            ),
            EMF_LIMIT_EXCEEDED
        );
        assert!(output.is_null());
        assert_eq!(
            emf_document_emf_plus_snapshot_v1(
                doc,
                &options(bytes.len() as u64),
                ptr::null(),
                &mut output,
                ptr::null_mut()
            ),
            EMF_OK
        );
        assert_eq!(view(output), bytes);
        assert_eq!(emf_serialize(doc, &mut output, ptr::null_mut()), EMF_OK);
        assert_eq!(view(output), original);
        emf_document_free(doc);
    }
}

fn object_prefix(first: usize, last: usize, total: Option<u32>, present: bool) -> Vec<u8> {
    let mut bytes = words(&[u32::from(total.is_some()), total.unwrap_or(0)]);
    count(&mut bytes, first as u64);
    count(&mut bytes, last as u64);
    bytes.extend(words(&[u32::from(present)]));
    bytes
}
fn blob(bytes: &[u8]) -> Vec<u8> {
    let mut out = vec![];
    count(&mut out, bytes.len() as u64);
    out.extend(bytes);
    out
}
fn word_array(values: &[u32]) -> Vec<u8> {
    let mut out = vec![];
    count(&mut out, values.len() as u64);
    out.extend(words(values));
    out
}
fn add_object_case(
    cases: &mut Vec<(Vec<u8>, u32, Vec<u8>)>,
    value: emf_core::emf_plus::ObjectData,
    expected: Vec<u8>,
) {
    let index = cases.len();
    let object_type = value.object_type();
    let body = value
        .serialize(&emf_core::SerializeLimits::default())
        .unwrap();
    let mut typed = object_prefix(index, index, None, true);
    typed.extend(words(&[7, object_type as u32]));
    typed.extend(expected);
    cases.push((
        frame(0x4008, (object_type as u16) << 8 | 7, &body, b"RAW!"),
        0x105,
        typed,
    ));
}

#[test]
fn normalized_objects_cover_scalars_strings_images_unknown_and_redefinitions() {
    use emf_core::emf_plus::*;
    let mut cases = vec![];
    let version = 0xdbc01002;
    let bits = 0x7fc12345;
    add_object_case(
        &mut cases,
        ObjectData::SolidBrush {
            version,
            argb: 0x80ff0033,
        },
        words(&[1, version, 0x80ff0033]),
    );
    add_object_case(
        &mut cases,
        ObjectData::HatchBrush {
            version,
            style: u32::MAX,
            foreground: 0,
            background: 0x80000000,
        },
        words(&[2, version, u32::MAX, 0, 0x80000000]),
    );
    let mut expected = words(&[9, version, bits, 3, u32::MAX, 0xa5b6]);
    count(&mut expected, 3);
    expected.extend([0, 0xd8, 65, 0, 0xff, 0xff]);
    expected.extend(blob(&[0xa5, 0xb6]));
    add_object_case(
        &mut cases,
        ObjectData::Font {
            version,
            em_size: bits,
            size_unit: 3,
            style: -1,
            reserved: 0xa5b6,
            family_name: vec![0xd800, 65, 0xffff],
            suffix: vec![0xa5, 0xb6],
        },
        expected,
    );
    let format = StringFormat {
        version,
        flags: u32::MAX,
        language: 1,
        alignment: 2,
        line_alignment: 3,
        digit_substitution: 4,
        digit_language: 5,
        first_tab_offset: bits,
        hotkey_prefix: -1,
        leading_margin: 0x80000000,
        trailing_margin: bits,
        tracking: 9,
        trimming: 10,
        tab_stops: vec![bits, 0x80000000],
        character_ranges: vec![[i32::MIN, -1], [0, i32::MAX]],
    };
    let mut expected = words(&[
        10,
        version,
        u32::MAX,
        1,
        2,
        3,
        4,
        5,
        bits,
        u32::MAX,
        0x80000000,
        bits,
        9,
        10,
    ]);
    expected.extend(word_array(&[bits, 0x80000000]));
    count(&mut expected, 2);
    expected.extend(words(&[0x80000000, u32::MAX, 0, 0x7fffffff]));
    add_object_case(&mut cases, ObjectData::StringFormat(format), expected);
    add_object_case(
        &mut cases,
        ObjectData::ImageAttributes {
            version,
            reserved1: 1,
            wrap_mode: 2,
            clamp_argb: 3,
            object_clamp: -1,
            reserved2: 4,
        },
        words(&[11, version, 1, 2, 3, u32::MAX, 4]),
    );
    for palette in [
        None,
        Some(Palette {
            style_flags: u32::MAX,
            entries: vec![],
        }),
        Some(Palette {
            style_flags: 7,
            entries: vec![0x80ff0033, 0],
        }),
    ] {
        let pixel_format = if palette.is_some() {
            0x00030803
        } else {
            0x0026200a
        };
        let mut expected = words(&[
            12,
            version,
            u32::MAX,
            0x80000000,
            u32::MAX,
            pixel_format,
            u32::from(palette.is_some()),
        ]);
        if let Some(palette) = &palette {
            expected.extend(words(&[palette.style_flags]));
            expected.extend(word_array(&palette.entries));
        }
        expected.extend(blob(&[0xa5, 0xb6, 0, 0xff]));
        add_object_case(
            &mut cases,
            ObjectData::PixelBitmap(PixelBitmap {
                version,
                width: -1,
                height: i32::MIN,
                stride: -1,
                pixel_format,
                palette,
                pixels: vec![0xa5, 0xb6, 0, 0xff],
            }),
            expected,
        );
    }
    let mut expected = words(&[13, version, u32::MAX, 2, 0x80000000, 0xdeadbeef, 1]);
    expected.extend(blob(&[1, 2, 3, 4]));
    add_object_case(
        &mut cases,
        ObjectData::BitmapImage {
            version,
            width: -1,
            height: 2,
            stride: i32::MIN,
            pixel_format: 0xdeadbeef,
            bitmap_type: 1,
            data: vec![1, 2, 3, 4],
        },
        expected,
    );
    let mut expected = words(&[14, version, 3]);
    expected.extend(blob(&[1, 2, 3]));
    expected.extend(blob(&[0xa5]));
    add_object_case(
        &mut cases,
        ObjectData::MetafileImage {
            version,
            metafile_type: 3,
            data: vec![1, 2, 3],
            suffix: vec![0xa5],
        },
        expected,
    );
    let mut expected = words(&[0, 127]);
    expected.extend(blob(&[0xff, 0x80, 0, 1]));
    add_object_case(
        &mut cases,
        ObjectData::Opaque {
            object_type: 127,
            bytes: vec![0xff, 0x80, 0, 1],
        },
        expected,
    );
    // Unknown brush subtype is normalized as an opaque body, preserving identity.
    let unknown = words(&[version, 0x12345678, 1]);
    let mut expected = words(&[0, 1]);
    expected.extend(blob(&unknown));
    add_object_case(
        &mut cases,
        ObjectData::Opaque {
            object_type: 1,
            bytes: unknown,
        },
        expected,
    );
    assert_normalized_cases(cases);
}

#[test]
fn normalized_object_chains_emit_once_at_first_fragment_and_keep_raw_bytes() {
    let body = words(&[0xdbc01002, 0, 0x80ff0033]);
    let mut first = words(&[12]);
    first.extend(&body[..5]);
    let first = frame(0x4008, 0x8107, &first, b"PAD");
    let final_frame = frame(0x4008, 0x0107, &body[5..], b"!");
    let mut normalized = object_prefix(0, 1, Some(12), true);
    normalized.extend(words(&[7, 1, 1, 0xdbc01002, 0x80ff0033]));
    let continuation = object_prefix(0, 1, None, false);
    // A C-set final fragment is also supported and retains its total-size word.
    let mut c_set_final = words(&[12]);
    c_set_final.extend(&body[5..]);
    let c_set_final = frame(0x4008, 0x8107, &c_set_final, b"!");
    for (last, expected) in [
        (final_frame, continuation),
        (c_set_final, object_prefix(0, 1, Some(12), false)),
    ] {
        assert_normalized_cases(vec![
            (first.clone(), 0x105, normalized.clone()),
            (last, 0x105, expected),
        ]);
    }
}

#[test]
fn normalized_objects_cover_nested_paths_regions_gradients_caps_and_pen_brushes() {
    use emf_core::emf_plus::*;
    let version = 0xdbc01002;
    let nan = 0x7fc12345;
    let matrix = [nan, 0x80000000, 1, 2, 3, 4];
    let mut cases = vec![];
    let path = Path {
        version,
        flags: 0x4000,
        points: PointData::Integer(vec![[i16::MIN, i16::MAX]]),
        point_types: PathPointTypes::Plain(vec![0x83]),
        alignment_padding: vec![0xa5, 0xb6, 0xc7],
    };
    let mut path_bytes = words(&[version, 0x4000, 1]);
    count(&mut path_bytes, 1);
    path_bytes.extend(words(&[0xffff8000, 32767, 0]));
    path_bytes.extend(blob(&[0x83]));
    path_bytes.extend(blob(&[0xa5, 0xb6, 0xc7]));
    let mut expected = words(&[7]);
    expected.extend(&path_bytes);
    add_object_case(&mut cases, ObjectData::Path(path.clone()), expected);
    let relative = Path {
        version,
        flags: 0x800,
        points: PointData::Relative(vec![[
            RelativeCoordinate::Seven(-64),
            RelativeCoordinate::Fifteen(-16384),
        ]]),
        point_types: PathPointTypes::RunLength(vec![PathPointRun {
            header: 0xc1,
            point_type: 0xff,
        }]),
        alignment_padding: vec![0xe8, 0xf9, 0xaa],
    };
    let mut expected = words(&[7, version, 0x800, 2]);
    count(&mut expected, 1);
    expected.extend(words(&[7, (-64i32) as u32, 15, (-16384i32) as u32, 1]));
    count(&mut expected, 1);
    expected.extend([0xc1, 0xff]);
    expected.extend(blob(&[0xe8, 0xf9, 0xaa]));
    add_object_case(&mut cases, ObjectData::Path(relative), expected);
    let float_path = Path {
        version,
        flags: 0,
        points: PointData::Float(vec![[nan, 0x80000000]]),
        point_types: PathPointTypes::Plain(vec![0]),
        alignment_padding: vec![1, 2, 3],
    };
    let mut expected = words(&[7, version, 0, 0]);
    count(&mut expected, 1);
    expected.extend(words(&[nan, 0x80000000, 0]));
    expected.extend(blob(&[0]));
    expected.extend(blob(&[1, 2, 3]));
    add_object_case(&mut cases, ObjectData::Path(float_path), expected);
    let nodes = vec![
        RegionNode::Binary { operation: 5 },
        RegionNode::Binary { operation: 1 },
        RegionNode::Rectangle([nan, 0x80000000, 1, 2]),
        RegionNode::Path(path.clone()),
        RegionNode::Binary { operation: 2 },
        RegionNode::Empty,
        RegionNode::Infinite,
    ];
    let mut expected = words(&[8, version]);
    count(&mut expected, 7);
    expected.extend(words(&[1, 5, 1, 1, 2, nan, 0x80000000, 1, 2, 3]));
    expected.extend(&path_bytes);
    expected.extend(words(&[1, 2, 4, 5]));
    add_object_case(
        &mut cases,
        ObjectData::Region(Region { version, nodes }),
        expected,
    );
    let cap = CustomLineCap {
        version,
        data: CustomLineCapData::Default(DefaultLineCap {
            flags: 3,
            base_cap: 1,
            base_inset: nan,
            stroke_start_cap: 2,
            stroke_end_cap: 3,
            stroke_join: 4,
            stroke_miter_limit: 5,
            width_scale: 6,
            fill_hot_spot: [7, 8],
            stroke_hot_spot: [9, 10],
            fill_path: Some(path.clone()),
            line_path: Some(path.clone()),
        }),
    };
    let mut cap_bytes = words(&[version, 0, 3, 1, nan, 2, 3, 4, 5, 6, 7, 8, 9, 10, 1]);
    cap_bytes.extend(&path_bytes);
    cap_bytes.extend(words(&[1]));
    cap_bytes.extend(&path_bytes);
    let mut expected = words(&[15]);
    expected.extend(&cap_bytes);
    add_object_case(&mut cases, ObjectData::CustomLineCap(cap.clone()), expected);
    let arrow = CustomLineCap {
        version,
        data: CustomLineCapData::AdjustableArrow(ArrowLineCap {
            width: nan,
            height: 0x80000000,
            middle_inset: 1,
            fill_state: u32::MAX,
            line_start_cap: 2,
            line_end_cap: 3,
            line_join: 4,
            line_miter_limit: 5,
            width_scale: 6,
            fill_hot_spot: [7, 8],
            line_hot_spot: [9, 10],
        }),
    };
    let arrow_bytes = words(&[
        version,
        1,
        nan,
        0x80000000,
        1,
        u32::MAX,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
    ]);
    let mut expected = words(&[15]);
    expected.extend(&arrow_bytes);
    add_object_case(
        &mut cases,
        ObjectData::CustomLineCap(arrow.clone()),
        expected,
    );
    let linear = LinearGradient {
        flags: 0x1a,
        wrap_mode: -1,
        rectangle: [nan, 0x80000000, 1, 2],
        start_color: 3,
        end_color: 4,
        reserved: [5, 6],
        transform: Some(matrix),
        blends: vec![vec![[nan, 7], [0x80000000, 8]], vec![[9, 10], [11, 12]]],
    };
    let mut linear_bytes = words(&[0x1a, u32::MAX, nan, 0x80000000, 1, 2, 3, 4, 5, 6, 1]);
    linear_bytes.extend(words(&matrix));
    count(&mut linear_bytes, 2);
    count(&mut linear_bytes, 2);
    linear_bytes.extend(words(&[nan, 7, 0x80000000, 8]));
    count(&mut linear_bytes, 2);
    linear_bytes.extend(words(&[9, 10, 11, 12]));
    let mut expected = words(&[5, version]);
    expected.extend(&linear_bytes);
    add_object_case(
        &mut cases,
        ObjectData::LinearGradientBrush {
            version,
            data: linear.clone(),
        },
        expected,
    );
    let gradient = PathGradient {
        flags: 0x47,
        wrap_mode: -1,
        center_color: 1,
        center_point: [nan, 0x80000000],
        surrounding_colors: vec![2, 3],
        boundary: GradientBoundary::Path(path),
        transform: Some(matrix),
        blend: Some(vec![]),
        focus_scales: Some([nan, 0x80000000]),
    };
    let mut gradient_bytes = words(&[0x47, u32::MAX, 1, nan, 0x80000000]);
    gradient_bytes.extend(word_array(&[2, 3]));
    gradient_bytes.extend(words(&[0]));
    gradient_bytes.extend(&path_bytes);
    gradient_bytes.extend(words(&[1]));
    gradient_bytes.extend(words(&matrix));
    gradient_bytes.extend(words(&[1]));
    count(&mut gradient_bytes, 0);
    gradient_bytes.extend(words(&[1, nan, 0x80000000]));
    let mut expected = words(&[4, version]);
    expected.extend(&gradient_bytes);
    add_object_case(
        &mut cases,
        ObjectData::PathGradientBrush {
            version,
            data: gradient.clone(),
        },
        expected,
    );
    let points_gradient = PathGradient {
        flags: 0,
        wrap_mode: 0,
        center_color: 0,
        center_point: [0, 0],
        surrounding_colors: vec![],
        boundary: GradientBoundary::Points(vec![[nan, 0x80000000]]),
        transform: None,
        blend: None,
        focus_scales: None,
    };
    let mut expected = words(&[4, version, 0, 0, 0, 0, 0]);
    count(&mut expected, 0);
    expected.extend(words(&[1]));
    count(&mut expected, 1);
    expected.extend(words(&[nan, 0x80000000, 0, 0, 0]));
    add_object_case(
        &mut cases,
        ObjectData::PathGradientBrush {
            version,
            data: points_gradient,
        },
        expected,
    );
    let texture = Texture {
        flags: 2,
        wrap_mode: -1,
        transform: Some(matrix),
        image: Some(TextureImage::Metafile {
            version,
            metafile_type: 4,
            data: vec![0xa5],
            suffix: vec![0xb6, 0xc7, 0xd8],
        }),
    };
    let mut texture_bytes = words(&[2, u32::MAX, 1]);
    texture_bytes.extend(words(&matrix));
    texture_bytes.extend(words(&[1, 3, version, 4]));
    texture_bytes.extend(blob(&[0xa5]));
    texture_bytes.extend(blob(&[0xb6, 0xc7, 0xd8]));
    let mut expected = words(&[3, version]);
    expected.extend(&texture_bytes);
    add_object_case(
        &mut cases,
        ObjectData::TextureBrush {
            version,
            data: texture.clone(),
        },
        expected,
    );
    for (brush, tag, brush_bytes) in [
        (PenBrushData::Solid { argb: nan }, 0, words(&[nan])),
        (
            PenBrushData::Hatch {
                style: 1,
                foreground: 2,
                background: 3,
            },
            1,
            words(&[1, 2, 3]),
        ),
        (PenBrushData::Texture(texture), 2, texture_bytes),
        (PenBrushData::PathGradient(gradient), 3, gradient_bytes),
        (PenBrushData::LinearGradient(linear), 4, linear_bytes),
    ] {
        let pen = Pen {
            version,
            flags: 0x1fff,
            unit: 1,
            width: nan,
            transform: Some(matrix),
            start_cap: Some(-1),
            end_cap: Some(i32::MIN),
            join: Some(3),
            miter_limit: Some(nan),
            line_style: Some(4),
            dashed_line_cap: Some(5),
            dash_offset: Some(0x80000000),
            dash_pattern: Some(vec![]),
            alignment: Some(-1),
            compound_line: Some(vec![nan, 0x80000000]),
            custom_caps: vec![cap.clone(), arrow.clone()],
            brush: PenBrush {
                version,
                data: brush,
            },
        };
        let mut expected = words(&[6, version, 0x1fff, 1, nan, 1]);
        expected.extend(words(&matrix));
        expected.extend(words(&[
            1,
            u32::MAX,
            1,
            0x80000000,
            1,
            3,
            1,
            nan,
            1,
            4,
            1,
            5,
            1,
            0x80000000,
            1,
        ]));
        count(&mut expected, 0);
        expected.extend(words(&[1, u32::MAX, 1]));
        expected.extend(word_array(&[nan, 0x80000000]));
        count(&mut expected, 2);
        expected.extend(&cap_bytes);
        expected.extend(&arrow_bytes);
        expected.extend(words(&[version, tag]));
        expected.extend(brush_bytes);
        add_object_case(&mut cases, ObjectData::Pen(pen), expected);
    }
    assert_normalized_cases(cases);
}

#[test]
fn normalized_object_optional_empty_values_and_texture_image_variants() {
    use emf_core::emf_plus::*;
    let version = 0xdbc01002;
    let mut cases = vec![];
    let pixel = PixelBitmap {
        version,
        width: -1,
        height: 0,
        stride: i32::MIN,
        pixel_format: 0x0026200a,
        palette: None,
        pixels: vec![],
    };
    let mut pixel_bytes = words(&[1, version, u32::MAX, 0, 0x80000000, 0x0026200a, 0]);
    pixel_bytes.extend(blob(&[]));
    let mut bitmap_bytes = words(&[2, version, 1, 2, 3, 4, 1]);
    bitmap_bytes.extend(blob(&[0xa5, 0xb6, 0xc7, 0xd8]));
    for (image, bytes) in [
        (None, vec![]),
        (Some(TextureImage::PixelBitmap(pixel)), pixel_bytes),
        (
            Some(TextureImage::Bitmap {
                version,
                width: 1,
                height: 2,
                stride: 3,
                pixel_format: 4,
                bitmap_type: 1,
                data: vec![0xa5, 0xb6, 0xc7, 0xd8],
            }),
            bitmap_bytes,
        ),
    ] {
        let mut expected = words(&[3, version, 0, 0, 0, u32::from(image.is_some())]);
        expected.extend(bytes);
        add_object_case(
            &mut cases,
            ObjectData::TextureBrush {
                version,
                data: Texture {
                    flags: 0,
                    wrap_mode: 0,
                    transform: None,
                    image,
                },
            },
            expected,
        );
    }
    let cap = CustomLineCap {
        version,
        data: CustomLineCapData::Default(DefaultLineCap {
            flags: 0,
            base_cap: 0,
            base_inset: 0,
            stroke_start_cap: 0,
            stroke_end_cap: 0,
            stroke_join: 0,
            stroke_miter_limit: 0,
            width_scale: 0,
            fill_hot_spot: [0, 0],
            stroke_hot_spot: [0, 0],
            fill_path: None,
            line_path: None,
        }),
    };
    let mut expected = words(&[15, version]);
    expected.extend(words(&[0; 15]));
    add_object_case(&mut cases, ObjectData::CustomLineCap(cap), expected);
    let pen = Pen {
        version,
        flags: 0,
        unit: 0,
        width: 0,
        transform: None,
        start_cap: None,
        end_cap: None,
        join: None,
        miter_limit: None,
        line_style: None,
        dashed_line_cap: None,
        dash_offset: None,
        dash_pattern: None,
        alignment: None,
        compound_line: None,
        custom_caps: vec![],
        brush: PenBrush {
            version,
            data: PenBrushData::Solid { argb: 0 },
        },
    };
    let mut expected = words(&[6, version, 0, 0, 0]);
    expected.extend(words(&[0; 19]));
    count(&mut expected, 0);
    expected.extend(words(&[version, 0, 0]));
    add_object_case(&mut cases, ObjectData::Pen(pen), expected);
    assert_normalized_cases(cases);
}

#[test]
fn invalid_object_layouts_and_incomplete_chains_fail_atomically() {
    let mut first = words(&[12]);
    first.extend([0, 1, 2, 3]);
    for raw in [
        frame(0x4008, 0x0107, &words(&[0xdbc01002, 0]), &[]),
        frame(0x4008, 0x8107, &first, &[]),
    ] {
        unsafe {
            let original = input(&[&raw]);
            let doc = parse(&original);
            let mut output = ptr::NonNull::dangling().as_ptr();
            assert_eq!(
                emf_document_emf_plus_snapshot_v1(
                    doc,
                    &options(1 << 20),
                    ptr::null(),
                    &mut output,
                    ptr::null_mut()
                ),
                EMF_FORMAT_ERROR
            );
            assert!(output.is_null());
            assert_eq!(emf_serialize(doc, &mut output, ptr::null_mut()), EMF_OK);
            assert_eq!(view(output), original);
            emf_document_free(doc);
        }
    }
}

#[test]
fn aggregate_budget_includes_retained_stages_and_output() {
    let logical = (0..4)
        .flat_map(|id| frame(0x4008, 0x7f00 | id, &vec![0x5a; 4096], &[]))
        .collect::<Vec<_>>();
    // Each standalone stage fits this cap: resetting between them bypassed the
    // cumulative retained-buffer ceiling before the shared-budget integration.
    let core_limits = emf_core::ParseLimits {
        max_allocated_bytes: 100000,
        max_work_units: 4000,
        ..Default::default()
    };
    let core_doc = emf_core::parse(&input(&[&logical]), &Default::default()).unwrap();
    let embedded = core_doc.structured_emf_plus(&core_limits).unwrap();
    let definitions = embedded.stream.object_definitions(&core_limits).unwrap();
    for definition in definitions {
        definition.decode(&core_limits).unwrap();
    }
    unsafe {
        let doc = parse(&input(&[&logical]));
        let expected = snapshot(doc);
        let mut limits = EmfLimits {
            struct_size: size_of::<EmfLimits>() as u32,
            version: 1,
            max_input_bytes: 1000000,
            max_record_bytes: 1000000,
            max_records: 4,
            max_allocated_bytes: 100000,
            max_work_units: 1000000,
        };
        let mut output = ptr::dangling_mut();
        assert_eq!(
            emf_document_emf_plus_snapshot_v1(
                doc,
                &options(1000000),
                &limits,
                &mut output,
                ptr::null_mut()
            ),
            EMF_LIMIT_EXCEEDED
        );
        assert!(output.is_null());
        assert_eq!(snapshot(doc), expected);
        limits.max_allocated_bytes = 1000000;
        limits.max_work_units = 4000;
        assert_eq!(
            emf_document_emf_plus_snapshot_v1(
                doc,
                &options(1000000),
                &limits,
                &mut output,
                ptr::null_mut()
            ),
            EMF_LIMIT_EXCEEDED
        );
        assert!(output.is_null());
        // Find the exact inclusive allocation and work caps through ABI 1.
        for work in [false, true] {
            limits.max_allocated_bytes = 1000000;
            limits.max_work_units = 1000000;
            let (mut low, mut high) = (0, 1000000);
            while low < high {
                let mid = low + (high - low) / 2;
                if work {
                    limits.max_work_units = mid;
                } else {
                    limits.max_allocated_bytes = mid;
                }
                let mut output = ptr::dangling_mut();
                let status = emf_document_emf_plus_snapshot_v1(
                    doc,
                    &options(1000000),
                    &limits,
                    &mut output,
                    ptr::null_mut(),
                );
                if status == EMF_OK {
                    assert_eq!(view(output), expected);
                    high = mid;
                } else {
                    assert_eq!(status, EMF_LIMIT_EXCEEDED);
                    assert!(output.is_null());
                    low = mid + 1;
                }
            }
            assert!(low > 0);
            for (cap, status) in [(low - 1, EMF_LIMIT_EXCEEDED), (low, EMF_OK)] {
                if work {
                    limits.max_work_units = cap;
                } else {
                    limits.max_allocated_bytes = cap;
                }
                let mut output = ptr::dangling_mut();
                assert_eq!(
                    emf_document_emf_plus_snapshot_v1(
                        doc,
                        &options(1000000),
                        &limits,
                        &mut output,
                        ptr::null_mut()
                    ),
                    status
                );
                if status == EMF_OK {
                    assert_eq!(view(output), expected);
                } else {
                    assert!(output.is_null());
                }
            }
        }
        emf_document_free(doc);
    }
}

#[test]
fn empty_snapshot_output_is_in_the_cumulative_allocation_budget() {
    unsafe {
        let doc = parse(&input(&[]));
        let expected = snapshot(doc);
        assert_eq!(expected.len(), 40);
        let mut limits = EmfLimits {
            struct_size: size_of::<EmfLimits>() as u32,
            version: 1,
            max_input_bytes: 0,
            max_record_bytes: 0,
            max_records: 0,
            max_allocated_bytes: 40,
            max_work_units: 3,
        };
        for (allocated, work, status) in [
            (39, 3, EMF_LIMIT_EXCEEDED),
            (40, 2, EMF_LIMIT_EXCEEDED),
            (40, 3, EMF_OK),
        ] {
            limits.max_allocated_bytes = allocated;
            limits.max_work_units = work;
            let mut output = ptr::dangling_mut();
            assert_eq!(
                emf_document_emf_plus_snapshot_v1(
                    doc,
                    &options(40),
                    &limits,
                    &mut output,
                    ptr::null_mut()
                ),
                status
            );
            if status == EMF_OK {
                assert_eq!(view(output), expected);
            } else {
                assert!(output.is_null());
            }
        }
        emf_document_free(doc);
    }
}
