use emf_core::{
    emf_plus::{self as plus, Drawing, PointData, RecordData, Rectangle, RelativeCoordinate},
    LimitKind, ParseFailure, ParseLimits, SerializeFailure,
};

fn words(values: &[u32]) -> Vec<u8> {
    values.iter().flat_map(|n| n.to_le_bytes()).collect()
}
fn record(kind: u16, flags: u16, data: &[u8]) -> Vec<u8> {
    let size = (12 + data.len() + 3) & !3;
    let mut bytes = Vec::new();
    bytes.extend_from_slice(&kind.to_le_bytes());
    bytes.extend_from_slice(&flags.to_le_bytes());
    bytes.extend_from_slice(&(size as u32).to_le_bytes());
    bytes.extend_from_slice(&(data.len() as u32).to_le_bytes());
    bytes.extend_from_slice(data);
    bytes.resize(size, 0xa5);
    bytes
}
fn parse(bytes: &[u8]) -> plus::Stream {
    plus::parse(bytes, &ParseLimits::default()).unwrap()
}

#[test]
fn rectangle_ellipse_and_arc_families_decode_and_edit_both_encodings() {
    for compressed in [false, true] {
        for kind in [0x400a, 0x400b, 0x400e, 0x400f, 0x4010, 0x4011, 0x4012] {
            let brush = matches!(kind, 0x400a | 0x400e | 0x4010);
            let mut body = Vec::new();
            if brush {
                body.extend(words(&[0xffabcdef]));
            }
            if matches!(kind, 0x400a | 0x400b) {
                body.extend(words(&[1]));
            }
            if matches!(kind, 0x4010..=0x4012) {
                body.extend(words(&[0x7fc00123, 0x80000000]));
            }
            if compressed {
                body.extend([-10i16, 20, -30, 40].iter().flat_map(|n| n.to_le_bytes()));
            } else {
                body.extend(words(&[0x7fc00123, 0x80000000, 3, 4]));
            }
            let bytes = record(kind, if compressed { 0xc05a } else { 0x805a }, &body);
            let mut stream = parse(&bytes);
            assert_eq!(plus::serialize(&stream).unwrap(), bytes);
            let RecordData::Drawing(drawing) = &mut stream.records[0].data else {
                panic!("drawing remains opaque")
            };
            let rectangle = match drawing {
                Drawing::Rectangles {
                    brush: b,
                    rectangles,
                } => {
                    assert_eq!(b.is_some(), brush);
                    &mut rectangles[0]
                }
                Drawing::Ellipse {
                    brush: b,
                    rectangle,
                } => {
                    assert_eq!(b.is_some(), brush);
                    rectangle
                }
                Drawing::Arc {
                    brush: b,
                    start_angle,
                    sweep_angle,
                    rectangle,
                } => {
                    assert_eq!(b.is_some(), brush);
                    assert_eq!(*start_angle, 0x7fc00123);
                    assert_eq!(*sweep_angle, 0x80000000);
                    rectangle
                }
                _ => panic!("wrong drawing family"),
            };
            match rectangle {
                Rectangle::Integer(r) => {
                    assert_eq!(r[0], -10);
                    r[0] = -123;
                }
                Rectangle::Float(r) => {
                    assert_eq!(r[0], 0x7fc00123);
                    r[0] = 0x12345678;
                }
            }
            let edited = plus::serialize(&stream).unwrap();
            assert_ne!(edited, bytes);
            assert_eq!(parse(&edited), stream);
            assert_eq!(edited[2..4], bytes[2..4]);
        }
    }
}

