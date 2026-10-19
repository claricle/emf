use emf_core::{
    parse, serialize, serialize_with_limits, DiagnosticKind, EditFailure, LimitKind, ParseFailure,
    ParseLimits, Point, Point16, RecordData, RecordSpan, Rect, SerializeFailure, SerializeLimits,
};

#[test]
fn multi_point_arrays_are_typed() {
    for kind in [7u32, 8, 90, 91] {
        let mut input = vec![0; 108];
        input[..4].copy_from_slice(&1u32.to_le_bytes());
        input[4..8].copy_from_slice(&108u32.to_le_bytes());
        input[40..44].copy_from_slice(&0x464d4520u32.to_le_bytes());
        input.extend_from_slice(&kind.to_le_bytes());
        input.extend_from_slice(&32u32.to_le_bytes());
        input.extend_from_slice(&[0; 24]);
        let doc = parse(&input, &ParseLimits::default()).unwrap();
        assert_ne!(doc.records()[0].data(), &RecordData::Raw, "type {kind}");
        assert!(doc.diagnostics().is_empty());
        assert_eq!(serialize(&doc).unwrap(), input);
    }
}

const TYPES: [u32; 4] = [7, 8, 90, 91];

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

fn payload(kind: u32, counts: &[u32], points: usize, edited: bool) -> Vec<u8> {
    let mut out: Vec<_> = if edited {
        [7i32, -8, 9, -10]
    } else {
        [i32::MIN, i32::MAX, -1, 0]
    }
    .into_iter()
    .flat_map(i32::to_le_bytes)
    .collect();
    out.extend_from_slice(&(counts.len() as u32).to_le_bytes());
    out.extend_from_slice(&(points as u32).to_le_bytes());
    for count in counts {
        out.extend_from_slice(&count.to_le_bytes());
    }
    for i in 0..points {
        if kind < 90 {
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
    out
}

fn state(kind: u32, counts: &[u32], count: usize, edited: bool) -> RecordData {
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
    let poly_counts = counts.to_vec();
    let points: Vec<_> = (0..count)
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
    let shorts: Vec<_> = (0..count)
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
    match kind {
        7 => RecordData::PolyPolyline {
            bounds,
            poly_counts,
            points,
        },
        8 => RecordData::PolyPolygon {
            bounds,
            poly_counts,
            points,
        },
        90 => RecordData::PolyPolyline16 {
            bounds,
            poly_counts,
            points: shorts,
        },
        91 => RecordData::PolyPolygon16 {
            bounds,
            poly_counts,
            points: shorts,
        },
        _ => panic!("unexpected kind {kind}"),
    }
}

#[test]
fn independent_counts_signed_fields_and_edits_preserve_exact_wire_bytes() {
    for kind in TYPES {
        for counts in [&[][..], &[0][..], &[u32::MAX, 0, 1][..]] {
            for count in [0, 1, 3] {
                for suffix in [&b""[..], &b"odd"[..], &b"suffix!!"[..]] {
                    let mut bytes = payload(kind, counts, count, false);
                    bytes.extend_from_slice(suffix);
                    let mut input = header();
                    input.extend(record(kind, &bytes));
                    input.extend(siblings());
                    let doc = parse(&input, &ParseLimits::default()).unwrap();
                    assert_eq!(doc.records()[0].data(), &state(kind, counts, count, false));
                    assert!(doc.diagnostics().is_empty());
                    assert_eq!(serialize(&doc).unwrap(), input);
                    for (next_counts, next_points, edited) in [
                        (counts, count, false),
                        (&[][..], 0, true),
                        (&[9, u32::MAX][..], 5, true),
                        (&[0][..], 1, true),
                    ] {
                        let replacement = state(kind, next_counts, next_points, edited);
                        let mut changed = doc.clone();
                        changed.edit_record(0, replacement.clone()).unwrap();
                        let mut expected = header();
                        let mut bytes = payload(kind, next_counts, next_points, edited);
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
}

#[test]
fn every_truncation_and_count_overrun_stays_raw_with_diagnostic_and_continued_framing() {
    for kind in TYPES {
        let valid = payload(kind, &[1, 2], 3, false);
        let mut cases: Vec<_> = (0..valid.len()).map(|len| valid[..len].to_vec()).collect();
        for (offset, counts) in [(16, [3, u32::MAX]), (20, [4, u32::MAX])] {
            for count in counts {
                let mut bytes = valid.clone();
                bytes[offset..offset + 4].copy_from_slice(&count.to_le_bytes());
                cases.push(bytes);
            }
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
fn wrong_family_edits_are_atomic_and_unknown_controls_remain_raw() {
    for kind in TYPES {
        let mut input = header();
        input.extend(record(kind, &payload(kind, &[1, 2], 3, false)));
        for unknown in [84, 92, 999] {
            input.extend(record(unknown, &[0; 24]));
        }
        let mut doc = parse(&input, &ParseLimits::default()).unwrap();
        let mut wrong: Vec<_> = TYPES
            .into_iter()
            .filter(|other| *other != kind)
            .map(|other| state(other, &[5], 1, true))
            .collect();
        wrong.push(RecordData::Polyline {
            bounds: Rect {
                left: 0,
                top: 0,
                right: 0,
                bottom: 0,
            },
            points: vec![],
        });
        for replacement in wrong {
            assert_eq!(
                doc.edit_record(0, replacement),
                Err(EditFailure::RecordFamily { index: 0 })
            );
            assert!(!doc.is_edited());
            assert_eq!(doc.records()[0].data(), &state(kind, &[1, 2], 3, false));
            assert_eq!(serialize(&doc).unwrap(), input);
        }
        let edited = state(kind, &[u32::MAX, 0], 1, true);
        doc.edit_record(0, edited.clone()).unwrap();
        let before_wrong_edit = serialize(&doc).unwrap();
        for other in TYPES.into_iter().filter(|other| *other != kind) {
            assert_eq!(
                doc.edit_record(0, state(other, &[1], 2, false)),
                Err(EditFailure::RecordFamily { index: 0 })
            );
            assert!(doc.is_edited());
            assert_eq!(doc.records()[0].data(), &edited);
            assert_eq!(serialize(&doc).unwrap(), before_wrong_edit);
        }
        for index in 1..=3 {
            assert_eq!(doc.records()[index].data(), &RecordData::Raw);
        }
        assert!(doc.diagnostics().is_empty());
    }
}

#[test]
fn parse_limits_charge_each_count_and_point_at_exact_boundaries() {
    for kind in TYPES {
        for (counts, points) in [
            (&[][..], 0),
            (&[0, u32::MAX][..], 0),
            (&[][..], 3),
            (&[1, 2][..], 3),
        ] {
            let bytes = record(kind, &payload(kind, counts, points, false));
            let mut input = header();
            input.extend(&bytes);
            let allocation = input.len()
                + std::mem::size_of::<RecordSpan>()
                + counts.len() * 4
                + points * if kind < 90 { 8 } else { 4 };
            let work = 8
                + (input.len() as u64).div_ceil(16)
                + 1
                + (bytes.len() as u64).div_ceil(16)
                + counts.len() as u64
                + points as u64;
            let limits = ParseLimits {
                max_allocated_bytes: allocation,
                max_work_units: work,
                ..ParseLimits::default()
            };
            assert_eq!(
                parse(&input, &limits).unwrap().records()[0].data(),
                &state(kind, counts, points, false)
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
fn serialization_limits_charge_each_edited_count_and_point_at_exact_boundaries() {
    for kind in TYPES {
        for (counts, points) in [
            (&[][..], 0),
            (&[0, u32::MAX][..], 0),
            (&[][..], 3),
            (&[1, 2][..], 3),
        ] {
            let mut input = header();
            input.extend(record(kind, &payload(kind, &[1], 1, false)));
            let mut doc = parse(&input, &ParseLimits::default()).unwrap();
            doc.edit_record(0, state(kind, counts, points, true))
                .unwrap();
            let output = serialize(&doc).unwrap();
            let work = 4 + (output.len() as u64).div_ceil(16) + counts.len() as u64 + points as u64;
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
