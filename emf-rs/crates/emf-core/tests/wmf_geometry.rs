use emf_core::wmf::{
    self,
    geometry::{GeometryRecord as G, Point},
    TypedRecord,
};
use emf_core::{EditFailure, LimitKind, ParseFailure, ParseLimits};

fn words(v: &[i16]) -> Vec<u8> {
    v.iter().flat_map(|n| n.to_le_bytes()).collect()
}
fn file(records: &[(u16, Vec<u8>)]) -> Vec<u8> {
    let mut b = words(&[1, 9, 0x0300, 0, 0, 0, 0, 0, 0]);
    for (function, body) in records {
        b.extend((3 + body.len() as u32 / 2).to_le_bytes());
        b.extend(function.to_le_bytes());
        b.extend(body);
    }
    b.extend([3, 0, 0, 0, 0, 0]);
    b
}
fn typed(doc: &wmf::Document, index: usize) -> Option<&TypedRecord> {
    doc.records()[index].typed()
}

#[test]
fn advisory_function_high_bytes_preserve_original_values_after_edits() {
    let cases = [
        (0xab14, words(&[-2, 1]), G::MoveTo { x: 1, y: -2 }),
        (
            0xab25,
            words(&[1, -3, 4]),
            G::Polyline {
                points: vec![Point { x: -3, y: 4 }],
            },
        ),
        (
            0xab38,
            words(&[1, 1, -3, 4]),
            G::PolyPolygon {
                poly_counts: vec![1],
                points: vec![Point { x: -3, y: 4 }],
            },
        ),
    ];
    for (function, mut body, expected) in cases {
        body.extend([0xaa, 0xbb]);
        let input = file(&[(function, body)]);
        let mut doc = wmf::parse(&input, &ParseLimits::default()).unwrap();
        assert_eq!(
            typed(&doc, 0),
            Some(&TypedRecord::Geometry(expected.clone()))
        );
        assert_eq!(wmf::serialize(&doc).unwrap(), input);
        doc.replace_typed(0, TypedRecord::Geometry(expected))
            .unwrap();
        assert_eq!(doc.records()[0].function(), function);
        assert_eq!(wmf::serialize(&doc).unwrap()[18..], input[18..]);
    }
}

#[test]
fn fixed_geometry_decodes_named_signed_fields_and_wire_order() {
    let cases = [
        (0x0214, words(&[-2, 1]), G::MoveTo { x: 1, y: -2 }),
        (0x0213, words(&[-2, 1]), G::LineTo { x: 1, y: -2 }),
        (0x020b, words(&[-2, 1]), G::SetWindowOrg { x: 1, y: -2 }),
        (0x020c, words(&[-2, 1]), G::SetWindowExt { x: 1, y: -2 }),
        (0x020d, words(&[-2, 1]), G::SetViewportOrg { x: 1, y: -2 }),
        (0x020e, words(&[-2, 1]), G::SetViewportExt { x: 1, y: -2 }),
        (0x020f, words(&[-2, 1]), G::OffsetWindowOrg { x: 1, y: -2 }),
        (
            0x0211,
            words(&[-2, 1]),
            G::OffsetViewportOrg { x: 1, y: -2 },
        ),
        (0x0220, words(&[-2, 1]), G::OffsetClipRgn { x: 1, y: -2 }),
        (
            0x0410,
            words(&[-4, 3, -2, 1]),
            G::ScaleWindowExt {
                x_num: 1,
                x_denom: -2,
                y_num: 3,
                y_denom: -4,
            },
        ),
        (
            0x0412,
            words(&[-4, 3, -2, 1]),
            G::ScaleViewportExt {
                x_num: 1,
                x_denom: -2,
                y_num: 3,
                y_denom: -4,
            },
        ),
        (
            0x0415,
            words(&[-4, 3, -2, 1]),
            G::ExcludeClipRect {
                left: 1,
                top: -2,
                right: 3,
                bottom: -4,
            },
        ),
        (
            0x0416,
            words(&[-4, 3, -2, 1]),
            G::IntersectClipRect {
                left: 1,
                top: -2,
                right: 3,
                bottom: -4,
            },
        ),
        (
            0x0418,
            words(&[-4, 3, -2, 1]),
            G::Ellipse {
                left: 1,
                top: -2,
                right: 3,
                bottom: -4,
            },
        ),
        (
            0x041b,
            words(&[-4, 3, -2, 1]),
            G::Rectangle {
                left: 1,
                top: -2,
                right: 3,
                bottom: -4,
            },
        ),
        (
            0x061c,
            words(&[-6, 5, -4, 3, -2, 1]),
            G::RoundRect {
                ellipse_width: 5,
                ellipse_height: -6,
                left: 1,
                top: -2,
                right: 3,
                bottom: -4,
            },
        ),
        (
            0x0817,
            words(&[-8, 7, -6, 5, -4, 3, -2, 1]),
            G::Arc {
                x_end: 7,
                y_end: -8,
                x_start: 5,
                y_start: -6,
                left: 1,
                top: -2,
                right: 3,
                bottom: -4,
            },
        ),
        (
            0x081a,
            words(&[-8, 7, -6, 5, -4, 3, -2, 1]),
            G::Pie {
                x_end: 7,
                y_end: -8,
                x_start: 5,
                y_start: -6,
                left: 1,
                top: -2,
                right: 3,
                bottom: -4,
            },
        ),
        (
            0x0830,
            words(&[-8, 7, -6, 5, -4, 3, -2, 1]),
            G::Chord {
                x_end: 7,
                y_end: -8,
                x_start: 5,
                y_start: -6,
                left: 1,
                top: -2,
                right: 3,
                bottom: -4,
            },
        ),
        (
            0x0419,
            words(&[0x1234, 0x5678, -2, 1]),
            G::FloodFill {
                color: 0x56781234,
                x: 1,
                y: -2,
            },
        ),
        (
            0x041f,
            words(&[0x1234, 0x5678, -2, 1]),
            G::SetPixel {
                color: 0x56781234,
                x: 1,
                y: -2,
            },
        ),
        (
            0x0548,
            words(&[1, 0x1234, 0x5678, -2, 1]),
            G::ExtFloodFill {
                mode: 1,
                color: 0x56781234,
                x: 1,
                y: -2,
            },
        ),
    ];
    for (function, body, expected) in cases {
        let input = file(&[(function, body.clone())]);
        let mut doc = wmf::parse(&input, &ParseLimits::default()).unwrap();
        assert_eq!(
            typed(&doc, 0),
            Some(&TypedRecord::Geometry(expected.clone())),
            "{function:04x}"
        );
        assert_eq!(wmf::serialize(&doc).unwrap(), input);
        doc.replace_typed(0, TypedRecord::Geometry(expected))
            .unwrap();
        let output = wmf::serialize(&doc).unwrap();
        let edited = wmf::parse(&output, &ParseLimits::default()).unwrap();
        assert_eq!(
            edited.record_body(&edited.records()[0]),
            Some(body.as_slice())
        );
        let input = file(&[
            (function, body[..body.len() - 2].to_vec()),
            (0x0214, words(&[2, 1])),
        ]);
        let doc = wmf::parse(&input, &ParseLimits::default()).unwrap();
        assert_eq!(typed(&doc, 0), None, "{function:04x}");
        assert_eq!(
            typed(&doc, 1),
            Some(&TypedRecord::Geometry(G::MoveTo { x: 1, y: 2 }))
        );
        assert_eq!(wmf::serialize(&doc).unwrap(), input);
    }
}

