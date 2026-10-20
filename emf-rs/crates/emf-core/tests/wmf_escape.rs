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

use wmf::escape::{EmptyEscape, EscapePayload, EscapeRecord};

fn fixtures() -> Vec<(u16, Vec<u8>, EscapePayload, EscapePayload)> {
    use EmptyEscape::*;
    use EscapePayload::*;
    let mut values: Vec<_> = [
        (0x0002, AbortDoc),
        (0x1000, BeginPath),
        (0x1010, CloseChannel),
        (0x0202, DownloadFace),
        (0x100f, DownloadHeader),
        (0x1002, EndPath),
        (0x000b, EndDoc),
        (0x0200, ExtTextOut),
        (0x002a, GetDeviceUnits),
        (0x0100, GetExtendedTextMetrics),
        (0x0201, GetFaceName),
        (0x0102, GetPairKernTable),
        (0x000c, GetPhysPageSize),
        (0x000d, GetPrintingOffset),
        (0x000e, GetScalingFactor),
        (0x0801, MetafileDriver),
        (0x0001, NewFrame),
        (0x0003, NextBand),
        (0x0026, PostScriptIgnore),
        (0x100e, OpenChannel),
        (0x0c01, QueryDibSupport),
    ]
    .into_iter()
    .map(|(code, kind)| (code, vec![], Empty(kind), Empty(BeginPath)))
    .collect();
    values.extend([
        (
            0x1001,
            vec![2, 0, 0xcd, 0xab],
            ClipToPath {
                clip_function: 2,
                reserved1: 0xabcd,
            },
            ClipToPath {
                clip_function: 0xffff,
                reserved1: 0xabcd,
            },
        ),
        (
            0x0019,
            [
                i32::MIN.to_le_bytes().as_slice(),
                i32::MAX.to_le_bytes().as_slice(),
                (-300i32).to_le_bytes().as_slice(),
                70000i32.to_le_bytes().as_slice(),
                &[0xff, 0xff, 0xcd, 0xab],
            ]
            .concat(),
            DrawPatternRect {
                position: [i32::MIN, i32::MAX],
                size: [-300, 70000],
                style: 0xffff,
                pattern: 0xabcd,
            },
            DrawPatternRect {
                position: [-1, 3],
                size: [4, -5],
                style: 0x8000,
                pattern: 0xffff,
            },
        ),
        (
            0x0021,
            vec![0xff, 0xff],
            EpsPrinting {
                set_eps_printing: 0xffff,
            },
            EpsPrinting {
                set_eps_printing: 2,
            },
        ),
        (
            0x1019,
            0x1001i32.to_le_bytes().to_vec(),
            GetPsFeatureSetting { feature: 0x1001 },
            GetPsFeatureSetting { feature: 0x1fff },
        ),
        (
            0x0008,
            vec![1, 0x10],
            QueryEscSupport { query: 0x1001 },
            QueryEscSupport { query: 0xffff },
        ),
        (
            0x0011,
            vec![0xff, 0xff],
            SetCopyCount { copy_count: 0xffff },
            SetCopyCount { copy_count: 0 },
        ),
        (
            0x0015,
            (-2i32).to_le_bytes().to_vec(),
            SetLineCap { cap: -2 },
            SetLineCap { cap: i32::MIN },
        ),
        (
            0x0016,
            (-2i32).to_le_bytes().to_vec(),
            SetLineJoin { join: -2 },
            SetLineJoin { join: 2 },
        ),
        (
            0x0017,
            (-77i32).to_le_bytes().to_vec(),
            SetMiterLimit { miter_limit: -77 },
            SetMiterLimit {
                miter_limit: i32::MIN,
            },
        ),
    ]);
    values
}

fn subtype_document(code: u16, data: &[u8], suffix: &[u8]) -> Vec<u8> {
    let mut body = code.to_le_bytes().to_vec();
    body.extend_from_slice(&(data.len() as u16).to_le_bytes());
    body.extend_from_slice(data);
    if data.len() % 2 != 0 {
        body.push(0xa5);
    }
    body.extend_from_slice(suffix);
    document(&body)
}

fn escape(doc: &wmf::Document) -> &EscapeRecord {
    match doc.records()[0].typed().unwrap() {
        wmf::TypedRecord::Escape(value) => value,
        other => panic!("expected escape, got {other:?}"),
    }
}

