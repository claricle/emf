use emf_core::{
    parse, serialize, serialize_with_limits, DiagnosticKind, EditFailure, LimitKind, ParseFailure,
    ParseLimits, Point, Point16, RecordData, RecordSpan, Rect, SerializeFailure, SerializeLimits,
};

#[test]
fn poly_draw_arrays_are_typed() {
    for kind in [56u32, 92] {
        let mut input = vec![0; 108];
        input[..4].copy_from_slice(&1u32.to_le_bytes());
        input[4..8].copy_from_slice(&108u32.to_le_bytes());
        input[40..44].copy_from_slice(&0x464d4520u32.to_le_bytes());
        input.extend_from_slice(&kind.to_le_bytes());
        input.extend_from_slice(&28u32.to_le_bytes());
        input.extend_from_slice(&[0; 20]);
        let doc = parse(&input, &ParseLimits::default()).unwrap();
        assert_ne!(doc.records()[0].data(), &RecordData::Raw, "type {kind}");
        assert!(doc.diagnostics().is_empty());
        assert_eq!(serialize(&doc).unwrap(), input);
    }
}

const TYPES: [u32; 2] = [56, 92];

fn record(kind: u32, payload: &[u8]) -> Vec<u8> {
    let mut out = kind.to_le_bytes().to_vec();
    out.extend_from_slice(&(8 + payload.len() as u32).to_le_bytes());
    out.extend_from_slice(payload);
    out
}

fn header() -> Vec<u8> {
    let mut out = vec![0; 112];
    out[..4].copy_from_slice(&1u32.to_le_bytes());
    out[4..8].copy_from_slice(&112u32.to_le_bytes());
    out[40..44].copy_from_slice(&0x464d4520u32.to_le_bytes());
    out[108..].copy_from_slice(b"head");
    out
}

fn siblings() -> Vec<u8> {
    let mut out = record(17, &9u32.to_le_bytes());
    out.extend(record(999, b"unknown!"));
    out.extend(record(14, &[0, 0, 0, 0, 16, 0, 0, 0, 20, 0, 0, 0]));
    out.extend_from_slice(b"tail");
    out
}

fn payload(kind: u32, types: &[u8], edited: bool) -> Vec<u8> {
    let bounds = if edited {
        [7i32, -8, 9, -10]
    } else {
        [i32::MIN, i32::MAX, -1, 0]
    };
    let mut out: Vec<_> = bounds.into_iter().flat_map(i32::to_le_bytes).collect();
    out.extend_from_slice(&(types.len() as u32).to_le_bytes());
    for i in 0..types.len() {
        if kind == 56 {
            let pair = if edited && i == 0 {
                [i32::MAX, i32::MIN]
            } else {
                [i32::MIN, i32::MAX]
            };
            out.extend(pair.into_iter().flat_map(i32::to_le_bytes));
        } else {
            let pair = if edited && i == 0 {
                [i16::MAX, i16::MIN]
            } else {
                [i16::MIN, i16::MAX]
            };
            out.extend(pair.into_iter().flat_map(i16::to_le_bytes));
        }
    }
    out.extend_from_slice(types);
    out
}

fn state(kind: u32, types: &[u8], edited: bool) -> RecordData {
    let bounds = if edited {
        Rect {
            left: 7,
            top: -8,
            right: 9,
            bottom: -10,
        }
    } else {
        Rect {
            left: i32::MIN,
            top: i32::MAX,
            right: -1,
            bottom: 0,
        }
    };
    let ab_types = types.to_vec();
    if kind == 56 {
        let points = (0..types.len())
            .map(|i| {
                if edited && i == 0 {
                    Point {
                        x: i32::MAX,
                        y: i32::MIN,
                    }
                } else {
                    Point {
                        x: i32::MIN,
                        y: i32::MAX,
                    }
                }
            })
            .collect();
        RecordData::PolyDraw {
            bounds,
            points,
            ab_types,
        }
    } else {
        let points = (0..types.len())
            .map(|i| {
                if edited && i == 0 {
                    Point16 {
                        x: i16::MAX,
                        y: i16::MIN,
                    }
                } else {
                    Point16 {
                        x: i16::MIN,
                        y: i16::MAX,
                    }
                }
            })
            .collect();
        RecordData::PolyDraw16 {
            bounds,
            points,
            ab_types,
        }
    }
}

