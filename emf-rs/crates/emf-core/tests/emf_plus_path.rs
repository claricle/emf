use emf_core::{
    emf_plus::{
        self, ObjectData, ObjectDefinition, PathPointRun, PathPointTypes, PointData,
        RelativeCoordinate,
    },
    LimitKind, ParseFailure, ParseLimits, SerializeFailure, SerializeLimits,
};

fn words(v: &[u32]) -> Vec<u8> {
    v.iter().flat_map(|n| n.to_le_bytes()).collect()
}
fn definition(bytes: Vec<u8>) -> ObjectDefinition {
    ObjectDefinition {
        id: 3,
        object_type: 3,
        first_record: 7,
        last_record: 7,
        bytes,
    }
}
fn exact(bytes: Vec<u8>) -> ObjectData {
    let value = definition(bytes.clone())
        .decode(&ParseLimits::default())
        .unwrap();
    assert_eq!(value.object_type(), 3);
    assert_eq!(value.serialize(&SerializeLimits::default()).unwrap(), bytes);
    value
}
fn floats() -> Vec<u8> {
    let mut bytes = words(&[0xdbc01002, 3, 0x80000000]);
    bytes.extend(words(&[
        0x7fc01234, 0x80000000, 0x3f800000, 0, 0, 0x7f800000,
    ]));
    bytes.extend([0, 1, 0x83, 0xab]);
    bytes
}
fn relative() -> Vec<u8> {
    // R takes precedence over C. Include nonminimal signed fifteen-bit values.
    let mut bytes = words(&[0xdbc01002, 3, 0xa0004800]);
    bytes.extend([0x80, 0, 0x7f, 0x40, 0xbf, 0xff, 0xc0, 0, 0x3f]);
    bytes.extend([0x41, 0, 0x82, 0x83]);
    bytes.extend([0xde, 0xad, 0xbe]);
    bytes
}

#[test]
fn path_coordinates_types_and_padding_are_typed_and_exact() {
    // MS-EMFPLUS 2.2.1.6: float points, one type per point, ignored padding.
    let bytes = floats();
    let value = definition(bytes.clone())
        .decode(&ParseLimits::default())
        .unwrap();
    assert!(!matches!(value, ObjectData::Opaque { .. }));
    assert_eq!(value.object_type(), 3);
    assert_eq!(value.serialize(&SerializeLimits::default()).unwrap(), bytes);
    let ObjectData::Path(path) = value else {
        panic!()
    };
    assert_eq!(path.flags, 0x80000000);
    assert!(matches!(path.points, PointData::Float(v) if v[0]==[0x7fc01234,0x80000000]));
    assert_eq!(path.point_types, PathPointTypes::Plain(vec![0, 1, 0x83]));
    assert_eq!(path.alignment_padding, [0xab]);

    let mut bytes = words(&[77, 2, 0x80004000]);
    for n in [i16::MIN, i16::MAX, -1, 13] {
        bytes.extend(n.to_le_bytes());
    }
    bytes.extend([0, 0x91, 0xff, 0xee]);
    let ObjectData::Path(path) = exact(bytes) else {
        panic!()
    };
    assert_eq!(
        path.points,
        PointData::Integer(vec![[i16::MIN, i16::MAX], [-1, 13]])
    );
    assert_eq!(path.point_types, PathPointTypes::Plain(vec![0, 0x91]));
    assert_eq!(path.alignment_padding, [0xff, 0xee]);
}

