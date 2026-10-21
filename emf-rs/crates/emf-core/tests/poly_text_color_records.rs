use emf_core::{
    parse, serialize, serialize_with_limits, EditFailure, ParseLimits, RecordData, SerializeLimits,
};
fn put(b: &mut [u8], offset: usize, value: u32) {
    b[offset..offset + 4].copy_from_slice(&value.to_le_bytes());
}
fn word(b: &[u8], offset: usize) -> u32 {
    u32::from_le_bytes(b[offset..offset + 4].try_into().unwrap())
}
fn document(record: &[u8]) -> Vec<u8> {
    let mut b = vec![0; 108];
    put(&mut b, 0, 1);
    put(&mut b, 4, 108);
    put(&mut b, 40, 0x464d4520);
    b.extend_from_slice(record);
    b.extend_from_slice(&[231, 3, 0, 0, 12, 0, 0, 0, 1, 2, 3, 4]);
    b.extend_from_slice(&[
        14, 0, 0, 0, 20, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 20, 0, 0, 0,
    ]);
    b.extend_from_slice(b"tail");
    b
}
fn fixture(wide: bool, count: usize, reverse: bool) -> Vec<u8> {
    let mut b = vec![0; 40];
    put(&mut b, 0, if wide { 97 } else { 96 });
    put(&mut b, 8, i32::MIN as u32);
    put(&mut b, 24, 2);
    put(&mut b, 28, 0x7fc01234);
    put(&mut b, 32, 0x80000000);
    put(&mut b, 36, count as u32);
    let mut descriptors = Vec::new();
    for index in 0..count {
        let d = b.len();
        descriptors.push(d);
        let no_rect = index % 2 == 1;
        b.resize(d + if no_rect { 24 } else { 40 }, 0);
        put(&mut b, d, (-19i32) as u32);
        put(&mut b, d + 8, 2);
        put(&mut b, d + 16, 0x2000 | if no_rect { 0x100 } else { 0 });
    }
    for (index, &d) in descriptors.iter().enumerate() {
        let dxfield = d + if index % 2 == 1 { 20 } else { 36 };
        for is_dx in [reverse, !reverse] {
            b.extend_from_slice(b"GAP!");
            let width = if is_dx {
                4
            } else if wide {
                2
            } else {
                1
            };
            while b.len() % width != 0 {
                b.push(0xa5);
            }
            let offset = b.len() as u32;
            put(&mut b, if is_dx { dxfield } else { d + 12 }, offset);
            if is_dx {
                for v in [u32::MAX, 0x80000000, 17, 29] {
                    b.extend_from_slice(&v.to_le_bytes());
                }
            } else if wide {
                b.extend_from_slice(&[0, 0xd8, 0xff, 0xff]);
            } else {
                b.extend_from_slice(&[0x80, 0xff]);
            }
        }
    }
    b.extend_from_slice(b"SUFFIX!!");
    while b.len() % 4 != 0 {
        b.push(0x5a);
    }
    let size = b.len() as u32;
    put(&mut b, 4, size);
    b
}
#[test]
fn poly_text_owns_many_mixed_descriptors_units_and_signed_bits() {
    for wide in [false, true] {
        for count in [0, 1, 2, 128] {
            for reverse in [false, true] {
                let input = document(&fixture(wide, count, reverse));
                let mut doc = parse(&input, &ParseLimits::default()).unwrap();
                assert!(doc.diagnostics().is_empty());
                assert_eq!(serialize(&doc).unwrap(), input);
                let data = doc.records()[0].data().clone();
                macro_rules! check {
                    ($t:expr,$units:expr) => {{
                        let t = $t;
                        assert_eq!(t.entries.len(), count);
                        assert_eq!(t.bounds.left, i32::MIN);
                        assert_eq!(t.ex_scale.to_bits(), 0x7fc01234);
                        assert_eq!(t.ey_scale.to_bits(), 0x80000000);
                        for (i, e) in t.entries.iter().enumerate() {
                            assert_eq!(e.reference.x, -19);
                            assert_eq!(e.text, $units);
                            assert_eq!(e.dx.as_deref(), Some(&[u32::MAX, 0x80000000, 17, 29][..]));
                            assert_eq!(e.rectangle.is_none(), i % 2 == 1);
                            assert_eq!(e.dx_first, reverse);
                        }
                    }};
                }
                match &data {
                    RecordData::PolyTextOutA(t) => check!(t, vec![0x80, 0xff]),
                    RecordData::PolyTextOutW(t) => check!(t, vec![0xd800, 0xffff]),
                    x => panic!("{x:?}"),
                }
                doc.edit_record(0, data).unwrap();
                assert_eq!(&serialize(&doc).unwrap()[108..], &input[108..]);
            }
        }
    }
}
#[test]
fn edits_rebuild_entry_counts_offsets_and_spacing_preserving_suffix_and_siblings() {
    for wide in [false, true] {
        for reverse in [false, true] {
            for count in [0, 1, 5] {
                let input = document(&fixture(wide, 2, reverse));
                let mut doc = parse(&input, &ParseLimits::default()).unwrap();
                let mut data = doc.records()[0].data().clone();
                macro_rules! edit {
                    ($t:expr,$unit:expr) => {{
                        let t = $t;
                        t.entries[0].text.resize(count, $unit);
                        t.entries[0].dx.as_mut().unwrap().resize(count * 2, 123);
                        let added = t.entries[1].clone();
                        t.entries.push(added);
                    }};
                }
                match &mut data {
                    RecordData::PolyTextOutA(t) => edit!(t, 0xfe),
                    RecordData::PolyTextOutW(t) => edit!(t, 0xdcff),
                    _ => panic!(),
                }
                doc.edit_record(0, data).unwrap();
                let output = serialize(&doc).unwrap();
                let r = &output[108..];
                assert_eq!(word(r, 36), 3);
                assert_eq!(word(r, 48), count as u32);
                assert!(r.windows(8).any(|w| w == b"SUFFIX!!"));
                let size = word(r, 4) as usize;
                let old = word(&input[108..], 4) as usize;
                assert_eq!(&output[108 + size..], &input[108 + old..]);
                let reparsed = parse(&output, &ParseLimits::default()).unwrap();
                assert!(reparsed.diagnostics().is_empty());
                match reparsed.records()[0].data() {
                    RecordData::PolyTextOutA(t) => {
                        assert_eq!(t.entries.len(), 3);
                        assert_eq!(t.entries[0].text.len(), count);
                        assert_eq!(t.entries[0].dx.as_ref().unwrap().len(), count * 2);
                    }
                    RecordData::PolyTextOutW(t) => {
                        assert_eq!(t.entries.len(), 3);
                        assert_eq!(t.entries[0].text.len(), count);
                        assert_eq!(t.entries[0].dx.as_ref().unwrap().len(), count * 2);
                    }
                    _ => panic!("edited record became raw"),
                }
                assert_eq!(serialize(&reparsed).unwrap(), output);
            }
        }
    }
}
#[test]
fn malformed_tables_counts_and_buffer_spans_recover_raw_with_diagnostics() {
    for wide in [false, true] {
        let valid = fixture(wide, 2, false);
        let mut cases = Vec::new();
        for (offset, value) in [
            (36, u32::MAX),
            (48, u32::MAX),
            (52, 0),
            (52, 40),
            (52, u32::MAX),
            (76, 52),
            (76, u32::MAX),
            (76, word(&valid, 52)),
        ] {
            let mut b = valid.clone();
            put(&mut b, offset, value);
            cases.push(b);
        }
        if wide {
            let mut b = valid.clone();
            put(&mut b, 52, 105);
            cases.push(b);
        }
        for length in [8, 39, 40, 63, 79, valid.len() - 24] {
            let mut b = valid[..length].to_vec();
            put(&mut b, 4, length as u32);
            cases.push(b);
        }
        for r in cases {
            let input = document(&r);
            let doc = parse(&input, &ParseLimits::default()).unwrap();
            assert_eq!(doc.records()[0].data(), &RecordData::Raw, "{r:?}");
            // PolyTextOut stays opaque without a diagnostic, like Ruby's tolerant native.
            assert!(doc.diagnostics().is_empty());
            assert_eq!(serialize(&doc).unwrap(), input);
        }
    }
}
#[test]
fn inconsistent_edits_are_atomic_and_bounded() {
    let input = document(&fixture(false, 2, false));
    let mut doc = parse(&input, &ParseLimits::default()).unwrap();
    let RecordData::PolyTextOutA(original) = doc.records()[0].data().clone() else {
        panic!()
    };
    for case in 0..3 {
        let mut t = original.clone();
        match case {
            0 => {
                t.entries[0].dx.as_mut().unwrap().pop();
            }
            1 => t.entries[0].rectangle = None,
            _ => t.entries[0].options &= !0x2000,
        };
        assert!(matches!(
            doc.edit_record(0, RecordData::PolyTextOutA(t)),
            Err(EditFailure::RecordLayout { .. })
        ));
        assert_eq!(serialize(&doc).unwrap(), input);
    }
    doc.edit_record(0, RecordData::PolyTextOutA(original))
        .unwrap();
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
            max_work_units: 1,
            ..ParseLimits::default()
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
}
#[test]
fn color_adjustment_owns_signed_and_unsigned_words_and_preserves_suffix() {
    let values = [
        0x8001u16,
        0xffff,
        0x8000,
        0xffff,
        0x8000,
        0xffff,
        0x8001,
        0xffff,
        0x8000,
        (-1234i16) as u16,
        0,
        0x7fff,
    ];
    let mut r = vec![0; 8];
    put(&mut r, 0, 23);
    for v in values {
        r.extend_from_slice(&v.to_le_bytes());
    }
    r.extend_from_slice(b"opaque");
    let size = r.len() as u32;
    put(&mut r, 4, size);
    let input = document(&r);
    let mut doc = parse(&input, &ParseLimits::default()).unwrap();
    assert!(doc.diagnostics().is_empty());
    assert_eq!(serialize(&doc).unwrap(), input);
    let RecordData::SetColorAdjustment(mut c) = doc.records()[0].data().clone() else {
        panic!()
    };
    assert_eq!(c.adjustment_size, 0x8001);
    assert_eq!(c.values, 0xffff);
    assert_eq!(c.contrast, i16::MIN);
    assert_eq!(c.brightness, -1234);
    assert_eq!(c.red_green_tint, i16::MAX);
    c.contrast = i16::MAX;
    c.red_green_tint = i16::MIN;
    doc.edit_record(0, RecordData::SetColorAdjustment(c))
        .unwrap();
    let output = serialize(&doc).unwrap();
    let mut expected = input.clone();
    // Edited documents rebuild header totals, including the header and EOF records.
    put(&mut expected, 48, input.len() as u32);
    put(&mut expected, 52, 4);
    expected[132..134].copy_from_slice(&i16::MAX.to_le_bytes());
    expected[138..140].copy_from_slice(&i16::MIN.to_le_bytes());
    assert_eq!(output, expected);
    for length in [8, 9, 31] {
        let mut short = r[..length].to_vec();
        put(&mut short, 4, length as u32);
        let input = document(&short);
        let doc = parse(&input, &ParseLimits::default()).unwrap();
        assert_eq!(doc.records()[0].data(), &RecordData::Raw);
        assert!(doc.diagnostics().is_empty());
        assert_eq!(serialize(&doc).unwrap(), input);
    }
}
