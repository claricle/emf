use emf_core::{parse, serialize, ParseLimits, RecordData};
fn put(b: &mut [u8], p: usize, v: u32) {
    b[p..p + 4].copy_from_slice(&v.to_le_bytes());
}
fn document(font_size: usize) -> Vec<u8> {
    let mut b = vec![0; 88];
    put(&mut b, 0, 1);
    put(&mut b, 4, 88);
    put(&mut b, 40, 0x464d4520);
    let mut r = vec![0; 12 + font_size];
    put(&mut r, 0, 82);
    let len = r.len() as u32;
    put(&mut r, 4, len);
    put(&mut r, 8, 0x87654321);
    if font_size >= 356 {
        put(&mut r, 360, 0x08007664);
        put(&mut r, 364, ((font_size - 356) / 4) as u32);
    }
    b.extend(r);
    for v in [999u32, 12, 0xfedcba98, 14, 20, 0, 16, 20] {
        b.extend(v.to_le_bytes());
    }
    b.extend(b"tail");
    b
}
#[test]
fn supported_fonts_decode_and_preserve_original_bytes() {
    for size in [92, 320, 356, 360, 420] {
        let bytes = document(size);
        let doc = parse(&bytes, &ParseLimits::default()).unwrap();
        assert_ne!(
            doc.records()[0].data(),
            &RecordData::Raw,
            "font bytes {size}"
        );
        assert_eq!(serialize(&doc).unwrap(), bytes);
    }
}

