use emf_core::{
    detect_format, parse, serialize, DiagnosticKind, Format, LimitKind, ParseFailure, ParseLimits,
    EMR_EOF,
};

fn le32(out: &mut Vec<u8>, v: u32) {
    out.extend_from_slice(&v.to_le_bytes());
}

/// Header record of `n_size` bytes (88, 100 or 108 are the valid shapes).
fn header(n_size: u32) -> Vec<u8> {
    let mut h = Vec::new();
    le32(&mut h, 1);
    le32(&mut h, n_size);
    for v in [0i32, 0, 99, 49] {
        le32(&mut h, v as u32); // bounds
    }
    for v in [0i32, 0, 2500, 1250] {
        le32(&mut h, v as u32); // frame
    }
    le32(&mut h, 0x464D_4520);
    le32(&mut h, 0x0001_0000);
    le32(&mut h, 0); // nBytes
    le32(&mut h, 2); // nRecords
    h.extend_from_slice(&1u16.to_le_bytes()); // nHandles
    h.extend_from_slice(&0u16.to_le_bytes()); // reserved
    le32(&mut h, 0);
    le32(&mut h, 0);
    le32(&mut h, 0);
    for v in [1024u32, 768, 270, 203] {
        le32(&mut h, v); // device, millimeters
    }
    while h.len() < n_size as usize {
        let value = 0xAA00 + h.len() as u32;
        le32(&mut h, value);
    }
    h
}

fn record(record_type: u32, payload: &[u8]) -> Vec<u8> {
    let mut r = Vec::new();
    le32(&mut r, record_type);
    le32(&mut r, 8 + payload.len() as u32);
    r.extend_from_slice(payload);
    r
}

fn eof() -> Vec<u8> {
    record(EMR_EOF, &[0, 0, 0, 0, 0x10, 0, 0, 0, 0x14, 0, 0, 0])
}

fn cat(parts: &[&[u8]]) -> Vec<u8> {
    parts.concat()
}

fn lim() -> ParseLimits {
    ParseLimits::default()
}

fn round_trip(input: &[u8]) -> emf_core::Document {
    let doc = parse(input, &lim()).expect("parses");
    assert_eq!(serialize(&doc).expect("serializes"), input);
    doc
}

#[test]
fn header_and_eof() {
    let input = cat(&[&header(88), &eof()]);
    let doc = round_trip(&input);
    let h = doc.header();
    assert_eq!(
        (h.n_size, h.signature, h.version),
        (88, 0x464D_4520, 0x0001_0000)
    );
    assert_eq!(
        (
            h.bounds.right,
            h.frame.bottom,
            h.device.cx,
            h.millimeters.cy
        ),
        (99, 1250, 1024, 203)
    );
    assert!(h.pixel_format.is_none() && h.micrometers.is_none());
    assert_eq!(doc.records().len(), 1);
    assert!(doc.has_eof());
    assert!(doc.diagnostics().is_empty());
    assert!(doc.trailing_bytes().is_empty());
}

#[test]
fn extended_header_fields_by_size() {
    let doc = round_trip(&cat(&[&header(100), &eof()]));
    assert!(doc.header().pixel_format.is_some() && doc.header().micrometers.is_none());
    // Bytes past the decoded fields (here 108 -> micrometers) are decoded; the
    // raw header bytes are kept regardless.
    let doc = round_trip(&cat(&[&header(120), &eof()]));
    assert!(doc.header().micrometers.is_some());
    assert_eq!(doc.header_bytes().len(), 120);
}

#[test]
fn header_sizes_between_shapes_fail() {
    for n in [89u32, 96, 101, 107] {
        let input = cat(&[&header(n), &eof()]);
        assert!(
            matches!(parse(&input, &lim()), Err(ParseFailure::HeaderSizeTooSmall { declared, .. }) if declared == n),
            "n_size {n}"
        );
    }
}

#[test]
fn preserves_unknown_record_padding_and_trailing_bytes() {
    let unknown = record(0x7FFF_0001, &[0xDE, 0xAD, 0xBE, 0xEF, 1, 2, 3]); // odd payload, no padding
    let known_padded = record(70, &[9; 12]);
    let trailing = [0u8, 1, 2, 0xFF, 0xFE];
    let input = cat(&[&header(108), &unknown, &known_padded, &eof(), &trailing]);
    let doc = round_trip(&input);
    let types: Vec<u32> = doc.records().iter().map(|r| r.record_type()).collect();
    assert_eq!(types, [0x7FFF_0001, 70, EMR_EOF]);
    assert_eq!(doc.record_bytes(&doc.records()[0]).unwrap(), &unknown[..]);
    assert_eq!(doc.trailing_bytes(), &trailing);
    assert!(doc.unframed_bytes().is_empty());
}