#[test]
fn counted_points_preserve_signed_relative_widths_and_float_bits() {
    for kind in [0x400c, 0x400d, 0x4019] {
        for mode in [0, 0x4000, 0x0800, 0x4800] {
            let mut body = Vec::new();
            if kind == 0x400c {
                body.extend(words(&[0xff010203]));
            }
            body.extend(words(&[4]));
            if mode & 0x0800 != 0 {
                // Mixed integer7/integer15; includes deliberately wide encoding of 1.
                body.extend([
                    0x40, 0xbf, 0xff, 0x3f, 0xc0, 0x00, 0x80, 0x01, 0x7f, 0x00, 0x00,
                ]);
                body.push(0xed); // internal DataSize padding, distinct from record padding.
            } else if mode != 0 {
                body.extend(
                    [-32768i16, 32767, -1, 0, 1, 2, 3, 4]
                        .iter()
                        .flat_map(|n| n.to_le_bytes()),
                );
            } else {
                body.extend(words(&[0x7fc00123, 0x80000000, 1, 2, 3, 4, 5, 6]));
            }
            let bytes = record(kind, mode | 0x123, &body);
            let mut stream = parse(&bytes);
            assert_eq!(plus::serialize(&stream).unwrap(), bytes);
            let RecordData::Drawing(Drawing::Points {
                points,
                data_padding,
                ..
            }) = &mut stream.records[0].data
            else {
                panic!()
            };
            assert_eq!(points.count(), 4);
            match points {
                PointData::Relative(p) => {
                    assert_eq!(
                        p[0],
                        [
                            RelativeCoordinate::Seven(-64),
                            RelativeCoordinate::Fifteen(16383)
                        ]
                    );
                    assert_eq!(p[1][1], RelativeCoordinate::Fifteen(-16384));
                    assert_eq!(p[2][0], RelativeCoordinate::Fifteen(1));
                    assert_eq!(data_padding, &[0xed]);
                    p[0][0] = RelativeCoordinate::Seven(-63);
                }
                PointData::Integer(p) => {
                    assert_eq!(p[0], [-32768, 32767]);
                    p[0][0] = -42;
                }
                PointData::Float(p) => {
                    assert_eq!(p[0], [0x7fc00123, 0x80000000]);
                    p[0][0] = 9;
                }
            }
            let edited = plus::serialize(&stream).unwrap();
            assert_ne!(edited, bytes);
            assert_eq!(parse(&edited), stream);
        }
    }
}

#[test]
fn drawing_counts_flags_and_budgets_fail_without_normalization() {
    for kind in [0x400a, 0x400b, 0x400c, 0x400d, 0x4019] {
        for count in [0, u32::MAX] {
            let data = if matches!(kind, 0x400a | 0x400c) {
                words(&[1, count])
            } else {
                words(&[count])
            };
            assert!(plus::parse(&record(kind, 0, &data), &ParseLimits::default()).is_err());
        }
    }
    let bytes = record(0x400d, 0x4000, &words(&[2, 1, 2]));
    let mut stream = parse(&bytes);
    stream.records[0].flags = 0;
    assert!(matches!(
        plus::serialize(&stream),
        Err(SerializeFailure::Inconsistent { .. })
    ));
    let mut stream = parse(&record(0x400d, 0x0800, &[2, 0, 0, 0, 0, 0, 0, 0]));
    let RecordData::Drawing(Drawing::Points {
        points: PointData::Relative(p),
        ..
    }) = &mut stream.records[0].data
    else {
        panic!()
    };
    p[0][0] = RelativeCoordinate::Seven(64);
    assert!(plus::serialize(&stream).is_err());
    // Enough bytes to validate count, but vector allocation is independently bounded.
    let limits = ParseLimits {
        max_allocated_bytes: bytes.len() + std::mem::size_of::<usize>(),
        ..ParseLimits::default()
    };
    assert!(matches!(
        plus::parse(&bytes, &limits),
        Err(plus::Error::Resource(ParseFailure::LimitExceeded {
            kind: LimitKind::AllocatedBytes,
            ..
        }))
    ));
    let bad_relative = record(0x400d, 0x0800, &[2, 0, 0, 0, 0, 0, 0, 0x80]);
    assert!(plus::parse(&bad_relative, &ParseLimits::default()).is_err());
}

#[test]
fn object_reference_drawing_words_are_typed_and_mutable() {
    for kind in 0x4013..=0x4015 {
        let bytes = record(kind, 0x8001, &words(&[0xffabcdef]));
        let mut stream = parse(&bytes);
        let RecordData::Drawing(Drawing::ObjectReference { value }) = &mut stream.records[0].data
        else {
            panic!()
        };
        assert_eq!(*value, 0xffabcdef);
        *value = 3;
        let edited = plus::serialize(&stream).unwrap();
        assert_eq!(parse(&edited), stream);
        assert_eq!(&edited[12..16], &3u32.to_le_bytes());
    }
}

