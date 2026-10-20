use emf_core::{
    emf_plus::{self as plus, Error, ObjectBody, RecordData},
    LimitKind, ParseFailure, ParseLimits, SerializeFailure, SerializeLimits,
};
fn words(values: &[u32]) -> Vec<u8> {
    values.iter().flat_map(|v| v.to_le_bytes()).collect()
}
fn record(kind: u16, flags: u16, bytes: &[u8], pad: &[u8]) -> Vec<u8> {
    let mut out = Vec::new();
    out.extend_from_slice(&kind.to_le_bytes());
    out.extend_from_slice(&flags.to_le_bytes());
    out.extend_from_slice(&(12u32 + bytes.len() as u32 + pad.len() as u32).to_le_bytes());
    out.extend_from_slice(&(bytes.len() as u32).to_le_bytes());
    out.extend_from_slice(bytes);
    out.extend_from_slice(pad);
    out
}
fn parse(bytes: &[u8]) -> plus::Stream {
    plus::parse(bytes, &ParseLimits::default()).unwrap()
}

#[test]
fn typed_header_state_transform_edits_preserve_unknown_padding_and_segments() {
    let mut bytes = record(0x4001, 0xa001, &words(&[0xdbc01002, 1, 96, 120]), &[]);
    bytes.extend(record(0x401d, 0x9876, &words(&[(-17i32) as u32, 32]), &[]));
    bytes.extend(record(
        0x402c,
        0x2000,
        &words(&[0x7fc01234, 0x80000000, 0, 0, 0, 0]),
        &[],
    ));
    bytes.extend(record(0x7777, 0xbeef, &[10, 20, 30], &[0xab]));
    bytes.extend(record(0x4002, 0x9911, &[], &[]));
    let parts = [&bytes[..3], &bytes[3..30], &bytes[30..30], &bytes[30..]];
    let mut stream = plus::parse_segments(&parts, &ParseLimits::default()).unwrap();
    assert!(stream.records[0].is_dual());
    let RecordData::Header(header) = &stream.records[0].data else {
        panic!()
    };
    assert_eq!(
        (header.version, header.logical_dpi_x, header.logical_dpi_y),
        (0xdbc01002, 96, 120)
    );
    assert_eq!(
        stream.records[1].data,
        RecordData::RenderingOrigin { x: -17, y: 32 }
    );
    assert!(stream.records[2].post_multiplied());
    assert_eq!(
        stream.records[2].data,
        RecordData::Matrix([0x7fc01234, 0x80000000, 0, 0, 0, 0])
    );
    assert_eq!(stream.records[3].padding, [0xab]);
    assert_eq!(plus::serialize(&stream).unwrap(), bytes);
    assert_eq!(
        plus::serialize_segments(&stream, &SerializeLimits::default()).unwrap(),
        parts
    );
    stream.records[1].data = RecordData::RenderingOrigin {
        x: i32::MIN,
        y: -44,
    };
    let edited = plus::serialize(&stream).unwrap();
    let reparsed = parse(&edited);
    assert_eq!(reparsed.records[1].data, stream.records[1].data);
    assert_eq!(reparsed.records[3], stream.records[3]);
    assert_eq!(&edited[..28], &bytes[..28]);
    assert_eq!(&edited[48..], &bytes[48..]);
}

#[test]
fn every_fixed_family_has_typed_exact_and_mutable_roundtrip() {
    let groups: &[(usize, &[u16])] = &[
        (
            0,
            &[
                0x4002, 0x4004, 0x401e, 0x401f, 0x4020, 0x4021, 0x4022, 0x4023, 0x4024, 0x402b,
                0x4031, 0x4033, 0x4034,
            ],
        ),
        (4, &[0x4009, 0x4025, 0x4026, 0x4028, 0x4029, 0x402f, 0x4030]),
        (8, &[0x401d, 0x402d, 0x402e, 0x4035]),
        (16, &[0x4001, 0x4032]),
        (24, &[0x402a, 0x402c]),
        (36, &[0x4027]),
    ];
    for &(length, kinds) in groups {
        for &kind in kinds {
            let bytes = record(kind, 0x1234, &vec![0xa5; length], &[]);
            let mut stream = parse(&bytes);
            assert!(
                !matches!(stream.records[0].data, RecordData::Opaque(_)),
                "{kind:04x}"
            );
            assert_eq!(plus::serialize(&stream).unwrap(), bytes);
            stream.records[0].flags ^= 1;
            let out = plus::serialize(&stream).unwrap();
            assert_eq!(parse(&out).records, stream.records);
            assert_eq!(&out[4..], &bytes[4..]);
        }
    }
}

