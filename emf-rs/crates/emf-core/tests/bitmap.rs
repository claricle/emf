use emf_core::{parse, serialize, ParseLimits, RecordData};
fn put(b: &mut [u8], at: usize, n: u32) {
    b[at..at + 4].copy_from_slice(&n.to_le_bytes());
}
fn shape(kind: u32) -> (usize, usize, Option<usize>) {
    match kind {
        76 => (100, 84, None),
        77 | 114 | 116 => (108, 84, None),
        78 => (128, 84, Some(112)),
        79 => (140, 96, Some(124)),
        80 => (76, 48, None),
        81 => (80, 48, None),
        93 | 94 => (32, 16, None),
        _ => panic!(),
    }
}
fn fixture(kind: u32) -> Vec<u8> {
    let (fixed, src, mask) = shape(kind);
    let mut r = vec![0; fixed];
    put(&mut r, 0, kind);
    // Deliberately unaligned data offsets: bitmap buffers are byte arrays.
    let mut cursor = fixed;
    for (i, at) in [Some(src + 8), mask, Some(src), mask.map(|v| v + 8)]
        .into_iter()
        .flatten()
        .enumerate()
    {
        r.extend_from_slice(&[0xd0 + i as u8; 3]);
        cursor += 3;
        put(&mut r, at, cursor as u32);
        put(&mut r, at + 4, 5);
        r.extend_from_slice(&[0xa0 + i as u8; 5]);
        cursor += 5;
    }
    r.extend_from_slice(b"suffix!!");
    let n = r.len() as u32;
    put(&mut r, 4, n);
    let mut b = vec![0; 88];
    put(&mut b, 0, 1);
    put(&mut b, 4, 88);
    put(&mut b, 40, 0x464d4520);
    b.extend_from_slice(&r);
    b.extend_from_slice(&[
        14, 0, 0, 0, 20, 0, 0, 0, 0, 0, 0, 0, 16, 0, 0, 0, 20, 0, 0, 0,
    ]);
    b.extend_from_slice(b"tail");
    b
}
const KINDS: [u32; 10] = [76, 77, 78, 79, 80, 81, 93, 94, 114, 116];
#[test]
fn bitmap_families_decode_and_preserve() {
    for kind in KINDS {
        let b = fixture(kind);
        let d = parse(&b, &ParseLimits::default()).unwrap();
        assert_ne!(d.records()[0].data(), &RecordData::Raw, "{kind}");
        assert_eq!(serialize(&d).unwrap(), b);
    }
}
#[test]
fn typed_edits_rebuild_offsets_preserve_gaps_suffixes_and_float_bits() {
    use emf_core::{BitmapRecord as B, ColorRef, Float32, Point};
    for kind in KINDS {
        let mut b = fixture(kind);
        if matches!(kind, 76..=79 | 114 | 116) {
            let xf = if kind == 79 { 64 } else { 52 };
            for (i, n) in [
                0x7fc01234, 0x80000000, 0x7f800000, 0xff800000, 1, 0xffcabcde,
            ]
            .into_iter()
            .enumerate()
            {
                put(&mut b, 88 + xf + i * 4, n);
            }
        }
        let mut d = parse(&b, &ParseLimits::default()).unwrap();
        let RecordData::Bitmap(mut r) = d.records()[0].data().clone() else {
            panic!()
        };
        assert_eq!(r.record_type(), kind);
        d.edit_record(0, RecordData::Bitmap(r.clone())).unwrap();
        assert_eq!(&serialize(&d).unwrap()[88..], &b[88..], "noop edit {kind}");
        let p = Point {
            x: i32::MIN,
            y: i32::MAX,
        };
        match &mut r {
            B::BitBlt {
                transfer,
                raster_operation,
            }
            | B::StretchBlt {
                transfer,
                raster_operation,
                ..
            }
            | B::MaskBlt {
                transfer,
                raster_operation,
                ..
            } => {
                transfer.destination = p;
                transfer.source.transform.dx = Float32::from_bits(0x80000000);
                *raster_operation = 0xdeadbeef;
            }
            B::AlphaBlend {
                transfer,
                blend,
                source_extent,
            } => {
                assert_eq!(transfer.source.transform.m11.to_bits(), 0x7fc01234);
                transfer.source.position = p;
                blend.flags = 0xd5;
                blend.source_constant_alpha = 0x7f;
                *source_extent = p;
            }
            B::TransparentBlt {
                transparent_color,
                source_extent,
                ..
            } => {
                *transparent_color = ColorRef {
                    red: 1,
                    green: 2,
                    blue: 3,
                    reserved: 255,
                };
                *source_extent = p;
            }
            B::PlgBlt {
                destination,
                source,
                mask,
                source_extent,
                ..
            } => {
                destination[2] = p;
                source.usage = u32::MAX;
                mask.position = p;
                *source_extent = p;
            }
            B::SetDibitsToDevice {
                transfer,
                start_scan,
                scan_count,
            } => {
                transfer.source = p;
                *start_scan = u32::MAX;
                *scan_count = 23;
            }
            B::StretchDibits {
                transfer,
                destination_extent,
                raster_operation,
            } => {
                transfer.source_extent = p;
                *destination_extent = p;
                *raster_operation = u32::MAX;
            }
            B::CreateMonoBrush {
                ih_brush, usage, ..
            }
            | B::CreateDibPatternBrushPt {
                ih_brush, usage, ..
            } => {
                *ih_brush = 0x80000001;
                *usage = u32::MAX;
            }
        }
        r.buffers_mut()
            .source_info
            .as_mut()
            .unwrap()
            .data
            .extend_from_slice(b"growth!");
        let expected = r.clone();
        d.edit_record(0, RecordData::Bitmap(r)).unwrap();
        let encoded = serialize(&d).unwrap();
        let decoded = parse(&encoded, &ParseLimits::default()).unwrap();
        assert_eq!(
            decoded.records()[0].data(),
            &RecordData::Bitmap(expected),
            "edited {kind}"
        );
        assert!(encoded.windows(8).any(|w| w == b"suffix!!"));
        assert_eq!(decoded.trailing_bytes(), b"tail");
        assert!(decoded.has_eof());
        assert_eq!(serialize(&decoded).unwrap(), encoded);
    }
}
#[test]
fn malformed_ranges_and_truncation_recover_without_losing_next_record() {
    for kind in KINDS {
        let (fixed, at, mask) = shape(kind);
        for (field, value) in [
            (at, 0),
            (at, 7),
            (at, (fixed - 1) as u32),
            (at, u32::MAX),
            (at + 4, u32::MAX),
            (at, read(&fixture(kind), 88 + at + 8)),
        ] {
            let mut b = fixture(kind);
            put(&mut b, 88 + field, value);
            let d = parse(&b, &ParseLimits::default()).unwrap();
            assert_eq!(
                d.records()[0].data(),
                &RecordData::Raw,
                "{kind} {field} {value}"
            );
            // The fixed prefix is intact, so the record is opaque, not rejected.
            assert!(d.diagnostics().is_empty(), "{kind} {field} {value}");
            assert!(d.has_eof());
            assert_eq!(serialize(&d).unwrap(), b);
        }
        if let Some(mask) = mask {
            let mut b = fixture(kind);
            let off = read(&b, 88 + at);
            put(&mut b, 88 + mask, off);
            let d = parse(&b, &ParseLimits::default()).unwrap();
            assert_eq!(d.records()[0].data(), &RecordData::Raw);
            assert!(d.has_eof());
        }
        let mut b = fixture(kind);
        let end = 88 + read(&b, 92) as usize;
        b.drain(88 + fixed - 4..end);
        put(&mut b, 92, (fixed - 4) as u32);
        let d = parse(&b, &ParseLimits::default()).unwrap();
        assert_eq!(d.records()[0].data(), &RecordData::Raw);
        assert_eq!(d.diagnostics().len(), 1, "{kind} below the fixed prefix");
        assert!(d.has_eof());
        assert_eq!(serialize(&d).unwrap(), b);
    }
}
fn read(b: &[u8], at: usize) -> u32 {
    u32::from_le_bytes(b[at..at + 4].try_into().unwrap())
}
#[test]
fn empty_absent_buffers_and_maskless_records_are_editable() {
    use emf_core::BitmapRecord;
    for kind in KINDS {
        let (fixed, at, mask) = shape(kind);
        let mut b = fixture(kind);
        // Make source info present and empty at the end of source bits.
        let end = read(&b, 88 + at + 8) + read(&b, 88 + at + 12);
        put(&mut b, 88 + at, end);
        put(&mut b, 88 + at + 4, 0);
        if let Some(mask) = mask {
            for off in [mask, mask + 4, mask + 8, mask + 12] {
                put(&mut b, 88 + off, 0);
            }
        }
        let mut d = parse(&b, &ParseLimits::default()).unwrap();
        let RecordData::Bitmap(r) = d.records()[0].data() else {
            panic!("{kind}")
        };
        assert!(r.buffers().source_info.as_ref().unwrap().data.is_empty());
        assert!(r.buffers().mask_info.is_none());
        d.edit_record(0, d.records()[0].data().clone()).unwrap();
        assert_eq!(&serialize(&d).unwrap()[88..], &b[88..]);
        // All four source offset/count values zero is a valid source-free operation.
        for off in [at, at + 4, at + 8, at + 12] {
            put(&mut b, 88 + off, 0);
        }
        let mut d = parse(&b, &ParseLimits::default()).unwrap();
        assert!(matches!(d.records()[0].data(), RecordData::Bitmap(_)));
        d.edit_record(0, d.records()[0].data().clone()).unwrap();
        assert_eq!(&serialize(&d).unwrap()[88..], &b[88..]);
        if let RecordData::Bitmap(BitmapRecord::BitBlt { transfer, .. }) = d.records()[0].data() {
            assert!(transfer.buffers.source_bits.is_none());
        }
        assert!(fixed >= 32);
    }
}
#[test]
fn invalid_buffer_edits_are_atomic() {
    use emf_core::{BitmapBuffer, BitmapBufferKind as K, EditFailure};
    let b = fixture(76);
    let mut d = parse(&b, &ParseLimits::default()).unwrap();
    let original = d.clone();
    let RecordData::Bitmap(mut r) = d.records()[0].data().clone() else {
        panic!()
    };
    r.buffers_mut().order = [K::SourceBits; 4];
    assert_eq!(
        d.edit_record(0, RecordData::Bitmap(r)),
        Err(EditFailure::RecordLayout { index: 0 })
    );
    assert_eq!(d, original);
    let RecordData::Bitmap(mut r) = d.records()[0].data().clone() else {
        panic!()
    };
    r.buffers_mut().mask_bits = Some(BitmapBuffer {
        padding: vec![],
        data: vec![1],
    });
    assert_eq!(
        d.edit_record(0, RecordData::Bitmap(r)),
        Err(EditFailure::RecordLayout { index: 0 })
    );
    assert_eq!(d, original);
}