#[test]
fn nothing_after_header_is_valid_without_eof() {
    let input = header(88);
    let doc = round_trip(&input);
    assert!(doc.records().is_empty() && !doc.has_eof() && doc.diagnostics().is_empty());
}

#[test]
fn stops_at_first_eof_even_if_more_records_follow() {
    let after = record(70, &[0; 4]);
    let doc = round_trip(&cat(&[&header(88), &eof(), &after]));
    assert_eq!(doc.records().len(), 1);
    assert_eq!(doc.trailing_bytes(), &after[..]);
}

#[test]
fn truncated_header_is_fatal() {
    let h = header(108);
    for len in [0usize, 3, 4, 7, 43, 44, 87, 107] {
        let err = parse(&h[..len], &lim()).unwrap_err();
        assert!(
            matches!(
                err,
                ParseFailure::TooShort { .. }
                    | ParseFailure::UnrecognizedFormat { .. }
                    | ParseFailure::Truncated { .. }
            ),
            "len {len}: {err:?}"
        );
    }
}

#[test]
fn bad_header_declarations_are_fatal() {
    let mut small = header(88);
    small[4..8].copy_from_slice(&80u32.to_le_bytes());
    assert!(matches!(
        parse(&small, &lim()),
        Err(ParseFailure::HeaderSizeTooSmall {
            declared: 80,
            minimum: 88
        })
    ));

    let mut huge = header(88);
    huge[4..8].copy_from_slice(&u32::MAX.to_le_bytes());
    assert!(matches!(
        parse(&huge, &lim()),
        Err(ParseFailure::HeaderSizeTooSmall { .. } | ParseFailure::LimitExceeded { .. })
    ));

    let mut huge_ok_limits = header(88);
    huge_ok_limits[4..8].copy_from_slice(&1000u32.to_le_bytes());
    assert!(matches!(
        parse(&huge_ok_limits, &lim()),
        Err(ParseFailure::HeaderSizeTooSmall { .. } | ParseFailure::Truncated { .. })
    ));
}

#[test]
fn truncated_record_head_keeps_tail() {
    let input = cat(&[&header(88), &[1, 2, 3, 4, 5]]);
    let doc = round_trip(&input);
    assert!(doc.records().is_empty());
    assert_eq!(doc.unframed_bytes(), &[1, 2, 3, 4, 5]);
    assert_eq!(
        doc.diagnostics()[0].kind,
        DiagnosticKind::TruncatedRecordHead { available: 5 }
    );
    assert_eq!(doc.diagnostics()[0].offset, 88);
}

#[test]
fn truncated_record_body_keeps_tail() {
    let good = record(70, &[0; 4]);
    let mut cut = record(71, &[0; 20]);
    cut.truncate(20);
    let input = cat(&[&header(88), &good, &cut]);
    let doc = round_trip(&input);
    assert_eq!(doc.records().len(), 1);
    let d = doc.diagnostics()[0];
    assert_eq!(
        d.kind,
        DiagnosticKind::TruncatedRecord {
            claimed: 28,
            available: 20
        }
    );
    assert_eq!((d.offset, d.record_type), (88 + 12, Some(71)));
    assert_eq!(doc.unframed_bytes(), &cut[..]);
}

#[test]
fn undersized_record_stops_without_progress_loop() {
    for size in [0u32, 1, 7] {
        let mut bad = Vec::new();
        le32(&mut bad, 70);
        le32(&mut bad, size);
        bad.extend_from_slice(&[0; 16]);
        let input = cat(&[&header(88), &bad]);
        let doc = round_trip(&input);
        assert!(doc.records().is_empty());
        assert_eq!(
            doc.diagnostics()[0].kind,
            DiagnosticKind::RecordSizeTooSmall { size }
        );
        assert_eq!(doc.unframed_bytes(), &bad[..]);
    }
}

#[test]
fn record_length_beyond_u32_arithmetic_is_not_trusted() {
    let mut bad = Vec::new();
    le32(&mut bad, 70);
    le32(&mut bad, u32::MAX);
    let input = cat(&[&header(88), &bad]);
    let doc = round_trip(&input);
    assert!(matches!(
        doc.diagnostics()[0].kind,
        DiagnosticKind::TruncatedRecord {
            claimed: u32::MAX,
            ..
        }
    ));
}

