use emf_core::{
    parse, serialize, serialize_with_limits, DiagnosticKind, EditFailure, LimitKind, ParseFailure,
    ParseLimits, Point, Point16, RecordData, RecordSpan, Rect, SerializeFailure, SerializeLimits,
};

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

const TYPES: [u32; 10] = [2, 3, 4, 5, 6, 85, 86, 87, 88, 89];

#[test]
fn point_arrays_are_typed() {
    for kind in TYPES {
        let mut input = header();
        input.extend(record(kind, &[0; 20]));
        let doc = parse(&input, &ParseLimits::default()).unwrap();
        assert_ne!(doc.records()[0].data(), &RecordData::Raw, "type {kind}");
        assert!(doc.diagnostics().is_empty());
        assert_eq!(serialize(&doc).unwrap(), input);
    }
}

fn bounds() -> Rect {
    Rect {
        left: i32::MIN,
        top: i32::MAX,
        right: -1,
        bottom: 0,
    }
}

fn state(kind: u32, count: usize) -> RecordData {
    let bounds = bounds();
    let points = vec![
        Point {
            x: i32::MIN,
            y: i32::MAX
        };
        count
    ];
    let shorts = vec![
        Point16 {
            x: i16::MIN,
            y: i16::MAX
        };
        count
    ];
    match kind {
        2 => RecordData::PolyBezier { bounds, points },
        3 => RecordData::Polygon { bounds, points },
        4 => RecordData::Polyline { bounds, points },
        5 => RecordData::PolyBezierTo { bounds, points },
        6 => RecordData::PolylineTo { bounds, points },
        85 => RecordData::PolyBezier16 {
            bounds,
            points: shorts,
        },
        86 => RecordData::Polygon16 {
            bounds,
            points: shorts,
        },
        87 => RecordData::Polyline16 {
            bounds,
            points: shorts,
        },
        88 => RecordData::PolyBezierTo16 {
            bounds,
            points: shorts,
        },
        89 => RecordData::PolylineTo16 {
            bounds,
            points: shorts,
        },
        _ => panic!("unexpected type {kind}"),
    }
}

fn payload(kind: u32, count: usize) -> Vec<u8> {
    let mut bytes: Vec<_> = [i32::MIN, i32::MAX, -1, 0]
        .into_iter()
        .flat_map(i32::to_le_bytes)
        .collect();
    bytes.extend_from_slice(&(count as u32).to_le_bytes());
    for _ in 0..count {
        if kind < 85 {
            bytes.extend_from_slice(&i32::MIN.to_le_bytes());
            bytes.extend_from_slice(&i32::MAX.to_le_bytes());
        } else {
            bytes.extend_from_slice(&i16::MIN.to_le_bytes());
            bytes.extend_from_slice(&i16::MAX.to_le_bytes());
        }
    }
    bytes
}

fn suffix_records() -> Vec<u8> {
    let mut bytes = record(17, &9u32.to_le_bytes());
    bytes.extend(record(999, b"unknown!"));
    bytes.extend(record(14, &[0, 0, 0, 0, 16, 0, 0, 0, 20, 0, 0, 0]));
    bytes.extend_from_slice(b"tail");
    bytes
}

#[test]
fn signed_fields_counts_and_edits_preserve_opaque_bytes() {
    for kind in TYPES {
        for count in [0, 1, 2, 3, 4] {
            for suffix in [&b""[..], &b"odd"[..], &b"suffix!!"[..]] {
                let mut original = payload(kind, count);
                original.extend_from_slice(suffix);
                let mut input = header();
                input.extend(record(kind, &original));
                input.extend(suffix_records());
                let doc = parse(&input, &ParseLimits::default()).unwrap();
                assert_eq!(doc.records()[0].data(), &state(kind, count));
                assert!(doc.diagnostics().is_empty());
                assert_eq!(serialize(&doc).unwrap(), input);
                for edited_count in [count, 0, 1, 5] {
                    let mut edited = doc.clone();
                    edited.edit_record(0, state(kind, edited_count)).unwrap();
                    let mut bytes = payload(kind, edited_count);
                    bytes.extend_from_slice(suffix);
                    let mut expected = header();
                    expected.extend(record(kind, &bytes));
                    expected.extend(suffix_records());
                    let len = expected.len() as u32;
                    expected[48..52].copy_from_slice(&len.to_le_bytes());
                    expected[52..56].copy_from_slice(&5u32.to_le_bytes());
                    let out = serialize(&edited).unwrap();
                    assert_eq!(out, expected, "type {kind} count {count}->{edited_count}");
                    let reparsed = parse(&out, &ParseLimits::default()).unwrap();
                    assert_eq!(reparsed.records()[0].data(), &state(kind, edited_count));
                    assert_eq!(reparsed.records()[1].data(), doc.records()[1].data());
                    assert_eq!(reparsed.records()[2].data(), &RecordData::Raw);
                    assert!(reparsed.records()[3].is_eof());
                    assert_eq!(reparsed.trailing_bytes(), b"tail");
                }
            }
        }
    }
}

