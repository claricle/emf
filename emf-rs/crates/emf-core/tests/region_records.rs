use emf_core::{
    parse, serialize, serialize_with_limits, DiagnosticKind, EditFailure, LimitKind, ParseFailure,
    ParseLimits, RecordData, Rect, RegionData, SerializeFailure, SerializeLimits, Size,
};
const BOUNDS: Rect = Rect {
    left: -20,
    top: i32::MIN,
    right: 100,
    bottom: i32::MAX,
};
fn words(values: &[u32]) -> Vec<u8> {
    values.iter().flat_map(|v| v.to_le_bytes()).collect()
}
fn rect_bytes(r: Rect) -> Vec<u8> {
    words(&[r.left as u32, r.top as u32, r.right as u32, r.bottom as u32])
}
fn record(kind: u32, payload: &[u8]) -> Vec<u8> {
    let mut bytes = words(&[kind, 8 + payload.len() as u32]);
    bytes.extend(payload);
    bytes
}
fn input(kind: u32, payload: &[u8]) -> Vec<u8> {
    let mut bytes = vec![0; 88];
    bytes[..8].copy_from_slice(&words(&[1, 88]));
    bytes[40..44].copy_from_slice(&0x464d4520u32.to_le_bytes());
    bytes.extend(record(kind, payload));
    bytes.extend(record(999, b"opaque!!"));
    bytes.extend(record(14, &words(&[0, 16, 20])));
    bytes.extend(b"tail");
    bytes
}
fn region() -> RegionData {
    RegionData {
        region_type: 0x12345678,
        bounds: BOUNDS,
        rectangles: vec![BOUNDS],
        trailing_bytes: b"inside!!".to_vec(),
    }
}
fn payload(kind: u32, region: &RegionData) -> Vec<u8> {
    let mut data = words(&[
        32,
        region.region_type,
        region.rectangles.len() as u32,
        region.rectangles.len() as u32 * 16,
    ]);
    data.extend(rect_bytes(region.bounds));
    for r in &region.rectangles {
        data.extend(rect_bytes(*r));
    }
    data.extend(&region.trailing_bytes);
    let mut bytes = if kind == 75 {
        Vec::new()
    } else {
        rect_bytes(BOUNDS)
    };
    bytes.extend(words(&[data.len() as u32]));
    if kind == 71 || kind == 72 {
        bytes.extend(words(&[0x87654321]));
    }
    if kind == 72 {
        bytes.extend(words(&[i32::MIN as u32, 27]));
    }
    if kind == 75 {
        bytes.extend(words(&[u32::MAX]));
    }
    bytes.extend(data);
    bytes.extend(b"outside!");
    bytes
}
fn state(kind: u32, region: RegionData) -> RecordData {
    match kind {
        71 => RecordData::FillRgn {
            bounds: BOUNDS,
            ih_brush: 0x87654321,
            region,
        },
        72 => RecordData::FrameRgn {
            bounds: BOUNDS,
            ih_brush: 0x87654321,
            stroke: Size {
                cx: i32::MIN,
                cy: 27,
            },
            region,
        },
        73 => RecordData::InvertRgn {
            bounds: BOUNDS,
            region,
        },
        74 => RecordData::PaintRgn {
            bounds: BOUNDS,
            region,
        },
        75 => RecordData::ExtSelectClipRgn {
            region_mode: u32::MAX,
            region: Some(region),
        },
        _ => unreachable!(),
    }
}
#[test]
fn semantic_decode_and_resize_preserve_unknown_fields_and_opaque_bytes() {
    for kind in 71..=75 {
        let original = input(kind, &payload(kind, &region()));
        let mut doc = parse(&original, &ParseLimits::default()).unwrap();
        assert_eq!(doc.records()[0].data(), &state(kind, region()));
        assert!(doc.diagnostics().is_empty());
        assert_eq!(serialize(&doc).unwrap(), original);
        let sibling = doc.record_bytes(&doc.records()[1]).unwrap().to_vec();
        let mut edited = region();
        edited.rectangles.push(Rect {
            left: 1,
            top: 2,
            right: 3,
            bottom: 4,
        });
        edited.bounds.left = -123;
        doc.edit_record(0, state(kind, edited.clone())).unwrap();
        let bytes = serialize(&doc).unwrap();
        let doc = parse(&bytes, &ParseLimits::default()).unwrap();
        assert_eq!(doc.records()[0].data(), &state(kind, edited.clone()));
        assert!(doc.diagnostics().is_empty());
        assert_eq!(
            doc.record_bytes(&doc.records()[0]).unwrap(),
            record(kind, &payload(kind, &edited))
        );
        assert_eq!(doc.record_bytes(&doc.records()[1]).unwrap(), sibling);
        assert_eq!(doc.trailing_bytes(), b"tail");
        assert_eq!(doc.header().n_bytes as usize, bytes.len());
        assert_eq!(doc.header().n_records, 4);
    }
}
fn assert_raw(kind: u32, payload: &[u8]) {
    let original = input(kind, payload);
    let doc = parse(&original, &ParseLimits::default()).unwrap();
    assert_eq!(doc.records()[0].data(), &RecordData::Raw);
    assert_eq!(
        doc.diagnostics()[0].kind,
        DiagnosticKind::InvalidRecordPayload
    );
    assert_eq!(doc.records()[1].record_type(), 999);
    assert_eq!(serialize(&doc).unwrap(), original);
}
#[test]
fn malformed_region_lengths_and_counts_remain_raw() {
    for kind in 71..=75 {
        let valid = payload(kind, &region());
        let fixed = match kind {
            71 => 24,
            72 => 32,
            73 | 74 => 20,
            _ => 8,
        };
        for len in 0..fixed + 32 {
            assert_raw(kind, &valid[..len]);
        }
        for (offset, value) in [
            (if kind == 75 { 0 } else { 16 }, u32::MAX),
            (fixed, 31),
            (fixed, 36),
            (fixed + 8, u32::MAX),
            (fixed + 12, 0),
            (fixed + 12, 15),
            (fixed + 12, 17),
            (fixed + 12, u32::MAX),
        ] {
            let mut bad = valid.clone();
            bad[offset..offset + 4].copy_from_slice(&value.to_le_bytes());
            assert_raw(kind, &bad);
        }
        assert_raw(kind, &valid[..fixed + 32 + 15]);
    }
}
#[test]
fn zero_clip_region_resets_only_in_copy_mode_and_can_be_edited() {
    let original = input(75, &words(&[0, 5]));
    let mut doc = parse(&original, &ParseLimits::default()).unwrap();
    let reset = RecordData::ExtSelectClipRgn {
        region_mode: 5,
        region: None,
    };
    assert_eq!(doc.records()[0].data(), &reset);
    assert_eq!(serialize(&doc).unwrap(), original);
    assert_eq!(
        doc.edit_record(
            0,
            RecordData::ExtSelectClipRgn {
                region_mode: 1,
                region: None
            }
        ),
        Err(EditFailure::RecordLayout { index: 0 })
    );
    doc.edit_record(0, state(75, region())).unwrap();
    let bytes = serialize(&doc).unwrap();
    let mut doc = parse(&bytes, &ParseLimits::default()).unwrap();
    assert_eq!(doc.records()[0].data(), &state(75, region()));
    doc.edit_record(0, reset.clone()).unwrap();
    assert_eq!(
        parse(&serialize(&doc).unwrap(), &ParseLimits::default())
            .unwrap()
            .records()[0]
            .data(),
        &reset
    );
    // A zero count carries no region for any mode, as in Ruby's tolerant native.
    for mode in [0, 1, 2, 3, 4, u32::MAX] {
        let original = input(75, &words(&[0, mode]));
        let doc = parse(&original, &ParseLimits::default()).unwrap();
        assert_eq!(
            doc.records()[0].data(),
            &RecordData::ExtSelectClipRgn {
                region_mode: mode,
                region: None
            }
        );
        assert!(doc.diagnostics().is_empty());
        assert_eq!(serialize(&doc).unwrap(), original);
    }
    let mut empty = region();
    empty.rectangles.clear();
    let doc = parse(&input(75, &payload(75, &empty)), &ParseLimits::default()).unwrap();
    assert_eq!(doc.records()[0].data(), &state(75, empty));
}
#[test]
fn parse_and_serialize_limits_are_inclusive() {
    let original = input(71, &payload(71, &region()));
    let mut limits = ParseLimits {
        max_allocated_bytes: 0,
        ..ParseLimits::default()
    };
    loop {
        match parse(&original, &limits) {
            Err(ParseFailure::LimitExceeded {
                kind: LimitKind::AllocatedBytes,
                requested,
                ..
            }) => limits.max_allocated_bytes = requested as usize,
            Ok(_) => break,
            other => panic!("{other:?}"),
        }
    }
    limits.max_allocated_bytes -= 1;
    assert!(matches!(
        parse(&original, &limits),
        Err(ParseFailure::LimitExceeded {
            kind: LimitKind::AllocatedBytes,
            ..
        })
    ));
    limits.max_allocated_bytes += 1;
    limits.max_work_units = 0;
    loop {
        match parse(&original, &limits) {
            Err(ParseFailure::LimitExceeded {
                kind: LimitKind::WorkUnits,
                requested,
                ..
            }) => limits.max_work_units = requested,
            Ok(_) => break,
            other => panic!("{other:?}"),
        }
    }
    limits.max_work_units -= 1;
    assert!(matches!(
        parse(&original, &limits),
        Err(ParseFailure::LimitExceeded {
            kind: LimitKind::WorkUnits,
            ..
        })
    ));
    limits.max_work_units += 1;
    let mut doc = parse(&original, &limits).unwrap();
    doc.edit_record(0, state(71, region())).unwrap();
    let mut limits = SerializeLimits {
        max_output_bytes: original.len(),
        max_work_units: 0,
    };
    loop {
        match serialize_with_limits(&doc, &limits) {
            Err(SerializeFailure::LimitExceeded {
                kind: LimitKind::WorkUnits,
                requested,
                ..
            }) => limits.max_work_units = requested,
            Ok(bytes) => {
                assert_eq!(bytes.len(), original.len());
                break;
            }
            other => panic!("{other:?}"),
        }
    }
    limits.max_work_units -= 1;
    assert!(matches!(
        serialize_with_limits(&doc, &limits),
        Err(SerializeFailure::LimitExceeded {
            kind: LimitKind::WorkUnits,
            ..
        })
    ));
    limits.max_work_units += 1;
    limits.max_output_bytes -= 1;
    assert!(matches!(
        serialize_with_limits(&doc, &limits),
        Err(SerializeFailure::LimitExceeded {
            kind: LimitKind::OutputBytes,
            ..
        })
    ));
}
