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
fn brush(flags: u32) -> Vec<u8> {
    let mut b = words(&[
        0xdbc01002, 3, flags, 0xffffffff, 0xff123456, 0x80000000, 0x7fc01234, 2, 0xff112233,
        0xff445566,
    ]);
    if flags & 1 != 0 {
        b.extend(words(&[20, 0xdbc01002, 1, 0x4000]));
        b.extend([0xff, 0xff, 0, 0x80, 0x81, 0xaa, 0xbb, 0xcc]);
    } else {
        b.extend(words(&[2, 0, 0x80000000, 0x7fc01234, 0x3f800000]));
    }
    if flags & 2 != 0 {
        b.extend(words(&[1, 2, 3, 4, 5, 0x7f800000]));
    }
    if flags & 0xc != 0 {
        b.extend(words(&[2, 0, 0x3f800000, 0x12345678, 0xabcdef01]));
    }
    if flags & 0x40 != 0 {
        b.extend(words(&[2, 0x80000000, 0x7fc01234]));
    }
    b
}
#[test]
fn path_gradient_is_typed_and_exact() {
    let bytes = brush(0);
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
    assert!(matches!(v, ObjectData::PathGradientBrush { .. }));
    assert_eq!(v.serialize(&SerializeLimits::default()).unwrap(), bytes);
    v
}
#[test]
fn every_optional_combination_preserves_boundary_and_raw_bits() {
    for boundary in [0, 1] {
        for transform in [0, 2] {
            for gamma in [0, 0x80] {
                for focus in [0, 0x40] {
                    for blend in [0, 4, 8] {
                        let flags = boundary | transform | gamma | focus | blend;
                        let ObjectData::PathGradientBrush { data, .. } = exact(brush(flags)) else {
                            panic!()
                        };
                        assert_eq!(data.center_point, [0x80000000, 0x7fc01234]);
                        assert_eq!(data.surrounding_colors, [0xff112233, 0xff445566]);
                        match data.boundary {
                            emf_plus::GradientBoundary::Path(p) => {
                                assert_eq!(p.alignment_padding, [0xaa, 0xbb, 0xcc]);
                                assert_eq!(
                                    p.points,
                                    emf_plus::PointData::Integer(vec![[-1, -32768]])
                                );
                            }
                            emf_plus::GradientBoundary::Points(p) => {
                                assert_eq!(p, [[0, 0x80000000], [0x7fc01234, 0x3f800000]])
                            }
                        }
                        if let Some(b) = data.blend {
                            assert_eq!(b, [[0, 0x12345678], [0x3f800000, 0xabcdef01]]);
                        }
                    }
                }
            }
        }
    }
}
#[test]
fn counts_and_nested_pen_brush_grow_and_shrink() {
    let mut v = exact(brush(0xca));
    let ObjectData::PathGradientBrush { data, .. } = &mut v else {
        panic!()
    };
    data.surrounding_colors.push(7);
    let emf_plus::GradientBoundary::Points(p) = &mut data.boundary else {
        panic!()
    };
    p.push([8, 9]);
    data.blend.as_mut().unwrap().push([10, 11]);
    let grown = v.serialize(&SerializeLimits::default()).unwrap();
    assert_eq!(grown.len(), brush(0xca).len() + 20);
    assert_eq!(exact(grown.clone()), v);
    let mut bytes = words(&[1, 0, 0, 0, 0]);
    bytes.extend(grown);
    let mut d = definition(bytes.clone());
    d.object_type = 2;
    let mut pen = d.decode(&ParseLimits::default()).unwrap();
    assert_eq!(pen.serialize(&SerializeLimits::default()).unwrap(), bytes);
    let ObjectData::Pen(p) = &mut pen else {
        panic!()
    };
    let emf_plus::PenBrushData::PathGradient(g) = &mut p.brush.data else {
        panic!()
    };
    g.surrounding_colors.truncate(2);
    g.blend.as_mut().unwrap().truncate(2);
    let emf_plus::GradientBoundary::Points(p) = &mut g.boundary else {
        panic!()
    };
    p.truncate(2);
    d.bytes = pen.serialize(&SerializeLimits::default()).unwrap();
    assert_eq!(d.bytes.len(), bytes.len() - 20);
    assert_eq!(d.decode(&ParseLimits::default()).unwrap(), pen);
    let mut v = exact(brush(1));
    let ObjectData::PathGradientBrush { data, .. } = &mut v else {
        panic!()
    };
    let emf_plus::GradientBoundary::Path(p) = &mut data.boundary else {
        panic!()
    };
    let emf_plus::PointData::Integer(points) = &mut p.points else {
        panic!()
    };
    points.push([4, 5]);
    let emf_plus::PathPointTypes::Plain(types) = &mut p.point_types else {
        panic!()
    };
    types.push(1);
    p.alignment_padding = vec![0x12, 0x34];
    let bytes = v.serialize(&SerializeLimits::default()).unwrap();
    assert_eq!(bytes.len(), brush(1).len() + 4);
    assert_eq!(u32::from_le_bytes(bytes[40..44].try_into().unwrap()), 24);
    assert_eq!(exact(bytes), v);
}
#[test]
fn malformed_lengths_counts_and_presence_fail() {
    for flags in [0, 1, 0xca, 0xcb, 4] {
        let b = brush(flags);
        for n in 0..b.len() {
            assert!(
                definition(b[..n].to_vec())
                    .decode(&ParseLimits::default())
                    .is_err(),
                "{flags:x}/{n}"
            );
        }
        let mut b = b;
        b.push(0);
        assert!(definition(b).decode(&ParseLimits::default()).is_err());
    }
    for (flags, offset, values) in [
        (0, 28, vec![u32::MAX]),
        (0, 40, vec![u32::MAX, 0x7fffffff]),
        (1, 40, vec![0, 19, 21, u32::MAX]),
        (8, 60, vec![0, 1, u32::MAX]),
        (0x40, 60, vec![0, 1, 3, u32::MAX]),
    ] {
        for value in values {
            let mut b = brush(flags);
            b[offset..offset + 4].copy_from_slice(&value.to_le_bytes());
            assert!(
                definition(b).decode(&ParseLimits::default()).is_err(),
                "{flags:x}/{offset}/{value}"
            );
        }
    }
    assert!(definition(brush(0xc))
        .decode(&ParseLimits::default())
        .is_err());
    for edit in 0..7 {
        let mut v = exact(brush(0xcb));
        let ObjectData::PathGradientBrush { data, .. } = &mut v else {
            panic!()
        };
        match edit {
            0 => data.flags |= 4,
            1 => data.transform = None,
            2 => data.focus_scales = None,
            3 => data.blend = None,
            4 => data.blend.as_mut().unwrap().truncate(1),
            5 => data.flags &= !1,
            6 => data.flags |= 0x100,
            _ => unreachable!(),
        };
        assert!(matches!(
            v.serialize(&SerializeLimits::default()),
            Err(emf_core::SerializeFailure::Inconsistent { .. })
        ));
    }
}
#[test]
fn unknown_flags_preserve_whole_object_and_pen() {
    for flags in [0x10, 0x20, 0x100, 0x80000000] {
        for pen in [false, true] {
            let mut d = definition(brush(flags));
            if pen {
                let mut p = words(&[1, 0, 0, 0, 0]);
                p.extend(d.bytes);
                d.bytes = p;
                d.object_type = 2;
            }
            let v = d.decode(&ParseLimits::default()).unwrap();
            assert!(matches!(v, ObjectData::Opaque { .. }));
            assert_eq!(v.serialize(&SerializeLimits::default()).unwrap(), d.bytes);
        }
    }
}
#[test]
fn shared_budgets_include_boundary_and_blend_vectors_and_nested_pen() {
    use emf_core::{emf_plus, LimitKind, ParseFailure, SerializeFailure};
    let bytes = brush(0xca);
    let allocated = 8 + 16 + 16;
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
fn path_gradient_edit_preserves_continuations_segments_unknowns_and_padding() {
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
    let body = brush(0xcb);
    let mut first = words(&[body.len() as u32]);
    first.extend(&body[..7]);
    let mut wire = record(0x7777, 0xabcd, &[1, 2, 3], &[0xee]);
    wire.extend(record(0x4008, 0x8101, &first, &[0xa5]));
    let last = wire.len();
    wire.extend(record(0x4008, 0x0101, &body[7..], &[0x17, 0x18, 0x19]));
    let limits = ParseLimits::default();
    let mut stream = emf_plus::parse_segments(&[&wire[..5], &[], &wire[5..]], &limits).unwrap();
    let def = stream.object_definitions(&limits).unwrap().remove(0);
    let mut value = def.decode(&limits).unwrap();
    let ObjectData::PathGradientBrush { data: p, .. } = &mut value else {
        panic!()
    };
    p.center_color = 0x7fc05678;
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
