use emf_core::{
    emf_plus::{
        self, CustomLineCap, CustomLineCapData, ObjectData, ObjectDefinition, PathPointTypes,
        PenBrushData, PointData,
    },
    LimitKind, ParseFailure, ParseLimits, SerializeFailure, SerializeLimits,
};
fn words(v: &[u32]) -> Vec<u8> {
    v.iter().flat_map(|n| n.to_le_bytes()).collect()
}
fn definition(bytes: Vec<u8>) -> ObjectDefinition {
    ObjectDefinition {
        id: 1,
        object_type: 2,
        first_record: 7,
        last_record: 7,
        bytes,
    }
}
fn exact(bytes: Vec<u8>) -> ObjectData {
    let v = definition(bytes.clone())
        .decode(&ParseLimits::default())
        .unwrap();
    assert_eq!(v.object_type(), 2);
    assert_eq!(v.serialize(&SerializeLimits::default()).unwrap(), bytes);
    v
}
fn cap() -> Vec<u8> {
    let mut b = words(&[
        0xdbc01002, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 20, 0xdbc01002, 1, 0x4000,
    ]);
    b.extend([0xff, 0xff, 0, 0x80, 0x81, 0xaa, 0xbb, 0xcc]);
    b
}
fn arrow() -> Vec<u8> {
    words(&[
        0xdbc01002, 1, 0x7fc01234, 0x80000000, 0x7f800000, 0x12345678, 5, 6, 7, 8, 9, 10, 11, 12,
        13,
    ])
}
fn pen(flags: u32, hatch: bool) -> Vec<u8> {
    let mut b = words(&[0xdbc01002, 0, flags, 2, 0x80000000]);
    if flags & 1 != 0 {
        b.extend(words(&[1, 2, 3, 4, 5, 0x7fc01234]));
    }
    for i in 1..8 {
        if flags & (1 << i) != 0 {
            b.extend(words(&[0x80000000 + i]));
        }
    }
    if flags & 0x100 != 0 {
        b.extend(words(&[2, 0x7fc01234, 0x80000000]));
    }
    if flags & 0x200 != 0 {
        b.extend(words(&[0xffffffff]));
    }
    if flags & 0x400 != 0 {
        b.extend(words(&[3, 0, 0x3f800000, 0x7f800000]));
    }
    for (flag, c) in [(0x800, cap()), (0x1000, arrow())] {
        if flags & flag != 0 {
            b.extend(words(&[c.len() as u32]));
            b.extend(c);
        }
    }
    b.extend(if hatch {
        words(&[0xdbc01001, 1, 0x12345678, 0xff112233, 0xff445566])
    } else {
        words(&[0xdbc01002, 0, 0xff123456])
    });
    b
}
#[test]
fn pen_is_typed() {
    assert!(!matches!(exact(pen(0, false)), ObjectData::Opaque { .. }));
}
#[test]
fn every_optional_field_and_brush_preserves_bits_and_order() {
    for flags in std::iter::once(0)
        .chain((0..13).map(|i| 1 << i))
        .chain([0x1fff])
    {
        for hatch in [false, true] {
            let ObjectData::Pen(v) = exact(pen(flags, hatch)) else {
                panic!()
            };
            assert_eq!(v.flags, flags);
            assert_eq!(v.width, 0x80000000);
            assert_eq!(v.custom_caps.len(), (flags & 0x1800).count_ones() as usize);
        }
    }
    let ObjectData::Pen(v) = exact(pen(0x1fff, true)) else {
        panic!()
    };
    assert_eq!(v.start_cap, Some(0x80000001u32 as i32));
    assert_eq!(v.dash_offset, Some(0x80000007));
    assert_eq!(v.alignment, Some(-1));
    assert_eq!(v.dash_pattern, Some(vec![0x7fc01234, 0x80000000]));
    assert!(matches!(
        v.brush.data,
        PenBrushData::Hatch {
            style: 0x12345678,
            ..
        }
    ));
}
#[test]
fn edits_derive_array_and_nested_cap_lengths() {
    let mut v = exact(pen(0x1fff, false));
    let ObjectData::Pen(p) = &mut v else { panic!() };
    p.dash_pattern.as_mut().unwrap().extend([1, 2, 3]);
    p.compound_line.as_mut().unwrap().clear();
    let CustomLineCapData::Default(c) = &mut p.custom_caps[0].data else {
        panic!()
    };
    let path = c.fill_path.as_mut().unwrap();
    let PointData::Integer(points) = &mut path.points else {
        panic!()
    };
    points.push([123, -456]);
    let PathPointTypes::Plain(types) = &mut path.point_types else {
        panic!()
    };
    types.push(1);
    path.alignment_padding = vec![0x99, 0x88];
    p.brush.data = PenBrushData::Hatch {
        style: 4,
        foreground: 5,
        background: 6,
    };
    let bytes = v.serialize(&SerializeLimits::default()).unwrap();
    assert_eq!(exact(bytes.clone()), v);
    // Re-parse to verify the cap length ends exactly at the following arrow cap and brush.
    let ObjectData::Pen(p) = definition(bytes).decode(&ParseLimits::default()).unwrap() else {
        panic!()
    };
    assert_eq!(p.dash_pattern.unwrap().len(), 5);
    assert_eq!(p.compound_line, Some(vec![]));
    assert_eq!(p.custom_caps.len(), 2);
    let mut shrink = v;
    let ObjectData::Pen(p) = &mut shrink else {
        panic!()
    };
    let CustomLineCapData::Default(c) = &mut p.custom_caps[0].data else {
        panic!()
    };
    c.flags = 0;
    c.fill_path = None;
    let smaller = shrink.serialize(&SerializeLimits::default()).unwrap();
    assert_eq!(exact(smaller), shrink);
}
#[test]
fn unknown_pen_flags_types_brushes_and_caps_remain_wholly_opaque() {
    let base = pen(0, false);
    for (offset, word) in [(4, 1u32), (8, 0x2000), (24, 2)] {
        let mut b = base.clone();
        b[offset..offset + 4].copy_from_slice(&word.to_le_bytes());
        assert!(matches!(exact(b), ObjectData::Opaque { .. }));
    }
    for (offset, word) in [(28, 99u32), (32, 4)] {
        let mut b = pen(0x800, false);
        b[offset..offset + 4].copy_from_slice(&word.to_le_bytes());
        assert!(matches!(exact(b), ObjectData::Opaque { .. }));
    }
}
#[test]
fn malformed_lengths_counts_and_inconsistent_edits_fail() {
    for full in [pen(0, false), pen(0x1fff, true)] {
        for len in 0..full.len() {
            assert!(
                matches!(
                    definition(full[..len].to_vec()).decode(&ParseLimits::default()),
                    Err(emf_plus::Error::InvalidObject { .. })
                ),
                "prefix {len}/{}",
                full.len()
            );
        }
        let mut suffix = full;
        suffix.push(0);
        assert!(definition(suffix).decode(&ParseLimits::default()).is_err());
    }
    for flags in [0x100, 0x400] {
        let mut b = pen(flags, false);
        b[20..24].copy_from_slice(&u32::MAX.to_le_bytes());
        assert!(definition(b).decode(&ParseLimits::default()).is_err());
    }
    for len in [0u32, 75, 77, 81, 0x80000000, u32::MAX] {
        let mut b = pen(0x800, false);
        b[20..24].copy_from_slice(&len.to_le_bytes());
        assert!(definition(b).decode(&ParseLimits::default()).is_err());
    }
    for edit in 0..4 {
        let mut v = exact(pen(0x1fff, false));
        let ObjectData::Pen(p) = &mut v else { panic!() };
        match edit {
            0 => p.flags |= 0x2000,
            1 => p.transform = None,
            2 => p.dash_pattern = None,
            3 => {
                p.custom_caps.pop();
            }
            _ => unreachable!(),
        };
        assert!(matches!(
            v.serialize(&SerializeLimits::default()),
            Err(SerializeFailure::Inconsistent { .. })
        ));
    }
}
#[test]
fn arrays_and_caps_share_all_resource_budgets() {
    let b = pen(0x1fff, false);
    for kind in [
        LimitKind::InputBytes,
        LimitKind::RecordBytes,
        LimitKind::RecordCount,
        LimitKind::AllocatedBytes,
        LimitKind::WorkUnits,
    ] {
        let mut limits = ParseLimits::default();
        match kind {
            LimitKind::InputBytes => limits.max_input_bytes = 0,
            LimitKind::RecordBytes => limits.max_record_bytes = 0,
            LimitKind::RecordCount => limits.max_records = 0,
            LimitKind::AllocatedBytes => limits.max_allocated_bytes = 0,
            LimitKind::WorkUnits => limits.max_work_units = 0,
            _ => unreachable!(),
        };
        assert!(
            matches!(definition(b.clone()).decode(&limits),Err(emf_plus::Error::Resource(ParseFailure::LimitExceeded{kind:k,..})) if k==kind)
        );
    }
    // Five float words, two cap structs and one eight-byte Path owned buffer.
    let allocated = 20 + 2 * std::mem::size_of::<CustomLineCap>() + 8;
    let mut limits = ParseLimits {
        max_allocated_bytes: allocated - 1,
        ..ParseLimits::default()
    };
    assert!(matches!(
        definition(b.clone()).decode(&limits),
        Err(emf_plus::Error::Resource(ParseFailure::LimitExceeded {
            kind: LimitKind::AllocatedBytes,
            ..
        }))
    ));
    limits.max_allocated_bytes = allocated;
    let value = definition(b.clone()).decode(&limits).unwrap();
    for limits in [
        SerializeLimits {
            max_output_bytes: b.len() - 1,
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
                max_output_bytes: b.len(),
                ..SerializeLimits::default()
            })
            .unwrap(),
        b
    );
}
#[test]
fn typed_pen_edit_preserves_continuations_segments_unknowns_and_padding() {
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
    let body = pen(0x1fff, false);
    let mut first = words(&[body.len() as u32]);
    first.extend(&body[..7]);
    let mut wire = record(0x7777, 0xabcd, &[1, 2, 3], &[0xee]);
    wire.extend(record(0x4008, 0x8201, &first, &[0xa5]));
    let last = wire.len();
    wire.extend(record(0x4008, 0x0201, &body[7..], &[0x17, 0x18, 0x19]));
    let limits = ParseLimits::default();
    let mut stream = emf_plus::parse_segments(&[&wire[..5], &[], &wire[5..]], &limits).unwrap();
    let def = stream.object_definitions(&limits).unwrap().remove(0);
    let mut value = def.decode(&limits).unwrap();
    let ObjectData::Pen(p) = &mut value else {
        panic!()
    };
    p.width = 0x7fc05678;
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
    wire[last + 12 + 16 - 7..last + 12 + 20 - 7].copy_from_slice(&0x7fc05678u32.to_le_bytes());
    assert_eq!(segments.concat(), wire);
}
