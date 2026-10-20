use emf_core::wmf::{self, bitmap::BitmapRecord, TypedRecord};
use emf_core::{EditFailure, ParseLimits};

fn words(values: &[i16]) -> Vec<u8> {
    values
        .iter()
        .flat_map(|value| value.to_le_bytes())
        .collect()
}
fn record(function: u16, body: &[u8]) -> Vec<u8> {
    let mut out = ((body.len() as u32 + 6) / 2).to_le_bytes().to_vec();
    out.extend_from_slice(&function.to_le_bytes());
    out.extend_from_slice(body);
    out
}
fn document(function: u16, body: &[u8]) -> Vec<u8> {
    let records = [
        record(function, body),
        record(0xfefe, &[0xab, 0xcd]),
        record(0, &[]),
    ]
    .concat();
    let mut out = words(&[1, 9, 0x300]);
    out.extend_from_slice(&((18 + records.len()) as u32 / 2).to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes());
    out.extend_from_slice(&((body.len() as u32 + 6) / 2).to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes());
    out.extend_from_slice(&records);
    out.extend_from_slice(&[0xde, 0xad, 0xbe]);
    out
}
fn typed(doc: &wmf::Document) -> BitmapRecord {
    match doc.records()[0].typed().unwrap() {
        TypedRecord::Bitmap(value) => value.clone(),
        other => panic!("{other:?}"),
    }
}
// Independently laid out Bitmap16 (one 1bpp pixel, one padded scan line).
fn bitmap16() -> Vec<u8> {
    vec![0, 0, 1, 0, 1, 0, 2, 0, 1, 1, 0x80, 0]
}
// BITMAPCOREHEADER, two RGB triples, one DWORD-aligned 1bpp scan line.
fn dib() -> Vec<u8> {
    vec![
        12, 0, 0, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 255, 255, 255, 0x80, 0, 0, 0,
    ]
}
fn fixture(function: u16, present: bool) -> Vec<u8> {
    let mut out = if function & 0xff == 0x33 {
        words(&[0, 1, 0, -1, -2, 1, 1, -3, -4])
    } else {
        let mut out = 0x00cc0020u32.to_le_bytes().to_vec();
        if function & 0xff == 0x43 {
            out.extend_from_slice(&words(&[0]));
        }
        if matches!(function & 0xff, 0x23 | 0x41 | 0x43) {
            out.extend_from_slice(&words(&[-10, -20]));
        }
        out.extend_from_slice(&words(&[-30, -40]));
        if !present {
            out.extend_from_slice(&0xa5b6u16.to_le_bytes());
        }
        out.extend_from_slice(&words(&[-50, -60, -70, -80]));
        out
    };
    if present {
        out.extend_from_slice(&if matches!(function & 0xff, 0x22 | 0x23) {
            bitmap16()
        } else {
            dib()
        });
    }
    out
}
fn image_mut(value: &mut BitmapRecord) -> &mut Vec<u8> {
    match value {
        BitmapRecord::BitBlt(v) | BitmapRecord::DibBitBlt(v) => v.bitmap.as_mut().unwrap(),
        BitmapRecord::StretchBlt(v) | BitmapRecord::DibStretchBlt(v) => v.bitmap.as_mut().unwrap(),
        BitmapRecord::SetDibToDev(v) => &mut v.bitmap,
        BitmapRecord::StretchDib(v) => &mut v.bitmap,
    }
}
#[test]
fn all_six_normative_headers_preserve_images_and_resize_edits() {
    for function in [0x0922, 0x0940, 0x0b23, 0x0b41, 0x0d33, 0x0f43] {
        let body = fixture(function, true);
        let bytes = document(function, &body);
        let mut doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
        assert!(doc.diagnostics().is_empty());
        assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
        let mut value = typed(&doc);
        match &value {
            BitmapRecord::BitBlt(v) | BitmapRecord::DibBitBlt(v) => {
                assert_eq!(
                    (
                        v.source_y,
                        v.source_x,
                        v.height,
                        v.width,
                        v.destination_y,
                        v.destination_x
                    ),
                    (-30, -40, -50, -60, -70, -80)
                );
                assert_eq!(v.raster_operation, 0x00cc0020);
            }
            BitmapRecord::StretchBlt(v) | BitmapRecord::DibStretchBlt(v) => {
                assert_eq!(
                    (v.source_height, v.source_width, v.destination_x),
                    (-10, -20, -80)
                );
            }
            BitmapRecord::SetDibToDev(v) => {
                assert_eq!(
                    (v.source_y, v.source_x, v.destination_y, v.destination_x),
                    (65535, 65534, 65533, 65532)
                );
            }
            BitmapRecord::StretchDib(v) => {
                assert_eq!(
                    (
                        v.source_height,
                        v.source_width,
                        v.source_y,
                        v.source_x,
                        v.destination_x
                    ),
                    (-10, -20, -30, -40, -80)
                );
            }
        }
        assert_eq!(
            image_mut(&mut value).as_slice(),
            if matches!(function & 0xff, 0x22 | 0x23) {
                bitmap16()
            } else {
                dib()
            }
        );
        image_mut(&mut value).extend_from_slice(&[0xca, 0xfe]);
        doc.replace_typed(0, TypedRecord::Bitmap(value.clone()))
            .unwrap();
        let output = wmf::serialize(&doc).unwrap();
        let parsed = wmf::parse(&output, &ParseLimits::default()).unwrap();
        assert_eq!(typed(&parsed), value);
        assert!(parsed.diagnostics().is_empty());
        assert_eq!(
            parsed.record_bytes(&parsed.records()[1]),
            Some(record(0xfefe, &[0xab, 0xcd]).as_slice())
        );
        assert_eq!(parsed.tail(), &[0xde, 0xad, 0xbe]);
    }
}
#[test]
fn absent_sources_preserve_reserved_and_opaque_record_suffix_on_scalar_edit() {
    for canonical in [0x0922, 0x0940, 0x0b23, 0x0b41] {
        let mut body = fixture(canonical, false);
        body.extend_from_slice(&[0xca, 0xfe]);
        let function = ((body.len() as u16 / 2) << 8) | (canonical & 0xff);
        let bytes = document(function, &body);
        let mut doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
        let mut value = typed(&doc);
        match &mut value {
            BitmapRecord::BitBlt(v) | BitmapRecord::DibBitBlt(v) => {
                assert!(v.bitmap.is_none());
                assert_eq!(v.reserved, 0xa5b6);
                v.destination_x = 123;
            }
            BitmapRecord::StretchBlt(v) | BitmapRecord::DibStretchBlt(v) => {
                assert!(v.bitmap.is_none());
                assert_eq!(v.reserved, 0xa5b6);
                v.destination_x = 123;
            }
            _ => unreachable!(),
        }
        assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
        doc.replace_typed(0, TypedRecord::Bitmap(value.clone()))
            .unwrap();
        let output = wmf::serialize(&doc).unwrap();
        let parsed = wmf::parse(&output, &ParseLimits::default()).unwrap();
        assert_eq!(typed(&parsed), value);
        assert!(parsed
            .record_body(&parsed.records()[0])
            .unwrap()
            .ends_with(&[0xca, 0xfe]));
    }
}
#[test]
fn fixed_header_truncation_recovers_as_opaque_and_required_payload_cannot_be_empty() {
    for function in [0x0922, 0x0940, 0x0b23, 0x0b41, 0x0d33, 0x0f43] {
        let header = match function & 0xff {
            0x22 | 0x40 => 16,
            0x23 | 0x41 => 20,
            0x33 => 18,
            _ => 22,
        };
        let full = fixture(function, true);
        for length in (0..=header).step_by(2) {
            let bytes = document(function, &full[..length]);
            let doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
            assert!(doc.records()[0].typed().is_none(), "{function:x}/{length}");
            assert!(!doc.diagnostics().is_empty());
            assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
        }
    }
}
#[test]
fn resized_source_cannot_turn_into_absent_form_and_invalid_images_are_rejected() {
    let bytes = document(0x0922, &fixture(0x0922, true));
    let mut doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
    for payload in [vec![], vec![0], vec![1, 2]] {
        let mut value = typed(&doc);
        *image_mut(&mut value) = payload;
        assert!(matches!(
            doc.replace_typed(0, TypedRecord::Bitmap(value)),
            Err(EditFailure::RecordLayout { .. })
        ));
    }
    assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
}

