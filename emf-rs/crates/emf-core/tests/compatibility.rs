use emf_core::{
    parse, serialize, DiagnosticKind, LimitKind, ParseFailure, ParseLimits, RecordData,
};

fn record(kind: u32, payload: &[u8]) -> Vec<u8> {
    let mut bytes = kind.to_le_bytes().to_vec();
    bytes.extend_from_slice(&(8 + payload.len() as u32).to_le_bytes());
    bytes.extend_from_slice(payload);
    bytes
}

fn header() -> Vec<u8> {
    let mut bytes = vec![0; 88];
    bytes[..4].copy_from_slice(&1u32.to_le_bytes());
    bytes[4..8].copy_from_slice(&88u32.to_le_bytes());
    bytes[40..44].copy_from_slice(&0x464d4520u32.to_le_bytes());
    bytes
}

fn eof() -> Vec<u8> {
    record(14, &[0, 0, 0, 0, 16, 0, 0, 0, 20, 0, 0, 0])
}

#[test]
fn malformed_eof_does_not_stop_framing_or_claim_a_valid_eof() {
    for payload_len in [0, 4, 8] {
        let mut input = header();
        input.extend(record(14, &vec![0; payload_len]));
        let malformed_only = parse(&input, &ParseLimits::default()).unwrap();
        assert!(!malformed_only.has_eof());
        assert!(!malformed_only.records()[0].is_eof());
        assert_eq!(malformed_only.records()[0].data(), &RecordData::Raw);
        assert_eq!(serialize(&malformed_only).unwrap(), input);
        input.extend(record(17, &2u32.to_le_bytes()));
        input.extend(eof());
        let tail = record(17, &3u32.to_le_bytes());
        input.extend_from_slice(&tail);
        let doc = parse(&input, &ParseLimits::default()).unwrap();
        assert_eq!(doc.records().len(), 3);
        assert_eq!(
            doc.records()[1].data(),
            &RecordData::SetMapMode { map_mode: 2 }
        );
        assert!(doc.has_eof());
        assert!(doc.records()[2].is_eof());
        assert_eq!(doc.trailing_bytes(), tail);
        assert_eq!(doc.diagnostics().len(), 1);
        assert_eq!(
            doc.diagnostics()[0].kind,
            DiagnosticKind::InvalidRecordPayload
        );
        assert_eq!(serialize(&doc).unwrap(), input);
    }
}

#[test]
fn comment_count_bounds_data_and_emf_plus_extraction() {
    for count in [0u32, 3, 4, 5, 8, 9] {
        let mut input = header();
        let mut payload = count.to_le_bytes().to_vec();
        payload.extend_from_slice(b"EMF+x\xcc\xcc\xcc");
        input.extend(record(70, &payload));
        input.extend(eof());
        let doc = parse(&input, &ParseLimits::default()).unwrap();
        if count > 8 {
            assert_eq!(doc.records()[0].data(), &RecordData::Raw);
            assert_eq!(
                doc.diagnostics()[0].kind,
                DiagnosticKind::InvalidRecordPayload
            );
        } else {
            assert_eq!(
                doc.records()[0].data(),
                &RecordData::Comment {
                    data: payload[4..4 + count as usize].to_vec(),
                }
            );
            assert!(doc.diagnostics().is_empty());
        }
        let expected = if (4..=8).contains(&count) {
            vec![&payload[8..4 + count as usize]]
        } else {
            vec![]
        };
        assert_eq!(doc.emf_plus_chunks().collect::<Vec<_>>(), expected);
        assert_eq!(doc.records().len(), 2);
        assert_eq!(serialize(&doc).unwrap(), input);
    }
}

#[test]
fn polyline_count_uses_configured_budgets_instead_of_ruby_array_cap() {
    let count = 1_000_001u32;
    let mut input = header();
    let mut payload = vec![0; 16];
    payload.extend_from_slice(&count.to_le_bytes());
    payload.resize(20 + count as usize * 8, 0);
    input.extend(record(4, &payload));
    input.extend(eof());
    let doc = parse(&input, &ParseLimits::default()).unwrap();
    let RecordData::Polyline { points, .. } = doc.records()[0].data() else {
        panic!("bounded polyline should decode");
    };
    assert_eq!(points.len(), count as usize);
    assert_eq!(serialize(&doc).unwrap(), input);
    let limits = ParseLimits {
        max_work_units: count as u64,
        ..ParseLimits::default()
    };
    assert!(matches!(
        parse(&input, &limits),
        Err(ParseFailure::LimitExceeded {
            kind: LimitKind::WorkUnits,
            ..
        })
    ));
    let limits = ParseLimits {
        max_record_bytes: payload.len() + 7,
        ..ParseLimits::default()
    };
    assert!(matches!(
        parse(&input, &limits),
        Err(ParseFailure::LimitExceeded {
            kind: LimitKind::RecordBytes,
            ..
        })
    ));
}
