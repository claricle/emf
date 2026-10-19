use emf_core::{
    parse, serialize, serialize_with_limits, EditFailure, ParseLimits, RecordData, SerializeLimits,
};

fn put(bytes: &mut [u8], offset: usize, value: u32) {
    bytes[offset..offset + 4].copy_from_slice(&value.to_le_bytes());
}
fn word(bytes: &[u8], offset: usize) -> u32 {
    u32::from_le_bytes(bytes[offset..offset + 4].try_into().unwrap())
}
fn document(record: &[u8]) -> Vec<u8> {
    let mut bytes = vec![0; 108];
    put(&mut bytes, 0, 1);
    put(&mut bytes, 4, 108);
    put(&mut bytes, 40, 0x464d4520);
    bytes.extend_from_slice(record);
    // An opaque sibling and bytes after EOF exercise surrounding preservation.
    bytes.extend_from_slice(&[231, 3, 0, 0, 12, 0, 0, 0, 1, 2, 3, 4]);
    bytes.extend_from_slice(&[
        14, 0, 0, 0, 20, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 20, 0, 0, 0,
    ]);
    bytes.extend_from_slice(b"tail");
    bytes
}
fn fixture(wide: bool, no_rect: bool, pdy: bool, dx_first: bool, with_dx: bool) -> Vec<u8> {
    let fixed = if no_rect { 60 } else { 76 };
    let text: &[u8] = if wide {
        &[0x00, 0xd8, 0xff, 0xff]
    } else {
        &[0x80, 0xff]
    };
    let dx: Vec<u8> = [0xffff_ffffu32, 0x8000_0000, 17, 29][..if pdy { 4 } else { 2 }]
        .iter()
        .flat_map(|v| v.to_le_bytes())
        .collect();
    let mut bytes = vec![0; fixed];
    put(&mut bytes, 0, if wide { 84 } else { 83 });
    put(&mut bytes, 8, i32::MIN as u32);
    put(&mut bytes, 24, 2);
    put(&mut bytes, 28, 0x7fc0_1234);
    put(&mut bytes, 32, 0x8000_0000);
    put(&mut bytes, 36, (-19i32) as u32);
    put(&mut bytes, 44, 2);
    put(
        &mut bytes,
        52,
        (if no_rect { 0x100 } else { 0 }) | (if pdy { 0x2000 } else { 0 }) | 0x10,
    );
    bytes.extend_from_slice(b"GAP!");
    if dx_first && with_dx {
        let offset = bytes.len() as u32;
        put(&mut bytes, fixed - 4, offset);
        bytes.extend_from_slice(&dx);
        bytes.extend_from_slice(b"gap!");
    }
    let offset = bytes.len() as u32;
    put(&mut bytes, 48, offset);
    bytes.extend_from_slice(text);
    if !dx_first && with_dx {
        while bytes.len() % 4 != 0 {
            bytes.push(0xa5);
        }
        bytes.extend_from_slice(b"gap!");
        let offset = bytes.len() as u32;
        put(&mut bytes, fixed - 4, offset);
        bytes.extend_from_slice(&dx);
    }
    bytes.extend_from_slice(b"SUFFIX!!");
    while bytes.len() % 4 != 0 {
        bytes.push(0x5a);
    }
    let size = bytes.len() as u32;
    put(&mut bytes, 4, size);
    bytes
}

#[test]
fn extended_text_records_are_semantic() {
    for wide in [false, true] {
        let input = document(&fixture(wide, false, false, false, true));
        let doc = parse(&input, &ParseLimits::default()).unwrap();
        assert_ne!(doc.records()[0].data(), &RecordData::Raw);
        assert!(doc.diagnostics().is_empty());
        assert_eq!(serialize(&doc).unwrap(), input);
    }
}

