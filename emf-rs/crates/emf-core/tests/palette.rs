use emf_core::{parse, serialize, ParseLimits, RecordData};

fn words(values: &[u32]) -> Vec<u8> {
    values.iter().flat_map(|v| v.to_le_bytes()).collect()
}
fn put(bytes: &mut [u8], offset: usize, value: u32) {
    bytes[offset..offset + 4].copy_from_slice(&value.to_le_bytes());
}
fn record(kind: u32, payload: &[u8]) -> Vec<u8> {
    let mut bytes = words(&[kind, (8 + payload.len()) as u32]);
    bytes.extend_from_slice(payload);
    bytes
}
fn document(record: &[u8]) -> Vec<u8> {
    let mut bytes = vec![0; 88];
    put(&mut bytes, 0, 1);
    put(&mut bytes, 4, 88);
    put(&mut bytes, 40, 0x464d4520);
    bytes.extend_from_slice(record);
    bytes.extend_from_slice(&words(&[999, 12, 0xfedcba98]));
    bytes.extend_from_slice(&words(&[14, 20, 0, 16, 20]));
    bytes.extend_from_slice(b"tail");
    bytes
}
fn fixtures() -> Vec<Vec<u8>> {
    vec![
        record(48, &words(&[0x8000000f, 0xabababab])),
        record(
            49,
            &words(&[0x87654321, 0x0002fedc, 0x80ff0201, 0xff0003fe, 0xabababab]),
        ),
        record(
            50,
            &words(&[0x87654321, u32::MAX, 2, 0x80ff0201, 0xff0003fe, 0xabababab]),
        ),
        record(51, &words(&[0x87654321, u32::MAX, 0xabababab])),
        record(52, &words(&[0xabababab])),
    ]
}
#[test]
fn palette_cohort_decodes_instead_of_remaining_raw() {
    for record in fixtures() {
        let bytes = document(&record);
        let doc = parse(&bytes, &ParseLimits::default()).unwrap();
        assert_ne!(doc.records()[0].data(), &RecordData::Raw);
        assert_eq!(serialize(&doc).unwrap(), bytes);
    }
}

