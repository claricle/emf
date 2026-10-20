use emf_core::wmf::{
    self,
    text::{TextRecord, TextRectangle},
    TypedRecord,
};
use emf_core::{EditFailure, ParseLimits};

fn words(values: &[i16]) -> Vec<u8> {
    values
        .iter()
        .flat_map(|value| value.to_le_bytes())
        .collect()
}

fn record(function: u16, body: &[u8]) -> Vec<u8> {
    assert_eq!(body.len() % 2, 0);
    let mut bytes = ((body.len() as u32 + 6) / 2).to_le_bytes().to_vec();
    bytes.extend_from_slice(&function.to_le_bytes());
    bytes.extend_from_slice(body);
    bytes
}

fn document(function: u16, body: &[u8]) -> Vec<u8> {
    let records = [
        record(function, body),
        record(0xfefe, &[9, 8]),
        record(0, &[]),
    ]
    .concat();
    let mut bytes = words(&[1, 9, 0x300]);
    bytes.extend_from_slice(&((18 + records.len()) as u32 / 2).to_le_bytes());
    bytes.extend_from_slice(&0u16.to_le_bytes());
    bytes.extend_from_slice(&((body.len() as u32 + 6) / 2).to_le_bytes());
    bytes.extend_from_slice(&0u16.to_le_bytes());
    bytes.extend_from_slice(&records);
    bytes.extend_from_slice(&[0xde, 0xad, 0xbe]);
    bytes
}

fn text(doc: &wmf::Document) -> TextRecord {
    match doc.records()[0].typed().unwrap() {
        TypedRecord::Text(value) => value.clone(),
        value => panic!("unexpected family: {value:?}"),
    }
}

#[test]
fn textout_preserves_signed_coordinates_bytes_and_all_string_padding_on_edit() {
    let mut body = words(&[3]);
    body.extend_from_slice(&[0x81, 0, 0xff, 0xa5, 0xb6, 0xc7]);
    body.extend_from_slice(&words(&[i16::MIN, -456]));
    // Only the low function byte is constrained by the record specification.
    let bytes = document(0xff21, &body);
    let mut doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
    assert_eq!(
        text(&doc),
        TextRecord::TextOut {
            function: 0xff21,
            text: vec![0x81, 0, 0xff],
            padding: vec![0xa5, 0xb6, 0xc7],
            x: -456,
            y: i16::MIN,
        }
    );
    assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
    let mut edited = text(&doc);
    if let TextRecord::TextOut { x, text, .. } = &mut edited {
        *x = 789;
        text[0] = 0x82;
    }
    doc.replace_typed(0, TypedRecord::Text(edited.clone()))
        .unwrap();
    let output = wmf::serialize(&doc).unwrap();
    let reparsed = wmf::parse(&output, &ParseLimits::default()).unwrap();
    assert_eq!(text(&reparsed), edited);
    assert_eq!(
        reparsed.record_bytes(&reparsed.records()[1]),
        Some(record(0xfefe, &[9, 8]).as_slice())
    );
    assert_eq!(reparsed.tail(), &[0xde, 0xad, 0xbe]);
}

