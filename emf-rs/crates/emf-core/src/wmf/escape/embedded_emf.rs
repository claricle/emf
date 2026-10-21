//! META_ESCAPE_ENHANCED_METAFILE (0x000F) segment validation and sequence assembly.
//!
//! The segment bytes stay inert: assembly concatenates them and never parses the EMF.
//! `ByteCount` is checked as 34 plus `CurrentRecordSize`: the literal MS-WMF text
//! ("34 plus EnhancedMetafileDataSize") cannot hold for a stream split across
//! 8,192-byte segments, and agrees with this rule for a single segment.

use super::EscapeRecord;
use crate::wmf::{Document, TypedRecord};
use crate::ParseLimits;

pub const EMBEDDED_EMF_ESCAPE: u16 = 0x000f;
pub const EMBEDDED_EMF_METADATA_BYTES: usize = 34;
pub const EMBEDDED_EMF_MAX_SEGMENT_BYTES: u32 = 8192;
const COMMENT_IDENTIFIER: u32 = 0x4346_4d57;
const COMMENT_TYPE: u32 = 1;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum EmbeddedEmfError {
    /// Not an Escape record with subtype 0x000F.
    NotEmbeddedEmf,
    /// Escape transport framing (alignment byte, count) is inconsistent.
    Transport,
    /// Fewer than 34 data bytes, or ByteCount differs from 34 + CurrentRecordSize.
    Metadata,
    CommentIdentifier,
    CommentType,
    NonZeroFlags,
    ZeroRecordCount,
    /// CurrentRecordSize is above 8,192.
    SegmentTooLarge,
    /// CurrentRecordSize + RemainingBytes exceeds EnhancedMetafileDataSize.
    InconsistentSizes,
    /// A later segment disagrees with the first on CommentRecordCount or total size.
    SequenceMismatch,
    /// RemainingBytes does not equal the total minus bytes seen so far.
    RemainingMismatch,
    /// Final segment reached with a different CommentRecordCount, or completion early.
    RecordCountMismatch,
    /// The sequence ended before RemainingBytes reached zero.
    Incomplete,
    /// The declared total exceeds the supplied allocation limit.
    LimitExceeded,
}

/// Borrowed view of one segment's 34-byte metadata and EMF bytes.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct EmbeddedEmfSegment<'a> {
    pub version: u32,
    pub checksum: u16,
    pub flags: u32,
    pub record_count: u32,
    pub current_size: u32,
    pub remaining_bytes: u32,
    pub total_size: u32,
    pub data: &'a [u8],
}

fn u32_at(data: &[u8], offset: usize) -> u32 {
    u32::from_le_bytes([
        data[offset],
        data[offset + 1],
        data[offset + 2],
        data[offset + 3],
    ])
}

impl EscapeRecord {
    /// Validates one segment against the record's own fields.
    pub fn embedded_emf_segment(&self) -> Result<EmbeddedEmfSegment<'_>, EmbeddedEmfError> {
        use EmbeddedEmfError as E;
        if self.function & 0xff != 0x26 || self.escape_function != EMBEDDED_EMF_ESCAPE {
            return Err(E::NotEmbeddedEmf);
        }
        let data = self.data.as_slice();
        if self.padding.is_some() != (data.len() % 2 != 0) || data.len() > usize::from(u16::MAX) {
            return Err(E::Transport);
        }
        if data.len() < EMBEDDED_EMF_METADATA_BYTES {
            return Err(E::Metadata);
        }
        if u32_at(data, 0) != COMMENT_IDENTIFIER {
            return Err(E::CommentIdentifier);
        }
        if u32_at(data, 4) != COMMENT_TYPE {
            return Err(E::CommentType);
        }
        let flags = u32_at(data, 14);
        let record_count = u32_at(data, 18);
        let current_size = u32_at(data, 22);
        let remaining_bytes = u32_at(data, 26);
        let total_size = u32_at(data, 30);
        if flags != 0 {
            return Err(E::NonZeroFlags);
        }
        if record_count == 0 {
            return Err(E::ZeroRecordCount);
        }
        if current_size > EMBEDDED_EMF_MAX_SEGMENT_BYTES {
            return Err(E::SegmentTooLarge);
        }
        if data.len() != EMBEDDED_EMF_METADATA_BYTES + current_size as usize {
            return Err(E::Metadata);
        }
        match current_size.checked_add(remaining_bytes) {
            Some(sum) if sum <= total_size => {}
            _ => return Err(E::InconsistentSizes),
        }
        Ok(EmbeddedEmfSegment {
            version: u32_at(data, 8),
            checksum: u16::from_le_bytes([data[12], data[13]]),
            flags,
            record_count,
            current_size,
            remaining_bytes,
            total_size,
            data: &data[EMBEDDED_EMF_METADATA_BYTES..],
        })
    }
}

