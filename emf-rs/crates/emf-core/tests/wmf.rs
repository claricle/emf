use emf_core::{
    wmf, EditFailure, LimitKind, ParseFailure, ParseLimits, SerializeFailure, SerializeLimits,
};

fn record(function: u16, body: &[u8]) -> Vec<u8> {
    assert_eq!(body.len() % 2, 0);
    let mut bytes = ((body.len() as u32 + 6) / 2).to_le_bytes().to_vec();
    bytes.extend_from_slice(&function.to_le_bytes());
    bytes.extend_from_slice(body);
    bytes
}

fn standard(records: &[Vec<u8>], tail: &[u8]) -> Vec<u8> {
    let words = 9 + records.iter().map(|r| r.len() / 2).sum::<usize>();
    let largest = records.iter().map(|r| r.len() / 2).max().unwrap_or(0);
    let mut bytes = Vec::new();
    bytes.extend_from_slice(&1u16.to_le_bytes());
    bytes.extend_from_slice(&9u16.to_le_bytes());
    bytes.extend_from_slice(&0x0300u16.to_le_bytes());
    bytes.extend_from_slice(&(words as u32).to_le_bytes());
    bytes.extend_from_slice(&7u16.to_le_bytes());
    bytes.extend_from_slice(&(largest as u32).to_le_bytes());
    bytes.extend_from_slice(&0u16.to_le_bytes());
    for bytes_record in records {
        bytes.extend_from_slice(bytes_record);
    }
    bytes.extend_from_slice(tail);
    bytes
}

#[test]
fn standard_wmf_preserves_unknown_records_eof_and_odd_trailing_bytes() {
    let bytes = standard(&[record(0xfedc, &[0xaa, 0xbb]), record(0, &[])], &[9, 8, 7]);
    let doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
    assert_eq!(doc.header().num_objects, 7);
    assert_eq!(doc.records().len(), 2);
    assert_eq!(doc.records()[0].function(), 0xfedc);
    assert_eq!(doc.records()[0].offset(), 18);
    assert_eq!(doc.records()[0].size_words(), 4);
    assert_eq!(doc.record_body(&doc.records()[0]).unwrap(), [0xaa, 0xbb]);
    assert_eq!(doc.tail(), [9, 8, 7]);
    assert!(doc.diagnostics().is_empty());
    assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
}

fn placeable(standard: &[u8]) -> Vec<u8> {
    let mut bytes = wmf::PLACEABLE_MAGIC.to_le_bytes().to_vec();
    for word in [0u16, (-123i16) as u16, (-456i16) as u16, 789, 1024, 1440] {
        bytes.extend_from_slice(&word.to_le_bytes());
    }
    bytes.extend_from_slice(&0x12345678u32.to_le_bytes());
    let checksum = bytes
        .chunks_exact(2)
        .fold(0, |sum, pair| sum ^ u16::from_le_bytes([pair[0], pair[1]]));
    bytes.extend_from_slice(&checksum.to_le_bytes());
    bytes.extend_from_slice(standard);
    bytes
}

#[test]
fn placeable_signed_bounds_and_checksum_survive_roundtrip_and_edits() {
    let bytes = placeable(&standard(&[record(0, &[])], &[0xab]));
    let mut doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
    let mut header = doc.placeable_header().unwrap().clone();
    assert_eq!(
        (header.left, header.top, header.right, header.inch),
        (-123, -456, 789, 1440)
    );
    assert_eq!(doc.records()[0].offset(), 40);
    assert!(doc.diagnostics().is_empty());
    assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
    header.left = -32768;
    header.inch = 720;
    doc.set_placeable_header(header).unwrap();
    let encoded = wmf::serialize(&doc).unwrap();
    assert_eq!(&encoded[22..], &bytes[22..]);
    let parsed = wmf::parse(&encoded, &ParseLimits::default()).unwrap();
    assert_eq!(parsed.placeable_header().unwrap().left, -32768);
    assert!(parsed.diagnostics().is_empty());
    let mut corrupt = bytes.clone();
    corrupt[20] ^= 1;
    let parsed = wmf::parse(&corrupt, &ParseLimits::default()).unwrap();
    assert!(parsed.diagnostics().iter().any(|d| matches!(
        d.kind,
        wmf::DiagnosticKind::PlaceableChecksumMismatch { .. }
    )));
    assert_eq!(wmf::serialize(&parsed).unwrap(), corrupt);
}

