use emf_core::{wmf, ParseLimits};

fn document(body: &[u8]) -> Vec<u8> {
    let mut bytes = vec![1, 0, 9, 0, 0, 3];
    bytes.extend_from_slice(&((30 + body.len()) as u32 / 2).to_le_bytes());
    bytes.extend_from_slice(&[0, 0]);
    bytes.extend_from_slice(&((6 + body.len()) as u32 / 2).to_le_bytes());
    bytes.extend_from_slice(&[0, 0]);
    bytes.extend_from_slice(&((6 + body.len()) as u32 / 2).to_le_bytes());
    bytes.extend_from_slice(&0xff26u16.to_le_bytes());
    bytes.extend_from_slice(body);
    bytes.extend_from_slice(&[3, 0, 0, 0, 0, 0, 0xde, 0xad]);
    bytes
}

#[test]
fn escape_transport_is_typed_and_preserves_bytes() {
    let bytes = document(&[0x13, 0, 3, 0, 0x80, 0, 0xff, 0xa5, 0xca, 0xfe]);
    let doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
    assert!(doc.records()[0].typed().is_some());
    assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
}

#[test]
fn escape_edit_derives_count_and_preserves_padding_suffix_and_tail() {
    use wmf::{escape::EscapeRecord, TypedRecord};
    let bytes = document(&[0x13, 0, 3, 0, 0x80, 0, 0xff, 0xa5, 0xca, 0xfe]);
    let mut doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
    let changed = EscapeRecord {
        function: 0x626,
        escape_function: 0x1013,
        data: vec![0, 0xff, 2, 3, 4],
        padding: Some(0x97),
    };
    doc.replace_typed(0, TypedRecord::Escape(changed.clone()))
        .unwrap();
    let output = wmf::serialize(&doc).unwrap();
    let reparsed = wmf::parse(&output, &ParseLimits::default()).unwrap();
    let mut expected = changed;
    expected.function = 0xff26;
    assert_eq!(
        reparsed.records()[0].typed(),
        Some(&TypedRecord::Escape(expected))
    );
    assert!(reparsed
        .record_body(&reparsed.records()[0])
        .unwrap()
        .ends_with(&[0xca, 0xfe]));
    assert_eq!(reparsed.tail(), &[0xde, 0xad]);
    let before = wmf::serialize(&doc).unwrap();
    let invalid = EscapeRecord {
        function: 0x626,
        escape_function: 0,
        data: vec![1],
        padding: None,
    };
    assert!(doc.replace_typed(0, TypedRecord::Escape(invalid)).is_err());
    assert_eq!(wmf::serialize(&doc).unwrap(), before);
}

#[test]
fn truncated_escape_payload_is_raw_and_recovers_at_eof() {
    for body in [vec![1, 0], vec![1, 0, 3, 0, 0, 0]] {
        let bytes = document(&body);
        let doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
        assert_eq!(doc.records()[0].typed(), None);
        assert!(doc.has_eof());
        assert!(doc
            .diagnostics()
            .iter()
            .any(|d| d.kind == wmf::DiagnosticKind::MalformedRecord));
        assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
    }
}
