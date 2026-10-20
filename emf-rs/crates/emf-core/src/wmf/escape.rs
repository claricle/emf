//! Escape transport framing and fixed payload views. Escape data is never executed.

use super::DecodeError;
use crate::limits::{try_vec_with_capacity, Budget};
use crate::EditFailure;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct EscapeRecord {
    pub function: u16,
    pub escape_function: u16,
    pub data: Vec<u8>,
    /// Odd byte payload alignment is retained verbatim.
    pub padding: Option<u8>,
}

/// Escape subtypes whose WMF payload is explicitly empty.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[repr(u16)]
pub enum EmptyEscape {
    AbortDoc = 0x0002,
    BeginPath = 0x1000,
    CloseChannel = 0x1010,
    DownloadFace = 0x0202,
    DownloadHeader = 0x100f,
    EndPath = 0x1002,
    EndDoc = 0x000b,
    ExtTextOut = 0x0200,
    GetDeviceUnits = 0x002a,
    GetExtendedTextMetrics = 0x0100,
    GetFaceName = 0x0201,
    GetPairKernTable = 0x0102,
    GetPhysPageSize = 0x000c,
    GetPrintingOffset = 0x000d,
    GetScalingFactor = 0x000e,
    MetafileDriver = 0x0801,
    NewFrame = 0x0001,
    NextBand = 0x0003,
    PostScriptIgnore = 0x0026,
    OpenChannel = 0x100e,
    QueryDibSupport = 0x0c01,
}

impl EmptyEscape {
    fn from_code(code: u16) -> Option<Self> {
        Some(match code {
            0x0002 => Self::AbortDoc,
            0x1000 => Self::BeginPath,
            0x1010 => Self::CloseChannel,
            0x0202 => Self::DownloadFace,
            0x100f => Self::DownloadHeader,
            0x1002 => Self::EndPath,
            0x000b => Self::EndDoc,
            0x0200 => Self::ExtTextOut,
            0x002a => Self::GetDeviceUnits,
            0x0100 => Self::GetExtendedTextMetrics,
            0x0201 => Self::GetFaceName,
            0x0102 => Self::GetPairKernTable,
            0x000c => Self::GetPhysPageSize,
            0x000d => Self::GetPrintingOffset,
            0x000e => Self::GetScalingFactor,
            0x0801 => Self::MetafileDriver,
            0x0001 => Self::NewFrame,
            0x0003 => Self::NextBand,
            0x0026 => Self::PostScriptIgnore,
            0x100e => Self::OpenChannel,
            0x0c01 => Self::QueryDibSupport,
            _ => return None,
        })
    }
}

/// Allocation-free values for the empty and fixed-size WMF escape payloads.
/// Numeric controls remain raw, including private values and reserved fields.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum EscapePayload {
    Empty(EmptyEscape),
    /// Four payload bytes, independent of the enclosing record's size or suffix.
    ClipToPath {
        clip_function: u16,
        reserved1: u16,
    },
    /// Position and size are signed PointL components in x, y order.
    DrawPatternRect {
        position: [i32; 2],
        size: [i32; 2],
        style: u16,
        pattern: u16,
    },
    EpsPrinting {
        set_eps_printing: u16,
    },
    GetPsFeatureSetting {
        feature: i32,
    },
    QueryEscSupport {
        query: u16,
    },
    SetCopyCount {
        copy_count: u16,
    },
    SetLineCap {
        cap: i32,
    },
    SetLineJoin {
        join: i32,
    },
    SetMiterLimit {
        miter_limit: i32,
    },
}

impl EscapeRecord {
    /// Reads only the declared payload, without allocating or interpreting a driver call.
    /// Unknown subtypes, unexpected sizes, and invalid transport framing return `None`.
    pub fn typed_payload(&self) -> Option<EscapePayload> {
        if self.function & 0xff != 0x26 || self.padding.is_some() {
            return None;
        }
        if self.data.is_empty() {
            return EmptyEscape::from_code(self.escape_function).map(EscapePayload::Empty);
        }
        let data = self.data.as_slice();
        let word = |offset| {
            Some(u16::from_le_bytes(
                data.get(offset..offset + 2)?.try_into().ok()?,
            ))
        };
        let long = |offset| {
            Some(i32::from_le_bytes(
                data.get(offset..offset + 4)?.try_into().ok()?,
            ))
        };
        Some(match (self.escape_function, data.len()) {
            (0x1001, 4) => EscapePayload::ClipToPath {
                clip_function: word(0)?,
                reserved1: word(2)?,
            },
            (0x0019, 20) => EscapePayload::DrawPatternRect {
                position: [long(0)?, long(4)?],
                size: [long(8)?, long(12)?],
                style: word(16)?,
                pattern: word(18)?,
            },
            (0x0021, 2) => EscapePayload::EpsPrinting {
                set_eps_printing: word(0)?,
            },
            (0x1019, 4) => EscapePayload::GetPsFeatureSetting { feature: long(0)? },
            (0x0008, 2) => EscapePayload::QueryEscSupport { query: word(0)? },
            (0x0011, 2) => EscapePayload::SetCopyCount {
                copy_count: word(0)?,
            },
            (0x0015, 4) => EscapePayload::SetLineCap { cap: long(0)? },
            (0x0016, 4) => EscapePayload::SetLineJoin { join: long(0)? },
            (0x0017, 4) => EscapePayload::SetMiterLimit {
                miter_limit: long(0)?,
            },
            _ => return None,
        })
    }