#[test]
fn all_thirty_subtypes_have_copy_views_and_roundtrip_edits() {
    fn assert_copy<T: Copy>(_: T) {}
    let fixtures = fixtures();
    assert_eq!(fixtures.len(), 30);
    for (code, data, expected, edited) in fixtures {
        assert_copy(expected);
        let bytes = subtype_document(code, &data, &[0xca, 0xfe]);
        let mut doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
        assert_eq!(
            escape(&doc).typed_payload(),
            Some(expected),
            "code {code:x}"
        );
        assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
        let mut changed = escape(&doc).clone();
        changed.replace_payload(edited).unwrap();
        assert_eq!(changed.typed_payload(), Some(edited));
        assert_eq!(changed.padding, None);
        doc.replace_typed(0, wmf::TypedRecord::Escape(changed))
            .unwrap();
        let output = wmf::serialize(&doc).unwrap();
        let reparsed = wmf::parse(&output, &ParseLimits::default()).unwrap();
        assert_eq!(escape(&reparsed).typed_payload(), Some(edited));
        assert_eq!(escape(&reparsed).function, 0xff26);
        assert!(reparsed
            .record_body(&reparsed.records()[0])
            .unwrap()
            .ends_with(&[0xca, 0xfe]));
        assert_eq!(reparsed.tail(), &[0xde, 0xad]);
        assert!(reparsed.has_eof());
    }
}

#[test]
fn malformed_and_unknown_interiors_stay_opaque_and_preserved() {
    let mut cases = vec![
        (0xffff, vec![]),
        (0x0006, vec![]),
        (0x1005, vec![0; 4]),
        (0x1015, vec![0; 4]),
        (0x1006, vec![0; 4]),
        (0x1016, vec![0; 4]),
    ];
    for (code, data, _, _) in fixtures() {
        if data.is_empty() {
            cases.push((code, vec![0, 1]));
        } else {
            cases.push((code, vec![]));
            cases.push((code, data[..data.len() - 1].to_vec()));
            let mut longer = data;
            longer.push(0xff);
            cases.push((code, longer));
        }
    }
    for (code, data) in cases {
        let bytes = subtype_document(code, &data, &[0xca, 0xfe]);
        let doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
        assert_eq!(
            escape(&doc).typed_payload(),
            None,
            "code {code:x}, data {data:?}"
        );
        assert!(doc.has_eof());
        assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
    }
}

#[test]
fn typed_replacement_discards_old_alignment_and_failure_is_atomic() {
    let bytes = subtype_document(0x13, &[0x80, 0, 0xff], &[0xca, 0xfe]);
    let mut doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
    let mut changed = escape(&doc).clone();
    changed
        .replace_payload(EscapePayload::SetCopyCount { copy_count: 7 })
        .unwrap();
    assert_eq!(changed.data, [7, 0]);
    assert_eq!(changed.padding, None);
    doc.replace_typed(0, wmf::TypedRecord::Escape(changed))
        .unwrap();
    let output = wmf::serialize(&doc).unwrap();
    let reparsed = wmf::parse(&output, &ParseLimits::default()).unwrap();
    assert_eq!(
        reparsed.record_body(&reparsed.records()[0]).unwrap(),
        &[0x11, 0, 2, 0, 7, 0, 0xca, 0xfe]
    );
    assert_eq!(reparsed.tail(), &[0xde, 0xad]);
    let mut invalid = escape(&reparsed).clone();
    invalid.function = 0x1234;
    let before = invalid.clone();
    assert_eq!(invalid.typed_payload(), None);
    assert!(invalid
        .replace_payload(EscapePayload::Empty(EmptyEscape::AbortDoc))
        .is_err());
    assert_eq!(invalid, before);
    let mut invalid_padding = escape(&reparsed).clone();
    invalid_padding.padding = Some(0xa5);
    assert_eq!(invalid_padding.typed_payload(), None);
}

#[test]
fn clip_to_path_preserves_both_record_sizes_and_reserved_field() {
    for suffix in [vec![], (0..14).collect()] {
        let bytes = subtype_document(0x1001, &[2, 0, 0xcd, 0xab], &suffix);
        assert_eq!(
            u32::from_le_bytes(bytes[18..22].try_into().unwrap()) * 2,
            14 + suffix.len() as u32
        );
        let mut doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
        assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
        let mut value = escape(&doc).clone();
        value
            .replace_payload(EscapePayload::ClipToPath {
                clip_function: 1,
                reserved1: 0xabcd,
            })
            .unwrap();
        doc.replace_typed(0, wmf::TypedRecord::Escape(value))
            .unwrap();
        let output = wmf::serialize(&doc).unwrap();
        assert_eq!(output.len(), bytes.len());
        let reparsed = wmf::parse(&output, &ParseLimits::default()).unwrap();
        assert_eq!(escape(&reparsed).data, [1, 0, 0xcd, 0xab]);
        assert_eq!(
            &reparsed.record_body(&reparsed.records()[0]).unwrap()[8..],
            suffix
        );
    }
}
