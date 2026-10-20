use emf_core::{
    wmf::{
        self,
        region::{Rect, RegionRecord, Scan, ScanLine},
        TypedRecord,
    },
    EditFailure, LimitKind, ParseFailure, ParseLimits,
};

fn words(values: &[u16]) -> Vec<u8> {
    values.iter().flat_map(|v| v.to_le_bytes()).collect()
}

fn file(function: u16, body: &[u8]) -> Vec<u8> {
    assert_eq!(body.len() % 2, 0);
    let record_words = (body.len() + 6) as u32 / 2;
    let mut out = words(&[1, 9, 0x300]);
    out.extend_from_slice(&(12 + record_words).to_le_bytes());
    out.extend_from_slice(&8u16.to_le_bytes());
    out.extend_from_slice(&record_words.to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes());
    out.extend_from_slice(&record_words.to_le_bytes());
    out.extend_from_slice(&function.to_le_bytes());
    out.extend_from_slice(body);
    out.extend_from_slice(&[3, 0, 0, 0, 0, 0]);
    out
}

fn body() -> Vec<u8> {
    // Fixed22 + scan12 + scan16 =50 bytes. Ignored fields are nonzero.
    words(&[
        0xabcd, 6, 0x5678, 0x1234, 50, 2, 4, 0xfffe, 0x8000, 300, 400, 2, 0x8001, 0xfffe, 0x8002,
        0xffff, 2, 4, 30, 40, 10, 20, 50, 60, 4,
    ])
}

#[test]
fn region_signed_bounds_unsigned_scans_and_ignored_fields_survive_edit() {
    let mut payload = body();
    payload.extend_from_slice(&[0xaa, 0xbb]);
    let bytes = file(0x7fff, &payload);
    let mut doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
    let Some(TypedRecord::Region(RegionRecord::CreateRegion(region))) = doc.records()[0].typed()
    else {
        panic!("region opaque")
    };
    assert_eq!(
        (region.next_in_chain, region.object_count),
        (0xabcd, 0x12345678)
    );
    assert_eq!(
        region.bounds,
        Rect {
            left: -2,
            top: i16::MIN,
            right: 300,
            bottom: 400
        }
    );
    assert_eq!(
        region.scans[0],
        Scan {
            top: 0x8001,
            bottom: 65534,
            lines: vec![ScanLine {
                left: 32770,
                right: 65535
            }]
        }
    );
    assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
    doc.replace_typed(0, doc.records()[0].typed().unwrap().clone())
        .unwrap();
    assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
    let mut region = region_clone(&doc);
    region.bounds.left = -9;
    doc.replace_typed(0, TypedRecord::Region(RegionRecord::CreateRegion(region)))
        .unwrap();
    let edited = wmf::serialize(&doc).unwrap();
    let mut expected = bytes;
    expected[38..40].copy_from_slice(&(-9i16).to_le_bytes());
    assert_eq!(edited, expected);
}

fn region_clone(doc: &wmf::Document) -> wmf::region::Region {
    match doc.records()[0].typed().unwrap() {
        TypedRecord::Region(RegionRecord::CreateRegion(region)) => region.clone(),
        _ => panic!("region opaque"),
    }
}

#[test]
fn drawing_wire_order_and_signed_frame_extents_round_trip() {
    let cases = [
        (
            0x0228,
            words(&[0xfffe, 0x8001]),
            RegionRecord::FillRegion {
                region: 65534,
                brush: 32769,
            },
        ),
        (
            0x0429,
            words(&[0xfffe, 0x8001, 0xffff, 0x8000]),
            RegionRecord::FrameRegion {
                region: 65534,
                brush: 32769,
                height: -1,
                width: i16::MIN,
            },
        ),
        (0x012a, words(&[0xfffe]), RegionRecord::InvertRegion(65534)),
        (0x012b, words(&[0x8001]), RegionRecord::PaintRegion(32769)),
    ];
    for (function, mut payload, record) in cases {
        payload.extend_from_slice(&[0xaa, 0xbb]);
        let bytes = file(function, &payload);
        let mut doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
        assert_eq!(
            doc.records()[0].typed(),
            Some(&TypedRecord::Region(record.clone()))
        );
        doc.replace_typed(0, TypedRecord::Region(record)).unwrap();
        assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
    }
}