#[test]
fn malformed_record_sizes_stop_without_losing_remainder() {
    for remainder in [
        vec![1, 2, 3],
        record(42, &[])
            .into_iter()
            .enumerate()
            .map(|(i, b)| if i == 0 { 2 } else { b })
            .collect(),
        vec![255, 255, 255, 255, 42, 0, 8, 9],
    ] {
        let prefix = record(0x1234, &[4, 5]);
        let bytes = standard(&[prefix], &remainder);
        let doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
        assert_eq!(doc.records().len(), 1);
        assert_eq!(doc.tail(), remainder);
        assert!(!doc.diagnostics().is_empty());
        assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
    }
}

#[test]
fn invalid_but_bounded_eof_continues_to_valid_following_records() {
    let bytes = standard(
        &[record(0, &[1, 2]), record(0x1234, &[3, 4]), record(0, &[])],
        &[9],
    );
    let doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
    assert_eq!(doc.records().len(), 3);
    assert_eq!(doc.records()[1].function(), 0x1234);
    assert!(doc
        .diagnostics()
        .iter()
        .any(|d| d.kind == wmf::DiagnosticKind::InvalidEof));
    assert_eq!(doc.tail(), [9]);
    assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
}

#[test]
fn edits_refresh_word_sizes_preserving_other_records_and_tail() {
    let unknown = record(0xfefe, &[1, 2, 3, 4]);
    let bytes = standard(
        &[record(0x1234, &[8, 9]), unknown.clone(), record(0, &[])],
        &[0xde, 0xad, 0xbe],
    );
    let mut doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
    doc.replace_record(0, 0xabcd, vec![6; 20]).unwrap();
    let encoded = wmf::serialize(&doc).unwrap();
    let reparsed = wmf::parse(&encoded, &ParseLimits::default()).unwrap();
    assert_eq!(reparsed.header().size, 30);
    assert_eq!(reparsed.header().max_record, 13);
    assert_eq!(reparsed.header().num_objects, 7);
    assert_eq!(reparsed.records()[0].function(), 0xabcd);
    assert_eq!(
        reparsed.record_body(&reparsed.records()[0]).unwrap(),
        [6; 20]
    );
    assert_eq!(
        reparsed.record_bytes(&reparsed.records()[1]).unwrap(),
        unknown
    );
    assert_eq!(reparsed.tail(), [0xde, 0xad, 0xbe]);
    assert_eq!(wmf::serialize(&reparsed).unwrap(), encoded);
    let before = wmf::serialize(&doc).unwrap();
    assert!(matches!(
        doc.replace_record(0, 0xabcd, vec![1]),
        Err(EditFailure::RecordLayout { .. })
    ));
    assert!(matches!(
        doc.replace_record(99, 0, vec![]),
        Err(EditFailure::RecordIndex { .. })
    ));
    assert_eq!(wmf::serialize(&doc).unwrap(), before);
}

#[test]
fn all_parse_resource_budgets_are_enforced() {
    let bytes = standard(&[record(42, &[1, 2]), record(0, &[])], &[]);
    for kind in [
        LimitKind::InputBytes,
        LimitKind::RecordBytes,
        LimitKind::RecordCount,
        LimitKind::AllocatedBytes,
        LimitKind::WorkUnits,
    ] {
        let mut limits = ParseLimits::default();
        match kind {
            LimitKind::InputBytes => limits.max_input_bytes = bytes.len() - 1,
            LimitKind::RecordBytes => limits.max_record_bytes = 7,
            LimitKind::RecordCount => limits.max_records = 1,
            LimitKind::AllocatedBytes => limits.max_allocated_bytes = 0,
            LimitKind::WorkUnits => limits.max_work_units = 0,
            _ => unreachable!(),
        }
        assert!(
            matches!(wmf::parse(&bytes, &limits), Err(ParseFailure::LimitExceeded { kind: actual, .. }) if actual == kind),
            "{kind:?}"
        );
    }
    let exact_input = ParseLimits {
        max_input_bytes: bytes.len(),
        ..ParseLimits::default()
    };
    assert!(wmf::parse(&bytes, &exact_input).is_ok());
}

