use emf_core::{parse, serialize, DiagnosticKind, EditFailure, ParseLimits, RecordData, Rect};

const TYPES: [u32; 14] = [22, 33, 34, 37, 40, 57, 59, 60, 61, 62, 63, 64, 67, 68];

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

fn payload(kind: u32, values: [u32; 4]) -> Vec<u8> {
    let count = match kind {
        33 | 59..=61 | 68 => 0,
        62..=64 => 4,
        _ => 1,
    };
    values[..count]
        .iter()
        .flat_map(|value| value.to_le_bytes())
        .collect()
}

#[test]
fn fixed_state_records_are_typed_and_round_trip_exactly() {
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

const VALUES: [[u32; 4]; 6] = [
    [0, 1, 2, 3],
    [u32::MAX, i32::MIN as u32, i32::MAX as u32, 0],
    [i32::MIN as u32, i32::MAX as u32, u32::MAX, 0],
    [i32::MAX as u32, 0, i32::MIN as u32, u32::MAX],
    [1, u32::MAX, i32::MIN as u32, i32::MAX as u32],
    [0, u32::MAX, i32::MAX as u32, i32::MIN as u32],
];

fn append_siblings_and_tail(input: &mut Vec<u8>) {
    input.extend(record(17, &9u32.to_le_bytes()));
    input.extend(record(999, b"unknown!"));
    input.extend(record(14, &[0, 0, 0, 0, 16, 0, 0, 0, 20, 0, 0, 0]));
    input.extend_from_slice(b"tail");
}

fn state(kind: u32, values: [u32; 4]) -> RecordData {
    let bounds = Rect {
        left: values[0] as i32,
        top: values[1] as i32,
        right: values[2] as i32,
        bottom: values[3] as i32,
    };
    match kind {
        22 => RecordData::SetTextAlign {
            text_align_mode: values[0],
        },
        33 => RecordData::SaveDc,
        34 => RecordData::RestoreDc {
            saved_dc: values[0] as i32,
        },
        37 => RecordData::SelectObject {
            ih_object: values[0],
        },
        40 => RecordData::DeleteObject {
            ih_object: values[0],
        },
        57 => RecordData::SetArcDirection {
            arc_direction: values[0],
        },
        59 => RecordData::BeginPath,
        60 => RecordData::EndPath,
        61 => RecordData::CloseFigure,
        62 => RecordData::FillPath { bounds },
        63 => RecordData::StrokeAndFillPath { bounds },
        64 => RecordData::StrokePath { bounds },
        67 => RecordData::SelectClipPath {
            region_mode: values[0],
        },
        68 => RecordData::AbortPath,
        _ => panic!("unexpected fixed-state type {kind}"),
    }
}

#[test]
fn fixed_state_edits_preserve_suffix_siblings_header_and_tail() {
    for kind in TYPES {
        for suffix in [
            &b""[..],
            &b"odd"[..],
            &b"suffix!!"[..],
            &b"0123456789abcdef"[..],
        ] {
            let mut input = header();
            let original = payload(kind, [7, 0xffff_fff8, 9, 0xffff_fff6]);
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
fn short_fixed_state_payloads_stay_raw_and_recover_through_eof() {
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
fn wrong_fixed_state_family_edits_reject_atomically_before_and_after_valid_edits() {
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
    for kind in [32, 35, 58, 65, 66, 69] {
        let mut input = header();
        input.extend(record(kind, &payload(62, VALUES[1])));
        let doc = parse(&input, &ParseLimits::default()).unwrap();
        assert_eq!(doc.records()[0].data(), &RecordData::Raw);
        assert!(doc.diagnostics().is_empty());
        assert_eq!(serialize(&doc).unwrap(), input);
    }
}
