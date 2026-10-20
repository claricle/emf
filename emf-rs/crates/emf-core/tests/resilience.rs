use emf_core::{
    parse, serialize, serialize_with_limits, DiagnosticKind, LimitKind, ParseFailure, ParseLimits,
    Point, Reader, RecordData, RecordSpan, Rect, SerializeFailure, SerializeLimits,
};

fn header() -> Vec<u8> {
    let mut bytes = vec![0; 88];
    bytes[..4].copy_from_slice(&1u32.to_le_bytes());
    bytes[4..8].copy_from_slice(&88u32.to_le_bytes());
    bytes[40..44].copy_from_slice(&0x464d4520u32.to_le_bytes());
    bytes
}
fn record(bytes: &mut Vec<u8>, kind: u32, payload: &[u8]) {
    bytes.extend_from_slice(&kind.to_le_bytes());
    bytes.extend_from_slice(&(8 + payload.len() as u32).to_le_bytes());
    bytes.extend_from_slice(payload);
}
fn fixture() -> Vec<u8> {
    let mut bytes = header();
    record(&mut bytes, 70, &[0; 4]);
    record(&mut bytes, 999, b"opaque!!");
    record(&mut bytes, 14, &[0, 0, 0, 0, 16, 0, 0, 0, 20, 0, 0, 0]);
    bytes.extend_from_slice(b"tail");
    bytes
}
fn check_output_boundary(doc: &emf_core::Document, expected: &[u8]) {
    let mut limits = SerializeLimits {
        max_output_bytes: expected.len() - 1,
        ..SerializeLimits::default()
    };
    assert_eq!(
        serialize_with_limits(doc, &limits),
        Err(SerializeFailure::LimitExceeded {
            kind: LimitKind::OutputBytes,
            limit: limits.max_output_bytes as u64,
            requested: expected.len() as u64,
        })
    );
    limits.max_output_bytes += 1;
    assert_eq!(serialize_with_limits(doc, &limits).unwrap(), expected);
}
#[test]
fn output_budget_includes_edited_growth_padding_and_trailing_bytes() {
    let input = fixture();
    let mut doc = parse(&input, &ParseLimits::default()).unwrap();
    check_output_boundary(&doc, &input);
    doc.edit_record(
        0,
        RecordData::Comment {
            data: vec![b'x'; 17],
        },
    )
    .unwrap();
    let expected = serialize(&doc).unwrap();
    assert_eq!(expected.len(), input.len() + 20);
    check_output_boundary(&doc, &expected);
    let reparsed = parse(&expected, &ParseLimits::default()).unwrap();
    assert_eq!(
        reparsed.records()[0].data(),
        &RecordData::Comment {
            data: vec![b'x'; 17]
        }
    );
    assert_eq!(
        reparsed.record_bytes(&reparsed.records()[1]).unwrap(),
        doc.record_bytes(&doc.records()[1]).unwrap()
    );
    assert_eq!(reparsed.trailing_bytes(), b"tail");
    assert_eq!(reparsed.header().n_bytes as usize, expected.len());
    assert_eq!(serialize(&doc).unwrap(), expected);
}
#[test]
fn serialization_work_charges_record_traversal_output_and_edited_points() {
    let mut input = header();
    record(&mut input, 4, &[0; 20]);
    let mut doc = parse(&input, &ParseLimits::default()).unwrap();
    let bounds = Rect {
        left: 0,
        top: 0,
        right: 0,
        bottom: 0,
    };
    doc.edit_record(
        0,
        RecordData::Polyline {
            bounds,
            points: vec![Point { x: -7, y: 9 }; 33],
        },
    )
    .unwrap();
    let expected = serialize(&doc).unwrap();
    let exact = 2 * 2 + (expected.len() as u64).div_ceil(16) + 33;
    let mut limits = SerializeLimits {
        max_work_units: exact - 1,
        ..SerializeLimits::default()
    };
    assert!(matches!(
        serialize_with_limits(&doc, &limits),
        Err(SerializeFailure::LimitExceeded {
            kind: LimitKind::WorkUnits,
            ..
        })
    ));
    limits.max_work_units = exact;
    assert_eq!(serialize_with_limits(&doc, &limits).unwrap(), expected);
    let parsed = parse(&expected, &ParseLimits::default()).unwrap();
    assert_eq!(parsed.records()[0].data(), doc.records()[0].data());
}
#[test]
fn serialization_work_accounts_for_unchanged_records_and_tail() {
    let input = fixture();
    let doc = parse(&input, &ParseLimits::default()).unwrap();
    let exact = 2 * (doc.records().len() as u64 + 1) + (input.len() as u64).div_ceil(16);
    let mut limits = SerializeLimits {
        max_work_units: exact - 1,
        ..SerializeLimits::default()
    };
    assert_eq!(
        serialize_with_limits(&doc, &limits),
        Err(SerializeFailure::LimitExceeded {
            kind: LimitKind::WorkUnits,
            limit: exact - 1,
            requested: exact,
        })
    );
    limits.max_work_units = exact;
    assert_eq!(serialize_with_limits(&doc, &limits).unwrap(), input);
    limits.max_work_units = 0;
    assert!(matches!(
        serialize_with_limits(&doc, &limits),
        Err(SerializeFailure::LimitExceeded {
            kind: LimitKind::WorkUnits,
            ..
        })
    ));
    assert_eq!(serialize(&doc).unwrap(), input);
}
#[test]
fn parser_decoded_allocation_and_work_fail_at_exact_boundaries() {
    let mut input = header();
    record(&mut input, 70, &[3, 0, 0, 0, b'a', b'b', b'c', 0xcc]);
    let allocation = input.len() + std::mem::size_of::<RecordSpan>() + 3;
    let mut limits = ParseLimits {
        max_allocated_bytes: allocation - 1,
        ..ParseLimits::default()
    };
    assert!(matches!(
        parse(&input, &limits),
        Err(ParseFailure::LimitExceeded {
            kind: LimitKind::AllocatedBytes,
            ..
        })
    ));
    limits.max_allocated_bytes = allocation;
    let doc = parse(&input, &limits).unwrap();
    assert_eq!(
        doc.records()[0].data(),
        &RecordData::Comment {
            data: b"abc".to_vec()
        }
    );
    assert_eq!(serialize(&doc).unwrap(), input);
    let exact_work = 7 + 2 + (input.len() as u64).div_ceil(16) + 1;
    limits.max_work_units = exact_work - 1;
    assert!(matches!(
        parse(&input, &limits),
        Err(ParseFailure::LimitExceeded {
            kind: LimitKind::WorkUnits,
            ..
        })
    ));
    limits.max_work_units = exact_work;
    assert_eq!(serialize(&parse(&input, &limits).unwrap()).unwrap(), input);
}
#[test]
fn extreme_counts_remain_raw_and_following_records_survive() {
    for kind in [4, 70] {
        let mut input = header();
        let mut payload = if kind == 4 { vec![0; 16] } else { vec![] };
        payload.extend_from_slice(&u32::MAX.to_le_bytes());
        record(&mut input, kind, &payload);
        record(&mut input, 17, &7u32.to_le_bytes());
        let doc = parse(&input, &ParseLimits::default()).unwrap();
        assert_eq!(doc.records()[0].data(), &RecordData::Raw);
        assert_eq!(
            doc.diagnostics()[0].kind,
            DiagnosticKind::InvalidRecordPayload
        );
        assert_eq!(
            doc.records()[1].data(),
            &RecordData::SetMapMode { map_mode: 7 }
        );
        assert_eq!(serialize(&doc).unwrap(), input);
    }
    let mut reader = Reader::new(&[1, 2, 3]);
    assert_eq!(reader.take(1).unwrap(), &[1]);
    assert_eq!(
        reader.take(usize::MAX),
        Err(ParseFailure::ArithmeticOverflow { offset: 1 })
    );
    assert_eq!(reader.position(), 1);
    assert_eq!(reader.take(2).unwrap(), &[2, 3]);
}
#[test]
fn pathological_corrupt_fixture_is_bounded_and_preserved() {
    let bytes = std::fs::read(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../../spec/fixtures/emf-corrupted/bad_corrupted_2014-12-09-002112.emf"
    ))
    .unwrap();
    let doc = parse(&bytes, &ParseLimits::default()).unwrap();
    assert!(!doc.records().is_empty());
    assert_eq!(serialize(&doc).unwrap(), bytes);
}