#[test]
fn relative_widths_rle_runs_and_ignored_bits_survive_typed_edits() {
    use RelativeCoordinate::{Fifteen, Seven};
    let mut value = exact(relative());
    let ObjectData::Path(path) = &mut value else {
        panic!()
    };
    assert_eq!(path.flags, 0xa0004800);
    assert_eq!(
        path.points,
        PointData::Relative(vec![
            [Fifteen(0), Seven(-1)],
            [Seven(-64), Fifteen(16383)],
            [Fifteen(-16384), Seven(63)]
        ])
    );
    assert_eq!(
        path.point_types,
        PathPointTypes::RunLength(vec![
            PathPointRun {
                header: 0x41,
                point_type: 0
            },
            PathPointRun {
                header: 0x82,
                point_type: 0x83
            }
        ])
    );
    assert_eq!(path.alignment_padding, [0xde, 0xad, 0xbe]);
    let PointData::Relative(points) = &mut path.points else {
        panic!()
    };
    points[0][0] = Fifteen(-1);
    let encoded = value.serialize(&SerializeLimits::default()).unwrap();
    let mut expected = relative();
    expected[12..14].copy_from_slice(&[0xff, 0xff]);
    assert_eq!(encoded, expected);
    assert_eq!(exact(encoded), value);
}

#[test]
fn path_edits_derive_counts_without_changing_other_fields() {
    let mut value = exact(floats());
    let ObjectData::Path(path) = &mut value else {
        panic!()
    };
    let PointData::Float(points) = &mut path.points else {
        panic!()
    };
    points.push([0xffc0ab12, 0x80000000]);
    let PathPointTypes::Plain(types) = &mut path.point_types else {
        panic!()
    };
    types.push(0x81);
    path.alignment_padding.clear();
    let bytes = value.serialize(&SerializeLimits::default()).unwrap();
    assert_eq!(u32::from_le_bytes(bytes[4..8].try_into().unwrap()), 4);
    assert_eq!(exact(bytes), value);
    let ObjectData::Path(path) = &mut value else {
        panic!()
    };
    path.points = PointData::Float(vec![]);
    path.point_types = PathPointTypes::Plain(vec![]);
    assert_eq!(
        value.serialize(&SerializeLimits::default()).unwrap(),
        words(&[0xdbc01002, 0, 0x80000000])
    );
}

#[test]
fn malformed_path_counts_runs_and_padding_fail_without_normalization() {
    for bytes in [
        words(&[3, u32::MAX, 0x4000]),
        words(&[3, 1, 0]),
        words(&[3, 0, 0]).into_iter().chain([1]).collect(),
        floats()[..39].to_vec(),
    ] {
        assert!(matches!(
            definition(bytes).decode(&ParseLimits::default()),
            Err(emf_plus::Error::InvalidObject {
                record_index: 7,
                ..
            })
        ));
    }
    for header in [0, 0x40, 0x80, 0xc0, 0x44] {
        let mut b = relative();
        b[21] = header;
        assert!(
            definition(b).decode(&ParseLimits::default()).is_err(),
            "header={header:x}"
        );
    }
    let mut truncated = words(&[3, 1, 0x0800]);
    truncated.extend([0x80]);
    assert!(definition(truncated)
        .decode(&ParseLimits::default())
        .is_err());
    let mut missing_type = words(&[3, 1, 0x0800]);
    missing_type.extend([0, 0]);
    assert!(definition(missing_type)
        .decode(&ParseLimits::default())
        .is_err());

    let baseline = exact(relative());
    for edit in 0..6 {
        let mut value = baseline.clone();
        let ObjectData::Path(path) = &mut value else {
            panic!()
        };
        match edit {
            0 => path.flags &= !0x0800,
            1 => path.point_types = PathPointTypes::Plain(vec![0; 3]),
            2 => {
                path.point_types = PathPointTypes::RunLength(vec![PathPointRun {
                    header: 0x40,
                    point_type: 0,
                }])
            }
            3 => {
                path.point_types = PathPointTypes::RunLength(vec![PathPointRun {
                    header: 0x44,
                    point_type: 0,
                }])
            }
            4 => path.alignment_padding.pop().map(|_| ()).unwrap(),
            5 => {
                let PointData::Relative(v) = &mut path.points else {
                    panic!()
                };
                v[0][0] = RelativeCoordinate::Seven(64);
            }
            _ => unreachable!(),
        }
        assert!(
            matches!(
                value.serialize(&SerializeLimits::default()),
                Err(SerializeFailure::Inconsistent { .. })
            ),
            "edit={edit}"
        );
    }
}

