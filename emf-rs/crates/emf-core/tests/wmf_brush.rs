use emf_core::{
    wmf::{
        self,
        brush::{BrushRecord, PatternBrush},
        TypedRecord,
    },
    EditFailure, ParseLimits,
};

fn file(function: u16, body: &[u8]) -> Vec<u8> {
    let record_words = (body.len() + 6) as u32 / 2;
    let mut out = vec![1, 0, 9, 0, 0, 3];
    out.extend_from_slice(&(12 + record_words).to_le_bytes());
    out.extend_from_slice(&1u16.to_le_bytes());
    out.extend_from_slice(&record_words.to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes());
    out.extend_from_slice(&record_words.to_le_bytes());
    out.extend_from_slice(&function.to_le_bytes());
    out.extend_from_slice(body);
    out.extend_from_slice(&[3, 0, 0, 0, 0, 0]);
    out
}

fn pattern() -> Vec<u8> {
    let mut body: Vec<_> = [-7i16, 9, 2, 4]
        .into_iter()
        .flat_map(i16::to_le_bytes)
        .collect();
    body.extend_from_slice(&[1, 1]);
    body.extend_from_slice(&[0xab; 4]);
    body.extend_from_slice(&[0xcd; 18]);
    body.extend_from_slice(&[1, 2, 3, 4]);
    body
}

fn typed(doc: &wmf::Document) -> PatternBrush {
    match doc.records()[0].typed() {
        Some(TypedRecord::Brush(BrushRecord::CreatePatternBrush(value))) => value.clone(),
        other => panic!("pattern brush was not decoded: {other:?}"),
    }
}

#[test]
fn pattern_is_typed_editable_and_preserves_ignored_fields_suffix_and_function() {
    let mut body = pattern();
    body.extend_from_slice(&[0xee, 0xff]);
    let bytes = file(0x7ff9, &body);
    let mut doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
    let mut value = typed(&doc);
    assert_eq!(
        (
            value.bitmap_type,
            value.width,
            value.height,
            value.width_bytes
        ),
        (-7, 9, 2, 4)
    );
    assert_eq!((value.planes, value.bits_pixel), (1, 1));
    assert_eq!(value.bits, [0xab; 4]);
    assert_eq!(value.reserved, [0xcd; 18]);
    assert_eq!(value.pattern, [1, 2, 3, 4]);
    assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
    doc.replace_typed(
        0,
        TypedRecord::Brush(BrushRecord::CreatePatternBrush(value.clone())),
    )
    .unwrap();
    assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
    value.function = 0x01f9;
    value.height = 3;
    value.pattern.extend_from_slice(&[5, 6]);
    doc.replace_typed(
        0,
        TypedRecord::Brush(BrushRecord::CreatePatternBrush(value.clone())),
    )
    .unwrap();
    let encoded = wmf::serialize(&doc).unwrap();
    let reparsed = wmf::parse(&encoded, &ParseLimits::default()).unwrap();
    value.function = 0x7ff9;
    assert_eq!(typed(&reparsed), value);
    assert_eq!(
        &reparsed.record_body(&reparsed.records()[0]).unwrap()[38..],
        &[0xee, 0xff]
    );
}

#[test]
fn pattern_preserves_independent_signed_width_bytes() {
    for width_bytes in [0i16, -1] {
        let mut body = pattern();
        body[6..8].copy_from_slice(&width_bytes.to_le_bytes());
        body.extend_from_slice(&[0xee, 0xff]);
        let bytes = file(0x7ff9, &body);
        let mut doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
        let mut value = typed(&doc);
        assert_eq!(value.width_bytes, width_bytes);
        assert_eq!(value.pattern, [1, 2, 3, 4]);
        assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
        doc.replace_typed(
            0,
            TypedRecord::Brush(BrushRecord::CreatePatternBrush(value.clone())),
        )
        .unwrap();
        assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
        value.pattern[0] = 0x99;
        doc.replace_typed(
            0,
            TypedRecord::Brush(BrushRecord::CreatePatternBrush(value.clone())),
        )
        .unwrap();
        let encoded = wmf::serialize(&doc).unwrap();
        let reparsed = wmf::parse(&encoded, &ParseLimits::default()).unwrap();
        assert_eq!(typed(&reparsed), value);
        assert_eq!(
            reparsed.record_body(&reparsed.records()[0]).unwrap()[36..],
            [0xee, 0xff]
        );
    }
}