#[test]
fn preserves_code_units_float_bits_flags_buffers_and_suffixes() {
    for wide in [false, true] {
        for no_rect in [false, true] {
            for pdy in [false, true] {
                for dx_first in [false, true] {
                    for with_dx in [false, true] {
                        let record = fixture(wide, no_rect, pdy, dx_first, with_dx);
                        let input = document(&record);
                        let mut doc = parse(&input, &ParseLimits::default()).unwrap();
                        let data = doc.records()[0].data().clone();
                        macro_rules! check {
                            ($text:expr, $units:expr) => {{
                                let t = $text;
                                assert_eq!(t.text, $units);
                                assert_eq!(t.ex_scale.to_bits(), 0x7fc0_1234);
                                assert_eq!(t.ey_scale.to_bits(), 0x8000_0000);
                                assert_eq!(t.rectangle.is_none(), no_rect);
                                assert_eq!(
                                    t.dx.as_ref().map(Vec::len),
                                    with_dx.then_some(if pdy { 4 } else { 2 })
                                );
                                assert_eq!(t.dx_first, dx_first && with_dx);
                            }};
                        }
                        match &data {
                            RecordData::ExtTextOutA(t) => check!(t, vec![0x80, 0xff]),
                            RecordData::ExtTextOutW(t) => check!(t, vec![0xd800, 0xffff]),
                            other => panic!("{other:?}"),
                        }
                        doc.edit_record(0, data).unwrap();
                        let output = serialize(&doc).unwrap();
                        assert_eq!(&output[108..], &input[108..]);
                    }
                }
            }
        }
    }
}

#[test]
fn resized_text_updates_counts_offsets_sizes_and_retains_opaque_bytes() {
    for wide in [false, true] {
        for dx_first in [false, true] {
            for count in [0, 1, 5] {
                let input = document(&fixture(wide, false, true, dx_first, true));
                let mut doc = parse(&input, &ParseLimits::default()).unwrap();
                let mut data = doc.records()[0].data().clone();
                match &mut data {
                    RecordData::ExtTextOutA(t) => {
                        t.text.resize(count, 0x81);
                        t.dx.as_mut().unwrap().resize(count * 2, 123);
                    }
                    RecordData::ExtTextOutW(t) => {
                        t.text.resize(count, 0xdcff);
                        t.dx.as_mut().unwrap().resize(count * 2, 123);
                    }
                    _ => unreachable!(),
                }
                doc.edit_record(0, data.clone()).unwrap();
                let output = serialize(&doc).unwrap();
                let r = &output[108..];
                assert_eq!(word(r, 44), count as u32);
                assert_eq!(word(r, 4) % 4, 0);
                assert_eq!(word(r, 72) % 4, 0);
                assert!(r.windows(8).any(|w| w == b"SUFFIX!!"));
                let old_size = word(&input[108..], 4) as usize;
                let size = word(r, 4) as usize;
                assert_eq!(&output[108 + size..], &input[108 + old_size..]);
                let reparsed = parse(&output, &ParseLimits::default()).unwrap();
                match (reparsed.records()[0].data(), &data) {
                    (RecordData::ExtTextOutA(a), RecordData::ExtTextOutA(b)) => {
                        assert_eq!(a.text, b.text);
                        assert_eq!(a.dx, b.dx);
                    }
                    (RecordData::ExtTextOutW(a), RecordData::ExtTextOutW(b)) => {
                        assert_eq!(a.text, b.text);
                        assert_eq!(a.dx, b.dx);
                    }
                    _ => panic!("resized record became raw"),
                }
                assert_eq!(serialize(&reparsed).unwrap(), output);
            }
        }
    }
}

#[test]
fn malformed_spans_counts_and_truncations_remain_raw_and_exact() {
    for wide in [false, true] {
        let valid = fixture(wide, false, true, false, true);
        let mut cases = Vec::new();
        for (field, value) in [
            (44, u32::MAX),
            (48, 0),
            (48, 12),
            (48, u32::MAX),
            (72, 12),
            (72, 79),
            (72, u32::MAX),
            (72, word(&valid, 48)),
        ] {
            let mut r = valid.clone();
            put(&mut r, field, value);
            cases.push(r);
        }
        if wide {
            let mut r = valid.clone();
            put(&mut r, 48, 81);
            cases.push(r);
        }
        for len in [8, 59, 60, 75, valid.len() - 9] {
            let mut r = valid[..len].to_vec();
            put(&mut r, 4, len as u32);
            cases.push(r);
        }
        for r in cases {
            let input = document(&r);
            let doc = parse(&input, &ParseLimits::default()).unwrap();
            assert_eq!(doc.records()[0].data(), &RecordData::Raw, "{r:?}");
            assert!(!doc.diagnostics().is_empty());
            assert_eq!(serialize(&doc).unwrap(), input);
        }
    }
}

#[test]
fn inconsistent_edits_are_rejected_atomically() {
    let input = document(&fixture(false, false, true, false, true));
    let mut doc = parse(&input, &ParseLimits::default()).unwrap();
    let RecordData::ExtTextOutA(original) = doc.records()[0].data().clone() else {
        panic!()
    };
    for case in 0..3 {
        let mut t = original.clone();
        match case {
            0 => t.dx.as_mut().unwrap().pop(),
            1 => {
                t.rectangle = None;
                None
            }
            _ => {
                t.options &= !0x2000;
                None
            }
        };
        assert!(matches!(
            doc.edit_record(0, RecordData::ExtTextOutA(t)),
            Err(EditFailure::RecordLayout { .. })
        ));
        assert_eq!(serialize(&doc).unwrap(), input);
    }
}

