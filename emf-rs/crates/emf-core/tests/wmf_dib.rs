use emf_core::wmf::dib::{Bitmap16, ColorTable, Dib, DibHeader};
use emf_core::{EditFailure, LimitKind, ParseFailure, ParseLimits};

fn info(
    width: i32,
    height: i32,
    bits: u16,
    compression: u32,
    image_size: u32,
    used: u32,
) -> Vec<u8> {
    let mut bytes = Vec::new();
    bytes.extend_from_slice(&40u32.to_le_bytes());
    bytes.extend_from_slice(&width.to_le_bytes());
    bytes.extend_from_slice(&height.to_le_bytes());
    bytes.extend_from_slice(&1u16.to_le_bytes());
    bytes.extend_from_slice(&bits.to_le_bytes());
    for value in [compression, image_size, 123, 456, used, 0] {
        bytes.extend_from_slice(&value.to_le_bytes());
    }
    bytes
}
fn parse(bytes: &[u8], usage: u16) -> Dib {
    Dib::parse(bytes, usage, &ParseLimits::default())
        .unwrap()
        .unwrap()
}
fn core() -> Vec<u8> {
    let mut bytes = 12u32.to_le_bytes().to_vec();
    for value in [3u16, 2, 1, 1] {
        bytes.extend_from_slice(&value.to_le_bytes());
    }
    bytes
}

#[test]
fn core_rgb_triples_palette_words_and_no_table_have_distinct_extents() {
    for (usage, table) in [
        (0, vec![1, 2, 3, 4, 5, 6]),
        (1, vec![5, 0, 9, 0]),
        (2, vec![]),
    ] {
        let mut bytes = core();
        bytes.extend_from_slice(&table);
        bytes.extend_from_slice(&[0xa0, 0x91, 0x82, 0x73, 0x60, 0x51, 0x42, 0x33]);
        bytes.extend_from_slice(&[0xcc, 0xdd]);
        let value = parse(&bytes, usage);
        match &value.colors {
            ColorTable::RgbTriples(entries) => assert_eq!(entries, &[[1, 2, 3], [4, 5, 6]]),
            ColorTable::PaletteIndices(entries) => assert_eq!(entries, &[5, 9]),
            ColorTable::None => assert_eq!(usage, 2),
            _ => panic!("wrong table type"),
        }
        assert_eq!(value.pixels.len(), 8);
        assert_eq!(value.trailing, [0xcc, 0xdd]);
        assert_eq!(value.encode().unwrap(), bytes);
    }
}

#[test]
fn rgb_uses_dword_stride_and_signed_height_ignoring_declared_size() {
    let mut bytes = info(3, -2, 24, 0, u32::MAX, 0);
    bytes.extend(0..24);
    bytes.extend_from_slice(&[0xfe, 0xed]);
    let mut value = parse(&bytes, 0);
    assert_eq!(value.pixels, (0..24).collect::<Vec<_>>());
    assert_eq!(value.trailing, [0xfe, 0xed]);
    let DibHeader::Info(h) = &value.header else {
        panic!("info expected")
    };
    assert_eq!(h.height, -2);
    assert_eq!(h.image_size, u32::MAX);
    assert_eq!(value.encode().unwrap(), bytes);
    value.pixels[0] = 0x77;
    let encoded = value.encode().unwrap();
    assert_eq!(parse(&encoded, 0).pixels[0], 0x77);
    assert_eq!(&encoded[41..], &bytes[41..]);
}

#[test]
fn info_color_used_controls_rgb_quads_and_palette_indices() {
    for usage in [0, 1] {
        let mut bytes = info(1, 1, 8, 0, 0, 2);
        bytes.extend_from_slice(if usage == 0 {
            &[1, 2, 3, 4, 5, 6, 7, 8]
        } else {
            &[7, 0, 8, 0]
        });
        bytes.extend_from_slice(&[0, 0xee, 0xdd, 0xcc]);
        let value = parse(&bytes, usage);
        if usage == 0 {
            assert_eq!(
                value.colors,
                ColorTable::RgbQuads(vec![[1, 2, 3, 4], [5, 6, 7, 8]])
            );
        } else {
            assert_eq!(value.colors, ColorTable::PaletteIndices(vec![7, 8]));
        }
        assert_eq!(value.pixels, [0, 0xee, 0xdd, 0xcc]);
        assert_eq!(value.encode().unwrap(), bytes);
    }
}

