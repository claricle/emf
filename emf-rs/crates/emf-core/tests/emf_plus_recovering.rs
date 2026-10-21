//! Recovering extraction: per-comment framing and clamped EMR_COMMENT lengths.
use emf_core::{emf_plus::RecordData as PlusData, *};

fn clear() -> Vec<u8> {
    let mut b = vec![9, 0x40, 0, 0, 16, 0, 0, 0, 4, 0, 0, 0];
    b.extend_from_slice(&0x11223344u32.to_le_bytes());
    b
}
/// An EMR_COMMENT with an explicit declared length (cbData) over `data`.
fn comment(data: &[u8], declared: u32) -> Vec<u8> {
    let padding = (4 - data.len() % 4) % 4;
    let mut b = 70u32.to_le_bytes().to_vec();
    b.extend_from_slice(&((12 + data.len() + padding) as u32).to_le_bytes());
    b.extend_from_slice(&declared.to_le_bytes());
    b.extend_from_slice(data);
    b.resize(b.len() + padding, 0);
    b
}
fn document(comments: &[Vec<u8>]) -> Document {
    let mut b = vec![0; 88];
    b[0..4].copy_from_slice(&1u32.to_le_bytes());
    b[4..8].copy_from_slice(&88u32.to_le_bytes());
    b[40..44].copy_from_slice(&0x464d4520u32.to_le_bytes());
    for c in comments {
        b.extend_from_slice(c);
    }
    parse(&b, &ParseLimits::default()).unwrap()
}
fn plus(stream: &[u8]) -> Vec<u8> {
    [b"EMF+".as_slice(), stream].concat()
}
fn recover(doc: &Document) -> Result<emf_plus::EmbeddedStream, emf_plus::Error> {
    let limits = ParseLimits::default();
    doc.structured_emf_plus_recovering_with_budget(&mut ParseBudget::new(&limits))
}

#[test]
fn a_malformed_header_ends_only_its_own_comment_and_the_stream_is_read_only() {
    let first = [
        clear(),
        vec![9, 0x40, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0],
        clear(),
    ]
    .concat();
    let doc = document(&[comment(&plus(&first), 4 + first.len() as u32), {
        let c = plus(&clear());
        comment(&c, c.len() as u32)
    }]);
    let extracted = recover(&doc).unwrap();
    assert_eq!(extracted.stream.records.len(), 2);
    // Framed bytes per comment, not the 28 / 16 byte payloads.
    assert_eq!(extracted.stream.segment_lengths(), [16, 16]);
    assert!(matches!(
        extracted.stream.records[1].data,
        PlusData::Clear { argb: 0x11223344 }
    ));
    assert!(doc.structured_emf_plus(&ParseLimits::default()).is_err());
    let mut copy = doc.clone();
    assert!(matches!(
        copy.apply_structured_emf_plus(&extracted, &SerializeLimits::default()),
        Err(emf_plus::EmbedError::Edit(EditFailure::RecordLayout { .. }))
    ));
    assert!(!copy.is_edited());
}

#[test]
fn a_comment_whose_declared_length_overruns_its_record_is_clamped() {
    let stream = plus(&clear());
    let doc = document(&[comment(&stream, 0xffff_fff0), comment(&stream, 3)]);
    // Strict extraction ignores the malformed (raw) comment; recovering selects it.
    assert_eq!(
        doc.structured_emf_plus(&ParseLimits::default())
            .unwrap()
            .stream
            .records
            .len(),
        0
    );
    let extracted = recover(&doc).unwrap();
    let sources: Vec<_> = extracted.segment_sources().collect();
    assert_eq!(sources, [(0, clear().as_slice())]);
    assert_eq!(extracted.stream.records.len(), 1);
}

#[test]
fn well_formed_streams_extract_the_same_records_in_both_modes() {
    let c = plus(&clear());
    let doc = document(&[comment(&c, c.len() as u32)]);
    let strict = doc.structured_emf_plus(&ParseLimits::default()).unwrap();
    let recovered = recover(&doc).unwrap();
    assert_eq!(strict.stream, recovered.stream);
}