fn entries(data: &RecordData) -> &[emf_core::PaletteEntry] {
    match data {
        RecordData::CreatePalette { entries, .. }
        | RecordData::SetPaletteEntries { entries, .. } => entries,
        other => panic!("expected entries, got {other:?}"),
    }
}
fn word(bytes: &[u8], offset: usize) -> u32 {
    u32::from_le_bytes(bytes[offset..offset + 4].try_into().unwrap())
}
#[test]
fn raw_fields_and_noop_edits_preserve_record_suffix_siblings_and_tail() {
    use emf_core::PaletteEntry;
    for record in fixtures() {
        let original = document(&record);
        let mut doc = parse(&original, &ParseLimits::default()).unwrap();
        assert!(doc.diagnostics().is_empty());
        match doc.records()[0].data() {
            RecordData::SelectPalette { ih_pal } => assert_eq!(*ih_pal, 0x8000000f),
            RecordData::CreatePalette {
                ih_pal,
                version,
                entries,
            } => {
                assert_eq!(*ih_pal, 0x87654321);
                assert_eq!(*version, 0xfedc);
                assert_eq!(
                    entries,
                    &[
                        PaletteEntry {
                            red: 1,
                            green: 2,
                            blue: 255,
                            flags: 128
                        },
                        PaletteEntry {
                            red: 254,
                            green: 3,
                            blue: 0,
                            flags: 255
                        },
                    ]
                );
            }
            RecordData::SetPaletteEntries {
                ih_pal,
                start,
                entries,
            } => {
                assert_eq!(*ih_pal, 0x87654321);
                assert_eq!(*start, u32::MAX);
                assert_eq!(
                    entries[0],
                    PaletteEntry {
                        red: 1,
                        green: 2,
                        blue: 255,
                        flags: 128
                    }
                );
                assert_eq!(
                    entries[1],
                    PaletteEntry {
                        red: 254,
                        green: 3,
                        blue: 0,
                        flags: 255
                    }
                );
            }
            RecordData::ResizePalette {
                ih_pal,
                entry_count,
            } => {
                assert_eq!(*ih_pal, 0x87654321);
                assert_eq!(*entry_count, u32::MAX);
            }
            other => assert_eq!(other, &RecordData::RealizePalette),
        }
        doc.edit_record(0, doc.records()[0].data().clone()).unwrap();
        let encoded = serialize(&doc).unwrap();
        assert_eq!(&encoded[88..], &original[88..]);
        assert_eq!(word(&encoded, 48) as usize, encoded.len());
        assert_eq!(word(&encoded, 52), 4);
        assert_eq!(doc.trailing_bytes(), b"tail");
    }
}
#[test]
fn scalar_edits_change_only_selected_fields() {
    for (record, replacement, offset, value) in [
        (
            fixtures()[0].clone(),
            RecordData::SelectPalette { ih_pal: 7 },
            8,
            7,
        ),
        (
            fixtures()[3].clone(),
            RecordData::ResizePalette {
                ih_pal: 0x87654321,
                entry_count: 0,
            },
            12,
            0,
        ),
    ] {
        let original = document(&record);
        let mut doc = parse(&original, &ParseLimits::default()).unwrap();
        doc.edit_record(0, replacement).unwrap();
        let encoded = serialize(&doc).unwrap();
        let mut expected = original[88..].to_vec();
        put(&mut expected, offset, value);
        assert_eq!(&encoded[88..], &expected);
    }
}
#[test]
fn entry_edits_rebuild_counts_and_preserve_unrelated_bytes() {
    use emf_core::PaletteEntry;
    for record in [fixtures()[1].clone(), fixtures()[2].clone()] {
        for count in [0, 1, 3] {
            let original = document(&record);
            let mut doc = parse(&original, &ParseLimits::default()).unwrap();
            let mut edited = doc.records()[0].data().clone();
            match &mut edited {
                RecordData::CreatePalette {
                    ih_pal,
                    version,
                    entries,
                } => {
                    *ih_pal = 9;
                    *version = 0x0300;
                    entries.resize(
                        count,
                        PaletteEntry {
                            red: 5,
                            green: 6,
                            blue: 7,
                            flags: 0x81,
                        },
                    );
                    if let Some(entry) = entries.first_mut() {
                        entry.flags = 0xfe;
                    }
                }
                RecordData::SetPaletteEntries {
                    ih_pal,
                    start,
                    entries,
                } => {
                    *ih_pal = 9;
                    *start = 0x80000001;
                    entries.resize(
                        count,
                        PaletteEntry {
                            red: 5,
                            green: 6,
                            blue: 7,
                            flags: 0x81,
                        },
                    );
                    if let Some(entry) = entries.first_mut() {
                        entry.flags = 0xfe;
                    }
                }
                _ => unreachable!(),
            }
            doc.edit_record(0, edited.clone()).unwrap();
            let encoded = serialize(&doc).unwrap();
            let reparsed = parse(&encoded, &ParseLimits::default()).unwrap();
            assert_eq!(reparsed.records()[0].data(), &edited);
            let bytes = reparsed.record_bytes(&reparsed.records()[0]).unwrap();
            let fixed = if word(bytes, 0) == 49 {
                assert_eq!(
                    u16::from_le_bytes(bytes[14..16].try_into().unwrap()) as usize,
                    count
                );
                16
            } else {
                assert_eq!(word(bytes, 16) as usize, count);
                20
            };
            assert_eq!(&bytes[fixed + count * 4..], &0xababababu32.to_le_bytes());
            assert_eq!(&encoded[88 + bytes.len()..], &original[88 + record.len()..]);
            assert_eq!(serialize(&reparsed).unwrap(), encoded);
            assert!(reparsed.diagnostics().is_empty());
        }
    }
}
#[test]
fn zero_entry_inputs_and_maximum_create_count_are_editable() {
    for record in [
        record(49, &words(&[0, 0x300])),
        record(50, &words(&[0, u32::MAX, 0])),
    ] {
        let mut doc = parse(&document(&record), &ParseLimits::default()).unwrap();
        assert!(entries(doc.records()[0].data()).is_empty());
        doc.edit_record(0, doc.records()[0].data().clone()).unwrap();
        let encoded = serialize(&doc).unwrap();
        assert_eq!(&encoded[88..88 + record.len()], &record);
    }
    let mut doc = parse(&document(&fixtures()[1]), &ParseLimits::default()).unwrap();
    let mut edited = doc.records()[0].data().clone();
    let RecordData::CreatePalette { entries, .. } = &mut edited else {
        unreachable!()
    };
    entries.resize(u16::MAX as usize, entries[0]);
    doc.edit_record(0, edited.clone()).unwrap();
    let encoded = serialize(&doc).unwrap();
    let reparsed = parse(&encoded, &ParseLimits::default()).unwrap();
    assert_eq!(reparsed.records()[0].data(), &edited);
    let original = doc.clone();
    let RecordData::CreatePalette { entries, .. } = &mut edited else {
        unreachable!()
    };
    entries.push(entries[0]);
    assert_eq!(
        doc.edit_record(0, edited),
        Err(emf_core::EditFailure::SizeOverflow)
    );
    assert_eq!(doc, original);
}
#[test]
fn malformed_counts_and_fixed_prefixes_stay_raw_with_diagnostics() {
    use emf_core::DiagnosticKind;
    let mut cases = Vec::new();
    for (kind, fixed) in [(48, 4), (49, 8), (50, 12), (51, 8)] {
        for len in 0..fixed {
            cases.push(record(kind, &vec![0; len]));
        }
    }
    cases.extend([
        record(49, &words(&[7, 0xffff0300])),
        record(49, &words(&[7, 0x00020300, 0x01020304])),
        record(50, &words(&[7, 0, u32::MAX])),
        record(50, &words(&[7, 0, 2, 0x01020304])),
    ]);
    for record in cases {
        let original = document(&record);
        let doc = parse(&original, &ParseLimits::default()).unwrap();
        assert_eq!(doc.records()[0].data(), &RecordData::Raw);
        assert_eq!(doc.diagnostics().len(), 1);
        assert_eq!(doc.diagnostics()[0].record_type, Some(word(&record, 0)));
        assert_eq!(
            doc.diagnostics()[0].kind,
            DiagnosticKind::InvalidRecordPayload
        );
        assert_eq!(doc.records()[1].record_type(), 999);
        assert_eq!(
            doc.record_bytes(&doc.records()[1]).unwrap(),
            words(&[999, 12, 0xfedcba98])
        );
        assert!(doc.has_eof());
        assert_eq!(doc.trailing_bytes(), b"tail");
        assert_eq!(serialize(&doc).unwrap(), original);
    }
}