/// An assembled embedded EMF stream.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct EmbeddedEmf {
    pub version: u32,
    pub checksum: u16,
    /// One's complement of the XOR of the stream's 16-bit words, against `checksum`.
    pub checksum_valid: bool,
    pub bytes: Vec<u8>,
}

/// Result for one run of consecutive 0x000F escapes starting at `first_record`.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct EmbeddedEmfSequence {
    pub first_record: usize,
    pub segment_count: usize,
    pub emf: Result<EmbeddedEmf, EmbeddedEmfError>,
}

pub fn embedded_emf_checksum(bytes: &[u8]) -> u16 {
    let mut xor = 0u16;
    for pair in bytes.chunks(2) {
        xor ^= u16::from_le_bytes([pair[0], pair.get(1).copied().unwrap_or(0)]);
    }
    !xor
}

/// Assembles segments that must be exactly one complete sequence, in order.
pub fn assemble_embedded_emf<'a>(
    segments: impl IntoIterator<Item = &'a EscapeRecord>,
    limits: &ParseLimits,
) -> Result<EmbeddedEmf, EmbeddedEmfError> {
    use EmbeddedEmfError as E;
    let mut first: Option<EmbeddedEmfSegment<'_>> = None;
    let mut bytes: Vec<u8> = Vec::new();
    let mut seen = 0u32;
    let mut complete = false;
    for record in segments {
        if complete {
            return Err(E::RecordCountMismatch);
        }
        let segment = record.embedded_emf_segment()?;
        let head = *first.get_or_insert(segment);
        if segment.record_count != head.record_count || segment.total_size != head.total_size {
            return Err(E::SequenceMismatch);
        }
        if usize::try_from(head.total_size).map_or(true, |t| t > limits.max_allocated_bytes) {
            return Err(E::LimitExceeded);
        }
        let consumed = bytes.len() as u64 + u64::from(segment.current_size);
        if u64::from(segment.total_size) - consumed != u64::from(segment.remaining_bytes) {
            return Err(E::RemainingMismatch);
        }
        bytes
            .try_reserve(segment.data.len())
            .map_err(|_| E::LimitExceeded)?;
        bytes.extend_from_slice(segment.data);
        seen += 1;
        complete = segment.remaining_bytes == 0;
        if complete != (seen == head.record_count) {
            return Err(E::RecordCountMismatch);
        }
    }
    let head = first.ok_or(E::Incomplete)?;
    if !complete {
        return Err(E::Incomplete);
    }
    Ok(EmbeddedEmf {
        version: head.version,
        checksum: head.checksum,
        checksum_valid: embedded_emf_checksum(&bytes) == head.checksum,
        bytes,
    })
}

impl Document {
    /// Groups consecutive 0x000F escapes into sequences and assembles each.
    /// A sequence ends when it completes, fails validation, or a different record
    /// follows. A new sequence starts at the next 0x000F escape.
    pub fn embedded_emf_sequences(&self, limits: &ParseLimits) -> Vec<EmbeddedEmfSequence> {
        let escapes: Vec<Option<&EscapeRecord>> = self
            .records()
            .iter()
            .map(|r| match r.typed() {
                Some(TypedRecord::Escape(e)) if e.escape_function == EMBEDDED_EMF_ESCAPE => Some(e),
                _ => None,
            })
            .collect();
        let mut result = Vec::new();
        let mut index = 0;
        while index < escapes.len() {
            if escapes[index].is_none() {
                index += 1;
                continue;
            }
            let mut end = index;
            let mut outcome = Err(EmbeddedEmfError::Incomplete);
            while end < escapes.len() {
                let Some(_) = escapes[end] else { break };
                end += 1;
                outcome =
                    assemble_embedded_emf(escapes[index..end].iter().flatten().copied(), limits);
                match outcome {
                    Err(EmbeddedEmfError::Incomplete) => {}
                    _ => break,
                }
            }
            result.push(EmbeddedEmfSequence {
                first_record: index,
                segment_count: end - index,
                emf: outcome,
            });
            index = end;
        }
        result
    }
}
