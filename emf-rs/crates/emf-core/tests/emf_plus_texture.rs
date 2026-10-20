use emf_core::{
    emf_plus::{self, ObjectData, ObjectDefinition},
    ParseLimits, SerializeLimits,
};
fn words(v: &[u32]) -> Vec<u8> {
    v.iter().flat_map(|n| n.to_le_bytes()).collect()
}
fn definition(bytes: Vec<u8>) -> ObjectDefinition {
    ObjectDefinition {
        id: 1,
        object_type: 1,
        first_record: 7,
        last_record: 7,
        bytes,
    }
}
fn brush(flags: u32, image: u32) -> Vec<u8> {
    let mut b = words(&[0xdbc01002, 2, flags, 0xffffffff]);
    if flags & 2 != 0 {
        b.extend(words(&[0x80000000, 0x7fc01234, 3, 4, 5, 6]));
    }
    match image {
        0 => {}
        1 => {
            b.extend(words(&[0xdbc01002, 1, 17, 19, 0xfffffff0, 0x12345678, 0]));
            b.extend([0xa1, 0xb2, 0xc3]);
        }
        2 => {
            b.extend(words(&[0xdbc01002, 2, 0x12345678, 3]));
            b.extend([0xa1, 0xb2, 0xc3, 0xdd, 0xee]);
        }
        _ => unreachable!(),
    };
    b
}
#[test]
fn texture_is_typed_and_exact() {
    let bytes = brush(0, 0);
    let v = definition(bytes.clone())
        .decode(&ParseLimits::default())
        .unwrap();
    assert!(!matches!(v, ObjectData::Opaque { .. }));
    assert_eq!(v.serialize(&SerializeLimits::default()).unwrap(), bytes);
}
fn exact(bytes: Vec<u8>) -> ObjectData {
    let v = definition(bytes.clone())
        .decode(&ParseLimits::default())
        .unwrap();
    assert!(matches!(v, ObjectData::TextureBrush { .. }));
    assert_eq!(v.serialize(&SerializeLimits::default()).unwrap(), bytes);
    v
}
#[test]
fn every_flag_combination_and_image_form_preserves_raw_bits() {
    for flags in [0, 2, 0x80, 0x82, 0x100, 0x102, 0x180, 0x182] {
        for image in 0..3 {
            let ObjectData::TextureBrush { data, .. } = exact(brush(flags, image)) else {
                panic!()
            };
            assert_eq!(data.wrap_mode, -1);
            if let Some(t) = data.transform {
                assert_eq!(t, [0x80000000, 0x7fc01234, 3, 4, 5, 6]);
            }
            match data.image {
                None => assert_eq!(image, 0),
                Some(emf_plus::TextureImage::Bitmap {
                    stride,
                    pixel_format,
                    data,
                    ..
                }) => {
                    assert_eq!(stride, -16);
                    assert_eq!(pixel_format, 0x12345678);
                    assert_eq!(data, [0xa1, 0xb2, 0xc3]);
                }
                Some(emf_plus::TextureImage::PixelBitmap(_)) => {
                    panic!("unknown format must stay raw")
                }
                Some(emf_plus::TextureImage::Metafile {
                    metafile_type,
                    data,
                    suffix,
                    ..
                }) => {
                    assert_eq!(metafile_type, 0x12345678);
                    assert_eq!(data, [0xa1, 0xb2, 0xc3]);
                    assert_eq!(suffix, [0xdd, 0xee]);
                }
            }
        }
    }
}
#[test]
fn image_payload_edits_grow_shrink_and_reach_nested_pen() {
    for image in [1, 2] {
        let mut v = exact(brush(0x182, image));
        let ObjectData::TextureBrush { data, .. } = &mut v else {
            panic!()
        };
        match data.image.as_mut().unwrap() {
            emf_plus::TextureImage::PixelBitmap(_) => panic!("unknown format must stay raw"),
            emf_plus::TextureImage::Bitmap { data, .. }
            | emf_plus::TextureImage::Metafile { data, .. } => data.extend([7, 8, 9, 10]),
        };
        let grown = v.serialize(&SerializeLimits::default()).unwrap();
        assert_eq!(grown.len(), brush(0x182, image).len() + 4);
        assert_eq!(exact(grown.clone()), v);
        let mut p = words(&[1, 0, 0, 0, 0]);
        p.extend(grown);
        let mut d = definition(p.clone());
        d.object_type = 2;
        let mut v = d.decode(&ParseLimits::default()).unwrap();
        assert_eq!(v.serialize(&SerializeLimits::default()).unwrap(), p);
        let ObjectData::Pen(pen) = &mut v else {
            panic!()
        };
        let emf_plus::PenBrushData::Texture(t) = &mut pen.brush.data else {
            panic!()
        };
        match t.image.as_mut().unwrap() {
            emf_plus::TextureImage::PixelBitmap(_) => panic!("unknown format must stay raw"),
            emf_plus::TextureImage::Bitmap { data, .. }
            | emf_plus::TextureImage::Metafile { data, .. } => data.truncate(3),
        };
        d.bytes = v.serialize(&SerializeLimits::default()).unwrap();
        assert_eq!(d.bytes.len(), p.len() - 4);
        assert_eq!(d.decode(&ParseLimits::default()).unwrap(), v);
        t_remove(&mut v);
        d.bytes = v.serialize(&SerializeLimits::default()).unwrap();
        assert_eq!(d.bytes, [words(&[1, 0, 0, 0, 0]), brush(0x182, 0)].concat());
        assert_eq!(d.decode(&ParseLimits::default()).unwrap(), v);
    }
    fn t_remove(v: &mut ObjectData) {
        let ObjectData::Pen(p) = v else { panic!() };
        let emf_plus::PenBrushData::Texture(t) = &mut p.brush.data else {
            panic!()
        };
        t.image = None;
    }
}
#[test]
fn unknown_flags_and_nested_image_types_preserve_the_whole_object() {
    for mut bytes in [brush(1, 0), brush(4, 1), brush(0x200, 2), brush(2, 1)] {
        if bytes == brush(2, 1) {
            bytes[44..48].copy_from_slice(&0x12345678u32.to_le_bytes());
        }
        for pen in [false, true] {
            let mut d = definition(bytes.clone());
            if pen {
                d.object_type = 2;
                d.bytes = [words(&[1, 0, 0, 0, 0]), d.bytes].concat();
            }
            let v = d.decode(&ParseLimits::default()).unwrap();
            assert!(matches!(v, ObjectData::Opaque { .. }));
            assert_eq!(v.serialize(&SerializeLimits::default()).unwrap(), d.bytes);
        }
    }
}
#[test]
fn malformed_image_headers_lengths_and_inconsistent_edits_fail() {
    for image in [1, 2] {
        let b = brush(2, image);
        for n in 0..b.len() {
            if n == 40 || (image == 1 && n >= 68) || (image == 2 && n >= 59) {
                continue;
            }
            assert!(
                definition(b[..n].to_vec())
                    .decode(&ParseLimits::default())
                    .is_err(),
                "{image}/{n}"
            );
        }
    }
    for count in [4, u32::MAX] {
        let mut b = brush(2, 2);
        b[52..56].copy_from_slice(&count.to_le_bytes());
        if count == 4 {
            b.pop();
            b.pop();
        }
        assert!(definition(b).decode(&ParseLimits::default()).is_err());
    }
    let mut b = brush(0, 2);
    b.extend([1, 2]);
    assert!(definition(b).decode(&ParseLimits::default()).is_err());
    for edit in 0..3 {
        let mut v = exact(brush(2, 2));
        let ObjectData::TextureBrush { data, .. } = &mut v else {
            panic!()
        };
        match edit {
            0 => data.flags |= 4,
            1 => data.transform = None,
            2 => {
                let Some(emf_plus::TextureImage::Metafile { suffix, .. }) = &mut data.image else {
                    panic!()
                };
                suffix.extend([1, 2]);
            }
            _ => unreachable!(),
        };
        assert!(matches!(
            v.serialize(&SerializeLimits::default()),
            Err(emf_core::SerializeFailure::Inconsistent { .. })
        ));
    }
}
#[test]
fn shared_budgets_include_image_payload_and_nested_pen() {
    use emf_core::{emf_plus, LimitKind, ParseFailure, SerializeFailure};
    let bytes = brush(2, 2);
    let allocated = 5;
    let mut limits = ParseLimits {
        max_allocated_bytes: allocated - 1,
        ..ParseLimits::default()
    };
    assert!(matches!(
        definition(bytes.clone()).decode(&limits),
        Err(emf_plus::Error::Resource(ParseFailure::LimitExceeded {
            kind: LimitKind::AllocatedBytes,
            ..
        }))
    ));
    limits.max_allocated_bytes = allocated;
    let value = definition(bytes.clone()).decode(&limits).unwrap();
    for limits in [
        SerializeLimits {
            max_output_bytes: bytes.len() - 1,
            ..SerializeLimits::default()
        },
        SerializeLimits {
            max_work_units: 0,
            ..SerializeLimits::default()
        },
    ] {
        assert!(matches!(
            value.serialize(&limits),
            Err(SerializeFailure::LimitExceeded { .. })
        ));
    }
    assert_eq!(
        value
            .serialize(&SerializeLimits {
                max_output_bytes: bytes.len(),
                ..SerializeLimits::default()
            })
            .unwrap(),
        bytes
    );
    for nested in [false, true] {
        for kind in [
            LimitKind::InputBytes,
            LimitKind::RecordBytes,
            LimitKind::RecordCount,
            LimitKind::WorkUnits,
        ] {
            let mut d = definition(bytes.clone());
            if nested {
                let mut p = words(&[1, 0, 0, 0, 0]);
                p.extend(&d.bytes);
                d.bytes = p;
                d.object_type = 2;
            }
            let mut limits = ParseLimits::default();
            match kind {
                LimitKind::InputBytes => limits.max_input_bytes = 0,
                LimitKind::RecordBytes => limits.max_record_bytes = 0,
                LimitKind::RecordCount => limits.max_records = 0,
                LimitKind::WorkUnits => limits.max_work_units = 0,
                _ => unreachable!(),
            }
            assert!(
                matches!(d.decode(&limits),Err(emf_plus::Error::Resource(ParseFailure::LimitExceeded{kind:k,..})) if k==kind)
            );
        }
    }
}
#[test]
fn texture_edit_preserves_continuations_segments_unknowns_and_padding() {
    fn record(kind: u16, flags: u16, data: &[u8], pad: &[u8]) -> Vec<u8> {
        let mut b = kind.to_le_bytes().to_vec();
        b.extend(flags.to_le_bytes());
        b.extend(words(&[
            (12 + data.len() + pad.len()) as u32,
            data.len() as u32,
        ]));
        b.extend(data);
        b.extend(pad);
        b
    }
    let body = brush(0x182, 2);
    let mut first = words(&[body.len() as u32]);
    first.extend(&body[..7]);
    let mut wire = record(0x7777, 0xabcd, &[1, 2, 3], &[0xee]);
    wire.extend(record(0x4008, 0x8101, &first, &[0xa5]));
    let last = wire.len();
    wire.extend(record(0x4008, 0x0101, &body[7..], &[0x17, 0x18]));
    let limits = ParseLimits::default();
    let mut stream = emf_plus::parse_segments(&[&wire[..5], &[], &wire[5..]], &limits).unwrap();
    let def = stream.object_definitions(&limits).unwrap().remove(0);
    let mut value = def.decode(&limits).unwrap();
    let ObjectData::TextureBrush { data: p, .. } = &mut value else {
        panic!()
    };
    p.wrap_mode = 0x7fc05678;
    stream
        .replace_object_bytes(
            def.first_record,
            &value.serialize(&SerializeLimits::default()).unwrap(),
            &limits,
        )
        .unwrap();
    let segments = emf_plus::serialize_segments(&stream, &SerializeLimits::default()).unwrap();
    assert_eq!(
        segments.iter().map(Vec::len).collect::<Vec<_>>(),
        vec![5, 0, wire.len() - 5]
    );
    wire[last + 12 + 12 - 7..last + 12 + 16 - 7].copy_from_slice(&0x7fc05678u32.to_le_bytes());
    assert_eq!(segments.concat(), wire);
}
