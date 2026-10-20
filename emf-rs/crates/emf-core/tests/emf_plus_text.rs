use emf_core::{
    emf_plus::{self as plus, RecordData, Text},
    ParseLimits,
};
fn words(v: &[u32]) -> Vec<u8> {
    v.iter().flat_map(|n| n.to_le_bytes()).collect()
}
fn record(kind: u16, data: &[u8]) -> Vec<u8> {
    let size = (12 + data.len() + 3) & !3;
    let mut b = Vec::new();
    b.extend(kind.to_le_bytes());
    b.extend(0xff01u16.to_le_bytes());
    b.extend((size as u32).to_le_bytes());
    b.extend((data.len() as u32).to_le_bytes());
    b.extend(data);
    b.resize(size, 0xa7);
    b
}
fn parse(b: &[u8]) -> plus::Stream {
    plus::parse(b, &ParseLimits::default()).unwrap()
}
#[test]
fn string_preserves_utf16_nan_bits_and_both_padding_layers() {
    let mut data = words(&[0xffaabbcc, u32::MAX, 3, 0x7fc00123, 0x80000000, 3, 4]);
    data.extend([0x41, 0, 0, 0xd8, 0xff, 0xdc]);
    data.extend([0xba, 0xad]);
    let bytes = record(0x401c, &data);
    let mut s = parse(&bytes);
    assert_eq!(plus::serialize(&s).unwrap(), bytes);
    let RecordData::Text(Text::String {
        brush,
        format_id,
        layout,
        utf16,
        data_padding,
    }) = &mut s.records[0].data
    else {
        panic!("string opaque")
    };
    assert_eq!(*brush, 0xffaabbcc);
    assert_eq!(*format_id, u32::MAX);
    assert_eq!(layout[0], 0x7fc00123);
    assert_eq!(utf16, &[0x41, 0xd800, 0xdcff]);
    assert_eq!(data_padding, &[0xba, 0xad]);
    utf16[1] = 0xdfff;
    assert_eq!(parse(&plus::serialize(&s).unwrap()), s);
    // Count edits derive DataSize/Size; original segment policy rejects length changes.
    let RecordData::Text(Text::String { utf16, .. }) = &mut s.records[0].data else {
        unreachable!()
    };
    utf16.extend([1, 2]);
    assert!(plus::serialize_segments(&s, &Default::default()).is_err());
    assert_eq!(parse(&plus::serialize(&s).unwrap()).records, s.records);
}
#[test]
fn driver_strings_handle_realized_advance_optional_matrix_and_empty_runs() {
    for realized in [false, true] {
        for matrix in [false, true] {
            for count in [0, 1, 3] {
                let options = 0x80000001 | if realized { 4 } else { 0 };
                let mut data = words(&[0xffabcdef, options, u32::from(matrix), count]);
                for i in 0..count {
                    data.extend((0xd800 + i as u16).to_le_bytes());
                }
                let positions = if realized && count != 0 { 1 } else { count };
                for _ in 0..positions {
                    data.extend(words(&[0x7fc12345, 0x80000000]));
                }
                if matrix {
                    data.extend(words(&[1, 2, 3, 4, 5, 0x7fc0ffff]));
                }
                data.extend([0xae, 0xbe]);
                let bytes = record(0x4036, &data);
                let mut s = parse(&bytes);
                assert_eq!(plus::serialize(&s).unwrap(), bytes);
                let RecordData::Text(Text::Driver {
                    options: o,
                    glyphs,
                    positions: p,
                    matrix: m,
                    ..
                }) = &mut s.records[0].data
                else {
                    panic!("driver opaque")
                };
                assert_eq!(*o, options);
                assert_eq!(glyphs.len(), count as usize);
                assert_eq!(p.len(), positions as usize);
                assert_eq!(m.is_some(), matrix);
                *o ^= 2;
                assert_eq!(parse(&plus::serialize(&s).unwrap()), s);
                if count == 3 && !realized {
                    let RecordData::Text(Text::Driver { options, .. }) = &mut s.records[0].data
                    else {
                        unreachable!()
                    };
                    *options |= 4;
                    assert!(plus::serialize(&s).is_err());
                }
            }
        }
    }
}
#[test]
fn text_counts_matrix_flags_and_resource_failures_are_bounded() {
    for count in [1, u32::MAX] {
        assert!(plus::parse(
            &record(0x401c, &words(&[0, 0, count, 0, 0, 0, 0])),
            &ParseLimits::default()
        )
        .is_err());
    }
    for present in [0, 1, 2, u32::MAX] {
        assert!(plus::parse(
            &record(0x4036, &words(&[0, 0, present, u32::MAX])),
            &ParseLimits::default()
        )
        .is_err());
    }
    let mut data = words(&[0, 0, 3, 0, 0, 0, 0]);
    data.extend([1, 0, 2, 0, 3, 0]);
    let bytes = record(0x401c, &data);
    let generous = ParseLimits::default();
    let mut limits = generous.clone();
    limits.max_allocated_bytes = bytes.len();
    assert!(plus::parse(&bytes, &limits).is_err());
    let mut limits = generous;
    limits.max_work_units = 0;
    assert!(plus::parse(&bytes, &limits).is_err());
    let mut data = words(&[0, 0, 0, 0, 0, 0, 0]);
    data.extend([0; 4]);
    assert!(plus::parse(&record(0x401c, &data), &ParseLimits::default()).is_err());
}