#[test]
fn signed_points_and_opaque_type_bytes_survive_grow_shrink_and_equal_edits() {
    for kind in TYPES {
        for types in [
            &[][..],
            &[0][..],
            &[1, 255][..],
            &[0, 1, 2, 3, 4, 5, 6, 128, 255][..],
        ] {
            for suffix in [&b""[..], &b"odd"[..], &b"suffix!!"[..]] {
                let mut bytes = payload(kind, types, false);
                bytes.extend_from_slice(suffix);
                let mut input = header();
                input.extend(record(kind, &bytes));
                input.extend(siblings());
                let doc = parse(&input, &ParseLimits::default()).unwrap();
                assert_eq!(doc.records()[0].data(), &state(kind, types, false));
                assert!(doc.diagnostics().is_empty());
                assert_eq!(serialize(&doc).unwrap(), input);
                for (next_types, edited) in [
                    (types, false),
                    (&[][..], true),
                    (&[255, 0, 128, 1, 2][..], true),
                    (&[42][..], true),
                ] {
                    let replacement = state(kind, next_types, edited);
                    let mut changed = doc.clone();
                    changed.edit_record(0, replacement.clone()).unwrap();
                    let mut expected = header();
                    let mut bytes = payload(kind, next_types, edited);
                    bytes.extend_from_slice(suffix);
                    expected.extend(record(kind, &bytes));
                    expected.extend(siblings());
                    let len = expected.len() as u32;
                    expected[48..52].copy_from_slice(&len.to_le_bytes());
                    expected[52..56].copy_from_slice(&5u32.to_le_bytes());
                    let output = serialize(&changed).unwrap();
                    assert_eq!(output, expected, "type {kind}");
                    let reparsed = parse(&output, &ParseLimits::default()).unwrap();
                    assert_eq!(reparsed.records()[0].data(), &replacement);
                    assert_eq!(
                        reparsed.records()[1].data(),
                        &RecordData::SetMapMode { map_mode: 9 }
                    );
                    assert_eq!(reparsed.records()[2].data(), &RecordData::Raw);
                    assert!(reparsed.records()[3].is_eof());
                    assert_eq!(reparsed.trailing_bytes(), b"tail");
                    assert!(reparsed.diagnostics().is_empty());
                }
            }
        }
    }
}

#[test]
fn mismatched_array_and_wrong_family_edits_are_atomic_before_and_after_valid_edits() {
    for kind in TYPES {
        let mut input = header();
        input.extend(record(kind, &payload(kind, &[0, 255], false)));
        let mut doc = parse(&input, &ParseLimits::default()).unwrap();
        for edited in [false, true] {
            if edited {
                doc.edit_record(0, state(kind, &[128], true)).unwrap();
            }
            let before = doc.clone();
            let before_bytes = serialize(&doc).unwrap();
            for grow_types in [false, true] {
                let mut invalid = state(kind, &[1, 2], true);
                match &mut invalid {
                    RecordData::PolyDraw { ab_types, .. }
                    | RecordData::PolyDraw16 { ab_types, .. } => {
                        if grow_types {
                            ab_types.push(255);
                        } else {
                            ab_types.clear();
                        }
                    }
                    _ => unreachable!(),
                }
                assert_eq!(
                    doc.edit_record(0, invalid),
                    Err(EditFailure::RecordLayout { index: 0 })
                );
                assert_eq!(doc, before);
                assert_eq!(serialize(&doc).unwrap(), before_bytes);
            }
            assert_eq!(
                doc.edit_record(0, state(if kind == 56 { 92 } else { 56 }, &[1], true)),
                Err(EditFailure::RecordFamily { index: 0 })
            );
            assert_eq!(doc, before);
            assert_eq!(serialize(&doc).unwrap(), before_bytes);
        }
    }
}
#[test]
fn every_truncation_and_count_overrun_stays_raw_with_diagnostic_and_continued_framing() {
    for kind in TYPES {
        let valid = payload(kind, &[0, 128, 255], false);
        let mut cases: Vec<_> = (0..valid.len()).map(|len| valid[..len].to_vec()).collect();
        for count in [4u32, u32::MAX] {
            let mut bytes = valid.clone();
            bytes[16..20].copy_from_slice(&count.to_le_bytes());
            cases.push(bytes);
        }
        for bytes in cases {
            let mut input = header();
            input.extend(record(kind, &bytes));
            input.extend(siblings());
            let doc = parse(&input, &ParseLimits::default()).unwrap();
            assert_eq!(doc.records()[0].data(), &RecordData::Raw);
            assert_eq!(doc.diagnostics().len(), 1);
            assert_eq!(doc.diagnostics()[0].offset, 112);
            assert_eq!(doc.diagnostics()[0].record_type, Some(kind));
            assert_eq!(
                doc.diagnostics()[0].kind,
                DiagnosticKind::InvalidRecordPayload
            );
            assert_eq!(
                doc.records()[1].data(),
                &RecordData::SetMapMode { map_mode: 9 }
            );
            assert_eq!(doc.records()[2].data(), &RecordData::Raw);
            assert!(doc.records()[3].is_eof());
            assert_eq!(doc.trailing_bytes(), b"tail");
            assert_eq!(serialize(&doc).unwrap(), input);
        }
    }
}