    /// Replaces the subtype and payload atomically, deriving the byte count at encoding.
    /// All supported payloads are even-sized, so old alignment bytes are discarded.
    /// The enclosing document retains any record suffix when replacing this record.
    pub fn replace_payload(&mut self, payload: EscapePayload) -> Result<(), EditFailure> {
        if self.function & 0xff != 0x26 {
            return Err(EditFailure::RecordLayout { index: 0 });
        }
        let mut bytes = [0u8; 20];
        let (code, len) = match payload {
            EscapePayload::Empty(kind) => (kind as u16, 0),
            EscapePayload::ClipToPath {
                clip_function,
                reserved1,
            } => {
                bytes[..2].copy_from_slice(&clip_function.to_le_bytes());
                bytes[2..4].copy_from_slice(&reserved1.to_le_bytes());
                (0x1001, 4)
            }
            EscapePayload::DrawPatternRect {
                position,
                size,
                style,
                pattern,
            } => {
                for (chunk, value) in bytes[..16]
                    .chunks_exact_mut(4)
                    .zip(position.into_iter().chain(size))
                {
                    chunk.copy_from_slice(&value.to_le_bytes());
                }
                bytes[16..18].copy_from_slice(&style.to_le_bytes());
                bytes[18..20].copy_from_slice(&pattern.to_le_bytes());
                (0x0019, 20)
            }
            EscapePayload::EpsPrinting { set_eps_printing } => {
                bytes[..2].copy_from_slice(&set_eps_printing.to_le_bytes());
                (0x0021, 2)
            }
            EscapePayload::QueryEscSupport { query } => {
                bytes[..2].copy_from_slice(&query.to_le_bytes());
                (0x0008, 2)
            }
            EscapePayload::SetCopyCount { copy_count } => {
                bytes[..2].copy_from_slice(&copy_count.to_le_bytes());
                (0x0011, 2)
            }
            EscapePayload::GetPsFeatureSetting { feature } => {
                bytes[..4].copy_from_slice(&feature.to_le_bytes());
                (0x1019, 4)
            }
            EscapePayload::SetLineCap { cap } => {
                bytes[..4].copy_from_slice(&cap.to_le_bytes());
                (0x0015, 4)
            }
            EscapePayload::SetLineJoin { join } => {
                bytes[..4].copy_from_slice(&join.to_le_bytes());
                (0x0016, 4)
            }
            EscapePayload::SetMiterLimit { miter_limit } => {
                bytes[..4].copy_from_slice(&miter_limit.to_le_bytes());
                (0x0017, 4)
            }
        };
        let mut data = Vec::new();
        data.try_reserve_exact(len)
            .map_err(|_| EditFailure::SizeOverflow)?;
        data.extend_from_slice(&bytes[..len]);
        self.escape_function = code;
        self.data = data;
        self.padding = None;
        Ok(())
    }
}

pub(crate) fn decode(
    function: u16,
    body: &[u8],
    budget: &mut Budget<'_>,
) -> Result<Option<(EscapeRecord, usize)>, DecodeError> {
    if function & 0xff != 0x26 {
        return Ok(None);
    }
    let head = body.get(..4).ok_or(DecodeError::Malformed)?;
    let count = usize::from(u16::from_le_bytes([head[2], head[3]]));
    let end = 4 + count;
    let data = body.get(4..end).ok_or(DecodeError::Malformed)?;
    let padding = if count % 2 != 0 {
        Some(*body.get(end).ok_or(DecodeError::Malformed)?)
    } else {
        None
    };
    budget.charge_work((count as u64).div_ceil(16))?;
    budget.charge_alloc(count)?;
    let mut owned = try_vec_with_capacity(count)?;
    owned.extend_from_slice(data);
    Ok(Some((
        EscapeRecord {
            function,
            escape_function: u16::from_le_bytes([head[0], head[1]]),
            data: owned,
            padding,
        },
        end + usize::from(padding.is_some()),
    )))
}

pub(crate) fn encode(value: &EscapeRecord) -> Result<(u16, Vec<u8>), EditFailure> {
    if value.function & 0xff != 0x26 || value.padding.is_some() != (value.data.len() % 2 != 0) {
        return Err(EditFailure::RecordLayout { index: 0 });
    }
    let count = u16::try_from(value.data.len()).map_err(|_| EditFailure::SizeOverflow)?;
    let mut body = Vec::new();
    body.try_reserve_exact(4 + value.data.len() + usize::from(value.padding.is_some()))
        .map_err(|_| EditFailure::SizeOverflow)?;
    body.extend_from_slice(&value.escape_function.to_le_bytes());
    body.extend_from_slice(&count.to_le_bytes());
    body.extend_from_slice(&value.data);
    body.extend(value.padding);
    Ok((value.function, body))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{LimitKind, ParseFailure, ParseLimits};

    #[test]
    fn copied_escape_bytes_share_limits() {
        for (allocation, work, kind) in [
            (2, 1, LimitKind::AllocatedBytes),
            (3, 0, LimitKind::WorkUnits),
        ] {
            let limits = ParseLimits {
                max_allocated_bytes: allocation,
                max_work_units: work,
                ..ParseLimits::default()
            };
            assert!(
                matches!(decode(0x626, &[0x13, 0, 3, 0, 1, 2, 3, 0], &mut Budget::new(&limits)), Err(DecodeError::Resource(ParseFailure::LimitExceeded { kind: found, .. })) if found == kind)
            );
        }
    }
}