fn font(doc: &emf_core::Document) -> &emf_core::FontRecord {
    let RecordData::CreateFontIndirectW(font) = doc.records()[0].data() else {
        panic!("expected font")
    };
    font
}
fn base(font: &emf_core::Font) -> &emf_core::LogFont {
    match font {
        emf_core::Font::LogFont(f) => f,
        emf_core::Font::Panose(f) => &f.log_font,
        emf_core::Font::ExDv(f) => &f.log_font_ex.log_font,
    }
}
fn base_mut(font: &mut emf_core::Font) -> &mut emf_core::LogFont {
    match font {
        emf_core::Font::LogFont(f) => f,
        emf_core::Font::Panose(f) => &mut f.log_font,
        emf_core::Font::ExDv(f) => &mut f.log_font_ex.log_font,
    }
}
#[test]
fn fields_preserve_signed_values_flags_and_every_utf16_unit_through_edit() {
    for size in [92, 96, 316, 320, 356, 420] {
        let mut bytes = document(size);
        for (i, v) in [i32::MIN, -1, -3600, i32::MAX, -900].iter().enumerate() {
            put(&mut bytes, 100 + i * 4, *v as u32);
        }
        bytes[120..128].copy_from_slice(&[255, 254, 253, 252, 251, 250, 249, 248]);
        for (i, v) in [0xd800u16, 0, 0xdc00, 0xffff].iter().enumerate() {
            bytes[128 + i * 2..130 + i * 2].copy_from_slice(&v.to_le_bytes());
        }
        if size == 320 {
            bytes[396..420].fill(0xa5);
        }
        let mut doc = parse(&bytes, &ParseLimits::default()).unwrap();
        let f = base(&font(&doc).font);
        assert_eq!(
            [f.height, f.width, f.escapement, f.orientation, f.weight],
            [i32::MIN, -1, -3600, i32::MAX, -900]
        );
        assert_eq!(
            [
                f.italic,
                f.underline,
                f.strike_out,
                f.char_set,
                f.out_precision,
                f.clip_precision,
                f.quality,
                f.pitch_and_family
            ],
            [255, 254, 253, 252, 251, 250, 249, 248]
        );
        assert_eq!(&f.face_name[..4], &[0xd800, 0, 0xdc00, 0xffff]);
        let mut edit = font(&doc).clone();
        edit.ih_object = 7;
        base_mut(&mut edit.font).height = 42;
        doc.edit_record(0, RecordData::CreateFontIndirectW(Box::new(edit.clone())))
            .unwrap();
        let out = serialize(&doc).unwrap();
        assert_eq!(&out[104..], &bytes[104..]);
        assert_eq!(&out[88..96], &bytes[88..96]);
        assert_eq!(
            u32::from_le_bytes(out[48..52].try_into().unwrap()) as usize,
            out.len()
        );
        assert_eq!(u32::from_le_bytes(out[52..56].try_into().unwrap()), 4);
        assert_eq!(font(&parse(&out, &ParseLimits::default()).unwrap()), &edit);
    }
}
#[test]
fn partial_panose_zero_fills_without_losing_its_length() {
    for size in [93, 94, 95, 96, 220, 284, 308, 318, 319] {
        let bytes = document(size);
        let mut doc = parse(&bytes, &ParseLimits::default()).unwrap();
        let mut edit = font(&doc).clone();
        let emf_core::Font::Panose(p) = &mut edit.font else {
            panic!("expected partial Panose")
        };
        assert_eq!(p.encoded_size, size);
        assert_eq!(p.padding, [0; 2]);
        p.log_font.height = -25;
        doc.edit_record(0, RecordData::CreateFontIndirectW(Box::new(edit)))
            .unwrap();
        let out = serialize(&doc).unwrap();
        assert_eq!(out.len(), bytes.len());
        assert_eq!(&out[104..], &bytes[104..]);
        let before = doc.clone();
        let mut bad = font(&doc).clone();
        let emf_core::Font::Panose(p) = &mut bad.font else {
            unreachable!()
        };
        p.padding[1] = 1;
        assert_eq!(
            doc.edit_record(0, RecordData::CreateFontIndirectW(Box::new(bad))),
            Err(emf_core::EditFailure::RecordLayout { index: 0 })
        );
        assert_eq!(doc, before);
    }
}
#[test]
fn malformed_fonts_remain_raw_and_do_not_stop_siblings_or_eof() {
    let mut cases = Vec::new();
    for size in [0, 4, 88, 91, 321, 324, 348, 352, 355] {
        cases.push(document(size));
    }
    for (size, count, signature) in [
        (356, 1, 0x08007664),
        (420, 17, 0x08007664),
        (356, u32::MAX, 0x08007664),
        (356, 0, 1),
    ] {
        let mut bytes = document(size);
        put(&mut bytes, 452, count);
        put(&mut bytes, 448, signature);
        cases.push(bytes);
    }
    for bytes in cases {
        let doc = parse(&bytes, &ParseLimits::default()).unwrap();
        assert_eq!(doc.records()[0].data(), &RecordData::Raw);
        assert_eq!(doc.diagnostics().len(), 1);
        assert_eq!(
            doc.diagnostics()[0].kind,
            emf_core::DiagnosticKind::InvalidRecordPayload
        );
        assert_eq!(doc.records()[1].record_type(), 999);
        assert!(doc.records()[2].is_eof());
        assert_eq!(serialize(&doc).unwrap(), bytes);
    }
}
#[test]
fn exdv_axis_resize_preserves_suffix_and_rejects_invalid_edits_atomically() {
    let mut bytes = document(364);
    put(&mut bytes, 452, 0);
    bytes[456..464].copy_from_slice(b"SUFFIX!!");
    let mut doc = parse(&bytes, &ParseLimits::default()).unwrap();
    let mut edit = font(&doc).clone();
    let emf_core::Font::ExDv(f) = &mut edit.font else {
        panic!("ExDv")
    };
    f.design_vector.values = vec![i32::MIN, -1, i32::MAX];
    doc.edit_record(0, RecordData::CreateFontIndirectW(Box::new(edit.clone())))
        .unwrap();
    let out = serialize(&doc).unwrap();
    assert_eq!(out.len(), bytes.len() + 12);
    assert_eq!(&out[468..], &bytes[456..]);
    assert_eq!(font(&parse(&out, &ParseLimits::default()).unwrap()), &edit);
    for invalid in [false, true] {
        let mut bad = edit.clone();
        let emf_core::Font::ExDv(f) = &mut bad.font else {
            unreachable!()
        };
        if invalid {
            f.design_vector.signature = 0;
        } else {
            f.design_vector.values = vec![0; 17];
        }
        let before = doc.clone();
        assert_eq!(
            doc.edit_record(0, RecordData::CreateFontIndirectW(Box::new(bad))),
            Err(emf_core::EditFailure::RecordLayout { index: 0 })
        );
        assert_eq!(doc, before);
    }
    let before = doc.clone();
    assert_eq!(
        doc.edit_record(1, RecordData::CreateFontIndirectW(Box::new(edit.clone()))),
        Err(emf_core::EditFailure::RecordFamily { index: 1 })
    );
    assert_eq!(doc, before);
    assert_eq!(
        doc.edit_record(0, RecordData::SetMapperFlags { flags: 0 }),
        Err(emf_core::EditFailure::RecordFamily { index: 0 })
    );
    assert_eq!(doc, before);
}