#[test]
fn path_vector_expansion_and_serialization_obey_shared_budgets() {
    let bytes = relative();
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
            matches!(definition(bytes.clone()).decode(&limits),Err(emf_plus::Error::Resource(ParseFailure::LimitExceeded{kind:k,..})) if k==kind)
        );
    }
    let coordinate_bytes = 3 * std::mem::size_of::<[RelativeCoordinate; 2]>();
    assert!(matches!(
        definition(bytes.clone()).decode(&ParseLimits {
            max_allocated_bytes: coordinate_bytes - 1,
            ..ParseLimits::default()
        }),
        Err(emf_plus::Error::Resource(ParseFailure::LimitExceeded {
            kind: LimitKind::AllocatedBytes,
            ..
        }))
    ));
    // Coordinates, two encoded runs and three alignment bytes are the only
    // owned allocations: no expanded point-type array or body copy is charged.
    let exact_allocation = coordinate_bytes + 2 * std::mem::size_of::<PathPointRun>() + 3;
    assert_eq!(
        definition(bytes.clone())
            .decode(&ParseLimits {
                max_allocated_bytes: exact_allocation,
                ..ParseLimits::default()
            })
            .unwrap(),
        exact(bytes.clone())
    );
    // A full run stays a single encoded type, not sixty-three expanded entries.
    let mut run = words(&[3, 63, 0x0800]);
    run.extend([0; 126]);
    run.extend([0xff, 0x83]);
    let ObjectData::Path(path) = exact(run) else {
        panic!()
    };
    assert!(
        matches!(path.point_types,PathPointTypes::RunLength(v) if v.len()==1&&v[0].count()==63)
    );
    let value = exact(bytes.clone());
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
}

#[test]
fn typed_path_edit_through_continuation_preserves_wire_and_segments() {
    fn record(flags: u16, data: &[u8], padding: &[u8]) -> Vec<u8> {
        let mut b = 0x4008u16.to_le_bytes().to_vec();
        b.extend(flags.to_le_bytes());
        b.extend(words(&[
            (12 + data.len() + padding.len()) as u32,
            data.len() as u32,
        ]));
        b.extend(data);
        b.extend(padding);
        b
    }
    let body = relative();
    let mut first = words(&[body.len() as u32]);
    first.extend(&body[..5]);
    let mut wire = record(0x8303, &first, &[0x12, 0x34, 0x56]);
    wire.extend(record(0x0303, &body[5..], &[0xab]));
    let limits = ParseLimits::default();
    let mut stream = emf_plus::parse_segments(&[&wire[..9], &[], &wire[9..]], &limits).unwrap();
    let before = stream.clone();
    let def = stream.object_definitions(&limits).unwrap().remove(0);
    let mut value = def.decode(&limits).unwrap();
    let ObjectData::Path(path) = &mut value else {
        panic!()
    };
    let PathPointTypes::RunLength(runs) = &mut path.point_types else {
        panic!()
    };
    runs[1].point_type = 0xa3;
    stream
        .replace_object_bytes(
            def.first_record,
            &value.serialize(&SerializeLimits::default()).unwrap(),
            &limits,
        )
        .unwrap();
    assert_eq!(
        stream
            .records
            .iter()
            .map(|r| r.padding.clone())
            .collect::<Vec<_>>(),
        before
            .records
            .iter()
            .map(|r| r.padding.clone())
            .collect::<Vec<_>>()
    );
    let segments = emf_plus::serialize_segments(&stream, &SerializeLimits::default()).unwrap();
    assert_eq!(
        segments.iter().map(Vec::len).collect::<Vec<_>>(),
        vec![9, 0, wire.len() - 9]
    );
    // Only the requested point-type byte changes, including continuation headers.
    let mut expected = wire;
    expected[12 + 4 + 5 + 3 + 12 + (24 - 5)] = 0xa3;
    assert_eq!(segments.concat(), expected);
    assert_eq!(
        stream.object_definitions(&limits).unwrap()[0]
            .decode(&limits)
            .unwrap(),
        value
    );
}
