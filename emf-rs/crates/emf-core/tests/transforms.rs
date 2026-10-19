use emf_core::{
    parse, serialize, serialize_with_limits, DiagnosticKind, EditFailure, Float32, LimitKind,
    ParseFailure, ParseLimits, Point, RecordData, ScaleFactors, SerializeFailure, SerializeLimits,
    XForm,
};

const TYPES: [u32; 6] = [31, 32, 35, 36, 41, 58];

fn record(kind: u32, payload: &[u8]) -> Vec<u8> {
    let mut bytes = kind.to_le_bytes().to_vec();
    bytes.extend_from_slice(&(8 + payload.len() as u32).to_le_bytes());
    bytes.extend_from_slice(payload);
    bytes
}

fn header() -> Vec<u8> {
    let mut bytes = vec![0; 112];
    bytes[..4].copy_from_slice(&1u32.to_le_bytes());
    bytes[4..8].copy_from_slice(&112u32.to_le_bytes());
    bytes[40..44].copy_from_slice(&0x464d4520u32.to_le_bytes());
    bytes[108..].copy_from_slice(b"head");
    bytes
}

fn payload(kind: u32, values: [u32; 8]) -> Vec<u8> {
    let count = match kind {
        31 | 32 => 4,
        35 => 6,
        36 => 7,
        41 => 5,
        58 => 1,
        _ => panic!("unexpected transform type {kind}"),
    };
    values[..count]
        .iter()
        .flat_map(|value| value.to_le_bytes())
        .collect()
}

#[test]
fn transform_records_are_typed_and_round_trip_exactly() {
    for kind in TYPES {
        for values in VALUES {
            let mut input = header();
            input.extend(record(kind, &payload(kind, values)));
            let doc = parse(&input, &ParseLimits::default()).unwrap();
            assert_eq!(doc.records()[0].data(), &state(kind, values));
            assert!(!doc.is_edited());
            assert!(doc.diagnostics().is_empty());
            assert_eq!(serialize(&doc).unwrap(), input);
        }
    }
}

const VALUES: [[u32; 8]; 7] = [
    [0, 1, 2, 3, 0x78563412, 5, 6, 7],
    [
        0x7f800001, 0x7fc00001, 0xff800001, 0x80000000, 0, 0x7f800000, 0xffffffff, 0,
    ],
    [
        0xffc12345, 0xff800000, 0x00000001, 0x80000001, 0xffc00001, 0x3f800000, 0x80000000, 0,
    ],
    [u32::MAX; 8],
    [i32::MIN as u32; 8],
    [i32::MAX as u32; 8],
    [
        0,
        u32::MAX,
        i32::MIN as u32,
        i32::MAX as u32,
        0xff00807f,
        0xfffffffe,
        19,
        0x80000001,
    ],
];

fn append_siblings_and_tail(input: &mut Vec<u8>) {
    input.extend(record(17, &9u32.to_le_bytes()));
    input.extend(record(999, b"unknown!"));
    input.extend(record(14, &[0, 0, 0, 0, 16, 0, 0, 0, 20, 0, 0, 0]));
    input.extend_from_slice(b"tail");
}

fn state(kind: u32, values: [u32; 8]) -> RecordData {
    let scale = ScaleFactors {
        x_num: values[0] as i32,
        x_denom: values[1] as i32,
        y_num: values[2] as i32,
        y_denom: values[3] as i32,
    };
    let xform = XForm {
        m11: Float32::from_bits(values[0]),
        m12: Float32::from_bits(values[1]),
        m21: Float32::from_bits(values[2]),
        m22: Float32::from_bits(values[3]),
        dx: Float32::from_bits(values[4]),
        dy: Float32::from_bits(values[5]),
    };
    match kind {
        31 => RecordData::ScaleViewportExtEx { scale },
        32 => RecordData::ScaleWindowExtEx { scale },
        35 => RecordData::SetWorldTransform { xform },
        36 => RecordData::ModifyWorldTransform {
            xform,
            modify_mode: values[6],
        },
        41 => RecordData::AngleArc {
            center: Point {
                x: values[0] as i32,
                y: values[1] as i32,
            },
            radius: values[2],
            start_angle: Float32::from_bits(values[3]),
            sweep_angle: Float32::from_bits(values[4]),
        },
        58 => RecordData::SetMiterLimit {
            miter_limit: Float32::from_bits(values[0]),
        },
        _ => panic!("unexpected transform type {kind}"),
    }
}

