//! First rejection under the Ruby WMF contract: one crafted input per reason, with the codec, offset,
//! function and detail the contract reports.
use emf_core::wmf::contract::{self, Codec, Limits, Reason, MAX_INPUT_BYTES, MAX_RECORDS};

fn first_rejection(input: &[u8]) -> Option<contract::Rejection> {
    contract::first_rejection(input, &Limits::default())
}

fn record(function: u16, body: &[u8]) -> Vec<u8> {
    assert_eq!(body.len() % 2, 0);
    let mut bytes = ((body.len() as u32 + 6) / 2).to_le_bytes().to_vec();
    bytes.extend_from_slice(&function.to_le_bytes());
    bytes.extend_from_slice(body);
    bytes
}

fn eof() -> Vec<u8> {
    record(0, &[])
}

fn header(size_words: u32, objects: u16, max_record: u32) -> Vec<u8> {
    let mut bytes = Vec::new();
    for word in [1u16, 9, 0x0300] {
        bytes.extend_from_slice(&word.to_le_bytes());
    }
    bytes.extend_from_slice(&size_words.to_le_bytes());
    bytes.extend_from_slice(&objects.to_le_bytes());
    bytes.extend_from_slice(&max_record.to_le_bytes());
    bytes.extend_from_slice(&0u16.to_le_bytes());
    bytes
}

fn wmf(records: &[Vec<u8>], objects: u16) -> Vec<u8> {
    let words: usize = records.iter().map(|r| r.len() / 2).sum();
    let largest = records.iter().map(|r| r.len() / 2).max().unwrap_or(0);
    let mut bytes = header(9 + words as u32, objects, largest as u32);
    records.iter().for_each(|r| bytes.extend_from_slice(r));
    bytes
}

fn words(values: &[u16]) -> Vec<u8> {
    values.iter().flat_map(|v| v.to_le_bytes()).collect()
}

fn with_eof(mut records: Vec<Vec<u8>>) -> Vec<Vec<u8>> {
    records.push(eof());
    records
}

/// A region record body with no scans: kind 6, size 22.
fn empty_region() -> Vec<u8> {
    words(&[0, 6, 0, 0, 22, 0, 0, 0, 0, 0, 0])
}

fn placeable(reserved: u32, checksum: Option<u16>, handle: u16) -> Vec<u8> {
    let mut bytes = 0x9AC6_CDD7u32.to_le_bytes().to_vec();
    bytes.extend_from_slice(&handle.to_le_bytes());
    bytes.extend_from_slice(&words(&[0, 0, 100, 100, 96]));
    bytes.extend_from_slice(&reserved.to_le_bytes());
    let sum = bytes.chunks(2).fold(0u16, |sum, pair| {
        sum ^ u16::from_le_bytes([pair[0], pair[1]])
    });
    bytes.extend_from_slice(&checksum.unwrap_or(sum).to_le_bytes());
    bytes
}

struct Case {
    name: &'static str,
    bytes: Vec<u8>,
    reason: Reason,
    offset: Option<usize>,
    function: Option<u16>,
    detail: u64,
}

fn case(name: &'static str, bytes: Vec<u8>, reason: Reason) -> Case {
    Case {
        name,
        bytes,
        reason,
        offset: None,
        function: None,
        detail: 0,
    }
}

/// Reason raised by the first record (offset 18) of a one-record metafile.
fn record_case(name: &'static str, function: u16, body: Vec<u8>, reason: Reason) -> Case {
    Case {
        name,
        bytes: wmf(&with_eof(vec![record(function, &body)]), 0),
        reason,
        offset: Some(18),
        function: Some(function),
        detail: 0,
    }
}

fn object_case(
    name: &'static str,
    objects: u16,
    records: Vec<Vec<u8>>,
    offset: usize,
    function: u16,
    reason: Reason,
    detail: u64,
) -> Case {
    Case {
        name,
        bytes: wmf(&with_eof(records), objects),
        reason,
        offset: Some(offset),
        function: Some(function),
        detail,
    }
}