#[test]
fn point_arrays_preserve_suffix_unknown_records_and_tail_after_edits() {
    let points = vec![
        Point {
            x: i16::MIN,
            y: i16::MAX,
        },
        Point { x: 3, y: -4 },
    ];
    for (function, prefix, expected, replacement) in [
        (
            0x0324,
            vec![2],
            G::Polygon {
                points: points.clone(),
            },
            G::Polygon {
                points: vec![Point { x: 9, y: -8 }; 2],
            },
        ),
        (
            0x0325,
            vec![2],
            G::Polyline {
                points: points.clone(),
            },
            G::Polyline {
                points: vec![Point { x: 9, y: -8 }; 2],
            },
        ),
        (
            0x0538,
            vec![2, 1, 1],
            G::PolyPolygon {
                poly_counts: vec![1, 1],
                points: points.clone(),
            },
            G::PolyPolygon {
                poly_counts: vec![2],
                points: vec![Point { x: 9, y: -8 }; 2],
            },
        ),
    ] {
        let mut body = words(&prefix);
        body.extend(words(&[i16::MIN, i16::MAX, 3, -4]));
        body.extend([0xaa, 0xbb]);
        let mut input = file(&[(function, body), (0x7777, vec![9, 8])]);
        input.extend([7, 6]);
        let mut doc = wmf::parse(&input, &ParseLimits::default()).unwrap();
        assert_eq!(typed(&doc, 0), Some(&TypedRecord::Geometry(expected)));
        assert_eq!(wmf::serialize(&doc).unwrap(), input);
        doc.replace_typed(0, TypedRecord::Geometry(replacement.clone()))
            .unwrap();
        let output = wmf::serialize(&doc).unwrap();
        let edited = wmf::parse(&output, &ParseLimits::default()).unwrap();
        assert_eq!(typed(&edited, 0), Some(&TypedRecord::Geometry(replacement)));
        assert!(edited
            .record_body(&edited.records()[0])
            .unwrap()
            .ends_with(&[0xaa, 0xbb]));
        assert_eq!(
            edited.record_bytes(&edited.records()[1]),
            doc.record_bytes(&doc.records()[1])
        );
        assert_eq!(edited.tail(), &[7, 6]);
    }
}