#[test]
fn transform_edits_preserve_suffix_siblings_header_and_tail() {
    for kind in TYPES {
        for suffix in [
            &b""[..],
            &b"odd"[..],
            &b"suffix!!"[..],
            &b"0123456789abcdef"[..],
        ] {
            let mut input = header();
            let original = payload(kind, VALUES[0]);
            let mut bytes = original.clone();
            bytes.extend_from_slice(suffix);
            input.extend(record(kind, &bytes));
            append_siblings_and_tail(&mut input);
            for values in VALUES {
                let mut doc = parse(&input, &ParseLimits::default()).unwrap();
                assert_eq!(serialize(&doc).unwrap(), input);
                doc.edit_record(0, state(kind, values)).unwrap();
                assert!(doc.records()[0].is_edited());
                let out = serialize(&doc).unwrap();
                let mut expected = input.clone();
                expected[48..52].copy_from_slice(&(input.len() as u32).to_le_bytes());
                expected[52..56].copy_from_slice(&5u32.to_le_bytes());
                expected[120..120 + original.len()].copy_from_slice(&payload(kind, values));
                assert_eq!(out, expected, "type {kind}, values {values:?}");
                assert_eq!(
                    &out[120 + original.len()..120 + original.len() + suffix.len()],
                    suffix
                );
                let reparsed = parse(&out, &ParseLimits::default()).unwrap();
                assert_eq!(reparsed.records()[0].data(), &state(kind, values));
                assert_eq!(
                    reparsed.records()[0].size() as usize,
                    8 + original.len() + suffix.len()
                );
                assert_eq!(reparsed.header().n_bytes as usize, out.len());
                assert_eq!(reparsed.header().n_records, 5);
                for index in 1..=3 {
                    assert_eq!(
                        reparsed.record_bytes(&reparsed.records()[index]),
                        doc.record_bytes(&doc.records()[index])
                    );
                }
                assert_eq!(reparsed.trailing_bytes(), b"tail");
                assert!(reparsed.diagnostics().is_empty());
                assert_eq!(serialize(&reparsed).unwrap(), out);
            }
        }
    }
}

#[test]
fn short_transform_payloads_stay_raw_and_recover_through_eof() {
    for kind in TYPES {
        for len in 0..payload(kind, VALUES[0]).len() {
            let mut input = header();
            input.extend(record(kind, &vec![0xaa; len]));
            append_siblings_and_tail(&mut input);
            let mut doc = parse(&input, &ParseLimits::default()).unwrap();
            assert_eq!(doc.records().len(), 4);
            assert_eq!(doc.records()[0].data(), &RecordData::Raw);
            assert_eq!(
                doc.records()[1].data(),
                &RecordData::SetMapMode { map_mode: 9 }
            );
            assert_eq!(doc.records()[2].data(), &RecordData::Raw);
            assert!(doc.records()[3].is_eof());
            assert_eq!(doc.diagnostics().len(), 1, "type {kind}, length {len}");
            let diagnostic = doc.diagnostics()[0];
            assert_eq!(diagnostic.offset, 112);
            assert_eq!(diagnostic.record_type, Some(kind));
            assert_eq!(diagnostic.kind, DiagnosticKind::InvalidRecordPayload);
            assert_eq!(doc.trailing_bytes(), b"tail");
            let before = doc.clone();
            assert_eq!(
                doc.edit_record(0, state(kind, VALUES[0])),
                Err(EditFailure::RecordFamily { index: 0 })
            );
            assert_eq!(doc, before);
            assert_eq!(serialize(&doc).unwrap(), input);
        }
    }
}