fn phase_cases() -> Vec<Case> {
    let mut with_placeable = placeable(0, None, 0);
    with_placeable.extend(wmf(&[eof()], 0));
    assert!(first_rejection(&with_placeable).is_none());
    let mut cases = vec![
        case(
            "truncated placeable",
            [0xD7, 0xCD, 0xC6, 0x9A, 1, 2, 3].to_vec(),
            Reason::PlaceableTruncated,
        ),
        case(
            "placeable reserved",
            [placeable(1, None, 0), wmf(&[eof()], 0)].concat(),
            Reason::PlaceableReserved,
        ),
        case(
            "placeable checksum",
            [placeable(0, Some(0xFFFF), 0), wmf(&[eof()], 0)].concat(),
            Reason::PlaceableChecksum,
        ),
        case(
            "truncated header",
            vec![1, 0, 9, 0, 0, 3],
            Reason::HeaderTruncated,
        ),
    ];
    for (name, at, value, reason) in [
        ("type", 0, 3u8, Reason::HeaderType),
        ("header size", 2, 8, Reason::HeaderSize),
        ("version", 5, 2, Reason::HeaderVersion),
    ] {
        let mut bytes = wmf(&[eof()], 0);
        bytes[at] = value;
        cases.push(case(name, bytes, reason));
    }
    let mut handle = placeable(0, None, 7);
    let mut standard = wmf(&[eof()], 0);
    standard[0] = 2;
    handle.extend(standard);
    cases.push(case(
        "placeable handle",
        handle,
        Reason::HeaderPlaceableHandle,
    ));
    cases
}

fn framing_cases() -> Vec<Case> {
    let mut short_header = header(11, 0, 0);
    short_header.extend([0, 0, 0, 0]);
    let mut bad_length = wmf(&[eof()], 0);
    bad_length[18] = 2;
    vec![
        Case {
            offset: Some(18),
            ..case(
                "truncated record header",
                short_header,
                Reason::TruncatedRecordHeader,
            )
        },
        Case {
            offset: Some(18),
            function: Some(0),
            detail: 2,
            ..case(
                "invalid record length",
                bad_length,
                Reason::InvalidRecordLength,
            )
        },
        Case {
            offset: Some(24),
            ..case(
                "missing eof",
                wmf(&[record(0x1E, &[])], 0),
                Reason::MissingEof,
            )
        },
        record_case(
            "invalid eof length",
            0,
            vec![0, 0],
            Reason::InvalidEofLength,
        ),
    ]
}