#[test]
fn parse_limits_charge_each_point_and_type_byte_at_exact_boundaries() {
    for kind in TYPES {
        for types in [&[][..], &[255][..], &[0, 128, 255][..]] {
            let bytes = record(kind, &payload(kind, types, false));
            let mut input = header();
            input.extend(&bytes);
            let allocation = input.len()
                + std::mem::size_of::<RecordSpan>()
                + types.len() * if kind == 56 { 9 } else { 5 };
            let work = 8
                + (input.len() as u64).div_ceil(16)
                + 1
                + (bytes.len() as u64).div_ceil(16)
                + types.len() as u64 * 2;
            let limits = ParseLimits {
                max_allocated_bytes: allocation,
                max_work_units: work,
                ..ParseLimits::default()
            };
            assert_eq!(
                parse(&input, &limits).unwrap().records()[0].data(),
                &state(kind, types, false)
            );
            for (expected, limits) in [
                (
                    LimitKind::AllocatedBytes,
                    ParseLimits {
                        max_allocated_bytes: allocation - 1,
                        ..limits.clone()
                    },
                ),
                (
                    LimitKind::WorkUnits,
                    ParseLimits {
                        max_work_units: work - 1,
                        ..limits.clone()
                    },
                ),
            ] {
                assert!(
                    matches!(parse(&input, &limits), Err(ParseFailure::LimitExceeded {kind, ..}) if kind == expected)
                );
            }
        }
    }
}

#[test]
fn serialization_limits_charge_each_edited_point_and_type_byte_at_exact_boundaries() {
    for kind in TYPES {
        for types in [&[][..], &[255][..], &[0, 128, 255][..]] {
            let mut input = header();
            input.extend(record(kind, &payload(kind, &[1], false)));
            let mut doc = parse(&input, &ParseLimits::default()).unwrap();
            doc.edit_record(0, state(kind, types, true)).unwrap();
            let output = serialize(&doc).unwrap();
            let work = 4 + (output.len() as u64).div_ceil(16) + types.len() as u64 * 2;
            let limits = SerializeLimits {
                max_output_bytes: output.len(),
                max_work_units: work,
            };
            assert_eq!(serialize_with_limits(&doc, &limits).unwrap(), output);
            for (expected, limits) in [
                (
                    LimitKind::OutputBytes,
                    SerializeLimits {
                        max_output_bytes: output.len() - 1,
                        ..limits.clone()
                    },
                ),
                (
                    LimitKind::WorkUnits,
                    SerializeLimits {
                        max_work_units: work - 1,
                        ..limits.clone()
                    },
                ),
            ] {
                assert!(
                    matches!(serialize_with_limits(&doc, &limits), Err(SerializeFailure::LimitExceeded {kind, ..}) if kind == expected)
                );
            }
        }
    }
}