#[test]
fn detection() {
    assert_eq!(detect_format(&cat(&[&header(88), &eof()])), Ok(Format::Emf));
    assert_eq!(detect_format(&[0xD7, 0xCD, 0xC6, 0x9A]), Ok(Format::WmfApm));
    let mut wmf = vec![1, 0, 9, 0];
    wmf.resize(18, 0);
    assert_eq!(detect_format(&wmf), Ok(Format::WmfStandard));
    assert_eq!(
        detect_format(&[1, 2]),
        Err(ParseFailure::TooShort { len: 2 })
    );
    assert!(matches!(
        detect_format(&[5, 0, 0, 0, 0]),
        Err(ParseFailure::UnrecognizedFormat { first_u32: 5 })
    ));
    // Signature 1 without the EMF magic is not EMF.
    let mut no_magic = header(88);
    no_magic[40..44].copy_from_slice(&[0; 4]);
    assert!(detect_format(&no_magic).is_err());
}

#[test]
fn wmf_is_detected_but_not_parsed() {
    assert_eq!(
        parse(&[0xD7, 0xCD, 0xC6, 0x9A, 0, 0, 0, 0], &lim()),
        Err(ParseFailure::UnsupportedFormat(Format::WmfApm))
    );
    let mut wmf = vec![2, 0, 9, 0];
    wmf.resize(18, 0);
    assert_eq!(
        parse(&wmf, &lim()),
        Err(ParseFailure::UnsupportedFormat(Format::WmfStandard))
    );
}

fn limited(f: impl FnOnce(&mut ParseLimits)) -> ParseLimits {
    let mut l = lim();
    f(&mut l);
    l
}

fn many_records(n: usize) -> Vec<u8> {
    let mut v = header(88);
    for _ in 0..n {
        v.extend(record(70, &[0; 8]));
    }
    v
}

#[test]
fn input_limit() {
    let input = many_records(1);
    let l = limited(|l| l.max_input_bytes = input.len() - 1);
    assert!(matches!(
        parse(&input, &l),
        Err(ParseFailure::LimitExceeded {
            kind: LimitKind::InputBytes,
            ..
        })
    ));
    assert!(parse(&input, &limited(|l| l.max_input_bytes = input.len())).is_ok());
}

#[test]
fn record_size_limit_applies_to_records_and_header() {
    let input = cat(&[&header(88), &record(70, &[0; 84])]);
    let l = limited(|l| l.max_record_bytes = 91);
    assert!(matches!(
        parse(&input, &l),
        Err(ParseFailure::LimitExceeded {
            kind: LimitKind::RecordBytes,
            requested: 92,
            ..
        })
    ));
    assert!(parse(&input, &limited(|l| l.max_record_bytes = 92)).is_ok());
    assert!(matches!(
        parse(&input, &limited(|l| l.max_record_bytes = 87)),
        Err(ParseFailure::LimitExceeded {
            kind: LimitKind::RecordBytes,
            ..
        })
    ));
}

#[test]
fn record_count_limit_counts_header() {
    let input = many_records(3);
    assert!(parse(&input, &limited(|l| l.max_records = 4)).is_ok());
    assert!(matches!(
        parse(&input, &limited(|l| l.max_records = 3)),
        Err(ParseFailure::LimitExceeded {
            kind: LimitKind::RecordCount,
            limit: 3,
            requested: 4
        })
    ));
}

#[test]
fn aggregate_allocation_limit() {
    let input = many_records(50);
    let per_record = std::mem::size_of::<emf_core::RecordSpan>();
    let exact = input.len() + 127 * per_record;
    assert!(parse(&input, &limited(|l| l.max_allocated_bytes = exact)).is_ok());
    assert!(matches!(
        parse(&input, &limited(|l| l.max_allocated_bytes = exact - 1)),
        Err(ParseFailure::LimitExceeded {
            kind: LimitKind::AllocatedBytes,
            ..
        })
    ));
}

#[test]
fn aggregate_work_limit() {
    let input = many_records(10);
    // header 88 -> 1 + 6, each 16-byte record -> 1 + 1.
    let exact = 7 + 10 * 2 + (input.len() as u64).div_ceil(16);
    assert!(parse(&input, &limited(|l| l.max_work_units = exact)).is_ok());
    assert!(matches!(
        parse(&input, &limited(|l| l.max_work_units = exact - 1)),
        Err(ParseFailure::LimitExceeded {
            kind: LimitKind::WorkUnits,
            ..
        })
    ));
}

#[test]
fn zero_limits_reject_instead_of_looping() {
    let input = many_records(2);
    let zero = ParseLimits {
        max_input_bytes: 0,
        max_record_bytes: 0,
        max_records: 0,
        max_allocated_bytes: 0,
        max_work_units: 0,
    };
    assert!(matches!(
        parse(&input, &zero),
        Err(ParseFailure::LimitExceeded { .. })
    ));
}

