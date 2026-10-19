use emf_core::{
    parse, serialize, serialize_with_limits, ColorRef, DiagnosticKind, Document, EditFailure,
    ExtCreatePen, LimitKind, ParseFailure, ParseLimits, RecordData, SerializeFailure,
    SerializeLimits,
};

fn words(values: &[u32]) -> Vec<u8> {
    values.iter().flat_map(|v| v.to_le_bytes()).collect()
}
fn put(bytes: &mut [u8], offset: usize, value: u32) {
    bytes[offset..offset + 4].copy_from_slice(&value.to_le_bytes());
}
fn word(bytes: &[u8], offset: usize) -> u32 {
    u32::from_le_bytes(bytes[offset..offset + 4].try_into().unwrap())
}
fn document(record: &[u8]) -> Vec<u8> {
    let mut bytes = vec![0; 88];
    put(&mut bytes, 0, 1);
    put(&mut bytes, 4, 88);
    put(&mut bytes, 40, 0x464d4520);
    bytes.extend_from_slice(record);
    bytes.extend_from_slice(&words(&[999, 12, 0xfedcba98]));
    bytes.extend_from_slice(&words(&[14, 20, 0, 16, 20]));
    bytes.extend_from_slice(b"tail");
    bytes
}
fn fixture() -> Vec<u8> {
    let mut bytes = words(&[
        95,
        0,
        0x87654321,
        0,
        0,
        0,
        0,
        0xffff3207,
        u32::MAX,
        0xdeadbeef,
        0xfedcba98,
        0x80000000,
        3,
        0,
        u32::MAX,
        0x80000000,
    ]);
    bytes.extend_from_slice(b"SUFFIX!!");
    let len = bytes.len() as u32;
    put(&mut bytes, 4, len);
    bytes
}
#[test]
fn extended_pen_decodes_instead_of_remaining_raw() {
    let bytes = document(&fixture());
    let doc = parse(&bytes, &ParseLimits::default()).unwrap();
    assert_ne!(doc.records()[0].data(), &RecordData::Raw);
    assert_eq!(serialize(&doc).unwrap(), bytes);
}

