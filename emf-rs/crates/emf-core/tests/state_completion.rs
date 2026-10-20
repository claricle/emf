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
        input.extend(record(kind, &[0xff; 16]));
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
        53 | 120 => semantic(kind, value as i32),
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

#[test]
fn truncated_fixed_fields_stay_raw_with_diagnostics_and_continue_framing() {
    use emf_core::{Diagnostic, DiagnosticKind, EditFailure};
    for (kind, fixed) in [(16, 4), (98, 4), (115, 4), (53, 16), (120, 8)] {
        for length in 0..fixed {
            let mut input = header();
            input.extend(record(kind, &[0xff; 16][..length]));
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
    for kind in [23, 69, 97, 99, 114, 116, 119, 121, 999] {
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

fn semantic(kind: u32, value: i32) -> RecordData {
    match kind {
        53 => RecordData::ExtFloodFill {
            start: emf_core::Point {
                x: value,
                y: i32::MAX,
            },
            color: emf_core::ColorRef {
                red: 0x98,
                green: 0xba,
                blue: 0xdc,
                reserved: 0xfe,
            },
            flood_fill_mode: u32::MAX,
        },
        120 => RecordData::SetTextJustification {
            break_extra: value,
            break_count: -1,
        },
        _ => unreachable!(),
    }
}

#[test]
fn semantic_state_edits_preserve_suffix_siblings_and_tail_with_checked_budgets() {
    use emf_core::{serialize_with_limits, LimitKind, SerializeFailure, SerializeLimits};
    for kind in [53, 120] {
        let fixed: Vec<u8> = if kind == 53 {
            [0x80000000u32, 0x7fffffff, 0xfedcba98, u32::MAX]
                .iter()
                .flat_map(|v| v.to_le_bytes())
                .collect()
        } else {
            [i32::MIN, -1]
                .iter()
                .flat_map(|v| v.to_le_bytes())
                .collect()
        };
        for suffix in [b"".as_slice(), b"odd".as_slice(), b"\xffTAIL".as_slice()] {
            let mut body = fixed.clone();
            body.extend_from_slice(suffix);
            let mut input = header();
            input.extend(record(kind, &body));
            input.extend(siblings_and_tail());
            let mut doc = parse(&input, &ParseLimits::default()).unwrap();
            assert_eq!(doc.records()[0].data(), &semantic(kind, i32::MIN));
            assert!(doc.diagnostics().is_empty());
            assert_eq!(serialize(&doc).unwrap(), input);
            doc.edit_record(0, semantic(kind, -17)).unwrap();
            let out = serialize(&doc).unwrap();
            let mut expected = input.clone();
            expected[48..52].copy_from_slice(&(out.len() as u32).to_le_bytes());
            expected[52..56].copy_from_slice(&5u32.to_le_bytes());
            expected[120..124].copy_from_slice(&(-17i32).to_le_bytes());
            assert_eq!(out, expected);
            let reparsed = parse(&out, &ParseLimits::default()).unwrap();
            assert_eq!(reparsed.records()[0].data(), &semantic(kind, -17));
            assert!(reparsed.diagnostics().is_empty());
            assert_eq!(reparsed.trailing_bytes(), b"tail");
            assert_eq!(serialize(&reparsed).unwrap(), out);
            let work = 2 + 2 * doc.records().len() as u64 + (out.len() as u64).div_ceil(16);
            let mut limits = SerializeLimits {
                max_output_bytes: out.len(),
                max_work_units: work,
            };
            assert_eq!(serialize_with_limits(&doc, &limits).unwrap(), out);
            limits.max_work_units -= 1;
            assert!(matches!(
                serialize_with_limits(&doc, &limits),
                Err(SerializeFailure::LimitExceeded {
                    kind: LimitKind::WorkUnits,
                    ..
                })
            ));
            limits.max_work_units = work;
            limits.max_output_bytes -= 1;
            assert!(matches!(
                serialize_with_limits(&doc, &limits),
                Err(SerializeFailure::LimitExceeded {
                    kind: LimitKind::OutputBytes,
                    ..
                })
            ));
        }
    }
}
