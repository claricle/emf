use emf_core::{
    emf_plus::{self as plus, ObjectData, ObjectDefinition, Palette, PixelBitmap, TextureImage},
    LimitKind, ParseLimits, SerializeLimits,
};
fn words(v: &[u32]) -> Vec<u8> {
    v.iter().flat_map(|n| n.to_le_bytes()).collect()
}
fn definition(kind: u8, bytes: Vec<u8>) -> ObjectDefinition {
    ObjectDefinition {
        id: 0,
        object_type: kind,
        first_record: 0,
        last_record: 0,
        bytes,
    }
}
fn bitmap(format: u32) -> Vec<u8> {
    let mut b = words(&[0xdbc01002, 1, 0xffffffff, 2, 0xfffffff8, format, 0]);
    if format & 0x10000 != 0 {
        b.extend(words(&[0xdeadbeef, 2, 0xff112233, 0x80445566]));
    }
    b.extend([0x80, 0xa1, 0xb2, 0xc3]);
    b
}
fn exact(kind: u8, b: Vec<u8>) -> ObjectData {
    let v = definition(kind, b.clone())
        .decode(&ParseLimits::default())
        .unwrap();
    assert_eq!(v.serialize(&SerializeLimits::default()).unwrap(), b);
    v
}
#[test]
fn pixel_bitmap_is_structured() {
    let v = exact(5, bitmap(0x00030101));
    assert!(
        !matches!(v, ObjectData::BitmapImage { .. }),
        "known pixel BitmapData must expose its palette and pixel bytes"
    );
    let ObjectData::PixelBitmap(v) = v else {
        panic!()
    };
    assert_eq!(
        v.palette,
        Some(Palette {
            style_flags: 0xdeadbeef,
            entries: vec![0xff112233, 0x80445566]
        })
    );
    assert_eq!(v.pixels, [0x80, 0xa1, 0xb2, 0xc3]);
}
#[test]
fn every_format_and_ignored_bits_preserve_metadata_and_unexpanded_pixels() {
    for format in [
        0x00030101, 0x00030402, 0x00030803, 0x00101004, 0x00021005, 0x00021006, 0x00061007,
        0x00021808, 0x00022009, 0x0026200a, 0x000e200b, 0x0010300c, 0x0034400d, 0x001a400e,
    ] {
        for reserved in [0, 0xffc00000] {
            let ObjectData::PixelBitmap(v) = exact(5, bitmap(format | reserved)) else {
                panic!()
            };
            assert_eq!(
                (v.version, v.width, v.height, v.stride, v.pixel_format),
                (0xdbc01002, -1, 2, -8, format | reserved)
            );
            assert_eq!(v.palette.is_some(), format & 0x10000 != 0);
            assert_eq!(v.pixels, [0x80, 0xa1, 0xb2, 0xc3]);
        }
    }
}
fn nested(kind: u8, b: Vec<u8>) -> Vec<u8> {
    match kind {
        5 => b,
        1 => [
            words(&[
                0xdbc01002, 2, 0x182, 0xffffffff, 0x80000000, 0x7fc01234, 3, 4, 5, 6,
            ]),
            b,
        ]
        .concat(),
        2 => [words(&[1, 0, 0, 0, 0]), nested(1, b)].concat(),
        _ => unreachable!(),
    }
}
fn pixels(v: &mut ObjectData) -> &mut PixelBitmap {
    match v {
        ObjectData::PixelBitmap(p) => p,
        ObjectData::TextureBrush { data, .. } => match data.image.as_mut().unwrap() {
            TextureImage::PixelBitmap(p) => p,
            _ => panic!(),
        },
        ObjectData::Pen(p) => match &mut p.brush.data {
            plus::PenBrushData::Texture(t) => match t.image.as_mut().unwrap() {
                TextureImage::PixelBitmap(p) => p,
                _ => panic!(),
            },
            _ => panic!(),
        },
        _ => panic!(),
    }
}
#[test]
fn palette_and_pixel_edits_grow_shrink_in_images_texture_brushes_and_pens() {
    for kind in [5, 1, 2] {
        let mut v = exact(kind, nested(kind, bitmap(0x00030803)));
        for count in [6, 0, 3] {
            let p = pixels(&mut v);
            p.palette
                .as_mut()
                .unwrap()
                .entries
                .resize(count, 0x77112233);
            p.palette.as_mut().unwrap().style_flags = 0x12345678;
            p.pixels.resize(count * 4, 0xaa);
            p.width = 13;
            let b = v.serialize(&SerializeLimits::default()).unwrap();
            assert_eq!(exact(kind, b.clone()), v);
            let start = match kind {
                5 => 0,
                1 => 40,
                2 => 60,
                _ => unreachable!(),
            };
            assert_eq!(&b[start + 32..start + 36], &(count as u32).to_le_bytes());
        }
        let p = pixels(&mut v);
        p.pixel_format = 0x00022009;
        p.palette = None;
        let b = v.serialize(&SerializeLimits::default()).unwrap();
        assert_eq!(exact(kind, b), v);
    }
}
#[test]
fn compressed_unknown_formats_and_types_remain_raw() {
    for format in [0, 0x12345678, 0xdeadbeef, 0x00030102] {
        for kind in [5, 1, 2] {
            let v = exact(kind, nested(kind, bitmap(format)));
            if kind == 5 {
                assert!(matches!(v, ObjectData::BitmapImage { .. }));
            } else {
                let t = match &v {
                    ObjectData::TextureBrush { data, .. } => data,
                    ObjectData::Pen(p) => match &p.brush.data {
                        plus::PenBrushData::Texture(t) => t,
                        _ => panic!(),
                    },
                    _ => panic!(),
                };
                assert!(matches!(t.image, Some(TextureImage::Bitmap { .. })));
            }
        }
    }
    for bitmap_type in [1, 99, u32::MAX] {
        let mut b = bitmap(0x00030101);
        b[24..28].copy_from_slice(&bitmap_type.to_le_bytes());
        assert!(matches!(exact(5, b), ObjectData::BitmapImage { .. }));
    }
}
#[test]
fn truncated_palettes_excessive_counts_and_inconsistent_edits_fail() {
    let b = bitmap(0x00030101);
    for n in 0..44 {
        assert!(
            definition(5, b[..n].to_vec())
                .decode(&ParseLimits::default())
                .is_err(),
            "{n}"
        );
    }
    for count in [4, u32::MAX] {
        let mut bad = b.clone();
        bad[32..36].copy_from_slice(&count.to_le_bytes());
        assert!(definition(5, bad).decode(&ParseLimits::default()).is_err());
    }
    for edit in 0..3 {
        let mut v = exact(5, b.clone());
        let p = pixels(&mut v);
        match edit {
            0 => p.palette = None,
            1 => p.pixel_format = 0x00022009,
            2 => p.pixel_format = 0x12345678,
            _ => unreachable!(),
        }
        assert!(v.serialize(&SerializeLimits::default()).is_err());
    }
}
#[test]
fn nested_palette_vectors_and_bytes_share_all_resource_budgets() {
    for kind in [5, 1, 2] {
        let b = nested(kind, bitmap(0x00030101));
        let d = definition(kind, b.clone());
        for limit in [
            LimitKind::InputBytes,
            LimitKind::RecordBytes,
            LimitKind::RecordCount,
            LimitKind::AllocatedBytes,
            LimitKind::WorkUnits,
        ] {
            let mut limits = ParseLimits::default();
            match limit {
                LimitKind::InputBytes => limits.max_input_bytes = 0,
                LimitKind::RecordBytes => limits.max_record_bytes = 0,
                LimitKind::RecordCount => limits.max_records = 0,
                LimitKind::AllocatedBytes => limits.max_allocated_bytes = 0,
                LimitKind::WorkUnits => limits.max_work_units = 0,
                _ => unreachable!(),
            }
            assert!(
                matches!(d.decode(&limits),Err(plus::Error::Resource(emf_core::ParseFailure::LimitExceeded{kind,..})) if kind==limit)
            );
        }
        let mut limits = ParseLimits {
            max_allocated_bytes: 12,
            ..Default::default()
        };
        let v = d.decode(&limits).unwrap();
        limits.max_allocated_bytes = 11;
        assert!(d.decode(&limits).is_err());
        let mut exact_work = 0;
        loop {
            limits = ParseLimits {
                max_work_units: exact_work,
                ..Default::default()
            };
            if d.decode(&limits).is_ok() {
                break;
            }
            exact_work += 1;
            assert!(exact_work < 1000);
        }
        limits.max_work_units -= 1;
        assert!(d.decode(&limits).is_err());
        assert_eq!(
            v.serialize(&SerializeLimits {
                max_output_bytes: b.len(),
                ..Default::default()
            })
            .unwrap(),
            b
        );
        assert!(v
            .serialize(&SerializeLimits {
                max_output_bytes: b.len() - 1,
                ..Default::default()
            })
            .is_err());
        let mut exact_work = 0;
        loop {
            if v.serialize(&SerializeLimits {
                max_work_units: exact_work,
                ..Default::default()
            })
            .is_ok()
            {
                break;
            }
            exact_work += 1;
            assert!(exact_work < 1000);
        }
        assert!(v
            .serialize(&SerializeLimits {
                max_work_units: exact_work - 1,
                ..Default::default()
            })
            .is_err());
    }
}
fn record(kind: u16, flags: u16, data: &[u8]) -> Vec<u8> {
    let padding = (4 - data.len() % 4) % 4;
    let mut b = kind.to_le_bytes().to_vec();
    b.extend(flags.to_le_bytes());
    b.extend(((12 + data.len() + padding) as u32).to_le_bytes());
    b.extend((data.len() as u32).to_le_bytes());
    b.extend(data);
    b.extend(vec![0xa7; padding]);
    b
}
fn stream_bytes() -> Vec<u8> {
    let b = bitmap(0x00030101);
    let first = [words(&[b.len() as u32]), b[..13].to_vec()].concat();
    [
        record(0x4008, 0x8500, &first),
        record(0x4008, 0x0500, &b[13..]),
        record(0x7fff, 0xabcdefu32 as u16, &[0xf1, 0xf2, 0xf3]),
    ]
    .concat()
}
#[test]
fn continuation_edit_preserves_unknowns_padding_and_untouched_segments() {
    let b = stream_bytes();
    let mut s = plus::parse_segments(&[&b[..5], &[], &b[5..]], &Default::default()).unwrap();
    assert_eq!(
        plus::serialize_segments(&s, &Default::default()).unwrap(),
        vec![b[..5].to_vec(), vec![], b[5..].to_vec()]
    );
    let original = s.clone();
    let d = s.object_definitions(&Default::default()).unwrap().remove(0);
    let mut v = d.decode(&Default::default()).unwrap();
    pixels(&mut v).palette.as_mut().unwrap().entries[1] = 0x44332211;
    s.replace_object_bytes(
        0,
        &v.serialize(&Default::default()).unwrap(),
        &Default::default(),
    )
    .unwrap();
    assert_eq!(s.records[2], original.records[2]);
    assert_eq!(s.records[0].padding, original.records[0].padding);
    assert_eq!(s.records[1].padding, original.records[1].padding);
    let parsed = plus::parse(&plus::serialize(&s).unwrap(), &Default::default()).unwrap();
    assert_eq!(
        parsed.object_definitions(&Default::default()).unwrap()[0]
            .decode(&Default::default())
            .unwrap(),
        v
    );
}
fn comment(data: &[u8]) -> Vec<u8> {
    let size = (12 + data.len() + 3) & !3;
    let mut b = words(&[70, size as u32, data.len() as u32]);
    b.extend(data);
    b.resize(size, 0xb9);
    b
}
#[test]
fn bitmap_palette_repack_is_atomic_stale_checked_and_preserves_unrelated_comments() {
    let logical = stream_bytes();
    let mut wire = vec![0; 88];
    wire[..4].copy_from_slice(&1u32.to_le_bytes());
    wire[4..8].copy_from_slice(&88u32.to_le_bytes());
    wire[40..44].copy_from_slice(&0x464d4520u32.to_le_bytes());
    for part in [&logical[..7], &logical[7..7], &logical[7..]] {
        wire.extend(comment(&[b"EMF+", part].concat()));
        wire.extend(comment(b"unrelated"));
    }
    wire.extend([
        14, 0, 0, 0, 20, 0, 0, 0, 0, 0, 0, 0, 16, 0, 0, 0, 20, 0, 0, 0,
    ]);
    let size = wire.len() as u32;
    wire[48..52].copy_from_slice(&size.to_le_bytes());
    wire[52..56].copy_from_slice(&8u32.to_le_bytes());
    let mut d = emf_core::parse(&wire, &Default::default()).unwrap();
    let original = d.clone();
    let untouched = d.structured_emf_plus(&Default::default()).unwrap();
    d.apply_structured_emf_plus(&untouched, &Default::default())
        .unwrap();
    assert_eq!(emf_core::serialize(&d).unwrap(), wire);
    for count in [8, 0] {
        let mut snapshot = d.structured_emf_plus(&Default::default()).unwrap();
        let def = snapshot
            .stream
            .object_definitions(&Default::default())
            .unwrap()
            .remove(0);
        let mut v = def.decode(&Default::default()).unwrap();
        pixels(&mut v)
            .palette
            .as_mut()
            .unwrap()
            .entries
            .resize(count, 0x77112233);
        pixels(&mut v).pixels.resize(count * 4, 0xa3);
        // Size-changing edits explicitly retain this object's two-fragment layout.
        let body = v.serialize(&Default::default()).unwrap();
        let plus::RecordData::Object(first) = &mut snapshot.stream.records[0].data else {
            panic!("first object fragment")
        };
        first.total_size = Some(body.len() as u32);
        first.bytes = body[..13].to_vec();
        let plus::RecordData::Object(last) = &mut snapshot.stream.records[1].data else {
            panic!("last object fragment")
        };
        last.bytes = body[13..].to_vec();
        let before = d.clone();
        assert!(d
            .apply_structured_emf_plus(
                &snapshot,
                &SerializeLimits {
                    max_output_bytes: 0,
                    ..Default::default()
                }
            )
            .is_err());
        assert_eq!(d, before);
        d.apply_structured_emf_plus(&snapshot, &Default::default())
            .unwrap();
        let parsed =
            emf_core::parse(&emf_core::serialize(&d).unwrap(), &Default::default()).unwrap();
        let s = parsed.structured_emf_plus(&Default::default()).unwrap();
        assert_eq!(
            s.stream.object_definitions(&Default::default()).unwrap()[0]
                .decode(&Default::default())
                .unwrap(),
            v
        );
        for i in [1, 3, 5, 6] {
            assert_eq!(d.records()[i], original.records()[i]);
        }
        assert_eq!(s.stream.records.last(), untouched.stream.records.last());
        let before = d.clone();
        assert_eq!(
            d.apply_structured_emf_plus(&snapshot, &Default::default()),
            Err(plus::EmbedError::StaleSource)
        );
        assert_eq!(d, before);
    }
}