fn pen(doc: &Document) -> &ExtCreatePen {
    let RecordData::ExtCreatePen(pen) = doc.records()[0].data() else {
        panic!("expected extended pen, got {:?}", doc.records()[0].data());
    };
    pen
}
fn with_buffers(info: Option<&[u8]>, bits: Option<&[u8]>, bits_first: bool) -> Vec<u8> {
    let mut bytes = fixture();
    bytes.truncate(64);
    for is_bits in [bits_first, !bits_first] {
        if let Some(data) = if is_bits { bits } else { info } {
            while bytes.len() % 4 != 0 {
                bytes.push(0xa5);
            }
            bytes.extend_from_slice(if is_bits { b"BITS" } else { b"INFO" });
            let field = if is_bits { 20 } else { 12 };
            let offset = bytes.len() as u32;
            put(&mut bytes, field, offset);
            put(&mut bytes, field + 4, data.len() as u32);
            bytes.extend_from_slice(data);
        }
    }
    bytes.extend_from_slice(b"SUFFIX!!");
    while bytes.len() % 4 != 0 {
        bytes.push(0x5a);
    }
    let len = bytes.len() as u32;
    put(&mut bytes, 4, len);
    bytes
}
#[test]
fn semantic_fields_and_scalar_edits_preserve_unknown_bits_and_unrelated_bytes() {
    for record in [
        fixture(),
        with_buffers(Some(b"header!!"), Some(b"pixels!!"), true),
    ] {
        let original = document(&record);
        let mut doc = parse(&original, &ParseLimits::default()).unwrap();
        let mut edited = pen(&doc).clone();
        assert_eq!(edited.ih_pen, 0x87654321);
        assert_eq!(edited.pen_style, 0xffff3207);
        assert_eq!(edited.width, u32::MAX);
        assert_eq!(edited.brush_style, 0xdeadbeef);
        assert_eq!(
            edited.color,
            ColorRef {
                red: 0x98,
                green: 0xba,
                blue: 0xdc,
                reserved: 0xfe
            }
        );
        assert_eq!(edited.brush_hatch, 0x80000000);
        assert_eq!(edited.style_entries, [0, u32::MAX, 0x80000000]);
        doc.edit_record(0, RecordData::ExtCreatePen(edited.clone()))
            .unwrap();
        let encoded = serialize(&doc).unwrap();
        assert_eq!(&encoded[88..], &original[88..]);
        edited.width = 17;
        doc.edit_record(0, RecordData::ExtCreatePen(edited))
            .unwrap();
        let encoded = serialize(&doc).unwrap();
        let mut expected = record.clone();
        put(&mut expected, 32, 17);
        assert_eq!(&encoded[88..88 + record.len()], &expected);
        assert_eq!(
            &encoded[88 + record.len()..],
            &original[88 + record.len()..]
        );
        assert_eq!(word(&encoded, 48) as usize, encoded.len());
        assert_eq!(word(&encoded, 52), 4);
    }
}
#[test]
fn optional_buffers_preserve_order_gaps_empty_presence_and_suffix() {
    for (info, bits) in [
        (None, None),
        (Some(&b""[..]), None),
        (None, Some(&b""[..])),
        (Some(&b"header!!"[..]), None),
        (None, Some(&b"pixel"[..])),
        (Some(&b""[..]), Some(&b""[..])),
        (Some(&b"header!"[..]), Some(&b"pixels!"[..])),
    ] {
        for bits_first in [false, true] {
            let record = with_buffers(info, bits, bits_first);
            let original = document(&record);
            let mut doc = parse(&original, &ParseLimits::default()).unwrap();
            assert!(doc.diagnostics().is_empty());
            assert_eq!(pen(&doc).bitmap_info.as_deref(), info);
            assert_eq!(pen(&doc).bitmap_bits.as_deref(), bits);
            if info.is_some() && bits.is_some() {
                assert_eq!(pen(&doc).bits_first, bits_first);
            }
            assert_eq!(serialize(&doc).unwrap(), original);
            doc.edit_record(0, doc.records()[0].data().clone()).unwrap();
            assert_eq!(&serialize(&doc).unwrap()[88..], &original[88..]);
        }
    }
}
#[test]
fn array_and_bitmap_edits_rebuild_counts_offsets_and_alignment() {
    for bits_first in [false, true] {
        let original = document(&with_buffers(
            Some(b"header!!"),
            Some(b"pixels!!"),
            bits_first,
        ));
        let mut doc = parse(&original, &ParseLimits::default()).unwrap();
        let mut edited = pen(&doc).clone();
        edited.style_entries.extend([7, 19]);
        edited.bitmap_info = Some(b"replacement header!".to_vec());
        edited.bitmap_bits = Some(b"replacement pixels!".to_vec());
        doc.edit_record(0, RecordData::ExtCreatePen(edited.clone()))
            .unwrap();
        let encoded = serialize(&doc).unwrap();
        let reparsed = parse(&encoded, &ParseLimits::default()).unwrap();
        let actual = pen(&reparsed);
        assert_eq!(actual.style_entries, edited.style_entries);
        assert_eq!(actual.bitmap_info, edited.bitmap_info);
        assert_eq!(actual.bitmap_bits, edited.bitmap_bits);
        assert_eq!(actual.bits_first, bits_first);
        assert!(actual.info_padding.starts_with(&edited.info_padding));
        assert!(actual.bits_padding.starts_with(&edited.bits_padding));
        let record = reparsed.record_bytes(&reparsed.records()[0]).unwrap();
        assert_eq!(word(record, 48), 5);
        assert_eq!(word(record, 12) % 4, 0);
        assert_eq!(word(record, 20) % 4, 0);
        assert_eq!(word(record, 16), 19);
        assert_eq!(word(record, 24), 19);
        assert_eq!(record.len() % 4, 0);
        assert_eq!(suffix(&reparsed), b"SUFFIX!!\0");
        let sibling = &reparsed.records()[1];
        assert_eq!(
            reparsed.record_bytes(sibling).unwrap(),
            &words(&[999, 12, 0xfedcba98])
        );
        assert_eq!(reparsed.trailing_bytes(), b"tail");
        assert_eq!(serialize(&reparsed).unwrap(), encoded);
    }
}
#[test]
fn malformed_structure_stays_raw_and_framing_continues() {
    let valid = with_buffers(Some(b"header!!"), Some(b"pixels!!"), false);
    let mut cases = Vec::new();
    for len in [8, 28, 48, 51, 52, 60, 63] {
        let mut record = valid[..len].to_vec();
        put(&mut record, 4, len as u32);
        cases.push(record);
    }
    for (offset, value) in [
        (48, u32::MAX), // style count overflow or outside payload
        (12, 0),        // nonempty buffer without an offset
        (12, 48),       // inside LogPenEx
        (12, 60),       // inside style entries
        (12, 65),       // unaligned buffer
        (12, u32::MAX),
        (16, u32::MAX),
        (20, 68), // overlaps the first buffer
        (20, 71),
        (24, u32::MAX),
    ] {
        let mut record = valid.clone();
        put(&mut record, offset, value);
        cases.push(record);
    }
    for record in cases {
        let original = document(&record);
        let doc = parse(&original, &ParseLimits::default()).unwrap();
        assert_eq!(doc.records()[0].data(), &RecordData::Raw, "{record:?}");
        assert_eq!(doc.diagnostics().len(), 1);
        assert_eq!(doc.diagnostics()[0].record_type, Some(95));
        assert_eq!(
            doc.diagnostics()[0].kind,
            DiagnosticKind::InvalidRecordPayload
        );
        assert_eq!(doc.records()[1].record_type(), 999);
        assert!(doc.has_eof());
        assert_eq!(serialize(&doc).unwrap(), original);
    }
}
#[test]
fn style_count_zero_and_non_user_styles_remain_editable() {
    let mut record = fixture();
    record.drain(52..64);
    put(&mut record, 48, 0);
    put(&mut record, 28, 0); // PS_SOLID, with no style entries
    let len = record.len() as u32;
    put(&mut record, 4, len);
    let mut doc = parse(&document(&record), &ParseLimits::default()).unwrap();
    assert!(pen(&doc).style_entries.is_empty());
    let mut edited = pen(&doc).clone();
    edited.style_entries = vec![0, u32::MAX]; // raw entries retained even without PS_USERSTYLE
    doc.edit_record(0, RecordData::ExtCreatePen(edited.clone()))
        .unwrap();
    let encoded = serialize(&doc).unwrap();
    let reparsed = parse(&encoded, &ParseLimits::default()).unwrap();
    assert_eq!(pen(&reparsed), &edited);
    assert_eq!(suffix(&reparsed), b"SUFFIX!!");
}
#[test]
fn inconsistent_absent_buffer_edits_are_rejected_without_mutation() {
    let mut doc = parse(&document(&fixture()), &ParseLimits::default()).unwrap();
    let original = doc.clone();
    for is_bits in [false, true] {
        let mut edited = pen(&doc).clone();
        if is_bits {
            edited.bits_padding.push(1);
        } else {
            edited.info_padding.push(1);
        }
        assert_eq!(
            doc.edit_record(0, RecordData::ExtCreatePen(edited)),
            Err(EditFailure::RecordLayout { index: 0 })
        );
        assert_eq!(doc, original);
    }
}

