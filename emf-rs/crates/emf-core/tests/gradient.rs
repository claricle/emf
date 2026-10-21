use emf_core::{parse, serialize, ParseLimits, RecordData};
fn put(b: &mut [u8], at: usize, n: u32) {
    b[at..at + 4].copy_from_slice(&n.to_le_bytes());
}
fn fixture(mode: u32) -> Vec<u8> {
    let mut b = vec![0; 88];
    put(&mut b, 0, 1);
    put(&mut b, 4, 88);
    put(&mut b, 40, 0x464d4520);
    let mut r = vec![0; 36 + 3 * 16 + 12];
    put(&mut r, 0, 118);
    let n = r.len() as u32;
    put(&mut r, 4, n);
    put(&mut r, 24, 3);
    put(&mut r, 28, 1);
    put(&mut r, 32, mode);
    for i in 0..3 {
        put(&mut r, 36 + i * 16, (-15 - i as i32) as u32);
        put(&mut r, 44 + i * 16, 0xabcd1234);
        put(&mut r, 48 + i * 16, 0xffff8000);
    }
    put(&mut r, 84, 0);
    put(&mut r, 88, 1);
    put(&mut r, 92, if mode == 2 { 2 } else { 0xdeadbeef });
    b.extend_from_slice(&r);
    b.extend_from_slice(&[
        14, 0, 0, 0, 20, 0, 0, 0, 0, 0, 0, 0, 16, 0, 0, 0, 20, 0, 0, 0,
    ]);
    b.extend_from_slice(b"tail");
    b
}
#[test]
fn gradient_decodes_and_preserves_bytes() {
    for mode in 0..=2 {
        let b = fixture(mode);
        let d = parse(&b, &ParseLimits::default()).unwrap();
        assert_ne!(d.records()[0].data(), &RecordData::Raw);
        assert_eq!(serialize(&d).unwrap(), b);
    }
}
#[test]
fn edits_rebuild_mesh_counts_and_preserve_padding_alpha_and_tail() {
    use emf_core::{GradientMesh, Point};
    for mode in 0..=2 {
        let b = fixture(mode);
        let mut d = parse(&b, &ParseLimits::default()).unwrap();
        let RecordData::GradientFill(mut g) = d.records()[0].data().clone() else {
            panic!()
        };
        assert_eq!(g.vertices[0].position, Point { x: -15, y: 0 });
        assert_eq!(
            (
                g.vertices[0].red,
                g.vertices[0].green,
                g.vertices[0].blue,
                g.vertices[0].alpha
            ),
            (0x1234, 0xabcd, 0x8000, 0xffff)
        );
        d.edit_record(0, RecordData::GradientFill(g.clone()))
            .unwrap();
        assert_eq!(&serialize(&d).unwrap()[88..], &b[88..]);
        g.vertices[0].position.x = i32::MIN;
        g.vertices.push(g.vertices[0]);
        match &mut g.mesh {
            GradientMesh::Rectangles {
                rectangles,
                padding,
                ..
            } => {
                rectangles.push([3, 2]);
                padding.push(0x87654321);
            }
            GradientMesh::Triangles(t) => t.push([3, 2, 1]),
        }
        d.edit_record(0, RecordData::GradientFill(g.clone()))
            .unwrap();
        let encoded = serialize(&d).unwrap();
        let reparsed = parse(&encoded, &ParseLimits::default()).unwrap();
        assert_eq!(reparsed.records()[0].data(), &RecordData::GradientFill(g));
        assert_eq!(reparsed.trailing_bytes(), b"tail");
        assert!(reparsed.has_eof());
        assert_eq!(serialize(&reparsed).unwrap(), encoded);
    }
}
#[test]
fn malformed_counts_modes_indexes_and_missing_rectangle_padding_recover() {
    for (at, value) in [
        (24, u32::MAX),
        (28, u32::MAX),
        (32, 3),
        (84, 3),
        (88, u32::MAX),
    ] {
        let mut b = fixture(0);
        put(&mut b, 88 + at, value);
        let d = parse(&b, &ParseLimits::default()).unwrap();
        // The fixed prefix is intact, so the record stays opaque without a diagnostic.
        assert_eq!(d.records()[0].data(), &RecordData::Raw);
        assert!(d.diagnostics().is_empty());
        assert!(d.has_eof());
        assert_eq!(serialize(&d).unwrap(), b);
    }
    // A record shorter than the fixed prefix still earns a diagnostic.
    let mut b = fixture(0);
    b.drain(88 + 32..88 + 36 + 3 * 16 + 12);
    put(&mut b, 88 + 4, 32);
    let d = parse(&b, &ParseLimits::default()).unwrap();
    assert_eq!(d.records()[0].data(), &RecordData::Raw);
    assert_eq!(d.diagnostics().len(), 1);
    assert_eq!(serialize(&d).unwrap(), b);
    let mut b = fixture(0);
    b.drain(88 + 92..88 + 96);
    put(&mut b, 88 + 4, 92);
    let d = parse(&b, &ParseLimits::default()).unwrap();
    // Missing rectangle padding is optional, so the record still decodes.
    let RecordData::GradientFill(g) = d.records()[0].data() else {
        panic!("expected a decoded gradient")
    };
    assert!(
        matches!(&g.mesh, emf_core::GradientMesh::Rectangles { padding, .. } if padding.is_empty())
    );
    assert!(d.has_eof());
    assert_eq!(serialize(&d).unwrap(), b);
}
#[test]
fn invalid_edit_is_atomic() {
    use emf_core::{EditFailure, GradientMesh};
    let mut d = parse(&fixture(0), &ParseLimits::default()).unwrap();
    let original = d.clone();
    let RecordData::GradientFill(g) = d.records()[0].data().clone() else {
        panic!()
    };
    // Padding is optional (all or nothing), so dropping it is a valid edit.
    let mut unpadded = g.clone();
    if let GradientMesh::Rectangles { padding, .. } = &mut unpadded.mesh {
        padding.clear();
    }
    let mut ok = d.clone();
    ok.edit_record(0, RecordData::GradientFill(unpadded))
        .unwrap();
    // A vertex index past the vertex table and a partial padding run stay invalid.
    let mut bad_index = g.clone();
    if let GradientMesh::Rectangles { rectangles, .. } = &mut bad_index.mesh {
        rectangles[0][0] = u32::MAX;
    }
    let mut bad_padding = g;
    if let GradientMesh::Rectangles { padding, .. } = &mut bad_padding.mesh {
        padding.push(0);
    }
    for bad in [bad_index, bad_padding] {
        assert_eq!(
            d.edit_record(0, RecordData::GradientFill(bad)),
            Err(EditFailure::RecordLayout { index: 0 })
        );
        assert_eq!(d, original);
    }
}
#[test]
fn allocation_and_work_limits_are_inclusive() {
    use emf_core::{
        serialize_with_limits, LimitKind, ParseFailure, SerializeFailure, SerializeLimits,
    };
    let b = fixture(1);
    let mut limits = ParseLimits {
        max_allocated_bytes: 0,
        max_work_units: 0,
        ..ParseLimits::default()
    };
    loop {
        match parse(&b, &limits) {
            Err(ParseFailure::LimitExceeded {
                kind: LimitKind::AllocatedBytes,
                requested,
                ..
            }) => limits.max_allocated_bytes = requested as usize,
            Err(ParseFailure::LimitExceeded {
                kind: LimitKind::WorkUnits,
                requested,
                ..
            }) => limits.max_work_units = requested,
            Ok(_) => break,
            other => panic!("{other:?}"),
        }
    }
    let mut d = parse(&b, &limits).unwrap();
    limits.max_allocated_bytes -= 1;
    assert!(matches!(
        parse(&b, &limits),
        Err(ParseFailure::LimitExceeded {
            kind: LimitKind::AllocatedBytes,
            ..
        })
    ));
    limits.max_allocated_bytes += 1;
    limits.max_work_units -= 1;
    assert!(matches!(
        parse(&b, &limits),
        Err(ParseFailure::LimitExceeded {
            kind: LimitKind::WorkUnits,
            ..
        })
    ));
    d.edit_record(0, d.records()[0].data().clone()).unwrap();
    let mut limits = SerializeLimits {
        max_output_bytes: b.len(),
        max_work_units: 0,
    };
    loop {
        match serialize_with_limits(&d, &limits) {
            Err(SerializeFailure::LimitExceeded {
                kind: LimitKind::WorkUnits,
                requested,
                ..
            }) => limits.max_work_units = requested,
            Ok(v) => {
                assert_eq!(v.len(), b.len());
                break;
            }
            other => panic!("{other:?}"),
        }
    }
    limits.max_work_units -= 1;
    assert!(matches!(
        serialize_with_limits(&d, &limits),
        Err(SerializeFailure::LimitExceeded {
            kind: LimitKind::WorkUnits,
            ..
        })
    ));
}