#[test]
fn malformed_layouts_and_all_parse_budgets_are_rejected() {
    let good = record(0x4009, 0, &words(&[0xff112233]), &[]);
    for len in 1..good.len() {
        assert!(plus::parse(&good[..len], &ParseLimits::default()).is_err());
    }
    for size in [0u32, 8, 13] {
        let mut bad = good.clone();
        bad[4..8].copy_from_slice(&size.to_le_bytes());
        assert!(matches!(
            plus::parse(&bad, &ParseLimits::default()),
            Err(Error::InvalidRecord { .. })
        ));
    }
    assert!(plus::parse(&record(0x4001, 0, &[], &[]), &ParseLimits::default()).is_err());
    for (kind, limits) in [
        (
            LimitKind::InputBytes,
            ParseLimits {
                max_input_bytes: 15,
                ..ParseLimits::default()
            },
        ),
        (
            LimitKind::RecordBytes,
            ParseLimits {
                max_record_bytes: 15,
                ..ParseLimits::default()
            },
        ),
        (
            LimitKind::RecordCount,
            ParseLimits {
                max_records: 0,
                ..ParseLimits::default()
            },
        ),
        (
            LimitKind::AllocatedBytes,
            ParseLimits {
                max_allocated_bytes: 0,
                ..ParseLimits::default()
            },
        ),
        (
            LimitKind::WorkUnits,
            ParseLimits {
                max_work_units: 0,
                ..ParseLimits::default()
            },
        ),
    ] {
        assert!(
            matches!(plus::parse(&good, &limits), Err(Error::Resource(ParseFailure::LimitExceeded { kind: found, .. })) if found == kind)
        );
    }
}

#[test]
fn output_limits_and_inconsistent_edits_fail() {
    let bytes = record(0x4009, 0, &words(&[5]), &[]);
    let mut stream = parse(&bytes);
    for limits in [
        SerializeLimits {
            max_output_bytes: 15,
            ..SerializeLimits::default()
        },
        SerializeLimits {
            max_work_units: 2,
            ..SerializeLimits::default()
        },
    ] {
        assert!(matches!(
            plus::serialize_with_limits(&stream, &limits),
            Err(SerializeFailure::LimitExceeded { .. })
        ));
    }
    assert_eq!(
        plus::serialize_with_limits(
            &stream,
            &SerializeLimits {
                max_output_bytes: 16,
                max_work_units: 3
            }
        )
        .unwrap(),
        bytes
    );
    assert!(matches!(
        plus::serialize_segments(
            &stream,
            &SerializeLimits {
                max_output_bytes: 16,
                max_work_units: 4
            }
        ),
        Err(SerializeFailure::LimitExceeded {
            kind: LimitKind::WorkUnits,
            ..
        })
    ));
    stream.records[0].data = RecordData::Empty;
    assert!(matches!(
        plus::serialize(&stream),
        Err(SerializeFailure::Inconsistent { .. })
    ));
}

fn objects(final_continued: bool) -> Vec<u8> {
    let body = words(&[0xdbc01002, 0, 0xffaabbcc]);
    let mut first = words(&[body.len() as u32]);
    first.extend_from_slice(&body[..5]);
    let mut last = if final_continued {
        words(&[12])
    } else {
        Vec::new()
    };
    last.extend_from_slice(&body[5..]);
    let mut bytes = record(0x4008, 0x8107, &first, &[0x91, 0x92, 0x93]);
    bytes.extend(record(
        0x4008,
        if final_continued { 0x8107 } else { 0x0107 },
        &last,
        &[0x94],
    ));
    bytes
}

