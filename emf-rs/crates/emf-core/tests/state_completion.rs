use emf_core::{parse, serialize, ParseLimits, RecordData};

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

#[test]
fn ruby_state_completion_records_decode_instead_of_staying_raw() {
    for kind in [16, 28, 53, 65, 66, 98, 115, 120] {
        let mut input = header();
        input.extend(record(kind, &[0xff, 0x80, 0x00, 0xfe]));
        let doc = parse(&input, &ParseLimits::default()).unwrap();
        assert_ne!(doc.records()[0].data(), &RecordData::Raw, "type {kind}");
        assert!(doc.diagnostics().is_empty());
        assert_eq!(serialize(&doc).unwrap(), input);
    }
}

fn state(kind: u32, value: u32) -> RecordData {
    match kind {
        16 => RecordData::SetMapperFlags { flags: value },
        28 => RecordData::SetMetaRgn,
        65 => RecordData::FlattenPath,
        66 => RecordData::WidenPath,
        98 => RecordData::SetIcmMode { mode: value },
        115 => RecordData::SetLayout { mode: value },
        _ => panic!("unexpected fixed state {kind}"),
    }
}

fn siblings_and_tail() -> Vec<u8> {
    let mut bytes = record(17, &9u32.to_le_bytes());
    bytes.extend(record(999, b"unknown!"));
    bytes.extend(record(14, &[0, 0, 0, 0, 16, 0, 0, 0, 20, 0, 0, 0]));
    bytes.extend_from_slice(b"tail");
    bytes
}

#[test]
fn fixed_fields_and_edits_preserve_suffix_siblings_header_and_tail() {
    for kind in [16, 28, 65, 66, 98, 115] {
        for value in [0, u32::MAX, 0x80000000, 0x7fffffff, 0x78563412] {
            for suffix in [&b""[..], &b"odd"[..], &b"opaque!!"[..]] {
                let fixed_len = if matches!(kind, 16 | 98 | 115) { 4 } else { 0 };
                let mut body = value.to_le_bytes()[..fixed_len].to_vec();
                body.extend_from_slice(suffix);
                let mut input = header();
                input.extend(record(kind, &body));
                input.extend(siblings_and_tail());
                let mut doc = parse(&input, &ParseLimits::default()).unwrap();
                assert_eq!(doc.records()[0].data(), &state(kind, value));
                assert_eq!(serialize(&doc).unwrap(), input);
                let replacement = !value;
                doc.edit_record(0, state(kind, replacement)).unwrap();
                let out = serialize(&doc).unwrap();
                let mut expected = input.clone();
                expected[48..52].copy_from_slice(&(input.len() as u32).to_le_bytes());
                expected[52..56].copy_from_slice(&5u32.to_le_bytes());
                expected[120..120 + fixed_len]
                    .copy_from_slice(&replacement.to_le_bytes()[..fixed_len]);
                assert_eq!(out, expected, "type {kind}");
                assert_eq!(&out[120 + fixed_len..120 + body.len()], suffix);
                let reparsed = parse(&out, &ParseLimits::default()).unwrap();
                assert_eq!(reparsed.records()[0].data(), &state(kind, replacement));
                assert_eq!(reparsed.trailing_bytes(), b"tail");
                assert!(reparsed.diagnostics().is_empty());
                assert_eq!(serialize(&reparsed).unwrap(), out);
            }
        }
    }
}

fn opaque(kind: u32, body: &[u8]) -> RecordData {
    match kind {
        53 => RecordData::ExtFloodFill {
            body: body.to_vec(),
        },
        120 => RecordData::SetTextJustification {
            body: body.to_vec(),
        },
        _ => panic!("unexpected opaque state {kind}"),
    }
}

#[test]
fn opaque_ruby_bodies_decode_and_resize_without_losing_following_bytes() {
    for kind in [53, 120] {
        for original in [
            &b""[..],
            &b"\xff\x00\x80"[..],
            &b"opaque body with extra bytes"[..],
        ] {
            let mut input = header();
            input.extend(record(kind, original));
            input.extend(siblings_and_tail());
            let source = parse(&input, &ParseLimits::default()).unwrap();
            assert_eq!(source.records()[0].data(), &opaque(kind, original));
            assert_eq!(serialize(&source).unwrap(), input);
            for replacement in [&b""[..], &b"\x80"[..], &b"longer\x00opaque\xffbody"[..]] {
                let mut doc = source.clone();
                doc.edit_record(0, opaque(kind, replacement)).unwrap();
                let out = serialize(&doc).unwrap();
                let mut expected = header();
                expected.extend(record(kind, replacement));
                expected.extend(siblings_and_tail());
                let len = expected.len() as u32;
                expected[48..52].copy_from_slice(&len.to_le_bytes());
                expected[52..56].copy_from_slice(&5u32.to_le_bytes());
                assert_eq!(out, expected);
                let reparsed = parse(&out, &ParseLimits::default()).unwrap();
                assert_eq!(reparsed.records()[0].data(), &opaque(kind, replacement));
                assert!(reparsed.diagnostics().is_empty());
                assert_eq!(serialize(&reparsed).unwrap(), out);
            }
        }
    }
}

