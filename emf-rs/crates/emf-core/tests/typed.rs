use emf_core::{
    parse, serialize, DiagnosticKind, EofRecord, LimitKind, ParseFailure, ParseLimits, Point,
    RecordData,
};

fn record(kind: u32, payload: &[u8]) -> Vec<u8> {
    let mut bytes = kind.to_le_bytes().to_vec();
    bytes.extend_from_slice(&(8 + payload.len() as u32).to_le_bytes());
    bytes.extend_from_slice(payload);
    bytes
}
fn fixture() -> Vec<u8> {
    let mut h = vec![0; 112];
    h[..4].copy_from_slice(&1u32.to_le_bytes());
    h[4..8].copy_from_slice(&112u32.to_le_bytes());
    h[40..44].copy_from_slice(&0x464d4520u32.to_le_bytes());
    h[108..].copy_from_slice(b"head");
    h.extend(record(17, &[1, 0, 0, 0, 0xab, 0xcd, 0xef, 0x99]));
    let mut poly = vec![0; 16];
    poly.extend_from_slice(&1u32.to_le_bytes());
    poly.extend_from_slice(&(-2i32).to_le_bytes());
    poly.extend_from_slice(&3i32.to_le_bytes());
    poly.extend_from_slice(b"poly");
    h.extend(record(4, &poly));
    h.extend(record(
        70,
        &[7, 0, 0, 0, b'E', b'M', b'F', b'+', 1, 2, 3, 0xcc],
    ));
    h.extend(record(999, b"unknown!"));
    h.extend(record(14, &[0, 0, 0, 0, 16, 0, 0, 0, 20, 0, 0, 0]));
    h.extend_from_slice(b"tail");
    h
}
#[test]
fn typed_round_trip_and_checked_edits_preserve_opaque_bytes() {
    let input = fixture();
    let mut doc = parse(&input, &ParseLimits::default()).unwrap();
    assert!(!doc.is_edited());
    assert_eq!(serialize(&doc).unwrap(), input);
    assert_eq!(
        doc.emf_plus_chunks().collect::<Vec<_>>(),
        vec![&[1, 2, 3][..]]
    );
    assert_eq!(
        doc.records()[0].data(),
        &RecordData::SetMapMode { map_mode: 1 }
    );
    let RecordData::Polyline { bounds, points } = doc.records()[1].data() else {
        panic!("polyline")
    };
    assert_eq!(points, &[Point { x: -2, y: 3 }]);
    let bounds = *bounds;
    doc.edit_record(
        1,
        RecordData::Polyline {
            bounds,
            points: vec![Point { x: 9, y: -8 }, Point { x: 7, y: 6 }],
        },
    )
    .unwrap();
    doc.edit_record(0, RecordData::SetMapMode { map_mode: 8 })
        .unwrap();
    doc.edit_record(
        2,
        RecordData::Comment {
            data: b"EMF+changed".to_vec(),
        },
    )
    .unwrap();
    let mut header = doc.header().clone();
    header.bounds.left = -123;
    doc.edit_header(header).unwrap();
    assert!(doc.is_edited() && doc.records()[1].is_edited());
    assert!(doc
        .edit_record(3, RecordData::SetMapMode { map_mode: 2 })
        .is_err());
    let out = serialize(&doc).unwrap();
    let reparsed = parse(&out, &ParseLimits::default()).unwrap();
    assert_eq!(reparsed.header().bounds.left, -123);
    assert_eq!(reparsed.header().n_bytes as usize, out.len());
    assert_eq!(reparsed.header().n_records, 6);
    assert_eq!(&out[108..112], b"head");
    assert_eq!(&out[124..128], &[0xab, 0xcd, 0xef, 0x99]);
    assert_eq!(
        reparsed.emf_plus_chunks().collect::<Vec<_>>(),
        vec![&b"changed"[..]]
    );
    assert_eq!(
        reparsed.record_bytes(&reparsed.records()[3]).unwrap(),
        doc.record_bytes(&doc.records()[3]).unwrap()
    );
    assert_eq!(reparsed.trailing_bytes(), b"tail");
    assert!(out.windows(4).any(|b| b == b"poly"));
    assert_eq!(serialize(&reparsed).unwrap(), out);
    doc.edit_record(
        1,
        RecordData::Polyline {
            bounds,
            points: vec![],
        },
    )
    .unwrap();
    doc.edit_record(2, RecordData::Comment { data: vec![] })
        .unwrap();
    let shrunk = serialize(&doc).unwrap();
    let reparsed = parse(&shrunk, &ParseLimits::default()).unwrap();
    assert!(reparsed.emf_plus_chunks().next().is_none());
    assert!(shrunk.windows(4).any(|b| b == b"poly"));
    assert_eq!(
        &reparsed.record_bytes(&reparsed.records()[2]).unwrap()[12..],
        &[]
    );
    assert_eq!(reparsed.trailing_bytes(), b"tail");
}
#[test]
fn malformed_counts_recover_raw_without_swallowing_following_records() {
    for (kind, payload) in [
        (4, [vec![0; 16], u32::MAX.to_le_bytes().to_vec()].concat()),
        (70, u32::MAX.to_le_bytes().to_vec()),
        (17, vec![]),
        (14, vec![]),
    ] {
        let mut input = fixture()[..112].to_vec();
        input.extend(record(kind, &payload));
        if kind != 14 {
            input.extend(record(17, &1u32.to_le_bytes()));
        }
        let doc = parse(&input, &ParseLimits::default()).unwrap();
        assert_eq!(doc.records()[0].data(), &RecordData::Raw);
        assert_eq!(
            doc.diagnostics()[0].kind,
            DiagnosticKind::InvalidRecordPayload
        );
        assert_eq!(serialize(&doc).unwrap(), input);
        if kind != 14 {
            assert_eq!(doc.records().len(), 2);
        }
    }
}
#[test]
fn typed_allocation_and_work_are_bounded() {
    let input = fixture();
    // Source and first two record capacity requests fit; the point allocation does not.
    let mut limits = ParseLimits {
        max_allocated_bytes: input.len() + 3 * std::mem::size_of::<emf_core::RecordSpan>(),
        ..ParseLimits::default()
    };
    assert!(matches!(
        parse(&input, &limits),
        Err(ParseFailure::LimitExceeded {
            kind: LimitKind::AllocatedBytes,
            ..
        })
    ));
    limits = ParseLimits::default();
    // Typed decode adds one point unit
    // and one comment-copy unit. Exact boundary catches uncharged decoding.
    let baseline_work = 1
        + 112u64.div_ceil(16)
        + [16u64, 40, 20, 16, 20]
            .iter()
            .map(|size| 1 + size.div_ceil(16))
            .sum::<u64>()
        + (input.len() as u64).div_ceil(16);
    limits.max_work_units = baseline_work + 1;
    assert!(matches!(
        parse(&input, &limits),
        Err(ParseFailure::LimitExceeded {
            kind: LimitKind::WorkUnits,
            ..
        })
    ));
    limits.max_work_units += 1;
    assert!(parse(&input, &limits).is_ok());
}
#[test]
fn invalid_header_edit_is_atomic() {
    let input = fixture();
    let mut doc = parse(&input, &ParseLimits::default()).unwrap();
    let mut h = doc.header().clone();
    h.n_size += 4;
    assert!(doc.edit_header(h).is_err());
    assert!(!doc.is_edited());
    assert_eq!(serialize(&doc).unwrap(), input);
}