#[test]
fn extended_text_conditional_rectangle_spacing_padding_and_suffix_roundtrip() {
    for options in [0u16, 2, 4, 6, 0x8006] {
        let mut body = words(&[-13, -27, 3, options as i16]);
        let rectangle = (options & 6 != 0).then_some(TextRectangle {
            left: -100,
            top: -200,
            right: 300,
            bottom: 400,
        });
        if rectangle.is_some() {
            body.extend_from_slice(&words(&[-100, -200, 300, 400]));
        }
        body.extend_from_slice(&[0x80, 0, 0xfe, 0xa5]);
        body.extend_from_slice(&words(&[-12, 0, 32767]));
        body.extend_from_slice(&[0xca, 0xfe]);
        let bytes = document(0x0a32, &body);
        let mut doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
        assert_eq!(
            text(&doc),
            TextRecord::ExtTextOut {
                function: 0x0a32,
                text: vec![0x80, 0, 0xfe],
                padding: vec![0xa5],
                x: -27,
                y: -13,
                options,
                rectangle,
                dx: Some(vec![-12, 0, 32767]),
            }
        );
        assert!(doc.diagnostics().is_empty());
        assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
        let mut edited = text(&doc);
        if let TextRecord::ExtTextOut { x, dx, .. } = &mut edited {
            *x = -300;
            *dx = Some(vec![123, -234, 0]);
        }
        doc.replace_typed(0, TypedRecord::Text(edited.clone()))
            .unwrap();
        let output = wmf::serialize(&doc).unwrap();
        let reparsed = wmf::parse(&output, &ParseLimits::default()).unwrap();
        assert_eq!(text(&reparsed), edited);
        assert!(reparsed
            .record_body(&reparsed.records()[0])
            .unwrap()
            .ends_with(&[0xca, 0xfe]));
        assert_eq!(
            reparsed.record_bytes(&reparsed.records()[1]),
            doc.record_bytes(&doc.records()[1])
        );
        assert_eq!(reparsed.tail(), doc.tail());
    }
}

#[test]
fn extended_text_pdy_uses_two_displacements_per_byte_and_preserves_suffix_on_edit() {
    for content in [vec![0x80, 0xfe], vec![0x80, 0xfe, 0x7f]] {
        let mut body = words(&[-13, -27, content.len() as i16, 0x2000]);
        body.extend_from_slice(&content);
        if content.len() % 2 != 0 {
            body.push(0xa5);
        }
        let original_dx = [-12, 13, 0, -1, 32767, -32768];
        body.extend_from_slice(&words(&original_dx[..content.len() * 2]));
        body.extend_from_slice(&[0xca, 0xfe]);
        let bytes = document(0x0a32, &body);
        let mut doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
        assert_eq!(
            text(&doc),
            TextRecord::ExtTextOut {
                function: 0x0a32,
                text: content.clone(),
                padding: if content.len() % 2 == 0 {
                    vec![]
                } else {
                    vec![0xa5]
                },
                x: -27,
                y: -13,
                options: 0x2000,
                rectangle: None,
                dx: Some(original_dx[..content.len() * 2].to_vec()),
            }
        );
        assert_eq!(wmf::serialize(&doc).unwrap(), bytes);

        let edited_dx = [1, -2, 3, -4, 5, -6];
        let mut edited = text(&doc);
        if let TextRecord::ExtTextOut { dx, .. } = &mut edited {
            *dx = Some(edited_dx[..content.len() * 2].to_vec());
        }
        doc.replace_typed(0, TypedRecord::Text(edited.clone()))
            .unwrap();
        let output = wmf::serialize(&doc).unwrap();
        let reparsed = wmf::parse(&output, &ParseLimits::default()).unwrap();
        assert_eq!(text(&reparsed), edited);
        assert!(reparsed
            .record_body(&reparsed.records()[0])
            .unwrap()
            .ends_with(&[0xca, 0xfe]));
        assert_eq!(
            reparsed.record_bytes(&reparsed.records()[1]),
            doc.record_bytes(&doc.records()[1])
        );
        assert_eq!(reparsed.tail(), doc.tail());
    }
}

#[test]
fn extended_text_accepts_absent_spacing_and_empty_text_with_opaque_suffix() {
    for content in [vec![1, 2], vec![]] {
        let mut body = words(&[-1, -2, content.len() as i16, 0]);
        body.extend_from_slice(&content);
        if content.is_empty() {
            body.extend_from_slice(&[0xab, 0xcd]);
        }
        let bytes = document(0x0a32, &body);
        let mut doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
        let mut edited = text(&doc);
        assert!(matches!(
            &edited,
            TextRecord::ExtTextOut {
                dx: None,
                rectangle: None,
                ..
            }
        ));
        if let TextRecord::ExtTextOut { y, .. } = &mut edited {
            *y = -99;
        }
        doc.replace_typed(0, TypedRecord::Text(edited.clone()))
            .unwrap();
        let output = wmf::serialize(&doc).unwrap();
        let reparsed = wmf::parse(&output, &ParseLimits::default()).unwrap();
        assert_eq!(text(&reparsed), edited);
        assert_eq!(&output[24..26], &(-99i16).to_le_bytes());
        if content.is_empty() {
            assert!(reparsed
                .record_body(&reparsed.records()[0])
                .unwrap()
                .ends_with(&[0xab, 0xcd]));
        }
    }
}

