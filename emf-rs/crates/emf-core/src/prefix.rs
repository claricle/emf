//! Records whose Ruby wire class is a fixed prefix plus an opaque body.
//!
//! When the semantic decoder cannot place a body (descriptors outside the record,
//! undefined modes, overrunning counts), the record stays `Raw` and byte-exact.
//! It is not malformed while its fixed prefix is present: consumers read the
//! prefix and defer body bounds to their accessors.
use crate::bitmap;

/// Bytes after the 8-byte record head that form the fixed prefix of `record_type`.
pub fn opaque_prefix_len(record_type: u32) -> Option<usize> {
    match record_type {
        118 => Some(GRADIENT_PREFIX),
        _ => bitmap::fixed_payload_len(record_type),
    }
}

pub(crate) const GRADIENT_PREFIX: usize = 28;
