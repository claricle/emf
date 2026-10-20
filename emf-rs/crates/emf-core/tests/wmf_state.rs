use emf_core::{
    wmf::{
        self,
        state::{Palette, StateRecord},
        TypedRecord,
    },
    EditFailure, LimitKind, PaletteEntry, ParseFailure, ParseLimits,
};

fn file(function: u16, body: &[u8]) -> Vec<u8> {
    assert_eq!(body.len() % 2, 0);
    let words = (body.len() + 6) / 2;
    let mut bytes = vec![1, 0, 9, 0, 0, 3];
    bytes.extend_from_slice(&(12u32 + words as u32).to_le_bytes());
    bytes.extend_from_slice(&8u16.to_le_bytes());
    bytes.extend_from_slice(&(words as u32).to_le_bytes());
    bytes.extend_from_slice(&0u16.to_le_bytes());
    bytes.extend_from_slice(&(words as u32).to_le_bytes());
    bytes.extend_from_slice(&function.to_le_bytes());
    bytes.extend_from_slice(body);
    bytes.extend_from_slice(&[3, 0, 0, 0, 0, 0]);
    bytes
}

#[test]
fn signed_pen_fields_raw_colors_and_suffix_survive_typed_edit() {
    let bytes = file(
        0x02fa,
        &[5, 0x80, 0xfe, 0xff, 0, 0x80, 1, 2, 3, 0xff, 0xaa, 0xbb],
    );
    let mut doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
    let Some(TypedRecord::State(StateRecord::CreatePenIndirect(pen))) = doc.records()[0].typed()
    else {
        panic!("pen not decoded")
    };
    assert_eq!(
        (pen.style, pen.width_x, pen.width_y, pen.color),
        (0x8005, -2, i16::MIN, 0xff030201)
    );
    let mut pen = pen.clone();
    pen.width_x = 19;
    doc.replace_typed(0, TypedRecord::State(StateRecord::CreatePenIndirect(pen)))
        .unwrap();
    let encoded = wmf::serialize(&doc).unwrap();
    let mut expected = bytes;
    expected[26..28].copy_from_slice(&19i16.to_le_bytes());
    assert_eq!(encoded, expected);
}

#[test]
fn scalar_wire_values_and_optional_reserved_words_are_preserved() {
    let cases = [
        (0x0127, vec![0xff, 0xff], StateRecord::RestoreDc(-1)),
        (0x0234, vec![0xfe, 0xff], StateRecord::SelectPalette(65534)),
        (
            0x0102,
            vec![0x81, 0x7f, 0xaa, 0xbb],
            StateRecord::SetBkMode(0x7f81),
        ),
        (
            0x020a,
            vec![2, 0x80, 0xfe, 0xff],
            StateRecord::SetTextJustification {
                break_count: 32770,
                break_extra: 65534,
            },
        ),
        (
            0x0108,
            vec![0xfd, 0xff],
            StateRecord::SetTextCharExtra(65533),
        ),
        (
            0x0149,
            vec![1, 0, 0xcd, 0xab],
            StateRecord::SetLayout {
                layout: 1,
                reserved: 0xabcd,
            },
        ),
        (0x7f03, vec![0x88, 0x77], StateRecord::SetMapMode(0x7788)),
    ];
    for (function, body, expected) in cases {
        let bytes = file(function, &body);
        let mut doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
        assert_eq!(
            doc.records()[0].typed(),
            Some(&TypedRecord::State(expected.clone()))
        );
        assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
        doc.replace_typed(0, TypedRecord::State(expected)).unwrap();
        // Canonical encoder may change only the function's advisory high byte.
        let encoded = wmf::serialize(&doc).unwrap();
        assert_eq!(&encoded[24..], &bytes[24..]);
    }
}

#[test]
fn fixed_font_retains_signed_values_and_bytes_after_face_name_nul() {
    let mut body: Vec<u8> = (-1i16..=3).flat_map(i16::to_le_bytes).collect();
    body.extend_from_slice(&[1, 2, 3, 4, 5, 6, 7, 8]);
    body.extend_from_slice(&[b'A', 0]);
    body.extend_from_slice(&[0xcc; 30]);
    body.extend_from_slice(&[0xdd, 0xee]);
    let bytes = file(0x02fb, &body);
    let mut doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
    let Some(TypedRecord::State(StateRecord::CreateFontIndirect(font))) = doc.records()[0].typed()
    else {
        panic!("font not decoded")
    };
    assert_eq!((font.height, font.width, font.weight), (-1, 0, 3));
    assert_eq!(&font.face_name[..3], &[b'A', 0, 0xcc]);
    let mut font = font.clone();
    font.height = -200;
    doc.replace_typed(0, TypedRecord::State(StateRecord::CreateFontIndirect(font)))
        .unwrap();
    let mut expected = bytes;
    expected[24..26].copy_from_slice(&(-200i16).to_le_bytes());
    assert_eq!(wmf::serialize(&doc).unwrap(), expected);
}

#[test]
fn bounded_malformed_objects_remain_opaque_and_do_not_hide_eof() {
    for (function, body) in [
        (0x02fa, vec![0; 8]),
        (0x02fc, vec![0; 6]),
        (0x02fb, vec![0; 48]),
        (0x00f7, vec![0, 3, 2, 0, 1, 2, 3, 4]),
        (0x0149, vec![0; 2]),
    ] {
        let bytes = file(function, &body);
        let doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
        assert!(doc.records()[0].typed().is_none());
        assert!(doc.has_eof());
        assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
        assert!(!doc.diagnostics().is_empty());
    }
}

