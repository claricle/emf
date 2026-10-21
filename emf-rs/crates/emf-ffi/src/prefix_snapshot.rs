//! Raw records that keep their Ruby wire class through a fixed prefix.
//!
//! The core leaves a bitmap or gradient record `Raw` when its body cannot be
//! placed (descriptors outside the record, undefined mode, overrunning counts).
//! Ruby still reads such a record as typed, with the unread bytes in `body`, so
//! the snapshot exposes the prefix in the family's usual payload layout.
use super::{bitmap_snapshot, u32_field, u64_field};
use emf_core::{Document, RecordData, RecordSpan};

pub(super) struct Prefixed {
    pub(super) family: u32,
    pub(super) payload: Vec<u8>,
}

const GRADIENT_FAMILY: u32 = 93;
const GRADIENT_TYPE: u32 = 118;
const RECORD_HEAD: usize = 8;

pub(super) fn of(document: &Document, record: &RecordSpan) -> Option<Prefixed> {
    if record.data() != &RecordData::Raw {
        return None;
    }
    let kind = record.record_type();
    let prefix = emf_core::opaque_prefix_len(kind)?;
    let bytes = document.record_bytes(record)?.get(RECORD_HEAD..)?;
    let bytes = bytes.get(..prefix)?;
    if kind == GRADIENT_TYPE {
        // Wire order is bounds, nVer, nTri, ulMode; the snapshot widens the counts.
        let word = |at: usize| {
            u32::from_le_bytes([bytes[at], bytes[at + 1], bytes[at + 2], bytes[at + 3]])
        };
        let mut payload = Vec::with_capacity(36);
        payload.extend_from_slice(&bytes[..16]);
        u32_field(&mut payload, word(24));
        u64_field(&mut payload, u64::from(word(16)));
        u64_field(&mut payload, u64::from(word(20)));
        return Some(Prefixed {
            family: GRADIENT_FAMILY,
            payload,
        });
    }
    Some(Prefixed {
        family: bitmap_snapshot::family_of(kind),
        payload: bytes.to_vec(),
    })
}