#[test]
fn object_continuation_supports_spec_and_windows_final_chunks_and_atomic_edits() {
    for continued in [false, true] {
        let bytes = objects(continued);
        let mut stream = parse(&bytes);
        let definitions = stream.object_definitions(&ParseLimits::default()).unwrap();
        assert_eq!(definitions.len(), 1);
        let object = &definitions[0];
        assert_eq!(
            (
                object.id,
                object.object_type,
                object.first_record,
                object.last_record
            ),
            (7, 1, 0, 1)
        );
        assert_eq!(
            object.body().unwrap(),
            ObjectBody::SolidBrush {
                version: 0xdbc01002,
                argb: 0xffaabbcc
            }
        );
        assert_eq!(plus::serialize(&stream).unwrap(), bytes);
        let replacement = words(&[0xdbc01002, 0, 0xff123456]);
        let before = stream.clone();
        assert!(stream
            .replace_object_bytes(
                0,
                &replacement,
                &ParseLimits {
                    max_allocated_bytes: 0,
                    ..ParseLimits::default()
                }
            )
            .is_err());
        assert_eq!(stream, before);
        stream
            .replace_object_bytes(0, &replacement, &ParseLimits::default())
            .unwrap();
        let output = plus::serialize(&stream).unwrap();
        let parsed = parse(&output);
        assert_eq!(
            parsed.object_definitions(&ParseLimits::default()).unwrap()[0]
                .body()
                .unwrap(),
            ObjectBody::SolidBrush {
                version: 0xdbc01002,
                argb: 0xff123456
            }
        );
        assert_eq!(parsed.records[0].padding, [0x91, 0x92, 0x93]);
        assert_eq!(parsed.records[1].flags, before.records[1].flags);
    }
}

#[test]
fn bad_continuations_reject_before_expansion() {
    let good = objects(false);
    for (position, value) in [(2, 0x40u8), (12, 0xff), (26, 8)] {
        let mut bad = good.clone();
        bad[position] = value;
        assert!(
            plus::parse(&bad, &ParseLimits::default()).is_err(),
            "position {position}"
        );
    }
    let lone = record(0x4008, 0x8101, &words(&[u32::MAX, 0]), &[]);
    assert!(matches!(
        plus::parse(&lone, &ParseLimits::default()),
        Err(Error::Resource(ParseFailure::LimitExceeded {
            kind: LimitKind::RecordBytes,
            ..
        }))
    ));
    let stream = parse(&good);
    assert!(stream
        .object_definitions(&ParseLimits {
            max_allocated_bytes: 11,
            ..ParseLimits::default()
        })
        .is_err());
}

#[test]
fn borrowed_font_name_bounds_and_image_attribute_reserved_values() {
    let mut font = words(&[0xdbc01002, 12f32.to_bits(), 3, 5, 0xdeadbeef, 2]);
    font.extend_from_slice(&[0, 0xd8, 65, 0]);
    let stream = parse(&record(0x4008, 0x0601, &font, &[]));
    let defs = stream.object_definitions(&ParseLimits::default()).unwrap();
    let ObjectBody::Font {
        family_name_utf16le,
        reserved,
        ..
    } = defs[0].body().unwrap()
    else {
        panic!()
    };
    assert_eq!(family_name_utf16le, [0, 0xd8, 65, 0]);
    assert_eq!(reserved, 0xdeadbeef);
    let mut bad = defs[0].clone();
    bad.bytes[20..24].copy_from_slice(&u32::MAX.to_le_bytes());
    assert!(bad.body().is_err());
    let attributes = words(&[0xdbc01002, 0xdeadbeef, 4, 0x12345678, u32::MAX, 9]);
    let stream = parse(&record(0x4008, 0x0802, &attributes, &[]));
    let defs = stream.object_definitions(&ParseLimits::default()).unwrap();
    assert!(matches!(
        defs[0].body().unwrap(),
        ObjectBody::ImageAttributes {
            reserved1: 0xdeadbeef,
            object_clamp: -1,
            reserved2: 9,
            ..
        }
    ));
}
