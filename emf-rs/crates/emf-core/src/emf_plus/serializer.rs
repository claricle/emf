use super::Stream;
use crate::{LimitKind, SerializeFailure, SerializeLimits};

pub fn serialize(stream: &Stream) -> Result<Vec<u8>, SerializeFailure> {
    serialize_with_limits(stream, &SerializeLimits::default())
}

pub fn serialize_with_limits(
    stream: &Stream,
    limits: &SerializeLimits,
) -> Result<Vec<u8>, SerializeFailure> {
    let (total, _) = plan(stream, limits, false)?;
    let mut out = Vec::new();
    out.try_reserve_exact(total)
        .map_err(|_| SerializeFailure::AllocationFailed { bytes: total })?;
    for r in &stream.records {
        let size = 12 + r.data.len() + r.padding.len();
        out.extend_from_slice(&r.record_type.to_le_bytes());
        out.extend_from_slice(&r.flags.to_le_bytes());
        out.extend_from_slice(&(size as u32).to_le_bytes());
        out.extend_from_slice(&(r.data.len() as u32).to_le_bytes());
        r.data.write(&mut out);
        out.extend_from_slice(&r.padding);
    }
    Ok(out)
}

/// Serialize into the original comment segmentation. Size-changing edits are
/// rejected: embedding code must choose explicit new segment boundaries.
pub fn serialize_segments(
    stream: &Stream,
    limits: &SerializeLimits,
) -> Result<Vec<Vec<u8>>, SerializeFailure> {
    let (total, _) = plan(stream, limits, true)?;
    let expected = stream.segment_lengths.iter().try_fold(0usize, |n, len| {
        n.checked_add(*len).ok_or(SerializeFailure::SizeOverflow)
    })?;
    if expected != total {
        return Err(SerializeFailure::Inconsistent { offset: total });
    }
    let bytes = serialize_with_limits(stream, limits)?;
    let mut out = Vec::new();
    out.try_reserve_exact(stream.segment_lengths.len())
        .map_err(|_| SerializeFailure::AllocationFailed {
            bytes: stream
                .segment_lengths
                .len()
                .saturating_mul(std::mem::size_of::<Vec<u8>>()),
        })?;
    let mut offset = 0;
    for len in &stream.segment_lengths {
        let mut segment = Vec::new();
        segment
            .try_reserve_exact(*len)
            .map_err(|_| SerializeFailure::AllocationFailed { bytes: *len })?;
        segment.extend_from_slice(&bytes[offset..offset + len]);
        out.push(segment);
        offset += len;
    }
    Ok(out)
}
fn check_limits(total: usize, work: u64, limits: &SerializeLimits) -> Result<(), SerializeFailure> {
    for (kind, requested, limit) in [
        (
            LimitKind::OutputBytes,
            total as u64,
            limits.max_output_bytes as u64,
        ),
        (LimitKind::WorkUnits, work, limits.max_work_units),
    ] {
        if requested > limit {
            return Err(SerializeFailure::LimitExceeded {
                kind,
                requested,
                limit,
            });
        }
    }
    Ok(())
}

fn plan(
    stream: &Stream,
    limits: &SerializeLimits,
    segmented: bool,
) -> Result<(usize, u64), SerializeFailure> {
    let mut total = 0usize;
    let mut work = 0u64;
    for r in &stream.records {
        work = work
            .checked_add(r.data.element_work())
            .ok_or(SerializeFailure::SizeOverflow)?;
        check_limits(total, work, limits)?;
        r.validate(total)
            .map_err(|_| SerializeFailure::Inconsistent { offset: total })?;
        let size = 12usize
            .checked_add(r.data.len())
            .and_then(|n| n.checked_add(r.padding.len()))
            .ok_or(SerializeFailure::SizeOverflow)?;
        if size % 4 != 0 || size > u32::MAX as usize {
            return Err(SerializeFailure::Inconsistent { offset: total });
        }
        total = total
            .checked_add(size)
            .ok_or(SerializeFailure::SizeOverflow)?;
        work = work
            .checked_add(2 + (size as u64).div_ceil(16))
            .ok_or(SerializeFailure::SizeOverflow)?;
    }
    if segmented {
        work = work
            .checked_add((total as u64).div_ceil(16))
            .and_then(|n| n.checked_add(stream.segment_lengths.len() as u64))
            .ok_or(SerializeFailure::SizeOverflow)?;
    }
    check_limits(total, work, limits)?;
    let parse_limits = crate::ParseLimits {
        max_record_bytes: usize::MAX,
        ..crate::ParseLimits::default()
    };
    let mut budget = crate::limits::Budget::new(&parse_limits);
    super::objects::visit_chains(stream, &mut budget, |_, _, _, _| Ok(()))
        .map_err(|_| SerializeFailure::Inconsistent { offset: 0 })?;
    Ok((total, work))
}