#[test]
fn eof_edits_preserve_palette_and_validate_final_size() {
    let mut input = fixture()[..112].to_vec();
    input.extend(record(
        14,
        &[1, 0, 0, 0, 16, 0, 0, 0, 0x11, 0x22, 0x33, 0x44, 24, 0, 0, 0],
    ));
    let mut doc = parse(&input, &ParseLimits::default()).unwrap();
    assert_eq!(serialize(&doc).unwrap(), input);
    let original = doc.record_bytes(&doc.records()[0]).unwrap().to_vec();
    let mut eof = EofRecord {
        n_pal_entries: 1,
        off_pal_entries: 16,
        n_size_last: 24,
    };
    assert_eq!(doc.records()[0].data(), &RecordData::Eof(eof));
    eof.n_size_last = 99;
    assert!(doc.edit_record(0, RecordData::Eof(eof)).is_err());
    assert!(!doc.is_edited());
    eof.n_size_last = 24;
    eof.n_pal_entries = 0;
    doc.edit_record(0, RecordData::Eof(eof)).unwrap();
    assert_eq!(doc.record_bytes(&doc.records()[0]).unwrap(), original);
    let out = serialize(&doc).unwrap();
    assert_eq!(&out[128..132], &[0x11, 0x22, 0x33, 0x44]);
    assert_eq!(&out[132..], &24u32.to_le_bytes());
    let parsed = parse(&out, &ParseLimits::default()).unwrap();
    assert_eq!(parsed.records()[0].data(), &RecordData::Eof(eof));
}