#[test]
fn malformed_known_text_stays_opaque_and_roundtrips() {
    let cases = [
        (0x0521, words(&[-1, 0, 0])),
        (0x0521, words(&[3, 0, 0])),
        (0x0a32, words(&[0, 0, -1, 0])),
        (0x0a32, words(&[0, 0, 0, 2])),
        (0x0a32, words(&[0, 0, 3, 0, 0, 0, 1])),
        // Two bytes with ETO_PDY require four displacement words.
        (0x0a32, words(&[0, 0, 2, 0x2000, 0x6261, 1])),
    ];
    for (function, body) in cases {
        let bytes = document(function, &body);
        let doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
        assert_eq!(doc.records()[0].typed(), None);
        assert!(doc
            .diagnostics()
            .iter()
            .any(|d| d.kind == wmf::DiagnosticKind::MalformedRecord));
        assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
    }
}

#[test]
fn invalid_pdy_edit_is_atomic() {
    let bytes = document(0x0a32, &words(&[0, 0, 2, 0x2000, 0x6261, 1, 2, 3, 4]));
    let mut doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
    assert!(text(&doc).eq(&TextRecord::ExtTextOut {
        function: 0x0a32,
        text: b"ab".to_vec(),
        padding: vec![],
        x: 0,
        y: 0,
        options: 0x2000,
        rectangle: None,
        dx: Some(vec![1, 2, 3, 4]),
    }));
    let mut edited = text(&doc);
    if let TextRecord::ExtTextOut { dx, .. } = &mut edited {
        *dx = Some(vec![7, 8]);
    }
    assert!(matches!(
        doc.replace_typed(0, TypedRecord::Text(edited)),
        Err(EditFailure::RecordLayout { .. })
    ));
    assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
}

#[test]
fn invalid_text_edits_are_atomic() {
    let bytes = document(0x0a32, &words(&[0, 0, 2, 0, 0x6261]));
    let mut doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
    for invalid in 0..5 {
        let mut edited = text(&doc);
        if let TextRecord::ExtTextOut {
            function,
            text,
            padding,
            rectangle,
            dx,
            ..
        } = &mut edited
        {
            match invalid {
                0 => *dx = Some(vec![1]),
                1 => {
                    *rectangle = Some(TextRectangle {
                        left: 0,
                        top: 0,
                        right: 1,
                        bottom: 1,
                    })
                }
                2 => *padding = vec![0],
                3 => *function = 0x0521,
                4 => *text = vec![0; 32768],
                _ => unreachable!(),
            }
        }
        assert!(matches!(
            doc.replace_typed(0, TypedRecord::Text(edited)),
            Err(EditFailure::RecordLayout { .. })
        ));
        assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
    }
}

#[test]
fn text_allocation_limit_propagates_as_a_resource_failure() {
    let bytes = document(0x0a32, &words(&[0, 0, 2, 0, 0x6261]));
    let ceiling = bytes.len() + std::mem::size_of::<wmf::Record>();
    let limits = ParseLimits {
        max_allocated_bytes: ceiling,
        ..ParseLimits::default()
    };
    assert!(matches!(
        wmf::parse(&bytes, &limits),
        Err(emf_core::ParseFailure::LimitExceeded {
            kind: emf_core::LimitKind::AllocatedBytes,
            limit,
            requested,
        }) if limit == ceiling as u64 && requested == ceiling as u64 + 2
    ));
}