#[test]
fn failed_parse_does_not_affect_later_parse() {
    let input = many_records(2);
    assert!(parse(&input, &limited(|l| l.max_records = 1)).is_err());
    assert!(parse(&input, &lim()).is_ok());
}

#[test]
fn many_minimum_size_records_make_forward_progress() {
    let mut input = header(88);
    for _ in 0..10_000 {
        input.extend(record(70, &[]));
    }
    let doc = round_trip(&input);
    assert_eq!(doc.records().len(), 10_000);
}

/// One existing valid fixture: header semantics probed from the file itself
/// (nSize 108, nBytes equals file length, nRecords counts the header, ends at
/// EMR_EOF with no trailing bytes) and exact bytes retained.
#[test]
fn existing_fixture_exact_bytes() {
    let path = concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../../spec/fixtures/simple/image1.emf"
    );
    let bytes = std::fs::read(path).expect("repository fixture exists");
    let doc = round_trip(&bytes);
    let h = doc.header();
    assert_eq!(h.n_size, 108);
    assert_eq!(h.n_bytes as usize, bytes.len());
    assert_eq!(h.n_records as usize, doc.records().len() + 1);
    assert!(doc.has_eof() && doc.trailing_bytes().is_empty() && doc.diagnostics().is_empty());
    assert!(h.pixel_format.is_some() && h.micrometers.is_some());
}

#[test]
fn allocation_limit_includes_diagnostics() {
    let input = cat(&[&header(88), &[1]]);
    let diagnostic = std::mem::size_of::<emf_core::Diagnostic>();
    assert!(matches!(
        parse(&input, &limited(|l| l.max_allocated_bytes = input.len())),
        Err(ParseFailure::LimitExceeded {
            kind: LimitKind::AllocatedBytes,
            ..
        })
    ));
    let doc = parse(
        &input,
        &limited(|l| l.max_allocated_bytes = input.len() + diagnostic),
    )
    .unwrap();
    assert_eq!(doc.diagnostics().len(), 1);
    assert_eq!(serialize(&doc).unwrap(), input);
}

#[test]
fn allocation_limit_includes_reserved_record_capacity() {
    let input = many_records(5);
    let record = std::mem::size_of::<emf_core::RecordSpan>();
    assert!(matches!(
        parse(
            &input,
            &limited(|l| l.max_allocated_bytes = input.len() + 5 * record)
        ),
        Err(ParseFailure::LimitExceeded {
            kind: LimitKind::AllocatedBytes,
            ..
        })
    ));
    let doc = parse(
        &input,
        &limited(|l| l.max_allocated_bytes = input.len() + 15 * record),
    )
    .unwrap();
    assert_eq!(doc.records().len(), 5);
    assert_eq!(serialize(&doc).unwrap(), input);
}

#[test]
fn work_limit_includes_copying_trailing_bytes() {
    let input = cat(&[&header(88), &eof(), &[0xFF; 4096]]);
    // Framing alone costs 7 + 3 units; copying the complete source costs more.
    assert!(matches!(
        parse(&input, &limited(|l| l.max_work_units = 10)),
        Err(ParseFailure::LimitExceeded {
            kind: LimitKind::WorkUnits,
            ..
        })
    ));
    let doc = round_trip(&input);
    assert_eq!(doc.trailing_bytes(), &[0xFF; 4096]);
}

#[test]
fn checked_reader_preserves_cursor_after_failed_reads() {
    let mut reader = emf_core::Reader::new(&[0x34, 0x12, 0xFE, 0xFF, 0xFF, 0xFF]);
    assert_eq!(reader.u16(), Ok(0x1234));
    assert_eq!(reader.i32(), Ok(-2));
    assert_eq!(reader.position(), 6);
    assert!(matches!(
        reader.take(usize::MAX),
        Err(ParseFailure::ArithmeticOverflow { offset: 6 })
    ));
    assert_eq!(reader.position(), 6);
    assert!(matches!(
        reader.u16(),
        Err(ParseFailure::Truncated {
            offset: 6,
            needed: 2,
            available: 0
        })
    ));
    assert!(reader.is_empty());
}

#[test]
fn document_owns_bytes_after_input_is_dropped() {
    let doc = {
        let bytes = cat(&[&header(88), &eof(), &[0xF0, 0x0D]]);
        parse(&bytes, &lim()).unwrap()
    };
    assert_eq!(
        serialize(&doc).unwrap(),
        cat(&[&header(88), &eof(), &[0xF0, 0x0D]])
    );
}