fn minimum_parse_limits(bytes: &[u8]) -> ParseLimits {
    use emf_core::{LimitKind, ParseFailure};
    let mut limits = ParseLimits {
        max_allocated_bytes: 0,
        max_work_units: 0,
        ..ParseLimits::default()
    };
    loop {
        match parse(bytes, &limits) {
            Err(ParseFailure::LimitExceeded {
                kind: LimitKind::AllocatedBytes,
                requested,
                ..
            }) => {
                limits.max_allocated_bytes = requested as usize;
            }
            Err(ParseFailure::LimitExceeded {
                kind: LimitKind::WorkUnits,
                requested,
                ..
            }) => {
                limits.max_work_units = requested;
            }
            Ok(_) => return limits,
            other => panic!("{other:?}"),
        }
    }
}
#[test]
fn entry_allocations_and_work_are_charged_and_limits_are_inclusive() {
    use emf_core::{
        serialize_with_limits, LimitKind, ParseFailure, SerializeFailure, SerializeLimits,
    };
    for (record, count_offset) in [(fixtures()[1].clone(), 14), (fixtures()[2].clone(), 16)] {
        let original = document(&record);
        let limits = minimum_parse_limits(&original);
        let mut zero_count = record.clone();
        if count_offset == 14 {
            zero_count[14..16].fill(0);
        } else {
            put(&mut zero_count, 16, 0);
        }
        let baseline = minimum_parse_limits(&document(&zero_count));
        assert_eq!(limits.max_allocated_bytes, baseline.max_allocated_bytes + 8);
        assert_eq!(limits.max_work_units, baseline.max_work_units + 2);
        assert!(parse(&original, &limits).is_ok());
        let mut below = limits.clone();
        below.max_allocated_bytes -= 1;
        assert!(matches!(
            parse(&original, &below),
            Err(ParseFailure::LimitExceeded {
                kind: LimitKind::AllocatedBytes,
                ..
            })
        ));
        below = limits.clone();
        below.max_work_units -= 1;
        assert!(matches!(
            parse(&original, &below),
            Err(ParseFailure::LimitExceeded {
                kind: LimitKind::WorkUnits,
                ..
            })
        ));
        let mut doc = parse(&original, &limits).unwrap();
        doc.edit_record(0, doc.records()[0].data().clone()).unwrap();
        let mut encoding_limits = SerializeLimits {
            max_output_bytes: original.len(),
            max_work_units: 0,
        };
        loop {
            match serialize_with_limits(&doc, &encoding_limits) {
                Err(SerializeFailure::LimitExceeded {
                    kind: LimitKind::WorkUnits,
                    requested,
                    ..
                }) => encoding_limits.max_work_units = requested,
                Ok(bytes) => {
                    assert_eq!(&bytes[88..], &original[88..]);
                    break;
                }
                other => panic!("{other:?}"),
            }
        }
        let mut empty = parse(&document(&zero_count), &ParseLimits::default()).unwrap();
        empty
            .edit_record(0, empty.records()[0].data().clone())
            .unwrap();
        let mut baseline_encoding = encoding_limits.clone();
        baseline_encoding.max_work_units -= 2;
        assert!(serialize_with_limits(&empty, &baseline_encoding).is_ok());
        baseline_encoding.max_work_units -= 1;
        assert!(matches!(
            serialize_with_limits(&empty, &baseline_encoding),
            Err(SerializeFailure::LimitExceeded {
                kind: LimitKind::WorkUnits,
                ..
            })
        ));
        encoding_limits.max_work_units -= 1;
        assert!(matches!(
            serialize_with_limits(&doc, &encoding_limits),
            Err(SerializeFailure::LimitExceeded {
                kind: LimitKind::WorkUnits,
                ..
            })
        ));
        encoding_limits.max_work_units += 1;
        encoding_limits.max_output_bytes -= 1;
        assert!(matches!(
            serialize_with_limits(&doc, &encoding_limits),
            Err(SerializeFailure::LimitExceeded {
                kind: LimitKind::OutputBytes,
                ..
            })
        ));
    }
}