#[test]
fn image_allocation_failure_is_fatal_instead_of_a_malformed_diagnostic() {
    let bytes = document(0x0d33, &fixture(0x0d33, true));
    let ceiling = bytes.len() + std::mem::size_of::<wmf::Record>();
    let limits = ParseLimits {
        max_allocated_bytes: ceiling,
        ..ParseLimits::default()
    };
    assert!(
        matches!(wmf::parse(&bytes, &limits), Err(emf_core::ParseFailure::LimitExceeded {
        kind: emf_core::LimitKind::AllocatedBytes, limit, requested,
    }) if limit == ceiling as u64 && requested == ceiling as u64 + dib().len() as u64)
    );
}

#[test]
fn typed_views_edit_all_six_interiors_without_losing_suffixes_or_neighbor_records() {
    use wmf::bitmap::BitmapImage;
    for function in [0x0922, 0x0940, 0x0b23, 0x0b41, 0x0d33, 0x0f43] {
        let mut body = fixture(function, true);
        body.extend_from_slice(&[0xca, 0xfe]);
        let bytes = document(function, &body);
        let mut doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
        let mut value = typed(&doc);
        let mut image = value.typed_image(&ParseLimits::default()).unwrap().unwrap();
        let pixels = match &mut image {
            BitmapImage::Bitmap16(image) => {
                assert!(matches!(function & 0xff, 0x22 | 0x23));
                assert_eq!(image.trailing, [0xca, 0xfe]);
                &mut image.pixels
            }
            BitmapImage::Dib(image) => {
                assert!(!matches!(function & 0xff, 0x22 | 0x23));
                assert_eq!(image.trailing, [0xca, 0xfe]);
                &mut image.pixels
            }
            BitmapImage::Absent => panic!("expected embedded image"),
        };
        pixels[0] = 0x40;
        value.replace_image(image.clone()).unwrap();
        doc.replace_typed(0, TypedRecord::Bitmap(value.clone()))
            .unwrap();
        let output = wmf::serialize(&doc).unwrap();
        let reparsed = wmf::parse(&output, &ParseLimits::default()).unwrap();
        assert_eq!(typed(&reparsed), value);
        assert_eq!(
            value.typed_image(&ParseLimits::default()).unwrap(),
            Some(image)
        );
        assert_eq!(
            reparsed.record_bytes(&reparsed.records()[1]),
            Some(record(0xfefe, &[0xab, 0xcd]).as_slice())
        );
        assert_eq!(reparsed.tail(), &[0xde, 0xad, 0xbe]);
    }
}