#[test]
fn comment_growth_and_shrink_rebuild_only_alignment_padding() {
    for original_len in 1usize..=8 {
        let mut input = fixture()[..112].to_vec();
        let mut payload = (original_len as u32).to_le_bytes().to_vec();
        payload.extend(vec![b'x'; original_len]);
        let old_padding = (4 - original_len % 4) % 4;
        payload.extend(vec![0xcc; old_padding]);
        input.extend(record(70, &payload));
        input.extend(record(999, b"unknown!"));
        input.extend(record(14, &[0, 0, 0, 0, 16, 0, 0, 0, 20, 0, 0, 0]));
        input.extend_from_slice(b"tail");
        for new_len in 0usize..=12 {
            let mut doc = parse(&input, &ParseLimits::default()).unwrap();
            assert_eq!(serialize(&doc).unwrap(), input);
            let data = vec![b'y'; new_len];
            doc.edit_record(0, RecordData::Comment { data: data.clone() })
                .unwrap();
            let out = serialize(&doc).unwrap();
            let parsed = parse(&out, &ParseLimits::default()).unwrap();
            let comment = &parsed.records()[0];
            let padding = (4 - new_len % 4) % 4;
            assert_eq!(comment.size() as usize, 12 + new_len + padding);
            assert_eq!(comment.size() % 4, 0);
            assert_eq!(comment.data(), &RecordData::Comment { data });
            let bytes = parsed.record_bytes(comment).unwrap();
            assert_eq!(&bytes[8..12], &(new_len as u32).to_le_bytes());
            let preserved = old_padding.min(padding);
            assert_eq!(
                &bytes[12 + new_len..12 + new_len + preserved],
                vec![0xcc; preserved]
            );
            assert_eq!(
                &bytes[12 + new_len + preserved..],
                vec![0; padding - preserved]
            );
            for index in 1..=2 {
                assert_eq!(
                    parsed.record_bytes(&parsed.records()[index]),
                    doc.record_bytes(&doc.records()[index])
                );
            }
            assert_eq!(parsed.trailing_bytes(), b"tail");
            assert_eq!(parsed.header().n_bytes as usize, out.len());
            assert_eq!(serialize(&parsed).unwrap(), out);
        }
    }
}

#[test]
fn noncanonical_comment_suffix_rejects_edit_atomically_and_preserves_source() {
    for payload in [vec![1, 0, 0, 0, b'x'], vec![0; 8]] {
        let mut input = fixture()[..112].to_vec();
        input.extend(record(70, &payload));
        let mut doc = parse(&input, &ParseLimits::default()).unwrap();
        assert!(doc
            .edit_record(0, RecordData::Comment { data: vec![] })
            .is_err());
        assert!(!doc.is_edited());
        assert_eq!(serialize(&doc).unwrap(), input);
    }
}

#[test]
fn emf_plus_extraction_filters_identifiers_and_keeps_chunk_order() {
    let mut input = fixture()[..112].to_vec();
    for data in [
        &b"ordinary"[..],
        &b"EMF+first"[..],
        &b"EMF"[..],
        &b"EMF+second"[..],
    ] {
        let mut payload = (data.len() as u32).to_le_bytes().to_vec();
        payload.extend_from_slice(data);
        input.extend(record(70, &payload));
    }
    let doc = parse(&input, &ParseLimits::default()).unwrap();
    assert_eq!(
        doc.emf_plus_chunks().collect::<Vec<_>>(),
        vec![&b"first"[..], &b"second"[..]]
    );
    assert_eq!(serialize(&doc).unwrap(), input);
}

#[test]
fn scalar_state_records_decode_as_supported_and_round_trip_unsigned_values() {
    for kind in 18..=21 {
        for value in [0u32, 0x8000_0000, u32::MAX] {
            let mut input = fixture()[..112].to_vec();
            input.extend(record(kind, &value.to_le_bytes()));
            let doc = parse(&input, &ParseLimits::default()).unwrap();
            assert_eq!(doc.records()[0].data(), &scalar_state(kind, value));
            assert!(!doc.is_edited());
            assert!(doc.diagnostics().is_empty());
            assert_eq!(serialize(&doc).unwrap(), input);
        }
    }
}

