//! Unchanged-document serialization.

use crate::error::SerializeFailure;
use crate::model::Document;

/// Write the document back out. Header, records and trailing bytes are copied
/// in order from their original spans; nothing is normalized.
pub fn serialize(document: &Document) -> Result<Vec<u8>, SerializeFailure> {
    let total = document.source.len();
    let mut out = Vec::new();
    out.try_reserve_exact(total)
        .map_err(|_| SerializeFailure::AllocationFailed { bytes: total })?;

    out.extend_from_slice(document.header_bytes());
    let mut next = document.header_len;
    for record in document.records() {
        if record.offset() != next {
            return Err(SerializeFailure::Inconsistent { offset: next });
        }
        let bytes = document
            .record_bytes(record)
            .ok_or(SerializeFailure::Inconsistent { offset: next })?;
        out.extend_from_slice(bytes);
        next += bytes.len();
    }
    if next != document.tail_offset {
        return Err(SerializeFailure::Inconsistent { offset: next });
    }
    out.extend_from_slice(&document.source[next..]);
    Ok(out)
}