#[test]
fn empty_absent_buffers_and_optional_spacing_are_editable() {
    for wide in [false, true] {
        let mut r = fixture(wide, true, false, false, false);
        put(&mut r, 44, 0);
        put(&mut r, 48, 0);
        let input = document(&r);
        let mut doc = parse(&input, &ParseLimits::default()).unwrap();
        let mut data = doc.records()[0].data().clone();
        match &mut data {
            RecordData::ExtTextOutA(t) => {
                assert!(!t.string_present);
                t.text.push(0xfe);
            }
            RecordData::ExtTextOutW(t) => {
                assert!(!t.string_present);
                t.text.push(0xdfff);
            }
            _ => panic!(),
        }
        doc.edit_record(0, data).unwrap();
        let output = serialize(&doc).unwrap();
        assert_eq!(word(&output[108..], 44), 1);
        assert_eq!(word(&output[108..], 48), 60);
        assert_ne!(
            parse(&output, &ParseLimits::default()).unwrap().records()[0].data(),
            &RecordData::Raw
        );
    }
}

#[test]
fn edited_text_obeys_serialization_limits() {
    let input = document(&fixture(true, false, true, false, true));
    let mut doc = parse(&input, &ParseLimits::default()).unwrap();
    doc.edit_record(0, doc.records()[0].data().clone()).unwrap();
    let output = serialize(&doc).unwrap();
    assert!(serialize_with_limits(
        &doc,
        &SerializeLimits {
            max_output_bytes: output.len() - 1,
            ..SerializeLimits::default()
        }
    )
    .is_err());
    assert!(serialize_with_limits(
        &doc,
        &SerializeLimits {
            max_work_units: 1,
            ..SerializeLimits::default()
        }
    )
    .is_err());
    assert!(parse(
        &input,
        &ParseLimits {
            max_allocated_bytes: input.len(),
            ..ParseLimits::default()
        }
    )
    .is_err());
    assert!(parse(
        &input,
        &ParseLimits {
            max_work_units: 1,
            ..ParseLimits::default()
        }
    )
    .is_err());
}

#[test]
fn text_and_gap_allocations_and_work_have_inclusive_budget_boundaries() {
    use emf_core::{LimitKind, ParseFailure, RecordSpan, SerializeFailure};
    let record = fixture(true, false, true, false, true);
    let mut input = document(&record);
    input.truncate(108 + record.len());
    // Two UTF-16 units, four Dx values, and two four-byte gaps.
    let allocation = input.len() + std::mem::size_of::<RecordSpan>() + 4 + 16 + 8;
    let work =
        8 + (input.len() as u64).div_ceil(16) + 1 + (record.len() as u64).div_ceil(16) + 2 + 4 + 2;
    let limits = ParseLimits {
        max_allocated_bytes: allocation,
        max_work_units: work,
        ..ParseLimits::default()
    };
    let mut doc = parse(&input, &limits).unwrap();
    assert!(matches!(
        parse(
            &input,
            &ParseLimits {
                max_allocated_bytes: allocation - 1,
                ..limits.clone()
            }
        ),
        Err(ParseFailure::LimitExceeded {
            kind: LimitKind::AllocatedBytes,
            ..
        })
    ));
    assert!(matches!(
        parse(
            &input,
            &ParseLimits {
                max_work_units: work - 1,
                ..limits
            }
        ),
        Err(ParseFailure::LimitExceeded {
            kind: LimitKind::WorkUnits,
            ..
        })
    ));
    doc.edit_record(0, doc.records()[0].data().clone()).unwrap();
    let output = serialize(&doc).unwrap();
    let work = 4 + (output.len() as u64).div_ceil(16) + 2 + 4 + 2;
    let limits = SerializeLimits {
        max_output_bytes: output.len(),
        max_work_units: work,
    };
    assert_eq!(serialize_with_limits(&doc, &limits).unwrap(), output);
    assert!(matches!(
        serialize_with_limits(
            &doc,
            &SerializeLimits {
                max_work_units: work - 1,
                ..limits
            }
        ),
        Err(SerializeFailure::LimitExceeded {
            kind: LimitKind::WorkUnits,
            ..
        })
    ));
}
