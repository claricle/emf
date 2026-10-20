//! Escape transport framing. Subtype payloads remain opaque and are never executed.

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