#[test]
fn external_and_embedded_bitfields_keep_masks_separate_from_pixels() {
    for header_size in [40usize, 52, 108, 124, 128] {
        let mut bytes = info(1, 1, 16, 3, 99, 0);
        bytes[..4].copy_from_slice(&(header_size as u32).to_le_bytes());
        for mask in [0xf800u32, 0x7e0, 0x1f] {
            bytes.extend_from_slice(&mask.to_le_bytes());
        }
        if header_size > 40 {
            bytes.resize(header_size, 0x59);
        }
        bytes.extend_from_slice(&[0x1f, 0, 0xab, 0xcd, 0xef, 0x00]);
        let value = parse(&bytes, 0);
        assert_eq!(
            value.bitfield_masks,
            if header_size == 40 {
                Some([0xf800, 0x7e0, 0x1f])
            } else {
                None
            }
        );
        assert_eq!(value.pixels, [0x1f, 0, 0xab, 0xcd]);
        assert_eq!(value.trailing, [0xef, 0]);
        assert_eq!(value.encode().unwrap(), bytes);
    }
}

#[test]
fn compressed_payloads_use_declared_extent_without_decoding() {
    for (compression, bits) in [(1, 8), (2, 4), (4, 0), (5, 0), (12, 8), (13, 4)] {
        let mut bytes = info(10, 20, bits, compression, 5, 0);
        // DIB_PAL_INDICES permits compressed palette data without a table.
        bytes.extend_from_slice(&[0xff, 0x00, 0x98, 0x76, 0x54, 0xaa]);
        let value = parse(&bytes, 2);
        assert_eq!(value.pixels, [0xff, 0x00, 0x98, 0x76, 0x54]);
        assert_eq!(value.trailing, [0xaa]);
        assert_eq!(value.encode().unwrap(), bytes);
    }
}

#[test]
fn malformed_boundaries_and_unsupported_layouts_return_none() {
    let mut valid = info(1, 1, 24, 0, 0, 0);
    valid.extend_from_slice(&[1, 2, 3, 0]);
    for end in 0..valid.len() {
        assert!(
            Dib::parse(&valid[..end], 0, &ParseLimits::default())
                .unwrap()
                .is_none(),
            "prefix {end}"
        );
    }
    let mut cases = Vec::new();
    for (offset, value) in [
        (0, 39u32),
        (0, u32::MAX),
        (4, 0),
        (8, 0),
        (16, 100),
        (32, u32::MAX),
    ] {
        let mut bytes = valid.clone();
        bytes[offset..offset + 4].copy_from_slice(&value.to_le_bytes());
        cases.push(bytes);
    }
    for (bits, compression) in [(8, 3), (4, 1), (8, 2), (0, 0)] {
        let mut bytes = info(1, 1, bits, compression, 4, 0);
        bytes.extend_from_slice(&[0; 4]);
        cases.push(bytes);
    }
    let mut top_down_rle = info(1, -1, 8, 1, 4, 0);
    top_down_rle.extend_from_slice(&[0; 4]);
    cases.push(top_down_rle);
    let mut huge = info(i32::MAX, i32::MIN, 32, 0, 0, 0);
    huge.extend_from_slice(&[0; 4]);
    cases.push(huge);
    for bytes in cases {
        assert!(Dib::parse(&bytes, 0, &ParseLimits::default())
            .unwrap()
            .is_none());
    }
    assert!(Dib::parse(&valid, 3, &ParseLimits::default())
        .unwrap()
        .is_none());
}

#[test]
fn v5_profile_after_pixels_is_preserved_and_overlap_is_rejected() {
    let mut bytes = info(1, 1, 24, 0, 0, 0);
    bytes[..4].copy_from_slice(&124u32.to_le_bytes());
    bytes.resize(124, 0);
    bytes[56..60].copy_from_slice(&0x4d42_4544u32.to_le_bytes());
    bytes[112..116].copy_from_slice(&130u32.to_le_bytes());
    bytes[116..120].copy_from_slice(&3u32.to_le_bytes());
    bytes.extend_from_slice(&[1, 2, 3, 0, 0xfe, 0xed, 7, 8, 9]);
    let value = parse(&bytes, 0);
    assert_eq!(value.trailing, [0xfe, 0xed, 7, 8, 9]);
    assert_eq!(value.encode().unwrap(), bytes);
    for offset in [40u32, 125, 131] {
        bytes[112..116].copy_from_slice(&offset.to_le_bytes());
        assert!(Dib::parse(&bytes, 0, &ParseLimits::default())
            .unwrap()
            .is_none());
    }
}