#[test]
fn extended_font_fields_are_semantic_and_lossless() {
    for size in [320, 356] {
        let mut bytes = document(size);
        for (offset, units) in [(192, 64), (320, 32)] {
            for i in 0..units {
                bytes[offset + i * 2..offset + i * 2 + 2]
                    .copy_from_slice(&(0xd800u16 + i as u16).to_le_bytes());
            }
        }
        if size == 320 {
            for (i, byte) in bytes.iter_mut().enumerate().take(420).skip(384) {
                *byte = i as u8;
            }
        } else {
            bytes[384..386].copy_from_slice(&0xdc00u16.to_le_bytes());
        }
        let mut doc = parse(&bytes, &ParseLimits::default()).unwrap();
        let mut edit = font(&doc).clone();
        match &mut edit.font {
            emf_core::Font::Panose(p) => {
                assert_eq!(p.full_name[63], 0xd83f);
                assert_eq!(p.style[31], 0xd81f);
                assert_eq!(
                    p.version,
                    u32::from_le_bytes(bytes[384..388].try_into().unwrap())
                );
                assert_eq!(
                    p.style_size,
                    u32::from_le_bytes(bytes[388..392].try_into().unwrap())
                );
                assert_eq!(
                    p.match_value,
                    u32::from_le_bytes(bytes[392..396].try_into().unwrap())
                );
                assert_eq!(
                    p.reserved,
                    u32::from_le_bytes(bytes[396..400].try_into().unwrap())
                );
                assert_eq!(&p.vendor_id, &bytes[400..404]);
                assert_eq!(
                    p.culture,
                    u32::from_le_bytes(bytes[404..408].try_into().unwrap())
                );
                assert_eq!(&p.panose, &bytes[408..418]);
                assert_eq!(&p.padding, &bytes[418..420]);
                p.full_name[5] = 0;
            }
            emf_core::Font::ExDv(f) => {
                assert_eq!(f.log_font_ex.full_name[63], 0xd83f);
                assert_eq!(f.log_font_ex.style[31], 0xd81f);
                assert_eq!(f.log_font_ex.script[0], 0xdc00);
                f.log_font_ex.full_name[5] = 0;
            }
            _ => unreachable!(),
        }
        doc.edit_record(0, RecordData::CreateFontIndirectW(Box::new(edit.clone())))
            .unwrap();
        let out = serialize(&doc).unwrap();
        assert_eq!(&out[204..], &bytes[204..]);
        assert_eq!(font(&parse(&out, &ParseLimits::default()).unwrap()), &edit);
    }
}

#[test]
fn font_axis_resource_limits_are_inclusive() {
    use emf_core::{
        serialize_with_limits, LimitKind, ParseFailure, SerializeFailure, SerializeLimits,
    };
    let bytes = document(420);
    let mut limits = ParseLimits {
        max_allocated_bytes: 0,
        ..ParseLimits::default()
    };
    loop {
        match parse(&bytes, &limits) {
            Err(ParseFailure::LimitExceeded {
                kind: LimitKind::AllocatedBytes,
                requested,
                ..
            }) => limits.max_allocated_bytes = requested as usize,
            Ok(_) => break,
            result => panic!("{result:?}"),
        }
    }
    limits.max_allocated_bytes -= 1;
    assert!(matches!(
        parse(&bytes, &limits),
        Err(ParseFailure::LimitExceeded {
            kind: LimitKind::AllocatedBytes,
            ..
        })
    ));
    limits.max_allocated_bytes += 1;
    limits.max_work_units = 0;
    loop {
        match parse(&bytes, &limits) {
            Err(ParseFailure::LimitExceeded {
                kind: LimitKind::WorkUnits,
                requested,
                ..
            }) => limits.max_work_units = requested,
            Ok(_) => break,
            result => panic!("{result:?}"),
        }
    }
    limits.max_work_units -= 1;
    assert!(matches!(
        parse(&bytes, &limits),
        Err(ParseFailure::LimitExceeded {
            kind: LimitKind::WorkUnits,
            ..
        })
    ));
    limits.max_work_units += 1;
    let mut doc = parse(&bytes, &limits).unwrap();
    doc.edit_record(0, doc.records()[0].data().clone()).unwrap();
    let mut limits = SerializeLimits {
        max_output_bytes: bytes.len(),
        max_work_units: 0,
    };
    loop {
        match serialize_with_limits(&doc, &limits) {
            Err(SerializeFailure::LimitExceeded {
                kind: LimitKind::WorkUnits,
                requested,
                ..
            }) => limits.max_work_units = requested,
            Ok(_) => break,
            result => panic!("{result:?}"),
        }
    }
    limits.max_work_units -= 1;
    assert!(matches!(
        serialize_with_limits(&doc, &limits),
        Err(SerializeFailure::LimitExceeded {
            kind: LimitKind::WorkUnits,
            ..
        })
    ));
    limits.max_work_units += 1;
    limits.max_output_bytes -= 1;
    assert!(matches!(
        serialize_with_limits(&doc, &limits),
        Err(SerializeFailure::LimitExceeded {
            kind: LimitKind::OutputBytes,
            ..
        })
    ));
}
