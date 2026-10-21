use emf_core::wmf::escape::{
    assemble_embedded_emf, embedded_emf_checksum, EmbeddedEmfError as E, EscapeRecord,
};
use emf_core::{wmf, ParseLimits};

fn segment_data(count: u32, total: u32, remaining: u32, chunk: &[u8], checksum: u16) -> Vec<u8> {
    let mut data = Vec::new();
    data.extend_from_slice(&0x4346_4d57u32.to_le_bytes());
    data.extend_from_slice(&1u32.to_le_bytes());
    data.extend_from_slice(&0x0001_0000u32.to_le_bytes());
    data.extend_from_slice(&checksum.to_le_bytes());
    data.extend_from_slice(&0u32.to_le_bytes());
    data.extend_from_slice(&count.to_le_bytes());
    data.extend_from_slice(&(chunk.len() as u32).to_le_bytes());
    data.extend_from_slice(&remaining.to_le_bytes());
    data.extend_from_slice(&total.to_le_bytes());
    data.extend_from_slice(chunk);
    data
}

fn escape(data: Vec<u8>) -> EscapeRecord {
    let padding = if data.len() % 2 != 0 { Some(0) } else { None };
    EscapeRecord {
        function: 0x626,
        escape_function: 0x000f,
        data,
        padding,
    }
}

/// Splits `stream` into segments of at most `size` bytes.
fn segments(stream: &[u8], size: usize) -> Vec<EscapeRecord> {
    let checksum = embedded_emf_checksum(stream);
    let chunks: Vec<&[u8]> = stream.chunks(size).collect();
    let mut left = stream.len();
    chunks
        .iter()
        .map(|chunk| {
            left -= chunk.len();
            escape(segment_data(
                chunks.len() as u32,
                stream.len() as u32,
                left as u32,
                chunk,
                checksum,
            ))
        })
        .collect()
}

fn stream(len: usize) -> Vec<u8> {
    (0..len).map(|i| (i * 7 + 3) as u8).collect()
}

fn assemble(records: &[EscapeRecord]) -> Result<Vec<u8>, E> {
    assemble_embedded_emf(records, &ParseLimits::default()).map(|e| e.bytes)
}

#[test]
fn single_segment_assembles_with_valid_checksum() {
    let data = stream(100);
    let records = segments(&data, 8192);
    assert_eq!(records.len(), 1);
    let segment = records[0].embedded_emf_segment().unwrap();
    assert_eq!(
        (
            segment.record_count,
            segment.remaining_bytes,
            segment.total_size
        ),
        (1, 0, 100)
    );
    let emf = assemble_embedded_emf(&records, &ParseLimits::default()).unwrap();
    assert_eq!(emf.bytes, data);
    assert!(emf.checksum_valid);
    assert_eq!(emf.version, 0x0001_0000);
}

#[test]
fn multi_segment_concatenates_in_order_at_limit_boundary() {
    let data = stream(8192 * 2 + 10);
    let records = segments(&data, 8192);
    assert_eq!(records.len(), 3);
    assert_eq!(assemble(&records).unwrap(), data);
    let exact = stream(8192);
    assert_eq!(assemble(&segments(&exact, 8192)).unwrap(), exact);
}

#[test]
fn bad_checksum_is_reported_not_rejected() {
    let data = stream(40);
    let mut records = segments(&data, 8192);
    records[0].data[12] ^= 1;
    let emf = assemble_embedded_emf(&records, &ParseLimits::default()).unwrap();
    assert!(!emf.checksum_valid);
}

#[test]
fn malformed_metadata_is_rejected_with_a_reason() {
    let good = segments(&stream(8), 8192).remove(0);
    let edit = |f: &dyn Fn(&mut EscapeRecord)| {
        let mut r = good.clone();
        f(&mut r);
        r.embedded_emf_segment().map(|_| ())
    };
    assert_eq!(edit(&|r| r.data.truncate(33)), Err(E::Transport));
    assert_eq!(
        edit(&|r| {
            r.data.truncate(32);
        }),
        Err(E::Metadata)
    );
    assert_eq!(edit(&|r| r.data[0] ^= 1), Err(E::CommentIdentifier));
    assert_eq!(edit(&|r| r.data[4] = 2), Err(E::CommentType));
    assert_eq!(edit(&|r| r.data[14] = 1), Err(E::NonZeroFlags));
    assert_eq!(edit(&|r| r.data[18] = 0), Err(E::ZeroRecordCount));
    assert_eq!(
        edit(&|r| r.escape_function = 0x0013),
        Err(E::NotEmbeddedEmf)
    );
    // ByteCount is 34 + CurrentRecordSize: a CurrentRecordSize that disagrees fails.
    assert_eq!(edit(&|r| r.data[22] = 7), Err(E::Metadata));
    assert_eq!(edit(&|r| r.data[26] = 1), Err(E::InconsistentSizes));
    assert_eq!(edit(&|r| r.padding = Some(0)), Err(E::Transport));
}

