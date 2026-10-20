use emf_core::{
    emf_plus::{self, ObjectData, ObjectDefinition, PathPointTypes, PointData, RegionNode},
    LimitKind, ParseFailure, ParseLimits, SerializeFailure, SerializeLimits,
};
fn words(v: &[u32]) -> Vec<u8> {
    v.iter().flat_map(|n| n.to_le_bytes()).collect()
}
fn definition(bytes: Vec<u8>) -> ObjectDefinition {
    ObjectDefinition {
        id: 4,
        object_type: 4,
        first_record: 9,
        last_record: 9,
        bytes,
    }
}
fn exact(bytes: Vec<u8>) -> ObjectData {
    let v = definition(bytes.clone())
        .decode(&ParseLimits::default())
        .unwrap();
    assert_eq!(v.object_type(), 4);
    assert_eq!(v.serialize(&SerializeLimits::default()).unwrap(), bytes);
    v
}
fn fixture() -> Vec<u8> {
    let mut b = words(&[
        0xdbc01002, 10, 1, 2, 3, 4, 5, 0x10000000, 0x7fc01234, 0x80000000, 0x3f800000, 0,
    ]);
    let mut path = words(&[0xdbc01002, 1, 0x4000]);
    path.extend([0xff, 0xff, 0, 0x80, 0x81, 0xaa, 0xbb, 0xcc]);
    b.extend(words(&[0x10000001, path.len() as u32]));
    b.extend(path);
    b.extend(words(&[0x10000002, 0x10000003, 0x10000002, 0x10000003]));
    b
}
#[test]
fn region_nodes_are_typed_in_preorder() {
    let bytes = words(&[0xdbc01002, 2, 1, 0x10000002, 0x10000003]);
    let value = exact(bytes);
    assert!(!matches!(value, ObjectData::Opaque { .. }));
    let ObjectData::Region(region) = value else {
        panic!()
    };
    assert_eq!(
        region.nodes,
        vec![
            RegionNode::Binary { operation: 1 },
            RegionNode::Empty,
            RegionNode::Infinite
        ]
    );
    let ObjectData::Region(region) = exact(fixture()) else {
        panic!()
    };
    assert_eq!(region.version, 0xdbc01002);
    for (i, node) in region.nodes[..5].iter().enumerate() {
        assert_eq!(
            node,
            &RegionNode::Binary {
                operation: (i + 1) as u32
            }
        );
    }
    assert_eq!(
        region.nodes[5],
        RegionNode::Rectangle([0x7fc01234, 0x80000000, 0x3f800000, 0])
    );
    let RegionNode::Path(p) = &region.nodes[6] else {
        panic!()
    };
    assert_eq!(p.points, PointData::Integer(vec![[-1, i16::MIN]]));
    assert_eq!(p.point_types, PathPointTypes::Plain(vec![0x81]));
    assert_eq!(p.alignment_padding, [0xaa, 0xbb, 0xcc]);
}
#[test]
fn region_edits_derive_node_counts_and_nested_path_lengths() {
    let mut v = exact(fixture());
    let ObjectData::Region(region) = &mut v else {
        panic!()
    };
    let RegionNode::Path(path) = &mut region.nodes[6] else {
        panic!()
    };
    path.points = PointData::Integer(vec![[-1, i16::MIN], [5, 6]]);
    path.point_types = PathPointTypes::Plain(vec![0x81, 1]);
    path.alignment_padding = vec![0xaa, 0xbb];
    let bytes = v.serialize(&SerializeLimits::default()).unwrap();
    assert_eq!(bytes.len(), fixture().len() + 4);
    assert_eq!(&bytes[..52], &fixture()[..52]);
    assert_eq!(u32::from_le_bytes(bytes[52..56].try_into().unwrap()), 24);
    assert_eq!(exact(bytes), v);
    let ObjectData::Region(region) = &mut v else {
        panic!()
    };
    region.nodes = vec![RegionNode::Infinite];
    assert_eq!(
        v.serialize(&SerializeLimits::default()).unwrap(),
        words(&[0xdbc01002, 0, 0x10000003])
    );
}
#[test]
fn malformed_region_counts_tree_shapes_and_nested_paths_reject() {
    for bytes in [
        words(&[3, u32::MAX, 0x10000002]),
        words(&[3, 0, 1]),
        words(&[3, 1, 0x10000002, 0x10000003]),
        words(&[3, 2, 1, 0x10000002]),
        words(&[3, 0, 0x10000002, 123]),
        words(&[3, 0, 0x10000000, 1, 2, 3]),
        words(&[3, 0, 0x10000001, u32::MAX]),
        words(&[3, 0, 0x10000001, 12, 3, 1, 0]),
        words(&[3, 0, 0x10000001, 13, 3, 0, 0])
            .into_iter()
            .chain([0])
            .collect(),
    ] {
        assert!(matches!(
            definition(bytes).decode(&ParseLimits::default()),
            Err(emf_plus::Error::InvalidObject {
                record_index: 9,
                ..
            })
        ));
    }
    let baseline = exact(fixture());
    for edit in 0..5 {
        let mut v = baseline.clone();
        let ObjectData::Region(r) = &mut v else {
            panic!()
        };
        match edit {
            0 => r.nodes.clear(),
            1 => {
                r.nodes.pop();
            }
            2 => r.nodes.push(RegionNode::Empty),
            3 => r.nodes[0] = RegionNode::Binary { operation: 6 },
            4 => {
                let RegionNode::Path(p) = &mut r.nodes[6] else {
                    panic!()
                };
                p.alignment_padding.clear();
            }
            _ => unreachable!(),
        }
        assert!(matches!(
            v.serialize(&SerializeLimits::default()),
            Err(SerializeFailure::Inconsistent { .. })
        ));
    }
}
#[test]
fn unknown_node_types_retain_the_complete_opaque_definition() {
    for bytes in [
        words(&[3, 0, 0xfeedbeef, 7, 8, 9]),
        words(&[3, 2, 1, 0xfeedbeef, 0x10000003, 17]),
    ] {
        let v = exact(bytes.clone());
        assert_eq!(
            v,
            ObjectData::Opaque {
                object_type: 4,
                bytes
            }
        );
    }
}
#[test]
fn region_vectors_and_nested_paths_share_resource_budgets() {
    let b = fixture();
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
        assert!(
            matches!(definition(b.clone()).decode(&limits),Err(emf_plus::Error::Resource(ParseFailure::LimitExceeded{kind:k,..})) if k==kind)
        );
    }
    let nodes = 11 * std::mem::size_of::<RegionNode>();
    // Node storage alone cannot cover the nested Path's coordinates/types/padding.
    assert!(matches!(
        definition(b.clone()).decode(&ParseLimits {
            max_allocated_bytes: nodes,
            ..ParseLimits::default()
        }),
        Err(emf_plus::Error::Resource(ParseFailure::LimitExceeded {
            kind: LimitKind::AllocatedBytes,
            ..
        }))
    ));
    let allocation = nodes + std::mem::size_of::<[i16; 2]>() + 1 + 3;
    let v = definition(b.clone())
        .decode(&ParseLimits {
            max_allocated_bytes: allocation,
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
fn deeply_nested_region_is_parsed_written_and_dropped_without_recursion() {
    let depth = 20_000;
    let mut b = words(&[3, depth * 2]);
    b.extend(words(&vec![1; depth as usize]));
    b.extend(words(&vec![0x10000002; depth as usize + 1]));
    let v = exact(b);
    let ObjectData::Region(r) = v else { panic!() };
    assert_eq!(r.nodes.len(), depth as usize * 2 + 1);
}

#[test]
fn typed_region_edit_preserves_continuation_headers_unknowns_padding_and_segments() {
    fn record(kind: u16, flags: u16, data: &[u8], padding: &[u8]) -> Vec<u8> {
        let mut b = kind.to_le_bytes().to_vec();
        b.extend(flags.to_le_bytes());
        b.extend(words(&[
            (12 + data.len() + padding.len()) as u32,
            data.len() as u32,
        ]));
        b.extend(data);
        b.extend(padding);
        b
    }
    let body = fixture();
    let mut first = words(&[body.len() as u32]);
    first.extend(&body[..7]);
    let mut wire = record(0x7777, 0xabcd, &[1, 2, 3], &[0xee]);
    wire.extend(record(0x4008, 0x8404, &first, &[0xa5]));
    let last_start = wire.len();
    wire.extend(record(0x4008, 0x0404, &body[7..], &[0x17, 0x18, 0x19]));
    let limits = ParseLimits::default();
    let mut stream = emf_plus::parse_segments(&[&wire[..5], &[], &wire[5..]], &limits).unwrap();
    let def = stream.object_definitions(&limits).unwrap().remove(0);
    let mut value = def.decode(&limits).unwrap();
    let ObjectData::Region(region) = &mut value else {
        panic!()
    };
    let RegionNode::Rectangle(rect) = &mut region.nodes[5] else {
        panic!()
    };
    rect[2] = 0x7fc05678;
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
    // Rectangle's third word is logical offset 40, in the second fragment.
    wire[last_start + 12 + 40 - 7..last_start + 12 + 44 - 7]
        .copy_from_slice(&0x7fc05678u32.to_le_bytes());
    assert_eq!(segments.concat(), wire);
    assert_eq!(
        stream.object_definitions(&limits).unwrap()[0]
            .decode(&limits)
            .unwrap(),
        value
    );
}