#[test]
fn serialization_limits_include_preserved_tail_and_edited_output() {
    let bytes = standard(&[record(42, &[1, 2]), record(0, &[])], &[9, 8, 7]);
    let mut doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
    for edited in [false, true] {
        if edited {
            doc.replace_record(0, 42, vec![5; 40]).unwrap();
        }
        let expected = wmf::serialize(&doc).unwrap();
        let exact = SerializeLimits {
            max_output_bytes: expected.len(),
            ..SerializeLimits::default()
        };
        assert_eq!(wmf::serialize_with_limits(&doc, &exact).unwrap(), expected);
        let short = SerializeLimits {
            max_output_bytes: expected.len() - 1,
            ..exact
        };
        assert!(matches!(
            wmf::serialize_with_limits(&doc, &short),
            Err(SerializeFailure::LimitExceeded {
                kind: LimitKind::OutputBytes,
                ..
            })
        ));
        let no_work = SerializeLimits {
            max_work_units: 0,
            ..SerializeLimits::default()
        };
        assert!(matches!(
            wmf::serialize_with_limits(&doc, &no_work),
            Err(SerializeFailure::LimitExceeded {
                kind: LimitKind::WorkUnits,
                ..
            })
        ));
    }
}

#[test]
fn truncated_placeable_and_metaheaders_fail_without_panicking() {
    let bytes = placeable(&standard(&[record(0, &[])], &[]));
    for len in 0..40 {
        assert!(
            wmf::parse(&bytes[..len], &ParseLimits::default()).is_err(),
            "length {len}"
        );
    }
}

#[test]
fn header_edits_keep_nonstructural_metadata_and_reject_changed_layout() {
    let bytes = standard(&[record(0, &[])], &[0x99]);
    let mut doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
    let mut header = doc.header().clone();
    header.file_type = 2;
    header.num_objects = 42;
    header.num_parameters = 0x1234;
    doc.set_header(header).unwrap();
    let encoded = wmf::serialize(&doc).unwrap();
    let reparsed = wmf::parse(&encoded, &ParseLimits::default()).unwrap();
    assert_eq!(reparsed.header().file_type, 2);
    assert_eq!(reparsed.header().num_objects, 42);
    assert_eq!(reparsed.header().num_parameters, 0x1234);
    assert_eq!(reparsed.tail(), [0x99]);
    let mut bad = doc.header().clone();
    bad.header_size = 10;
    assert_eq!(doc.set_header(bad), Err(EditFailure::HeaderLayout));
    assert_eq!(wmf::serialize(&doc).unwrap(), encoded);
}

#[test]
fn missing_eof_is_diagnostic_and_mismatched_declared_sizes_are_preserved() {
    let mut bytes = standard(&[record(0x4567, &[1, 2])], &[]);
    bytes[6..10].copy_from_slice(&u32::MAX.to_le_bytes());
    bytes[12..16].copy_from_slice(&12345u32.to_le_bytes());
    let doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
    assert_eq!(doc.records().len(), 1);
    assert_eq!(doc.header().size, u32::MAX);
    assert!(doc
        .diagnostics()
        .iter()
        .any(|d| d.kind == wmf::DiagnosticKind::MissingEof));
    assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
}

#[test]
fn existing_standard_and_placeable_line_fixtures_roundtrip() {
    for bytes in [
        include_bytes!("../../../../spec/fixtures/wmf/standard-line.wmf").as_slice(),
        include_bytes!("../../../../spec/fixtures/wmf/placeable-line.wmf").as_slice(),
    ] {
        let doc = wmf::parse(bytes, &ParseLimits::default()).unwrap();
        assert_eq!(doc.records().last().unwrap().function(), 0);
        assert!(doc.records().iter().any(|r| r.function() == 0x0214));
        assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
    }
}