#[test]
fn allocation_and_work_limits_are_inclusive() {
    use emf_core::{
        serialize_with_limits, LimitKind, ParseFailure, SerializeFailure, SerializeLimits,
    };
    let b = fixture(78);
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

#[test]
fn fixed_fields_follow_independent_wire_offsets() {
    use emf_core::{BitmapRecord as B, BitmapSource, Point};
    // Each fixed word identifies its absolute offset within the record.
    let word = |at: usize| 0x8000_0000 | at as u32;
    let point = |at| Point {
        x: word(at) as i32,
        y: word(at + 4) as i32,
    };
    let source = |s: &BitmapSource, pos, xf| {
        assert_eq!(s.position, point(pos));
        for (i, f) in [
            s.transform.m11,
            s.transform.m12,
            s.transform.m21,
            s.transform.m22,
            s.transform.dx,
            s.transform.dy,
        ]
        .into_iter()
        .enumerate()
        {
            assert_eq!(f.to_bits(), word(xf + i * 4));
        }
        let color = s.background_color;
        assert_eq!(
            [color.red, color.green, color.blue, color.reserved],
            word(xf + 24).to_le_bytes()
        );
        assert_eq!(s.usage, word(xf + 28));
    };
    for kind in KINDS {
        let mut bytes = fixture(kind);
        let (fixed, src, mask) = shape(kind);
        for at in (8..fixed).step_by(4) {
            if (src..src + 16).contains(&at) || mask.is_some_and(|m| (m..m + 16).contains(&at)) {
                continue;
            }
            put(&mut bytes, 88 + at, word(at));
        }
        let mut doc = parse(&bytes, &ParseLimits::default()).unwrap();
        let RecordData::Bitmap(r) = doc.records()[0].data().clone() else {
            panic!("{kind}")
        };
        match &r {
            B::BitBlt { transfer, .. }
            | B::StretchBlt { transfer, .. }
            | B::MaskBlt { transfer, .. }
            | B::AlphaBlend { transfer, .. }
            | B::TransparentBlt { transfer, .. } => {
                assert_eq!(transfer.destination, point(24));
                assert_eq!(transfer.destination_extent, point(32));
                assert_eq!(transfer.bounds.left, word(8) as i32);
                assert_eq!(transfer.bounds.bottom, word(20) as i32);
                source(&transfer.source, 44, 52);
            }
            B::PlgBlt {
                destination,
                source: s,
                source_extent,
                mask,
                ..
            } => {
                assert_eq!(*destination, [point(24), point(32), point(40)]);
                assert_eq!(*source_extent, point(56));
                source(s, 48, 64);
                assert_eq!(mask.position, point(112));
                assert_eq!(mask.usage, word(120));
            }
            B::SetDibitsToDevice { transfer, .. } | B::StretchDibits { transfer, .. } => {
                assert_eq!(transfer.destination, point(24));
                assert_eq!(transfer.source, point(32));
                assert_eq!(transfer.source_extent, point(40));
                assert_eq!(transfer.usage, word(64));
            }
            B::CreateMonoBrush {
                ih_brush, usage, ..
            }
            | B::CreateDibPatternBrushPt {
                ih_brush, usage, ..
            } => {
                assert_eq!(*ih_brush, word(8));
                assert_eq!(*usage, word(12));
            }
        }
        match &r {
            B::BitBlt {
                raster_operation, ..
            }
            | B::StretchBlt {
                raster_operation, ..
            }
            | B::MaskBlt {
                raster_operation, ..
            } => assert_eq!(*raster_operation, word(40)),
            B::StretchDibits {
                raster_operation,
                destination_extent,
                ..
            } => {
                assert_eq!(*raster_operation, word(68));
                assert_eq!(*destination_extent, point(72));
            }
            B::SetDibitsToDevice {
                start_scan,
                scan_count,
                ..
            } => {
                assert_eq!(*start_scan, word(68));
                assert_eq!(*scan_count, word(72));
            }
            B::AlphaBlend { blend, .. } => assert_eq!(
                [
                    blend.operation,
                    blend.flags,
                    blend.source_constant_alpha,
                    blend.alpha_format
                ],
                word(40).to_le_bytes()
            ),
            B::TransparentBlt {
                transparent_color: c,
                ..
            } => assert_eq!([c.red, c.green, c.blue, c.reserved], word(40).to_le_bytes()),
            _ => {}
        }
        if let B::StretchBlt { source_extent, .. }
        | B::AlphaBlend { source_extent, .. }
        | B::TransparentBlt { source_extent, .. } = &r
        {
            assert_eq!(*source_extent, point(100));
        }
        if let B::MaskBlt { mask, .. } = &r {
            assert_eq!(mask.position, point(100));
            assert_eq!(mask.usage, word(108));
        }
        doc.edit_record(0, RecordData::Bitmap(r)).unwrap();
        assert_eq!(&serialize(&doc).unwrap()[88..], &bytes[88..], "{kind}");
    }
}

#[test]
fn buffers_can_be_added_removed_reordered_and_family_edits_are_atomic() {
    use emf_core::{BitmapBuffer, BitmapBufferKind as K, EditFailure};
    for kind in KINDS {
        let mut doc = parse(&fixture(kind), &ParseLimits::default()).unwrap();
        for edited in [false, true] {
            if edited {
                let RecordData::Bitmap(mut r) = doc.records()[0].data().clone() else {
                    panic!()
                };
                let buffers = r.buffers_mut();
                buffers.source_info = None;
                buffers.source_bits = Some(BitmapBuffer {
                    data: vec![8, 9, 10],
                    padding: vec![0xfe],
                });
                buffers.order = [K::MaskBits, K::SourceInfo, K::MaskInfo, K::SourceBits];
                if matches!(kind, 78 | 79) {
                    buffers.mask_info = None;
                    buffers.mask_bits = Some(BitmapBuffer {
                        data: vec![1, 2],
                        padding: vec![0xfd, 0xfc],
                    });
                }
                doc.edit_record(0, RecordData::Bitmap(r)).unwrap();
                let output = serialize(&doc).unwrap();
                let reparsed = parse(&output, &ParseLimits::default()).unwrap();
                let RecordData::Bitmap(r) = reparsed.records()[0].data() else {
                    panic!()
                };
                assert!(r.buffers().source_info.is_none());
                assert_eq!(r.buffers().source_bits.as_ref().unwrap().data, [8, 9, 10]);
                if matches!(kind, 78 | 79) {
                    assert_eq!(r.buffers().mask_bits.as_ref().unwrap().data, [1, 2]);
                }
                assert!(output.windows(8).any(|w| w == b"suffix!!"));
                assert_eq!(reparsed.trailing_bytes(), b"tail");
            }
            let before = doc.clone();
            for other in KINDS.into_iter().filter(|other| *other != kind) {
                let replacement = parse(&fixture(other), &ParseLimits::default())
                    .unwrap()
                    .records()[0]
                    .data()
                    .clone();
                assert_eq!(
                    doc.edit_record(0, replacement),
                    Err(EditFailure::RecordFamily { index: 0 })
                );
                assert_eq!(doc, before);
            }
        }
    }
}