#[test]
fn palette_growth_preserves_suffix_and_rejects_excessive_count_atomically() {
    let bytes = file(0x00f7, &[0, 3, 1, 0, 0x11, 0x22, 0x33, 0x84, 0xca, 0xfe]);
    let mut doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
    let Some(TypedRecord::State(StateRecord::CreatePalette(p))) = doc.records()[0].typed() else {
        panic!("palette not decoded")
    };
    assert_eq!(
        p.entries[0],
        PaletteEntry {
            red: 0x11,
            green: 0x22,
            blue: 0x33,
            flags: 0x84
        }
    );
    let mut p = p.clone();
    p.entries.push(PaletteEntry {
        red: 4,
        green: 5,
        blue: 6,
        flags: 7,
    });
    doc.replace_typed(0, TypedRecord::State(StateRecord::CreatePalette(p.clone())))
        .unwrap();
    let encoded = wmf::serialize(&doc).unwrap();
    assert_eq!(
        &encoded[24..38],
        &[0, 3, 2, 0, 0x11, 0x22, 0x33, 0x84, 4, 5, 6, 7, 0xca, 0xfe]
    );
    let snapshot = doc.clone();
    p.entries.resize(
        65536,
        PaletteEntry {
            red: 0,
            green: 0,
            blue: 0,
            flags: 0,
        },
    );
    assert_eq!(
        doc.replace_typed(0, TypedRecord::State(StateRecord::CreatePalette(p))),
        Err(EditFailure::SizeOverflow)
    );
    assert_eq!(doc, snapshot);
}

#[test]
fn palette_entries_consume_shared_work_and_allocation_budgets() {
    let body = [0, 3, 2, 0, 1, 2, 3, 4, 5, 6, 7, 8];
    let typed = file(0x00f7, &body);
    let empty = file(0x00f7, &[0, 3, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8]);
    fn minimum(bytes: &[u8], allocation: bool) -> u64 {
        let (mut low, mut high) = (0, 1_000_000);
        while low < high {
            let mid = (low + high) / 2;
            let mut limits = ParseLimits::default();
            if allocation {
                limits.max_allocated_bytes = mid as usize;
            } else {
                limits.max_work_units = mid;
            }
            match wmf::parse(bytes, &limits) {
                Ok(_) => high = mid,
                Err(ParseFailure::LimitExceeded { kind, .. }) => {
                    assert_eq!(
                        kind,
                        if allocation {
                            LimitKind::AllocatedBytes
                        } else {
                            LimitKind::WorkUnits
                        }
                    );
                    low = mid + 1;
                }
                Err(other) => panic!("unexpected parse error: {other:?}"),
            }
        }
        low
    }
    // Identical framing, object creation, and source sizes isolate the two
    // decoded entries; the empty palette retains the eight bytes as a suffix.
    assert_eq!(minimum(&typed, false), minimum(&empty, false) + 2);
    assert_eq!(minimum(&typed, true), minimum(&empty, true) + 8);
    let doc = wmf::parse(&typed, &ParseLimits::default()).unwrap();
    assert!(
        matches!(doc.records()[0].typed(),Some(TypedRecord::State(StateRecord::CreatePalette(Palette {entries,..}))) if entries.len()==2)
    );
}

#[test]
fn brush_and_palette_update_layouts_keep_raw_fields() {
    let bytes = file(0x02fc, &[2, 0x80, 4, 3, 2, 1, 0xfe, 0xff]);
    let doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
    let Some(TypedRecord::State(StateRecord::CreateBrushIndirect(brush))) =
        doc.records()[0].typed()
    else {
        panic!("brush not decoded")
    };
    assert_eq!(
        (brush.style, brush.color, brush.hatch),
        (0x8002, 0x01020304, 65534)
    );
    for function in [0x0037, 0x0436] {
        let bytes = file(function, &[9, 0, 1, 0, 10, 20, 30, 0x80, 0xaa, 0xbb]);
        let mut doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
        let typed = doc.records()[0].typed().unwrap().clone();
        let palette = match &typed {
            TypedRecord::State(StateRecord::SetPalEntries(p) | StateRecord::AnimatePalette(p)) => p,
            _ => panic!("palette update not decoded"),
        };
        assert_eq!((palette.start, palette.entries[0].flags), (9, 0x80));
        doc.replace_typed(0, typed).unwrap();
        assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
    }
}

#[test]
fn set_rel_abs_is_typed_as_ignored_and_retains_suffix_and_function_high_byte() {
    let bytes = file(0x7f05, &[0x34, 0x12, 0xaa, 0xbb]);
    let mut doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
    assert_eq!(
        doc.records()[0].typed(),
        Some(&TypedRecord::State(StateRecord::SetRelAbs))
    );
    assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
    assert_eq!(
        doc.replace_typed(0, TypedRecord::State(StateRecord::SetBkMode(1))),
        Err(EditFailure::RecordFamily { index: 0 })
    );
    assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
    doc.replace_typed(0, TypedRecord::State(StateRecord::SetRelAbs))
        .unwrap();
    assert_eq!(doc.records()[0].function(), 0x7f05);
    assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
}