#[test]
fn truncated_fixed_fields_stay_raw_with_diagnostics_and_continue_framing() {
    use emf_core::{Diagnostic, DiagnosticKind, EditFailure};
    for kind in [16, 98, 115] {
        for length in 0..4 {
            let mut input = header();
            input.extend(record(kind, &b"abc"[..length]));
            input.extend(siblings_and_tail());
            let mut doc = parse(&input, &ParseLimits::default()).unwrap();
            assert_eq!(doc.records()[0].data(), &RecordData::Raw);
            assert_eq!(
                doc.diagnostics(),
                &[Diagnostic {
                    offset: 112,
                    record_type: Some(kind),
                    kind: DiagnosticKind::InvalidRecordPayload,
                }]
            );
            assert_eq!(
                doc.records()[1].data(),
                &RecordData::SetMapMode { map_mode: 9 }
            );
            assert!(doc.has_eof());
            assert_eq!(
                doc.edit_record(0, state(kind, 9)),
                Err(EditFailure::RecordFamily { index: 0 })
            );
            assert_eq!(serialize(&doc).unwrap(), input);
        }
    }
}

#[test]
fn unknown_ids_and_cross_family_edits_preserve_original_records() {
    use emf_core::EditFailure;
    for kind in [23, 48, 52, 69, 97, 99, 114, 116, 119, 121, 999] {
        let mut input = header();
        input.extend(record(kind, b"unknown\xff"));
        let mut doc = parse(&input, &ParseLimits::default()).unwrap();
        assert_eq!(doc.records()[0].data(), &RecordData::Raw);
        assert!(doc.diagnostics().is_empty());
        assert_eq!(
            doc.edit_record(0, RecordData::SetMetaRgn),
            Err(EditFailure::RecordFamily { index: 0 })
        );
        assert_eq!(serialize(&doc).unwrap(), input);
    }
    for kind in [16, 28, 53, 65, 66, 98, 115, 120] {
        let mut input = header();
        input.extend(record(kind, &[0; 4]));
        let mut doc = parse(&input, &ParseLimits::default()).unwrap();
        assert_eq!(
            doc.edit_record(0, RecordData::SaveDc),
            Err(EditFailure::RecordFamily { index: 0 })
        );
        assert_eq!(serialize(&doc).unwrap(), input);
    }
}

#[test]
fn opaque_body_copy_and_edited_serialization_respect_inclusive_budgets() {
    use emf_core::{
        serialize_with_limits, LimitKind, ParseFailure, RecordSpan, SerializeFailure,
        SerializeLimits,
    };
    for kind in [53, 120] {
        let body = [0xff; 33];
        let mut input = header();
        input.extend(record(kind, &body));
        let allocation = input.len() + std::mem::size_of::<RecordSpan>() + body.len();
        let work = 8
            + (input.len() as u64).div_ceil(16)
            + 1
            + (8 + body.len() as u64).div_ceil(16)
            + (body.len() as u64).div_ceil(16);
        let mut limits = ParseLimits {
            max_allocated_bytes: allocation - 1,
            ..ParseLimits::default()
        };
        assert!(
            matches!(parse(&input, &limits), Err(ParseFailure::LimitExceeded {
            kind: LimitKind::AllocatedBytes, requested, ..
        }) if requested == allocation as u64)
        );
        limits.max_allocated_bytes = allocation;
        limits.max_work_units = work - 1;
        assert!(
            matches!(parse(&input, &limits), Err(ParseFailure::LimitExceeded {
            kind: LimitKind::WorkUnits, requested, ..
        }) if requested == work)
        );
        limits.max_work_units = work;
        let mut doc = parse(&input, &limits).unwrap();
        assert_eq!(doc.records()[0].data(), &opaque(kind, &body));
        doc.edit_record(0, opaque(kind, &body)).unwrap();
        let exact_work = 4 + (input.len() as u64).div_ceil(16) + (body.len() as u64).div_ceil(16);
        let mut output_limits = SerializeLimits {
            max_output_bytes: input.len(),
            max_work_units: exact_work - 1,
        };
        assert!(
            matches!(serialize_with_limits(&doc, &output_limits), Err(SerializeFailure::LimitExceeded {
            kind: LimitKind::WorkUnits, requested, ..
        }) if requested == exact_work)
        );
        output_limits.max_work_units = exact_work;
        let out = serialize_with_limits(&doc, &output_limits).unwrap();
        assert_eq!(out.len(), input.len());
        assert_eq!(&out[120..], &body);
        output_limits.max_output_bytes -= 1;
        assert!(
            matches!(serialize_with_limits(&doc, &output_limits), Err(SerializeFailure::LimitExceeded {
            kind: LimitKind::OutputBytes, requested, ..
        }) if requested == input.len() as u64)
        );
    }
}