#[test]
fn scan_growth_recomputes_nested_counts_size_and_maximum_preserving_suffix() {
    let mut payload = body();
    payload.extend_from_slice(&[0xaa, 0xbb]);
    let mut doc = wmf::parse(&file(0x06ff, &payload), &ParseLimits::default()).unwrap();
    let mut region = region_clone(&doc);
    region.scans[0].lines.extend_from_slice(&[
        ScanLine { left: 4, right: 5 },
        ScanLine { left: 6, right: 7 },
    ]);
    region.scans.push(Scan {
        top: 80,
        bottom: 90,
        lines: vec![],
    });
    doc.replace_typed(
        0,
        TypedRecord::Region(RegionRecord::CreateRegion(region.clone())),
    )
    .unwrap();
    let encoded = wmf::serialize(&doc).unwrap();
    let reparsed = wmf::parse(&encoded, &ParseLimits::default()).unwrap();
    assert_eq!(region_clone(&reparsed), region);
    let payload = reparsed.record_body(&reparsed.records()[0]).unwrap();
    assert_eq!(&payload[8..14], &words(&[66, 3, 6]));
    assert_eq!(&payload[66..], &[0xaa, 0xbb]);
}

#[test]
fn malformed_region_counts_sizes_and_scans_remain_opaque_without_hiding_eof() {
    let mut invalid = vec![vec![], vec![0; 20]];
    for (offset, value) in [
        (2, 5u16),
        (8, 21),
        (8, 48),
        (8, 52),
        (8, 0x8000),
        (10, 0xffff),
        (10, 3),
        (12, 2),
        (12, 0x8000),
        (22, 3),
        (22, 200),
        (32, 4),
    ] {
        let mut payload = body();
        payload[offset..offset + 2].copy_from_slice(&value.to_le_bytes());
        invalid.push(payload);
    }
    for payload in invalid {
        let bytes = file(0x06ff, &payload);
        let doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
        assert_eq!(doc.records().len(), 2);
        assert!(doc.records()[0].typed().is_none());
        assert!(!doc.diagnostics().is_empty());
        assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
    }
    for (function, payload) in [
        (0x0228, vec![0; 2]),
        (0x0429, vec![0; 6]),
        (0x012a, vec![]),
        (0x012b, vec![]),
    ] {
        let doc = wmf::parse(&file(function, &payload), &ParseLimits::default()).unwrap();
        assert!(doc.records()[0].typed().is_none());
        assert_eq!(doc.records().len(), 2);
    }
}

#[test]
fn excessive_region_edit_is_rejected_atomically() {
    let mut doc = wmf::parse(&file(0x06ff, &body()), &ParseLimits::default()).unwrap();
    let original = wmf::serialize(&doc).unwrap();
    let mut region = region_clone(&doc);
    region.scans[0].lines = vec![ScanLine { left: 1, right: 2 }; 8190];
    assert_eq!(
        doc.replace_typed(0, TypedRecord::Region(RegionRecord::CreateRegion(region))),
        Err(EditFailure::SizeOverflow)
    );
    assert_eq!(wmf::serialize(&doc).unwrap(), original);
}

fn minimum(bytes: &[u8], allocated: bool) -> usize {
    let (mut low, mut high) = (0, 100_000);
    while low < high {
        let mid = (low + high) / 2;
        let mut limits = ParseLimits::default();
        if allocated {
            limits.max_allocated_bytes = mid;
        } else {
            limits.max_work_units = mid as u64;
        }
        match wmf::parse(bytes, &limits) {
            Ok(_) => high = mid,
            Err(ParseFailure::LimitExceeded { kind, .. }) => {
                assert_eq!(
                    kind,
                    if allocated {
                        LimitKind::AllocatedBytes
                    } else {
                        LimitKind::WorkUnits
                    }
                );
                low = mid + 1;
            }
            Err(other) => panic!("unexpected {other:?}"),
        }
    }
    low
}

#[test]
fn scans_charge_cumulative_work_and_allocations_on_the_shared_budget() {
    let full = file(0x06ff, &body());
    // Same function/body length and object lifecycle, with original scan bytes
    // kept as suffix: isolates decoded nested work and vector allocations.
    let mut empty = body();
    empty[8..14].copy_from_slice(&words(&[22, 0, 0]));
    let empty = file(0x06ff, &empty);
    assert_eq!(minimum(&full, false), minimum(&empty, false) + 8);
    let allocated = 2 * std::mem::size_of::<Scan>() + 3 * std::mem::size_of::<ScanLine>();
    assert_eq!(minimum(&full, true), minimum(&empty, true) + allocated);
}