#[test]
fn cardinal_splines_preserve_relative_or_reserved_flags_and_edit_tension() {
    for kind in 0x4016..=0x4018 {
        for compressed in [false, true] {
            for relative in [false, true] {
                let count = if kind == 0x4018 { 2 } else { 3 };
                let mut body = Vec::new();
                if kind == 0x4016 {
                    body.extend(words(&[0xffabcdef]));
                }
                body.extend(words(&[0x7fc12345]));
                if kind == 0x4018 {
                    body.extend(words(&[1, 1]));
                }
                body.extend(words(&[count]));
                if relative && kind != 0x4018 {
                    body.extend(vec![1u8; count as usize * 2]);
                    body.extend([0xab, 0xcd]);
                } else if compressed {
                    body.extend(vec![0x7fu8; count as usize * 4]);
                } else {
                    body.extend(words(&vec![0x80000000; count as usize * 2]));
                }
                let flags = 0xa055
                    | if compressed { 0x4000 } else { 0 }
                    | if relative { 0x0800 } else { 0 };
                let bytes = record(kind, flags, &body);
                let mut stream = parse(&bytes);
                assert_eq!(plus::serialize(&stream).unwrap(), bytes);
                let RecordData::Drawing(Drawing::Curve {
                    brush,
                    tension,
                    range,
                    points,
                    ..
                }) = &mut stream.records[0].data
                else {
                    panic!("curve remains opaque")
                };
                assert_eq!(*brush, (kind == 0x4016).then_some(0xffabcdef));
                assert_eq!(*tension, 0x7fc12345);
                assert_eq!(*range, (kind == 0x4018).then_some([1, 1]));
                assert_eq!(points.count(), count as usize);
                assert_eq!(
                    matches!(points, PointData::Relative(_)),
                    relative && kind != 0x4018
                );
                *tension = 0x3f800000;
                assert_eq!(parse(&plus::serialize(&stream).unwrap()), stream);
            }
        }
    }
    for kind in 0x4016..=0x4018 {
        let mut body = Vec::new();
        if kind == 0x4016 {
            body.extend(words(&[0]));
        }
        body.extend(words(&[0]));
        if kind == 0x4018 {
            body.extend(words(&[0, 1]));
        }
        body.extend(words(&[u32::MAX]));
        assert!(plus::parse(&record(kind, 0x4800, &body), &ParseLimits::default()).is_err());
    }
}

#[test]
fn image_destinations_are_typed_counted_and_mutable() {
    for kind in [0x401a, 0x401b] {
        for compressed in [false, true] {
            for relative in [false, true] {
                let mut body = words(&[u32::MAX, 2, 0x80000000, 0x7fc12345, 3, 4]);
                let count = if kind == 0x401b {
                    body.extend(words(&[3]));
                    3
                } else {
                    2
                };
                if relative && kind == 0x401b {
                    body.extend([0x80, 1, 0x7f, 2, 3, 4, 5]);
                    body.push(0xaa);
                } else if compressed {
                    body.extend(vec![0x80u8; count * 4]);
                } else {
                    body.extend(words(&vec![0x7fc12345; count * 2]));
                }
                let flags =
                    0xa001 | if compressed { 0x4000 } else { 0 } | if relative { 0x800 } else { 0 };
                let bytes = record(kind, flags, &body);
                let mut stream = parse(&bytes);
                assert_eq!(plus::serialize(&stream).unwrap(), bytes);
                let RecordData::Drawing(d) = &mut stream.records[0].data else {
                    panic!("image remains opaque")
                };
                let source = match d {
                    Drawing::ImageRect {
                        source,
                        destination,
                    } => {
                        assert_eq!(matches!(destination, Rectangle::Integer(_)), compressed);
                        source
                    }
                    Drawing::ImagePoints { source, points, .. } => {
                        assert_eq!(points.count(), 3);
                        assert_eq!(matches!(points, PointData::Relative(_)), relative);
                        source
                    }
                    _ => panic!("wrong image shape"),
                };
                assert_eq!(source.attributes_id, u32::MAX);
                assert_eq!(source.unit, 2);
                assert_eq!(source.rectangle, [0x80000000, 0x7fc12345, 3, 4]);
                source.rectangle[0] = 0x3f800000;
                assert_eq!(parse(&plus::serialize(&stream).unwrap()), stream);
            }
        }
    }
    for count in [0, 2, 4, u32::MAX] {
        let mut body = words(&[0, 2, 0, 0, 0, 0, count]);
        body.extend([0u8; 32]);
        assert!(plus::parse(&record(0x401b, 0x4800, &body), &ParseLimits::default()).is_err());
    }
}