fn record_cases() -> Vec<Case> {
    let region_scan = |count: u16, size: u16, max: u16, scan: &[u16]| {
        let mut body = words(&[0, 6, 0, 0, size, count, max, 0, 0, 0, 0]);
        body.extend(words(scan));
        body
    };
    vec![
        record_case("fixed", 0x14, words(&[0, 0, 0, 0]), Reason::FixedLength),
        record_case("state", 0x01, words(&[0]), Reason::StateLength),
        record_case("font", 0xFB, vec![0; 20], Reason::FontLength),
        record_case("object", 0x2D, words(&[0, 0]), Reason::ObjectLength),
        record_case(
            "point missing count",
            0x25,
            vec![],
            Reason::PointMissingCount,
        ),
        record_case(
            "point truncated counts",
            0x38,
            words(&[5, 0]),
            Reason::PointTruncatedCounts,
        ),
        record_case(
            "point invalid count",
            0x24,
            words(&[1, 0, 0]),
            Reason::PointInvalidCount,
        ),
        record_case(
            "point length mismatch",
            0x25,
            words(&[2, 0, 0]),
            Reason::PointLengthMismatch,
        ),
        record_case("text", 0x21, vec![0; 4], Reason::TextTruncated),
        record_case(
            "text rectangle",
            0x32,
            words(&[0, 0, 0, 2]),
            Reason::TextTruncatedRectangle,
        ),
        record_case(
            "text negative",
            0x21,
            words(&[0xFFFF, 0, 0]),
            Reason::TextNegativeLength,
        ),
        record_case(
            "text string",
            0x21,
            words(&[10, 0, 0]),
            Reason::TextTruncatedString,
        ),
        record_case(
            "text spacing",
            0x32,
            [words(&[0, 0, 4, 0]), b"abcd".to_vec(), words(&[0])].concat(),
            Reason::TextTruncatedSpacing,
        ),
        record_case(
            "palette prefix",
            0xF7,
            words(&[0]),
            Reason::PaletteTruncatedPrefix,
        ),
        record_case(
            "palette entries",
            0xF7,
            words(&[0, 5]),
            Reason::PaletteTruncatedEntries,
        ),
        record_case(
            "region prefix",
            0x28,
            words(&[0]),
            Reason::RegionTruncatedPrefix,
        ),
        record_case(
            "region header truncated",
            0xFF,
            vec![0; 10],
            Reason::RegionTruncatedHeader,
        ),
        record_case(
            "region header",
            0xFF,
            vec![0; 22],
            Reason::RegionInvalidHeader,
        ),
        record_case(
            "region scan truncated",
            0xFF,
            region_scan(2, 38, 4, &[4, 0, 0, 0, 0, 0, 0, 4]),
            Reason::RegionTruncatedScan,
        ),
        record_case(
            "region scan",
            0xFF,
            region_scan(1, 30, 0, &[1, 0, 0, 0]),
            Reason::RegionInvalidScan,
        ),
        record_case(
            "region scan size",
            0xFF,
            region_scan(1, 30, 5, &[0, 0, 0, 0]),
            Reason::RegionInvalidScanSize,
        ),
        record_case(
            "brush pattern prefix",
            0xF9,
            vec![0; 10],
            Reason::BrushTruncatedPattern,
        ),
        record_case(
            "brush pattern extent",
            0xF9,
            vec![0; 32],
            Reason::BrushInvalidPatternExtent,
        ),
        record_case(
            "brush dib prefix",
            0x42,
            words(&[0]),
            Reason::BrushTruncatedDib,
        ),
        record_case(
            "brush dib usage",
            0x42,
            words(&[1, 5, 0]),
            Reason::BrushInvalidDibUsage,
        ),
        record_case(
            "bitmap prefix",
            0x22,
            vec![0; 4],
            Reason::BitmapTruncatedPrefix,
        ),
        record_case(
            "bitmap source",
            0x22,
            vec![0; 16],
            Reason::BitmapEmptySource,
        ),
        record_case(
            "geometry prefix",
            0x10,
            words(&[0]),
            Reason::GeometryTruncatedPrefix,
        ),
        record_case(
            "flood mode",
            0x48,
            words(&[2, 0, 0, 0, 0]),
            Reason::GeometryInvalidFloodMode,
        ),
        record_case("restore dc", 0x27, vec![], Reason::DcRestoreTruncated),
        record_case(
            "escape prefix",
            0x26,
            words(&[0]),
            Reason::DcEscapeTruncatedPrefix,
        ),
        record_case(
            "escape data",
            0x26,
            words(&[1, 10]),
            Reason::DcEscapeTruncatedData,
        ),
    ]
}

fn object_cases() -> Vec<Case> {
    let pen = || record(0xFA, &words(&[0, 0, 0, 0, 0]));
    let brush = || record(0xFC, &words(&[0, 0, 0, 0]));
    let palette_ref = |index| record(0x34, &words(&[index]));
    vec![
        object_case(
            "capacity",
            0,
            vec![pen()],
            18,
            0xFA,
            Reason::ObjectCapacity,
            0,
        ),
        object_case(
            "invalid reference",
            1,
            vec![record(0x2D, &words(&[5]))],
            18,
            0x2D,
            Reason::ObjectInvalidReference,
            5,
        ),
        object_case(
            "not palette",
            1,
            vec![brush(), palette_ref(0)],
            32,
            0x34,
            Reason::ObjectNotPalette,
            0,
        ),
        object_case(
            "not region",
            1,
            vec![brush(), record(0x2A, &words(&[0]))],
            32,
            0x2A,
            Reason::ObjectNotRegion,
            0,
        ),
        object_case(
            "invalid region",
            1,
            vec![record(0x28, &words(&[0, 0]))],
            18,
            0x28,
            Reason::ObjectInvalidRegion,
            0,
        ),
        object_case(
            "invalid brush",
            2,
            vec![record(0xFF, &empty_region()), record(0x28, &words(&[0, 1]))],
            46,
            0x28,
            Reason::ObjectInvalidBrush,
            1,
        ),
        object_case(
            "not brush",
            2,
            vec![
                record(0xFF, &empty_region()),
                pen(),
                record(0x28, &words(&[0, 1])),
            ],
            46 + 16,
            0x28,
            Reason::ObjectNotBrush,
            1,
        ),
    ]
}