#[test]
fn short_scalar_state_records_diagnose_and_continue_through_eof() {
    for kind in 18..=21 {
        for len in 0..4 {
            let mut input = fixture()[..112].to_vec();
            input.extend(record(kind, &vec![0xaa; len]));
            input.extend(record(999, b"unknown!"));
            input.extend(record(17, &1u32.to_le_bytes()));
            input.extend(record(14, &[0, 0, 0, 0, 16, 0, 0, 0, 20, 0, 0, 0]));
            input.extend_from_slice(b"tail");
            let doc = parse(&input, &ParseLimits::default()).unwrap();
            assert_eq!(doc.records().len(), 4);
            assert_eq!(doc.records()[0].data(), &RecordData::Raw);
            assert_eq!(doc.records()[1].data(), &RecordData::Raw);
            assert_eq!(
                doc.records()[2].data(),
                &RecordData::SetMapMode { map_mode: 1 }
            );
            assert!(doc.records()[3].is_eof());
            assert_eq!(doc.diagnostics().len(), 1, "type {kind}, length {len}");
            assert_eq!(doc.diagnostics()[0].offset, 112);
            assert_eq!(doc.diagnostics()[0].record_type, Some(kind));
            assert_eq!(
                doc.diagnostics()[0].kind,
                DiagnosticKind::InvalidRecordPayload
            );
            assert_eq!(doc.trailing_bytes(), b"tail");
            assert_eq!(serialize(&doc).unwrap(), input);
        }
    }
}

fn scalar_state(kind: u32, value: u32) -> RecordData {
    match kind {
        18 => RecordData::SetBkMode { bk_mode: value },
        19 => RecordData::SetPolyFillMode {
            poly_fill_mode: value,
        },
        20 => RecordData::SetRop2 { rop2: value },
        21 => RecordData::SetStretchBltMode {
            stretch_mode: value,
        },
        _ => panic!("unexpected scalar state type {kind}"),
    }
}

#[test]
fn scalar_state_edits_preserve_suffix_siblings_header_and_tail() {
    for kind in 18..=21 {
        for value in [0u32, 0x8000_0000, u32::MAX] {
            let mut input = fixture()[..112].to_vec();
            let mut payload = 7u32.to_le_bytes().to_vec();
            payload.extend_from_slice(b"suffix!!");
            input.extend(record(kind, &payload));
            input.extend(record(17, &9u32.to_le_bytes()));
            input.extend(record(999, b"unknown!"));
            input.extend(record(14, &[0, 0, 0, 0, 16, 0, 0, 0, 20, 0, 0, 0]));
            input.extend_from_slice(b"tail");
            let mut doc = parse(&input, &ParseLimits::default()).unwrap();
            assert_eq!(serialize(&doc).unwrap(), input);
            doc.edit_record(0, scalar_state(kind, value)).unwrap();
            assert_eq!(doc.records()[0].data(), &scalar_state(kind, value));
            assert!(doc.records()[0].is_edited());
            let out = serialize(&doc).unwrap();
            let mut expected = input.clone();
            expected[48..52].copy_from_slice(&(input.len() as u32).to_le_bytes());
            expected[52..56].copy_from_slice(&5u32.to_le_bytes());
            expected[120..124].copy_from_slice(&value.to_le_bytes());
            assert_eq!(out, expected, "type {kind}, value {value}");
            assert_eq!(&out[124..132], b"suffix!!");
            assert_eq!(&out[132..], &input[132..]);
            let reparsed = parse(&out, &ParseLimits::default()).unwrap();
            assert_eq!(reparsed.records()[0].data(), &scalar_state(kind, value));
            assert!(reparsed.diagnostics().is_empty());
            assert_eq!(reparsed.trailing_bytes(), b"tail");
            assert_eq!(serialize(&reparsed).unwrap(), out);
        }
    }
}

#[test]
fn scalar_state_wrong_family_edits_reject_atomically() {
    for kind in 18..=21 {
        let mut input = fixture()[..112].to_vec();
        input.extend(record(kind, &7u32.to_le_bytes()));
        let mut doc = parse(&input, &ParseLimits::default()).unwrap();
        for wrong_kind in 18..=21 {
            if wrong_kind == kind {
                continue;
            }
            let before = doc.clone();
            assert_eq!(
                doc.edit_record(0, scalar_state(wrong_kind, u32::MAX)),
                Err(emf_core::EditFailure::RecordFamily { index: 0 })
            );
            assert_eq!(doc, before);
            assert_eq!(serialize(&doc).unwrap(), input);
        }
    }
}