#[test]
fn absent_and_malformed_interiors_are_distinct_and_keep_original_wire_bytes() {
    use wmf::bitmap::BitmapImage;
    let limits = ParseLimits::default();
    for function in [0x0922, 0x0940, 0x0b23, 0x0b41] {
        let bytes = document(function, &fixture(function, false));
        let doc = wmf::parse(&bytes, &limits).unwrap();
        assert_eq!(
            typed(&doc).typed_image(&limits).unwrap(),
            Some(BitmapImage::Absent)
        );
        assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
    }
    for function in [0x0922, 0x0940, 0x0b23, 0x0b41, 0x0d33, 0x0f43] {
        let bytes = document(function, &fixture(function, true));
        let mut doc = wmf::parse(&bytes, &limits).unwrap();
        let mut value = typed(&doc);
        image_mut(&mut value)[0..4].fill(0xff);
        assert_eq!(value.typed_image(&limits).unwrap(), None);
        doc.replace_typed(0, TypedRecord::Bitmap(value.clone()))
            .unwrap();
        let output = wmf::serialize(&doc).unwrap();
        let reparsed = wmf::parse(&output, &limits).unwrap();
        assert_eq!(typed(&reparsed), value);
        assert_eq!(wmf::serialize(&reparsed).unwrap(), output);
    }
}