#[test]
fn every_reason_names_its_codec_offset_function_and_detail() {
    let mut cases = phase_cases();
    cases.extend(framing_cases());
    cases.extend(record_cases());
    cases.extend(object_cases());
    // A high-bit stock selector needs no slot, so it is not a rejection.
    assert!(first_rejection(&wmf(&[record(0x2D, &words(&[0x8005])), eof()], 0)).is_none());
    let mut seen = Vec::new();
    for case in cases {
        let found =
            first_rejection(&case.bytes).unwrap_or_else(|| panic!("{} accepted", case.name));
        assert_eq!(found.reason, case.reason, "{}", case.name);
        assert_eq!(
            (found.offset, found.function, found.detail),
            (case.offset, case.function, case.detail),
            "{}",
            case.name
        );
        assert_eq!(found.codec(), case.reason.codec(), "{}", case.name);
        seen.push(case.reason as u32);
    }
    seen.sort_unstable();
    seen.dedup();
    // Reasons without a crafted case here are the two that need a huge input; they have their own tests.
    assert_eq!(seen.len(), 56 - 2 - 3, "{seen:?}");
}

#[test]
fn input_size_and_record_limit() {
    let found = first_rejection(&vec![0u8; MAX_INPUT_BYTES + 1]).unwrap();
    assert_eq!(
        (found.reason, found.codec(), found.offset),
        (Reason::InputTooLarge, Codec::Input, None)
    );
    let mut records: Vec<Vec<u8>> = (0..=MAX_RECORDS).map(|_| record(0x1E, &[])).collect();
    records.push(eof());
    let found = first_rejection(&wmf(&records, 0)).unwrap();
    assert_eq!(found.reason, Reason::RecordLimit);
    assert_eq!(
        (found.offset, found.function),
        (Some(18 + MAX_RECORDS * 6), None)
    );
}

#[test]
fn an_accepted_metafile_has_no_rejection() {
    let records = vec![record(0x14, &words(&[1, 2])), eof()];
    assert!(first_rejection(&wmf(&records, 0)).is_none());
}

#[test]
fn the_first_failure_in_contract_order_wins() {
    // A later malformed record loses to an earlier bad object reference only when records decode first.
    let bad_reference = record(0x2D, &words(&[3]));
    let later_malformed = record(0x14, &words(&[0]));
    let found = first_rejection(&wmf(&[bad_reference, later_malformed, eof()], 1)).unwrap();
    assert_eq!(
        (found.reason, found.offset, found.function),
        (Reason::FixedLength, Some(26), Some(0x14))
    );
}

#[test]
fn the_callers_limits_replace_the_defaults() {
    let bytes = wmf(&[record(0x1E, &[]), eof()], 0);
    let at = |max_input_bytes, max_records| {
        contract::first_rejection(
            &bytes,
            &Limits {
                max_input_bytes,
                max_records,
            },
        )
        .map(|found| found.reason)
    };
    assert_eq!(at(bytes.len(), 2), None);
    assert_eq!(at(bytes.len() - 1, 2), Some(Reason::InputTooLarge));
    assert_eq!(at(bytes.len(), 1), Some(Reason::RecordLimit));
}

fn set_u32(bytes: &mut [u8], at: usize, value: u32) {
    bytes[at..at + 4].copy_from_slice(&value.to_le_bytes());
}

#[test]
fn header_size_and_max_record_drift_are_not_rejections() {
    let base = wmf(&[record(0x14, &words(&[1, 2])), eof()], 0);
    assert!(first_rejection(&base).is_none());
    // Size too large (Inkscape), Size too small, Size zero and MaxRecord too small, too large, zero.
    for (at, value) in [(6, 9 + 8 + 1000), (6, 9 + 2), (6, 0), (12, 1), (12, 9999), (12, 0)] {
        let mut bytes = base.clone();
        set_u32(&mut bytes, at, value);
        assert!(first_rejection(&bytes).is_none(), "offset {at} value {value}");
    }
}

#[test]
fn records_after_eof_are_trailing_data_not_a_rejection() {
    // The walk ends at the first EOF; what follows is retained as the tail, whatever the declared Size says.
    assert!(first_rejection(&wmf(&[eof(), record(0x1E, &[])], 0)).is_none());
}

#[test]
fn a_declared_size_past_the_input_does_not_extend_the_walk() {
    let mut bytes = wmf(&[record(0x1E, &[])], 0);
    set_u32(&mut bytes, 6, u32::MAX);
    let found = first_rejection(&bytes).unwrap();
    assert_eq!((found.reason, found.offset), (Reason::MissingEof, Some(24)));
}