#[test]
fn every_truncated_payload_and_impossible_count_stays_raw_and_recovers() {
    for kind in TYPES {
        let valid = payload(kind, 3);
        let mut malformed: Vec<_> = (0..valid.len()).map(|len| valid[..len].to_vec()).collect();
        for count in [4, u32::MAX] {
            let mut bytes = valid.clone();
            bytes[16..20].copy_from_slice(&count.to_le_bytes());
            malformed.push(bytes);
        }
        for bytes in malformed {
            let mut input = header();
            input.extend(record(kind, &bytes));
            input.extend(suffix_records());
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
fn wrong_family_edits_are_atomic_and_adjacent_unknowns_stay_unknown() {
    for kind in TYPES {
        let mut input = header();
        input.extend(record(kind, &payload(kind, 2)));
        for unknown in [7, 84, 90] {
            input.extend(record(unknown, &payload(kind, 2)));
        }
        let mut doc = parse(&input, &ParseLimits::default()).unwrap();
        for other in TYPES.into_iter().filter(|other| *other != kind) {
            assert_eq!(
                doc.edit_record(0, state(other, 3)),
                Err(EditFailure::RecordFamily { index: 0 })
            );
            assert!(!doc.is_edited());
            assert_eq!(doc.records()[0].data(), &state(kind, 2));
            assert_eq!(serialize(&doc).unwrap(), input);
        }
        for index in 1..=3 {
            assert_eq!(doc.records()[index].data(), &RecordData::Raw);
        }
        assert!(doc.diagnostics().is_empty());
    }
}

#[test]
fn point_array_parse_budgets_are_inclusive_for_both_widths() {
    for kind in TYPES {
        let bytes = record(kind, &payload(kind, 3));
        let mut input = header();
        input.extend(&bytes);
        let allocation =
            input.len() + std::mem::size_of::<RecordSpan>() + if kind < 85 { 24 } else { 12 };
        let work =
            8 + (input.len() as u64).div_ceil(16) + 1 + (bytes.len() as u64).div_ceil(16) + 3;
        let limits = ParseLimits {
            max_allocated_bytes: allocation,
            max_work_units: work,
            ..ParseLimits::default()
        };
        assert_eq!(
            parse(&input, &limits).unwrap().records()[0].data(),
            &state(kind, 3)
        );
        for (kind, limits) in [
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
                matches!(parse(&input, &limits), Err(ParseFailure::LimitExceeded { kind: actual, .. }) if actual == kind)
            );
        }
    }
}

#[test]
fn edited_point_array_serialization_budgets_include_every_point() {
    for kind in TYPES {
        let mut input = header();
        input.extend(record(kind, &payload(kind, 1)));
        let mut doc = parse(&input, &ParseLimits::default()).unwrap();
        doc.edit_record(0, state(kind, 5)).unwrap();
        let output = serialize(&doc).unwrap();
        let work = 4 + (output.len() as u64).div_ceil(16) + 5;
        let limits = SerializeLimits {
            max_output_bytes: output.len(),
            max_work_units: work,
        };
        assert_eq!(serialize_with_limits(&doc, &limits).unwrap(), output);
        for (kind, limits) in [
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
                matches!(serialize_with_limits(&doc, &limits), Err(SerializeFailure::LimitExceeded { kind: actual, .. }) if actual == kind)
            );
        }
    }
}

#[test]
fn edited_bounds_and_point_values_are_written_at_the_declared_width() {
    for kind in TYPES {
        let mut input = header();
        let mut original = payload(kind, 2);
        original.extend_from_slice(b"suffix");
        input.extend(record(kind, &original));
        input.extend(suffix_records());
        let mut doc = parse(&input, &ParseLimits::default()).unwrap();
        let mut replacement = state(kind, 2);
        let new_bounds = Rect {
            left: 7,
            top: -8,
            right: 9,
            bottom: -10,
        };
        match &mut replacement {
            RecordData::PolyBezier { bounds, points }
            | RecordData::Polygon { bounds, points }
            | RecordData::Polyline { bounds, points }
            | RecordData::PolyBezierTo { bounds, points }
            | RecordData::PolylineTo { bounds, points } => {
                *bounds = new_bounds;
                points[0] = Point {
                    x: i32::MAX,
                    y: i32::MIN,
                };
                points[1] = Point { x: -1, y: 0 };
            }
            RecordData::PolyBezier16 { bounds, points }
            | RecordData::Polygon16 { bounds, points }
            | RecordData::Polyline16 { bounds, points }
            | RecordData::PolyBezierTo16 { bounds, points }
            | RecordData::PolylineTo16 { bounds, points } => {
                *bounds = new_bounds;
                points[0] = Point16 {
                    x: i16::MAX,
                    y: i16::MIN,
                };
                points[1] = Point16 { x: -1, y: 0 };
            }
            _ => unreachable!(),
        }
        doc.edit_record(0, replacement.clone()).unwrap();
        let mut expected = input.clone();
        let len = expected.len() as u32;
        expected[48..52].copy_from_slice(&len.to_le_bytes());
        expected[52..56].copy_from_slice(&5u32.to_le_bytes());
        let bounds_bytes: Vec<_> = [7i32, -8, 9, -10]
            .into_iter()
            .flat_map(i32::to_le_bytes)
            .collect();
        expected[120..136].copy_from_slice(&bounds_bytes);
        let points_bytes: Vec<_> = if kind < 85 {
            [i32::MAX, i32::MIN, -1, 0]
                .into_iter()
                .flat_map(i32::to_le_bytes)
                .collect()
        } else {
            [i16::MAX, i16::MIN, -1, 0]
                .into_iter()
                .flat_map(i16::to_le_bytes)
                .collect()
        };
        expected[140..140 + points_bytes.len()].copy_from_slice(&points_bytes);
        let output = serialize(&doc).unwrap();
        assert_eq!(output, expected);
        assert_eq!(
            parse(&output, &ParseLimits::default()).unwrap().records()[0].data(),
            &replacement
        );
    }
}