#[test]
fn patblt_uses_normative_dword_then_signed_rectangle_layout_and_preserves_wire() {
    let mut body = Vec::new();
    body.extend_from_slice(&0x00cc_0020u32.to_le_bytes());
    body.extend(words(&[-3, 4, -5, 6])); // height, width, YLeft, XLeft
    body.extend([0xaa, 0xbb]);
    let input = file(&[(0xab1d, body.clone())]);
    let mut doc = wmf::parse(&input, &ParseLimits::default()).unwrap();
    let expected = G::PatBlt {
        raster_operation: 0x00cc_0020,
        height: -3,
        width: 4,
        y_left: -5,
        x_left: 6,
    };
    assert_eq!(
        typed(&doc, 0),
        Some(&TypedRecord::Geometry(expected.clone()))
    );
    assert_eq!(&wmf::serialize(&doc).unwrap()[18..], &input[18..]);
    let snapshot = doc.clone();
    assert_eq!(
        doc.replace_typed(0, TypedRecord::Geometry(G::MoveTo { x: 1, y: 2 })),
        Err(EditFailure::RecordFamily { index: 0 })
    );
    assert_eq!(doc, snapshot);
    doc.replace_typed(0, TypedRecord::Geometry(expected))
        .unwrap();
    assert_eq!(doc.records()[0].function(), 0xab1d);
    assert_eq!(&wmf::serialize(&doc).unwrap()[18..], &input[18..]);

    let malformed = file(&[(0x061d, vec![0; 10]), (0x0214, words(&[2, 1]))]);
    let recovered = wmf::parse(&malformed, &ParseLimits::default()).unwrap();
    assert!(typed(&recovered, 0).is_none());
    assert_eq!(
        typed(&recovered, 1),
        Some(&TypedRecord::Geometry(G::MoveTo { x: 1, y: 2 }))
    );
    assert_eq!(&wmf::serialize(&recovered).unwrap()[18..], &malformed[18..]);
}

#[test]
fn malformed_counts_recover_with_original_bytes() {
    for (function, body) in [
        (0x0324, words(&[-1])),
        (0x0325, words(&[-1])),
        (0x0324, words(&[1, 2, 3])),
        (0x0325, words(&[2, 1, 2])),
        (0x0538, words(&[2, 1])),
        (0x0538, words(&[2, 32767, 32767])),
    ] {
        let input = file(&[(function, body), (0x0214, words(&[2, 1]))]);
        let doc = wmf::parse(&input, &ParseLimits::default()).unwrap();
        assert_eq!(typed(&doc, 0), None);
        assert_eq!(
            typed(&doc, 1),
            Some(&TypedRecord::Geometry(G::MoveTo { x: 1, y: 2 }))
        );
        assert!(!doc.diagnostics().is_empty());
        assert_eq!(wmf::serialize(&doc).unwrap(), input);
    }
}

#[test]
fn invalid_edits_are_atomic() {
    let input = file(&[(0x0538, words(&[1, 2, 1, 2, 3, 4]))]);
    let mut doc = wmf::parse(&input, &ParseLimits::default()).unwrap();
    assert!(matches!(
        doc.replace_typed(
            0,
            TypedRecord::Geometry(G::PolyPolygon {
                poly_counts: vec![3],
                points: vec![Point { x: 1, y: 2 }; 2]
            })
        ),
        Err(EditFailure::RecordLayout { .. })
    ));
    assert_eq!(wmf::serialize(&doc).unwrap(), input);
    let input = file(&[(0x0325, words(&[0]))]);
    let mut doc = wmf::parse(&input, &ParseLimits::default()).unwrap();
    assert!(matches!(
        doc.replace_typed(
            0,
            TypedRecord::Geometry(G::Polyline {
                points: vec![Point { x: 0, y: 0 }; 32768]
            })
        ),
        Err(EditFailure::SizeOverflow)
    ));
    assert_eq!(wmf::serialize(&doc).unwrap(), input);
}

#[test]
fn point_work_uses_the_cumulative_document_budget() {
    let body = words(&[4, 1, 2, 3, 4, 5, 6, 7, 8]);
    let input = file(&[(0x0325, body.clone()), (0x0325, body)]);
    let limits = ParseLimits {
        max_work_units: 14,
        ..ParseLimits::default()
    };
    assert!(matches!(
        wmf::parse(&input, &limits),
        Err(ParseFailure::LimitExceeded {
            kind: LimitKind::WorkUnits,
            ..
        })
    ));
    assert!(wmf::parse(&input, &ParseLimits::default()).is_ok());
}

#[test]
fn invalid_flood_mode_is_preserved_as_malformed_and_valid_modes_are_editable() {
    let input = file(&[
        (0x0548, words(&[2, 0, 0, -1, 2])),
        (0x0548, words(&[0, 0, 0, -1, 2])),
    ]);
    let mut doc = wmf::parse(&input, &ParseLimits::default()).unwrap();
    assert_eq!(typed(&doc, 0), None);
    assert_eq!(
        typed(&doc, 1),
        Some(&TypedRecord::Geometry(G::ExtFloodFill {
            mode: 0,
            color: 0,
            x: 2,
            y: -1
        }))
    );
    assert!(matches!(
        doc.replace_typed(
            1,
            TypedRecord::Geometry(G::ExtFloodFill {
                mode: 2,
                color: 0,
                x: 2,
                y: -1
            })
        ),
        Err(EditFailure::RecordLayout { .. })
    ));
    assert_eq!(wmf::serialize(&doc).unwrap(), input);
}
