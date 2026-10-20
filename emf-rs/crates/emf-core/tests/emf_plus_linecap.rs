use emf_core::{
    emf_plus::{self, CustomLineCapData, ObjectData, ObjectDefinition, PathPointTypes, PointData},
    LimitKind, ParseFailure, ParseLimits, SerializeFailure, SerializeLimits,
};
fn words(v: &[u32]) -> Vec<u8> {
    v.iter().flat_map(|n| n.to_le_bytes()).collect()
}
fn definition(bytes: Vec<u8>) -> ObjectDefinition {
    ObjectDefinition {
        id: 1,
        object_type: 9,
        first_record: 7,
        last_record: 7,
        bytes,
    }
}
fn exact(bytes: Vec<u8>) -> ObjectData {
    let value = definition(bytes.clone())
        .decode(&ParseLimits::default())
        .unwrap();
    assert_eq!(value.object_type(), 9);
    assert_eq!(value.serialize(&SerializeLimits::default()).unwrap(), bytes);
    value
}
fn path() -> Vec<u8> {
    let mut b = words(&[0xdbc01002, 1, 0x4000]);
    b.extend([0xff, 0xff, 0, 0x80, 0x81, 0xaa, 0xbb, 0xcc]);
    b
}
fn default_cap(flags: u32) -> Vec<u8> {
    let mut b = words(&[
        0xdbc01002, 0, flags, 0x123, 0x80000000, 0x456, 0x789, 0xabc, 0x7fc01234, 0x3f800000,
        0x80000000, 0, 0, 0x7f800000,
    ]);
    for flag in [1, 2] {
        if flags & flag != 0 {
            b.extend(words(&[path().len() as u32]));
            b.extend(path());
        }
    }
    b
}
fn arrow() -> Vec<u8> {
    words(&[
        0xdbc01002, 1, 0x7fc01234, 0x80000000, 0x7f800000, 0x12345678, 5, 6, 7, 8, 9, 10, 11, 12,
        13,
    ])
}
#[test]
fn custom_line_cap_is_typed() {
    let value = exact(arrow());
    assert!(!matches!(value, ObjectData::Opaque { .. }));
    let ObjectData::CustomLineCap(cap) = value else {
        panic!()
    };
    assert_eq!(cap.version, 0xdbc01002);
    let CustomLineCapData::AdjustableArrow(v) = cap.data else {
        panic!()
    };
    assert_eq!(
        [v.width, v.height, v.middle_inset, v.fill_state],
        [0x7fc01234, 0x80000000, 0x7f800000, 0x12345678]
    );
    assert_eq!(
        [
            v.line_start_cap,
            v.line_end_cap,
            v.line_join,
            v.line_miter_limit,
            v.width_scale
        ],
        [5, 6, 7, 8, 9]
    );
    assert_eq!(v.fill_hot_spot, [10, 11]);
    assert_eq!(v.line_hot_spot, [12, 13]);
    for flags in 0..=3 {
        let ObjectData::CustomLineCap(cap) = exact(default_cap(flags)) else {
            panic!()
        };
        let CustomLineCapData::Default(v) = cap.data else {
            panic!()
        };
        assert_eq!(v.flags, flags);
        assert_eq!(
            [
                v.base_cap,
                v.base_inset,
                v.stroke_start_cap,
                v.stroke_end_cap,
                v.stroke_join,
                v.stroke_miter_limit,
                v.width_scale
            ],
            [0x123, 0x80000000, 0x456, 0x789, 0xabc, 0x7fc01234, 0x3f800000]
        );
        assert_eq!(v.fill_hot_spot, [0x80000000, 0]);
        assert_eq!(v.stroke_hot_spot, [0, 0x7f800000]);
        assert_eq!(v.fill_path.is_some(), flags & 1 != 0);
        assert_eq!(v.line_path.is_some(), flags & 2 != 0);
        for p in [v.fill_path, v.line_path].into_iter().flatten() {
            assert_eq!(p.points, PointData::Integer(vec![[-1, i16::MIN]]));
            assert_eq!(p.point_types, PathPointTypes::Plain(vec![0x81]));
            assert_eq!(p.alignment_padding, [0xaa, 0xbb, 0xcc]);
        }
    }
}
#[test]
fn edits_derive_nested_lengths_and_preserve_the_other_path() {
    let mut value = exact(default_cap(3));
    let ObjectData::CustomLineCap(cap) = &mut value else {
        panic!()
    };
    let CustomLineCapData::Default(v) = &mut cap.data else {
        panic!()
    };
    let p = v.fill_path.as_mut().unwrap();
    p.points = PointData::Integer(vec![[-1, i16::MIN], [7, 8]]);
    p.point_types = PathPointTypes::Plain(vec![0x81, 1]);
    p.alignment_padding = vec![0xaa, 0xbb];
    let b = value.serialize(&SerializeLimits::default()).unwrap();
    assert_eq!(b.len(), default_cap(3).len() + 4);
    assert_eq!(&b[..56], &default_cap(3)[..56]);
    assert_eq!(&b[56..60], &24u32.to_le_bytes());
    assert_eq!(&b[84..], &default_cap(3)[80..]);
    assert_eq!(exact(b), value);
    let ObjectData::CustomLineCap(cap) = &mut value else {
        panic!()
    };
    let CustomLineCapData::Default(v) = &mut cap.data else {
        panic!()
    };
    v.flags = 2;
    v.fill_path = None;
    assert_eq!(
        value.serialize(&SerializeLimits::default()).unwrap(),
        default_cap(2)
    );
}
#[test]
fn unknown_variants_preserve_the_whole_object() {
    for bytes in [words(&[3, 42, 1, 2, 3]), words(&[3, 0, 4, 7, 8, 9])] {
        assert_eq!(
            exact(bytes.clone()),
            ObjectData::Opaque {
                object_type: 9,
                bytes
            }
        );
    }
}
#[test]
fn malformed_caps_and_inconsistent_edits_fail() {
    for full in [
        arrow(),
        default_cap(0),
        default_cap(1),
        default_cap(2),
        default_cap(3),
    ] {
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
    for len in [0, 19, 21, 24, 0x80000000, u32::MAX] {
        let mut b = default_cap(1);
        b[56..60].copy_from_slice(&len.to_le_bytes());
        assert!(definition(b).decode(&ParseLimits::default()).is_err());
    }
    for edit in 0..4 {
        let mut value = exact(default_cap(3));
        let ObjectData::CustomLineCap(cap) = &mut value else {
            panic!()
        };
        let CustomLineCapData::Default(v) = &mut cap.data else {
            panic!()
        };
        match edit {
            0 => v.flags = 0,
            1 => v.flags |= 4,
            2 => v.line_path = None,
            3 => v.fill_path.as_mut().unwrap().alignment_padding.clear(),
            _ => unreachable!(),
        }
        assert!(matches!(
            value.serialize(&SerializeLimits::default()),
            Err(SerializeFailure::Inconsistent { .. })
        ));
    }
}
#[test]
fn nested_paths_share_parse_and_serialize_budgets() {
    let b = default_cap(3);
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
        }
        assert!(matches!(definition(b.clone()).decode(&limits),
            Err(emf_plus::Error::Resource(ParseFailure::LimitExceeded {kind:k,..})) if k == kind));
    }
    // Each nested Path owns four coordinate bytes, one type byte and three pad bytes.
    for allocation in [8, 15] {
        assert!(matches!(
            definition(b.clone()).decode(&ParseLimits {
                max_allocated_bytes: allocation,
                ..ParseLimits::default()
            }),
            Err(emf_plus::Error::Resource(ParseFailure::LimitExceeded {
                kind: LimitKind::AllocatedBytes,
                ..
            }))
        ));
    }
    let v = definition(b.clone())
        .decode(&ParseLimits {
            max_allocated_bytes: 16,
            ..ParseLimits::default()
        })
        .unwrap();
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
            v.serialize(&limits),
            Err(SerializeFailure::LimitExceeded { .. })
        ));
    }
    assert_eq!(
        v.serialize(&SerializeLimits {
            max_output_bytes: b.len(),
            ..SerializeLimits::default()
        })
        .unwrap(),
        b
    );
}
#[test]
fn typed_cap_edit_preserves_continuation_framing_unknowns_and_padding() {
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
    let body = default_cap(3);
    let mut first = words(&[body.len() as u32]);
    first.extend(&body[..7]);
    let mut wire = record(0x7777, 0xabcd, &[1, 2, 3], &[0xee]);
    wire.extend(record(0x4008, 0x8901, &first, &[0xa5]));
    let last = wire.len();
    wire.extend(record(0x4008, 0x0901, &body[7..], &[0x17, 0x18, 0x19]));
    let limits = ParseLimits::default();
    let mut stream = emf_plus::parse_segments(&[&wire[..5], &[], &wire[5..]], &limits).unwrap();
    let def = stream.object_definitions(&limits).unwrap().remove(0);
    let mut value = def.decode(&limits).unwrap();
    let ObjectData::CustomLineCap(cap) = &mut value else {
        panic!()
    };
    let CustomLineCapData::Default(v) = &mut cap.data else {
        panic!()
    };
    v.base_inset = 0x7fc05678;
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
    assert_eq!(
        stream.object_definitions(&limits).unwrap()[0]
            .decode(&limits)
            .unwrap(),
        value
    );
}
