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
#[test]
fn linear_brush_is_typed_and_exact() {
    let bytes = words(&[
        0xdbc01002, 4, 0, 3, 1, 2, 3, 4, 0xff123456, 0xffabcdef, 0x12345678, 0xabcdef01,
    ]);
    let value = definition(bytes.clone())
        .decode(&ParseLimits::default())
        .unwrap();
    assert!(!matches!(value, ObjectData::Opaque { .. }));
    assert_eq!(value.serialize(&SerializeLimits::default()).unwrap(), bytes);
}
fn brush(flags: u32) -> Vec<u8> {
    let mut b = words(&[
        0xdbc01002, 4, flags, 0xffffffff, 0x80000000, 0x7fc01234, 3, 4, 0xff123456, 0xffabcdef,
        0x12345678, 0xabcdef01,
    ]);
    if flags & 2 != 0 {
        b.extend(words(&[1, 2, 3, 4, 5, 0x7f800000]));
    }
    for flag in [4, 0x10, 8] {
        if flags & flag != 0 {
            b.extend(words(&[2, 0, 0x3f800000, flag, flag + 1]));
        }
    }
    b
}
fn exact(bytes: Vec<u8>) -> ObjectData {
    let value = definition(bytes.clone())
        .decode(&ParseLimits::default())
        .unwrap();
    assert!(matches!(value, ObjectData::LinearGradientBrush { .. }));
    assert_eq!(value.serialize(&SerializeLimits::default()).unwrap(), bytes);
    value
}
#[test]
fn every_optional_combination_preserves_bits_and_vertical_horizontal_order() {
    for pattern in [0, 4, 8, 0x10, 0x18] {
        for extra in [0, 2, 0x80, 0x82] {
            let value = exact(brush(pattern | extra));
            let ObjectData::LinearGradientBrush { data, .. } = value else {
                panic!()
            };
            assert_eq!(data.reserved, [0x12345678, 0xabcdef01]);
            assert_eq!(data.rectangle[1], 0x7fc01234);
            let expected: Vec<_> = [4, 0x10, 8]
                .into_iter()
                .filter(|f| pattern & f != 0)
                .collect();
            assert_eq!(
                data.blends.iter().map(|b| b[0][1]).collect::<Vec<_>>(),
                expected
            );
        }
    }
}
#[test]
fn edited_counts_and_nested_pen_brush_grow_and_shrink() {
    let mut value = exact(brush(0x1a));
    let ObjectData::LinearGradientBrush { data, .. } = &mut value else {
        panic!()
    };
    data.blends[0].push([0x3f000000, 0x3e800000]);
    data.blends[1].extend([[1, 2], [3, 4]]);
    let grown = value.serialize(&SerializeLimits::default()).unwrap();
    assert_eq!(grown.len(), brush(0x1a).len() + 24);
    assert_eq!(exact(grown.clone()), value);
    let mut p = words(&[0xdbc01002, 0, 0, 2, 0x3f800000]);
    p.extend(grown);
    let mut def = definition(p.clone());
    def.object_type = 2;
    let mut pen = def.decode(&ParseLimits::default()).unwrap();
    assert_eq!(pen.serialize(&SerializeLimits::default()).unwrap(), p);
    let ObjectData::Pen(pen_data) = &mut pen else {
        panic!()
    };
    let emf_core::emf_plus::PenBrushData::LinearGradient(g) = &mut pen_data.brush.data else {
        panic!()
    };
    g.blends[0].truncate(2);
    g.blends[1].truncate(2);
    let shrunk = pen.serialize(&SerializeLimits::default()).unwrap();
    assert_eq!(shrunk.len(), p.len() - 24);
    def.bytes = shrunk;
    assert_eq!(def.decode(&ParseLimits::default()).unwrap(), pen);
}
#[test]
fn unknown_flags_are_wholly_opaque_and_known_invalid_layouts_fail() {
    for flags in [1, 0x20, 0x40, 0x100, 0x80000000] {
        let bytes = brush(flags);
        let v = definition(bytes.clone())
            .decode(&ParseLimits::default())
            .unwrap();
        assert!(matches!(v, ObjectData::Opaque { .. }));
        assert_eq!(v.serialize(&SerializeLimits::default()).unwrap(), bytes);
        let mut p = words(&[1, 0, 0, 0, 0]);
        p.extend(bytes);
        let mut d = definition(p.clone());
        d.object_type = 2;
        let v = d.decode(&ParseLimits::default()).unwrap();
        assert!(matches!(v, ObjectData::Opaque { .. }));
        assert_eq!(v.serialize(&SerializeLimits::default()).unwrap(), p);
    }
    for flags in [0xc, 0x14, 0x1c] {
        assert!(definition(brush(flags))
            .decode(&ParseLimits::default())
            .is_err());
    }
    for flags in [0, 4, 0x1a] {
        let b = brush(flags);
        for n in 0..b.len() {
            assert!(
                definition(b[..n].to_vec())
                    .decode(&ParseLimits::default())
                    .is_err(),
                "{flags:x}/{n}"
            );
        }
        let mut suffix = b.clone();
        suffix.push(0);
        assert!(definition(suffix).decode(&ParseLimits::default()).is_err());
    }
    for count in [0, 1, u32::MAX] {
        let mut b = brush(8);
        b[48..52].copy_from_slice(&count.to_le_bytes());
        assert!(definition(b).decode(&ParseLimits::default()).is_err());
    }
    for edit in 0..4 {
        let mut v = exact(brush(0x1a));
        let ObjectData::LinearGradientBrush { data, .. } = &mut v else {
            panic!()
        };
        match edit {
            0 => data.flags |= 4,
            1 => data.transform = None,
            2 => {
                data.blends.pop();
            }
            3 => data.blends[0].truncate(1),
            _ => unreachable!(),
        }
        assert!(matches!(
            v.serialize(&SerializeLimits::default()),
            Err(emf_core::SerializeFailure::Inconsistent { .. })
        ));
    }
}
#[test]
fn shared_budgets_include_blend_vectors_and_nested_pen() {
    use emf_core::{emf_plus, LimitKind, ParseFailure, SerializeFailure};
    let bytes = brush(0x1a);
    let allocated = 2 * std::mem::size_of::<Vec<[u32; 2]>>() + 4 * 8;
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
fn linear_gradient_edit_preserves_continuations_segments_unknowns_and_padding() {
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
    let body = brush(0x1a);
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
    let ObjectData::LinearGradientBrush { data: p, .. } = &mut value else {
        panic!()
    };
    p.start_color = 0x7fc05678;
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
    wire[last + 12 + 32 - 7..last + 12 + 36 - 7].copy_from_slice(&0x7fc05678u32.to_le_bytes());
    assert_eq!(segments.concat(), wire);
}