#[test]
fn wrong_transform_family_edits_reject_atomically_before_and_after_valid_edits() {
    for kind in TYPES {
        let mut input = header();
        input.extend(record(kind, &payload(kind, VALUES[0])));
        let mut doc = parse(&input, &ParseLimits::default()).unwrap();
        for edited in [false, true] {
            if edited {
                doc.edit_record(0, state(kind, VALUES[1])).unwrap();
            }
            let before = doc.clone();
            let bytes = serialize(&doc).unwrap();
            let mut invalid = vec![RecordData::Raw, RecordData::SetMapMode { map_mode: 1 }];
            invalid.extend(
                TYPES
                    .into_iter()
                    .filter(|other| *other != kind)
                    .map(|other| state(other, VALUES[2])),
            );
            for data in invalid {
                assert_eq!(
                    doc.edit_record(0, data),
                    Err(EditFailure::RecordFamily { index: 0 })
                );
                assert_eq!(doc, before);
                assert_eq!(serialize(&doc).unwrap(), bytes);
            }
        }
    }
}

#[test]
fn neighboring_unknown_types_remain_raw_without_diagnostics() {
    for kind in [23, 48, 49] {
        let mut input = header();
        input.extend(record(kind, &payload(35, VALUES[1])));
        let doc = parse(&input, &ParseLimits::default()).unwrap();
        assert_eq!(doc.records()[0].data(), &RecordData::Raw);
        assert!(doc.diagnostics().is_empty());
        assert_eq!(serialize(&doc).unwrap(), input);
    }
}

#[test]
fn float_accessors_and_equality_preserve_bits() {
    for bits in [
        0,
        0x80000000,
        0x7f800001,
        0x7fc12345,
        0xffc54321,
        0x7f800000,
        0xff800000,
        1,
        u32::MAX,
    ] {
        let value = Float32::from_bits(bits);
        assert_eq!(value.to_bits(), bits);
        assert_eq!(Float32::from_f32(value.to_f32()), value);
        assert_eq!(value, value);
    }
    assert_ne!(Float32::from_bits(0), Float32::from_bits(0x80000000));
    assert_ne!(
        Float32::from_bits(0x7fc00001),
        Float32::from_bits(0x7fc00002)
    );
}

#[test]
fn transform_limits_reject_without_mutating_document() {
    for kind in TYPES {
        let mut input = header();
        input.extend(record(kind, &payload(kind, VALUES[0])));
        let mut doc = parse(&input, &ParseLimits::default()).unwrap();
        doc.edit_record(0, state(kind, VALUES[5])).unwrap();
        let before = doc.clone();
        let output = serialize(&doc).unwrap();
        for (limits, expected_kind) in [
            (
                SerializeLimits {
                    max_output_bytes: output.len() - 1,
                    ..SerializeLimits::default()
                },
                LimitKind::OutputBytes,
            ),
            (
                SerializeLimits {
                    max_work_units: 0,
                    ..SerializeLimits::default()
                },
                LimitKind::WorkUnits,
            ),
        ] {
            assert!(
                matches!(serialize_with_limits(&doc, &limits), Err(SerializeFailure::LimitExceeded { kind, .. }) if kind == expected_kind)
            );
            assert_eq!(doc, before);
        }
        assert_eq!(
            serialize_with_limits(
                &doc,
                &SerializeLimits {
                    max_output_bytes: output.len(),
                    max_work_units: 4 + (output.len() as u64).div_ceil(16)
                }
            )
            .unwrap(),
            output
        );
        for (limits, expected_kind) in [
            (
                ParseLimits {
                    max_work_units: 0,
                    ..ParseLimits::default()
                },
                LimitKind::WorkUnits,
            ),
            (
                ParseLimits {
                    max_allocated_bytes: 0,
                    ..ParseLimits::default()
                },
                LimitKind::AllocatedBytes,
            ),
            (
                ParseLimits {
                    max_records: 1,
                    ..ParseLimits::default()
                },
                LimitKind::RecordCount,
            ),
        ] {
            assert!(
                matches!(parse(&input, &limits), Err(ParseFailure::LimitExceeded { kind, .. }) if kind == expected_kind)
            );
        }
    }
}