#[test]
fn oversize_segment_and_inconsistent_sizes_are_rejected() {
    let big = vec![0u8; 8193];
    let oversize = escape(segment_data(1, 8193, 0, &big, 0));
    assert_eq!(oversize.embedded_emf_segment(), Err(E::SegmentTooLarge));
    let over_total = escape(segment_data(1, 4, 0, &[0u8; 8], 0));
    assert_eq!(over_total.embedded_emf_segment(), Err(E::InconsistentSizes));
}

#[test]
fn count_and_byte_arithmetic_mismatches_are_rejected() {
    let data = stream(20_000);
    let good = segments(&data, 8192);
    // Declared count larger than the sequence supplies -> incomplete.
    assert_eq!(assemble(&good[..2]), Err(E::Incomplete));
    assert_eq!(assemble(&[]), Err(E::Incomplete));
    // Extra segment after completion.
    let mut extra = good.clone();
    extra.push(good[0].clone());
    assert_eq!(assemble(&extra), Err(E::RecordCountMismatch));
    // Out of order segments break the remaining-bytes arithmetic.
    let swapped = vec![good[1].clone(), good[0].clone(), good[2].clone()];
    assert_eq!(assemble(&swapped), Err(E::RemainingMismatch));
    // Total disagreement between segments.
    let mut total = good.clone();
    total[1].data[30] ^= 1;
    assert_eq!(assemble(&total), Err(E::SequenceMismatch));
    // CommentRecordCount disagreement.
    let mut count = good.clone();
    count[2].data[18] = 9;
    assert_eq!(assemble(&count), Err(E::SequenceMismatch));
    // Declared count of two while three segments are needed.
    let mut short = good.clone();
    for r in &mut short {
        r.data[18] = 2;
    }
    assert_eq!(assemble(&short), Err(E::RecordCountMismatch));
    // A declared total above the allocation limit never allocates.
    let limits = ParseLimits {
        max_allocated_bytes: 100,
        ..ParseLimits::default()
    };
    assert_eq!(
        assemble_embedded_emf(&good, &limits).map(|e| e.bytes),
        Err(E::LimitExceeded)
    );
}

fn document(records: &[(u16, Vec<u8>)]) -> Vec<u8> {
    let mut body = Vec::new();
    let mut largest = 3u32;
    for (function, payload) in records {
        let words = 3 + payload.len() as u32 / 2;
        largest = largest.max(words);
        body.extend_from_slice(&words.to_le_bytes());
        body.extend_from_slice(&function.to_le_bytes());
        body.extend_from_slice(payload);
    }
    body.extend_from_slice(&[3, 0, 0, 0, 0, 0]);
    let mut bytes = vec![1, 0, 9, 0, 0, 3];
    bytes.extend_from_slice(&(9 + body.len() as u32 / 2).to_le_bytes());
    bytes.extend_from_slice(&[0, 0]);
    bytes.extend_from_slice(&largest.to_le_bytes());
    bytes.extend_from_slice(&[0, 0]);
    bytes.extend_from_slice(&body);
    bytes
}

fn wire(record: &EscapeRecord) -> (u16, Vec<u8>) {
    let mut payload = Vec::new();
    payload.extend_from_slice(&record.escape_function.to_le_bytes());
    payload.extend_from_slice(&(record.data.len() as u16).to_le_bytes());
    payload.extend_from_slice(&record.data);
    payload.extend(record.padding);
    (0x0626, payload)
}

#[test]
fn document_sequences_are_found_and_serialization_is_byte_identical() {
    let first = stream(9000);
    let second = stream(30);
    let mut records: Vec<(u16, Vec<u8>)> = segments(&first, 8192).iter().map(wire).collect();
    records.push((0x001e, Vec::new()));
    records.extend(segments(&second, 8192).iter().map(wire));
    let mut broken = segments(&stream(20), 8192).remove(0);
    broken.data[4] = 9;
    records.push(wire(&broken));
    let bytes = document(&records);
    let doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
    let found = doc.embedded_emf_sequences(&ParseLimits::default());
    assert_eq!(found.len(), 3);
    assert_eq!((found[0].first_record, found[0].segment_count), (0, 2));
    assert_eq!(found[0].emf.as_ref().unwrap().bytes, first);
    assert_eq!((found[1].first_record, found[1].segment_count), (3, 1));
    assert_eq!(found[1].emf.as_ref().unwrap().bytes, second);
    assert_eq!(found[2].emf, Err(E::CommentType));
    assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
}