#[test]
fn invalid_dimensions_planes_and_truncations_remain_raw_with_diagnostics() {
    let mut cases = Vec::new();
    for length in (0..pattern().len()).step_by(2) {
        cases.push(pattern()[..length].to_vec());
    }
    for (offset, bytes) in [
        (2, [0, 0]),
        (2, [0xff, 0xff]),
        (4, [0, 0]),
        (4, [0, 0x80]),
        (8, [2, 1]),
        (8, [1, 0]),
        (2, [0xff, 0x7f]),
    ] {
        let mut body = pattern();
        body[offset..offset + 2].copy_from_slice(&bytes);
        cases.push(body);
    }
    for body in cases {
        let bytes = file(0x01f9, &body);
        let doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
        assert!(doc.records()[0].typed().is_none());
        assert!(!doc.diagnostics().is_empty());
        assert_eq!(doc.records().len(), 2);
        assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
    }
}

#[test]
fn invalid_pattern_edits_fail_atomically() {
    let bytes = file(0x01f9, &pattern());
    let mut doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
    let original = typed(&doc);
    for change in 0..4 {
        let mut value = original.clone();
        match change {
            0 => value.pattern.push(9),
            1 => value.width = -1,
            2 => value.planes = 0,
            _ => value.function = 0x0142,
        }
        assert!(matches!(
            doc.replace_typed(
                0,
                TypedRecord::Brush(BrushRecord::CreatePatternBrush(value))
            ),
            Err(EditFailure::RecordLayout { .. })
        ));
        assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
    }
}

#[test]
fn dib_style_controls_color_usage_and_retains_opaque_target_on_edit() {
    for (style, usage) in [(3u16, 0xffffu16), (5, 2), (0xffff, 1)] {
        let mut body: Vec<_> = [style, usage]
            .into_iter()
            .flat_map(u16::to_le_bytes)
            .collect();
        body.extend_from_slice(&[0xaa, 0xbb, 0xcc, 0xdd]);
        let bytes = file(0x7f42, &body);
        let mut doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
        let Some(TypedRecord::Brush(BrushRecord::DibCreatePatternBrush(mut value))) =
            doc.records()[0].typed().cloned()
        else {
            panic!("DIB brush opaque")
        };
        assert_eq!(
            value.effective_color_usage(),
            if style == 3 { 0 } else { usage }
        );
        assert_eq!(value.target, [0xaa, 0xbb, 0xcc, 0xdd]);
        value.target[0] = 0x11;
        doc.replace_typed(
            0,
            TypedRecord::Brush(BrushRecord::DibCreatePatternBrush(value)),
        )
        .unwrap();
        let mut expected = bytes;
        expected[28] = 0x11;
        assert_eq!(wmf::serialize(&doc).unwrap(), expected);
    }
    for body in [vec![], vec![5, 0], vec![5, 0, 0, 0], vec![5, 0, 3, 0, 1, 2]] {
        let bytes = file(0x0142, &body);
        let doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
        assert!(doc.records()[0].typed().is_none());
        assert!(!doc.diagnostics().is_empty());
        assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
    }
}

#[test]
fn pattern_copies_charge_the_shared_public_resource_limits() {
    fn minimum(bytes: &[u8], allocation: bool) -> usize {
        let (mut low, mut high) = (0, 100_000);
        while low < high {
            let mid = (low + high) / 2;
            let mut limits = ParseLimits::default();
            if allocation {
                limits.max_allocated_bytes = mid;
            } else {
                limits.max_work_units = mid as u64;
            }
            match wmf::parse(bytes, &limits) {
                Ok(_) => high = mid,
                Err(emf_core::ParseFailure::LimitExceeded { kind, .. }) => {
                    assert_eq!(
                        kind,
                        if allocation {
                            emf_core::LimitKind::AllocatedBytes
                        } else {
                            emf_core::LimitKind::WorkUnits
                        }
                    );
                    low = mid + 1;
                }
                Err(other) => panic!("unexpected {other:?}"),
            }
        }
        low
    }
    let mut full = pattern();
    full[2..8].copy_from_slice(&[16, 0, 16, 0, 2, 0]);
    full.resize(64, 0);
    let mut short = full.clone();
    short[4..6].copy_from_slice(&1u16.to_le_bytes());
    let full = file(0x01f9, &full);
    let short = file(0x01f9, &short);
    assert_eq!(minimum(&full, true), minimum(&short, true) + 30);
    assert_eq!(minimum(&full, false), minimum(&short, false) + 1);
}

