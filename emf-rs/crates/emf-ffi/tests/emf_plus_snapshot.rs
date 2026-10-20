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
    // Unsupported core record types and pending Objects keep their raw payloads.
    cases.push((frame(0x7fff, 0xbeef, b"raw!", &[]), 0, vec![]));
    cases.push((
        frame(0x4008, 0x0101, &words(&[0xdbc01002, 0, 0x80ff0033]), &[]),
        0x105,
        vec![],
    ));
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