fn suffix(doc: &Document) -> &[u8] {
    let record = doc.record_bytes(&doc.records()[0]).unwrap();
    let end = (52 + word(record, 48) as usize * 4)
        .max(word(record, 12) as usize + word(record, 16) as usize)
        .max(word(record, 20) as usize + word(record, 24) as usize);
    &record[end..]
}

#[test]
fn parse_and_serialize_limits_are_inclusive() {
    let original = document(&with_buffers(Some(&[5; 73]), Some(&[9; 127]), true));
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
    doc.edit_record(0, doc.records()[0].data().clone()).unwrap();
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

#[test]
fn bitmap_buffers_can_be_added_and_removed_with_checked_offsets() {
    let mut doc = parse(&document(&fixture()), &ParseLimits::default()).unwrap();
    let mut edited = pen(&doc).clone();
    edited.bitmap_info = Some(vec![1, 2, 3]);
    edited.bitmap_bits = Some(vec![4, 5]);
    edited.bits_first = true;
    doc.edit_record(0, RecordData::ExtCreatePen(edited))
        .unwrap();
    let encoded = serialize(&doc).unwrap();
    let mut reparsed = parse(&encoded, &ParseLimits::default()).unwrap();
    assert_eq!(pen(&reparsed).bitmap_info.as_deref(), Some(&[1, 2, 3][..]));
    assert_eq!(pen(&reparsed).bitmap_bits.as_deref(), Some(&[4, 5][..]));
    assert!(suffix(&reparsed).starts_with(b"SUFFIX!!"));
    let mut removed = pen(&reparsed).clone();
    removed.bitmap_info = None;
    removed.bitmap_bits = None;
    removed.info_padding.clear();
    removed.bits_padding.clear();
    removed.bits_first = false;
    reparsed
        .edit_record(0, RecordData::ExtCreatePen(removed))
        .unwrap();
    let encoded = serialize(&reparsed).unwrap();
    let reparsed = parse(&encoded, &ParseLimits::default()).unwrap();
    let record = reparsed.record_bytes(&reparsed.records()[0]).unwrap();
    assert_eq!(&record[12..28], &[0; 16]);
    assert!(pen(&reparsed).bitmap_info.is_none());
    assert!(pen(&reparsed).bitmap_bits.is_none());
    assert!(suffix(&reparsed).starts_with(b"SUFFIX!!"));
}