fn packed_dib(palette: bool) -> Vec<u8> {
    let mut bytes = 12u32.to_le_bytes().to_vec();
    bytes.extend([1u16, 1, 1, 1].into_iter().flat_map(u16::to_le_bytes));
    if palette {
        bytes.extend_from_slice(&[7, 0, 9, 0]);
    } else {
        bytes.extend_from_slice(&[1, 2, 3, 4, 5, 6]);
    }
    bytes.extend_from_slice(&[0x80, 0, 0, 0, 0xaa, 0xbb]);
    bytes
}

#[test]
fn dib_target_view_uses_effective_usage_and_edits_round_trip() {
    use wmf::{
        brush::DibPatternBrush,
        dib::{ColorTable, DibHeader},
    };
    for (style, color_usage, palette) in [(3, 0xffff, false), (5, 1, true)] {
        let target = packed_dib(palette);
        let mut brush = DibPatternBrush {
            function: 0x7f42,
            style,
            color_usage,
            target: target.clone(),
        };
        let mut dib = brush.target_dib(&ParseLimits::default()).unwrap().unwrap();
        assert_eq!(dib.trailing, [0xaa, 0xbb]);
        assert_eq!(
            dib.colors,
            if palette {
                ColorTable::PaletteIndices(vec![7, 9])
            } else {
                ColorTable::RgbTriples(vec![[1, 2, 3], [4, 5, 6]])
            }
        );
        assert_eq!(dib.encode().unwrap(), target);
        let DibHeader::Core(header) = &mut dib.header else {
            panic!("expected core header")
        };
        header.width = 2;
        dib.pixels[0] = 0xc0;
        brush.replace_target_dib(&dib).unwrap();
        assert_eq!(
            (brush.function, brush.style, brush.color_usage),
            (0x7f42, style, color_usage)
        );
        assert_eq!(
            brush.target_dib(&ParseLimits::default()).unwrap(),
            Some(dib.clone())
        );
        let mut payload: Vec<_> = [style, color_usage]
            .into_iter()
            .flat_map(u16::to_le_bytes)
            .collect();
        payload.extend_from_slice(&target);
        let mut doc = wmf::parse(&file(0x7f42, &payload), &ParseLimits::default()).unwrap();
        doc.replace_typed(
            0,
            TypedRecord::Brush(BrushRecord::DibCreatePatternBrush(brush.clone())),
        )
        .unwrap();
        let reparsed = wmf::parse(&wmf::serialize(&doc).unwrap(), &ParseLimits::default()).unwrap();
        assert_eq!(
            reparsed.records()[0].typed(),
            Some(&TypedRecord::Brush(BrushRecord::DibCreatePatternBrush(
                brush
            )))
        );
    }
}

#[test]
fn dib_target_fallback_and_failed_edits_preserve_raw_bytes() {
    use wmf::{brush::DibPatternBrush, dib::ColorTable};
    let mut brush = DibPatternBrush {
        function: 0x0142,
        style: 5,
        color_usage: 0,
        target: vec![0xaa, 0xbb],
    };
    assert_eq!(brush.target_dib(&ParseLimits::default()).unwrap(), None);
    assert_eq!(brush.target, [0xaa, 0xbb]);
    let valid = wmf::dib::Dib::parse(&packed_dib(false), 0, &ParseLimits::default())
        .unwrap()
        .unwrap();
    for change in 0..3 {
        let mut dib = valid.clone();
        match change {
            0 => dib.trailing.push(1),
            1 => dib.colors = ColorTable::PaletteIndices(vec![7, 9]),
            _ => dib.pixels.clear(),
        }
        assert!(matches!(
            brush.replace_target_dib(&dib),
            Err(EditFailure::RecordLayout { .. })
        ));
        assert_eq!(brush.target, [0xaa, 0xbb]);
    }
}

#[test]
fn dib_target_resource_failures_remain_errors_instead_of_opaque_fallback() {
    use emf_core::{LimitKind, ParseFailure};
    use wmf::brush::DibPatternBrush;
    let brush = DibPatternBrush {
        function: 0x0142,
        style: 3,
        color_usage: 0xffff,
        target: packed_dib(false),
    };
    for (allocation, work, expected) in [
        (11, 100, LimitKind::AllocatedBytes),
        (100, 3, LimitKind::WorkUnits),
    ] {
        let limits = ParseLimits {
            max_allocated_bytes: allocation,
            max_work_units: work,
            ..ParseLimits::default()
        };
        assert!(
            matches!(brush.target_dib(&limits), Err(ParseFailure::LimitExceeded { kind, .. }) if kind == expected)
        );
    }
    let exact = ParseLimits {
        max_allocated_bytes: 12,
        max_work_units: 4,
        ..ParseLimits::default()
    };
    assert!(brush.target_dib(&exact).unwrap().is_some());
}