#[test]
fn views_use_record_color_usage_and_enforce_direct_input_allocation_and_work_limits() {
    use emf_core::{LimitKind, ParseFailure};
    use wmf::{bitmap::BitmapImage, dib::ColorTable};
    for function in [0x0d33, 0x0f43] {
        for usage in [1u16, 2] {
            let mut body = fixture(function, true);
            let usage_offset = if function == 0x0d33 { 0 } else { 4 };
            body[usage_offset..usage_offset + 2].copy_from_slice(&usage.to_le_bytes());
            let header = if function == 0x0d33 { 18 } else { 22 };
            // Replace six RGB bytes with two palette WORDs, or no color table.
            body.splice(
                header + 12..header + 18,
                if usage == 1 { vec![3, 0, 7, 0] } else { vec![] },
            );
            let bytes = document(function, &body);
            let doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
            let mut value = typed(&doc);
            let image = value.typed_image(&ParseLimits::default()).unwrap().unwrap();
            match &image {
                BitmapImage::Dib(dib) if usage == 1 => {
                    assert_eq!(dib.colors, ColorTable::PaletteIndices(vec![3, 7]))
                }
                BitmapImage::Dib(dib) => assert_eq!(dib.colors, ColorTable::None),
                other => panic!("{other:?}"),
            }
            let original = value.clone();
            value.replace_image(image).unwrap();
            assert_eq!(value, original);
        }
    }
    for function in [0x0922, 0x0940] {
        let bytes = document(function, &fixture(function, true));
        let doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
        let value = typed(&doc);
        for (limits, expected) in [
            (
                ParseLimits {
                    max_input_bytes: 1,
                    ..ParseLimits::default()
                },
                LimitKind::InputBytes,
            ),
            (
                ParseLimits {
                    max_allocated_bytes: 0,
                    ..ParseLimits::default()
                },
                LimitKind::AllocatedBytes,
            ),
            (
                ParseLimits {
                    max_work_units: 0,
                    ..ParseLimits::default()
                },
                LimitKind::WorkUnits,
            ),
        ] {
            assert!(
                matches!(value.typed_image(&limits), Err(ParseFailure::LimitExceeded { kind, .. }) if kind == expected)
            );
        }
    }
}

#[test]
fn typed_replacement_rejects_invalid_kind_usage_and_discriminator_atomically() {
    use wmf::{
        bitmap::BitmapImage,
        dib::{Bitmap16, ColorTable, Dib},
    };
    let limits = ParseLimits::default();
    let bitmap = BitmapImage::Bitmap16(Bitmap16::parse(&bitmap16(), &limits).unwrap().unwrap());
    let dib = BitmapImage::Dib(Dib::parse(&dib(), 0, &limits).unwrap().unwrap());
    for function in [0x0922, 0x0940, 0x0b23, 0x0b41, 0x0d33, 0x0f43] {
        let doc = wmf::parse(&document(function, &fixture(function, true)), &limits).unwrap();
        let mut value = typed(&doc);
        let original = value.clone();
        let wrong_kind = if matches!(function & 0xff, 0x22 | 0x23) {
            dib.clone()
        } else {
            bitmap.clone()
        };
        assert!(matches!(
            value.replace_image(wrong_kind),
            Err(EditFailure::RecordLayout { .. })
        ));
        assert_eq!(value, original);
        let mut invalid_image = value.typed_image(&limits).unwrap().unwrap();
        match &mut invalid_image {
            BitmapImage::Bitmap16(v) => v.pixels.clear(),
            BitmapImage::Dib(v) => v.pixels.clear(),
            BitmapImage::Absent => unreachable!(),
        }
        assert!(value.replace_image(invalid_image).is_err());
        assert_eq!(value, original);
        if matches!(function, 0x0d33 | 0x0f43) {
            assert!(value.replace_image(BitmapImage::Absent).is_err());
            assert_eq!(value, original);
        } else {
            let original_image = value.typed_image(&limits).unwrap().unwrap();
            value.replace_image(BitmapImage::Absent).unwrap();
            assert_eq!(
                value.typed_image(&limits).unwrap(),
                Some(BitmapImage::Absent)
            );
            value.replace_image(original_image).unwrap();
            assert_eq!(value, original);
        }
    }
    let mut value = typed(&wmf::parse(&document(0x0940, &fixture(0x0940, true)), &limits).unwrap());
    let mut wrong_usage = match dib.clone() {
        BitmapImage::Dib(d) => d,
        _ => unreachable!(),
    };
    wrong_usage.colors = ColorTable::None;
    let original = value.clone();
    assert!(value.replace_image(BitmapImage::Dib(wrong_usage)).is_err());
    assert_eq!(value, original);
    if let BitmapRecord::DibBitBlt(v) = &mut value {
        v.function = 0x1440;
    }
    let original = value.clone();
    // 16 header bytes + 22 DIB bytes equals 19 WORDs; make the high byte 19.
    if let BitmapRecord::DibBitBlt(v) = &mut value {
        v.function = 0x1340;
    }
    let ambiguous = value.clone();
    assert!(value.replace_image(dib).is_err());
    assert_eq!(value, ambiguous);
    value = original;
    let original = value.clone();
    assert!(value.replace_image(BitmapImage::Absent).is_err());
    assert_eq!(value, original);
}