#[test]
fn bitmap16_uses_word_stride_and_retains_padding_with_mutable_pixels() {
    let mut bytes = Vec::new();
    for value in [-7i16, 9, 2, 2] {
        bytes.extend_from_slice(&value.to_le_bytes());
    }
    bytes.extend_from_slice(&[1, 1, 0xaa, 0x80, 0x55, 0, 0xbe, 0xef]);
    let mut value = Bitmap16::parse(&bytes, &ParseLimits::default())
        .unwrap()
        .unwrap();
    assert_eq!(value.bitmap_type, -7);
    assert_eq!(value.pixels, [0xaa, 0x80, 0x55, 0]);
    assert_eq!(value.trailing, [0xbe, 0xef]);
    assert_eq!(value.encode().unwrap(), bytes);
    value.pixels[2] = 0x77;
    let encoded = value.encode().unwrap();
    assert_eq!(encoded[12], 0x77);
    assert_eq!(&encoded[14..], &[0xbe, 0xef]);
    for end in 0..14 {
        assert!(Bitmap16::parse(&bytes[..end], &ParseLimits::default())
            .unwrap()
            .is_none());
    }
    bytes[6..8].copy_from_slice(&4i16.to_le_bytes());
    let value = Bitmap16::parse(&bytes, &ParseLimits::default())
        .unwrap()
        .unwrap();
    assert_eq!(value.width_bytes, 4);
    assert_eq!(value.pixels.len(), 4);
    assert_eq!(value.encode().unwrap(), bytes);
}

#[test]
fn bitmap16_preserves_nonstandard_depth_and_independent_width_bytes() {
    let mut bytes = Vec::new();
    for value in [0i16, 9, 2, 999] {
        bytes.extend_from_slice(&value.to_le_bytes());
    }
    bytes.extend_from_slice(&[1, 3, 0, 1, 2, 3, 4, 5, 6, 7, 0xfe]);
    let value = Bitmap16::parse(&bytes, &ParseLimits::default())
        .unwrap()
        .unwrap();
    assert_eq!(value.width_bytes, 999);
    assert_eq!(value.bits_pixel, 3);
    assert_eq!(value.pixels, [0, 1, 2, 3, 4, 5, 6, 7]);
    assert_eq!(value.trailing, [0xfe]);
    assert_eq!(value.encode().unwrap(), bytes);
}

#[test]
fn resource_limits_remain_errors_and_exact_allocation_boundary_succeeds() {
    let mut bytes = core();
    bytes.extend_from_slice(&[1, 2, 3, 4, 5, 6]);
    bytes.extend_from_slice(&[0; 8]);
    bytes.extend_from_slice(&[0xaa, 0xbb]);
    let limits = ParseLimits {
        max_allocated_bytes: 16,
        ..ParseLimits::default()
    };
    assert_eq!(
        Dib::parse(&bytes, 0, &limits)
            .unwrap()
            .unwrap()
            .encode()
            .unwrap(),
        bytes
    );
    for (limits, kind) in [
        (
            ParseLimits {
                max_allocated_bytes: 15,
                ..limits.clone()
            },
            LimitKind::AllocatedBytes,
        ),
        (
            ParseLimits {
                max_work_units: 0,
                ..limits.clone()
            },
            LimitKind::WorkUnits,
        ),
        (
            ParseLimits {
                max_input_bytes: bytes.len() - 1,
                ..limits
            },
            LimitKind::InputBytes,
        ),
    ] {
        assert!(
            matches!(Dib::parse(&bytes, 0, &limits), Err(ParseFailure::LimitExceeded { kind: actual, .. }) if actual == kind)
        );
    }
}

#[test]
fn encode_rejects_changed_pixel_extent() {
    let mut bytes = info(1, 1, 24, 0, 0, 0);
    bytes.extend_from_slice(&[0; 4]);
    let mut value = parse(&bytes, 0);
    value.pixels.pop();
    assert_eq!(value.encode(), Err(EditFailure::RecordLayout { index: 0 }));
}

#[test]
fn encode_rejects_wrong_color_entry_format_even_with_same_byte_extent() {
    let mut bytes = info(1, 1, 8, 0, 0, 3);
    bytes.extend_from_slice(&[0; 12]);
    bytes.extend_from_slice(&[0; 4]);
    let mut value = parse(&bytes, 0);
    value.colors = ColorTable::RgbTriples(vec![[1, 2, 3]; 4]);
    assert_eq!(value.encode(), Err(EditFailure::RecordLayout { index: 0 }));
}

#[test]
fn bitmap16_copies_are_budgeted_including_trailing_bytes() {
    let bytes = [0, 0, 1, 0, 1, 0, 2, 0, 1, 1, 0xab, 0xcd, 0xef];
    let limits = ParseLimits {
        max_allocated_bytes: 3,
        ..ParseLimits::default()
    };
    assert_eq!(
        Bitmap16::parse(&bytes, &limits)
            .unwrap()
            .unwrap()
            .encode()
            .unwrap(),
        bytes
    );
    let limits = ParseLimits {
        max_allocated_bytes: 2,
        ..limits
    };
    assert!(matches!(
        Bitmap16::parse(&bytes, &limits),
        Err(ParseFailure::LimitExceeded {
            kind: LimitKind::AllocatedBytes,
            ..
        })
    ));
}
