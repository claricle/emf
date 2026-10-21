use emf_core::{
    parse, serialize, DiagnosticKind, EditFailure, ParseLimits, Point, RecordData, Size,
};

const TYPES: [u32; 7] = [9, 10, 11, 12, 13, 26, 27];

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

fn pair(first: i32, second: i32) -> Vec<u8> {
    [first.to_le_bytes(), second.to_le_bytes()].concat()
}

#[test]
fn coordinate_records_are_typed_and_round_trip_exactly() {
    for kind in TYPES {
        for (first, second) in VALUES {
            let mut input = header();
            input.extend(record(kind, &pair(first, second)));
            let doc = parse(&input, &ParseLimits::default()).unwrap();
            assert_eq!(doc.records()[0].data(), &coordinate(kind, first, second));
            assert!(!doc.is_edited());
            assert!(doc.diagnostics().is_empty());
            assert_eq!(serialize(&doc).unwrap(), input);
        }
    }
}

const VALUES: [(i32, i32); 4] = [(0, -1), (-2, 3), (i32::MIN, i32::MAX), (i32::MAX, i32::MIN)];

fn coordinate(kind: u32, first: i32, second: i32) -> RecordData {
    let extent = Size {
        cx: first,
        cy: second,
    };
    let point = Point {
        x: first,
        y: second,
    };
    match kind {
        9 => RecordData::SetWindowExtEx { extent },
        10 => RecordData::SetWindowOrgEx { origin: point },
        11 => RecordData::SetViewportExtEx { extent },
        12 => RecordData::SetViewportOrgEx { origin: point },
        13 => RecordData::SetBrushOrgEx { origin: point },
        26 => RecordData::OffsetClipRgn { offset: point },
        27 => RecordData::MoveToEx { origin: point },
        _ => panic!("unexpected coordinate type {kind}"),
    }
}

fn append_siblings_and_tail(input: &mut Vec<u8>) {
    input.extend(record(17, &9u32.to_le_bytes()));
    input.extend(record(999, b"unknown!"));
    input.extend(record(14, &[0, 0, 0, 0, 16, 0, 0, 0, 20, 0, 0, 0]));
    input.extend_from_slice(b"tail");
}

#[test]
fn coordinate_edits_preserve_suffix_siblings_header_and_tail() {
    for kind in TYPES {
        for suffix in [&b""[..], &b"odd"[..], &b"suffix!!"[..]] {
            let mut input = header();
            let mut payload = pair(7, -8);
            payload.extend_from_slice(suffix);
            input.extend(record(kind, &payload));
            append_siblings_and_tail(&mut input);
            for (first, second) in VALUES {
                let mut doc = parse(&input, &ParseLimits::default()).unwrap();
                assert_eq!(serialize(&doc).unwrap(), input);
                doc.edit_record(0, coordinate(kind, first, second)).unwrap();
                assert!(doc.records()[0].is_edited());
                let out = serialize(&doc).unwrap();
                let mut expected = input.clone();
                expected[48..52].copy_from_slice(&(input.len() as u32).to_le_bytes());
                expected[52..56].copy_from_slice(&5u32.to_le_bytes());
                expected[120..128].copy_from_slice(&pair(first, second));
                assert_eq!(out, expected, "type {kind}, pair {first}, {second}");
                assert_eq!(&out[128..128 + suffix.len()], suffix);
                let reparsed = parse(&out, &ParseLimits::default()).unwrap();
                assert_eq!(
                    reparsed.records()[0].data(),
                    &coordinate(kind, first, second)
                );
                assert_eq!(reparsed.records()[0].size() as usize, 16 + suffix.len());
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
fn short_coordinate_payloads_stay_raw_and_recover_through_eof() {
    for kind in TYPES {
        for len in 0..8 {
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
                doc.edit_record(0, coordinate(kind, 1, -2)),
                Err(EditFailure::RecordFamily { index: 0 })
            );
            assert_eq!(doc, before);
            assert_eq!(serialize(&doc).unwrap(), input);
        }
    }
}

#[test]
fn wrong_coordinate_family_edits_reject_atomically_before_and_after_valid_edits() {
    for kind in TYPES {
        let mut input = header();
        input.extend(record(kind, &pair(7, -8)));
        let mut doc = parse(&input, &ParseLimits::default()).unwrap();
        for edited in [false, true] {
            if edited {
                doc.edit_record(0, coordinate(kind, i32::MIN, i32::MAX))
                    .unwrap();
            }
            let before = doc.clone();
            let bytes = serialize(&doc).unwrap();
            let mut invalid = vec![RecordData::Raw, RecordData::SetMapMode { map_mode: 1 }];
            invalid.extend(
                TYPES
                    .into_iter()
                    .filter(|other| *other != kind)
                    .map(|other| coordinate(other, 1, -2)),
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
fn unknown_record_types_remain_raw_without_diagnostics() {
    for kind in [999, 1000] {
        let mut input = header();
        input.extend(record(kind, &pair(i32::MIN, i32::MAX)));
        let doc = parse(&input, &ParseLimits::default()).unwrap();
        assert_eq!(doc.records()[0].data(), &RecordData::Raw);
        assert!(doc.diagnostics().is_empty());
        assert_eq!(serialize(&doc).unwrap(), input);
    }
}
