use super::{
    records::{decode_fixed, fixed_len},
    Error, Record, RecordData, Stream,
};
use crate::{
    limits::{try_vec_with_capacity, Budget},
    ParseFailure, ParseLimits,
};

/// Parse a logical EMF+ stream. This does not make EMF+ a top-level EMF format.
pub fn parse(bytes: &[u8], limits: &ParseLimits) -> Result<Stream, Error> {
    parse_segments(&[bytes], limits)
}

/// Parse ordered EMF+ comment payloads, excluding their four-byte signatures.
/// Empty segments and boundaries inside records are retained.
pub fn parse_segments(segments: &[&[u8]], limits: &ParseLimits) -> Result<Stream, Error> {
    let mut budget = Budget::new(limits);
    parse_segments_budget(segments, &mut budget)
}

pub(crate) fn parse_segments_budget(
    segments: &[&[u8]],
    budget: &mut Budget<'_>,
) -> Result<Stream, Error> {
    let len = segments.iter().try_fold(0usize, |n, b| {
        n.checked_add(b.len())
            .ok_or(ParseFailure::ArithmeticOverflow { offset: n })
    })?;
    budget.check_input(len)?;
    budget.charge_work(segments.len() as u64)?;
    budget.charge_alloc(
        segments
            .len()
            .checked_mul(std::mem::size_of::<usize>())
            .ok_or(ParseFailure::ArithmeticOverflow { offset: 0 })?,
    )?;
    let mut lengths = try_vec_with_capacity(segments.len())?;
    budget.charge_alloc(len)?;
    budget.charge_work((len as u64).div_ceil(16))?;
    let mut bytes = try_vec_with_capacity(len)?;
    for b in segments {
        lengths.push(b.len());
        bytes.extend_from_slice(b);
    }
    let mut records = Vec::new();
    let mut offset = 0;
    while offset < bytes.len() {
        let available = bytes.len() - offset;
        if available < 12 {
            return Err(ParseFailure::Truncated {
                offset,
                needed: 12,
                available,
            }
            .into());
        }
        let b = &bytes[offset..];
        let kind = u16::from_le_bytes([b[0], b[1]]);
        let flags = u16::from_le_bytes([b[2], b[3]]);
        let size = u32::from_le_bytes(b[4..8].try_into().unwrap()) as usize;
        let data_len = u32::from_le_bytes(b[8..12].try_into().unwrap()) as usize;
        if size < 12 || size % 4 != 0 || data_len > size - 12 {
            return Err(Error::InvalidRecord {
                offset,
                reason: "invalid Size/DataSize",
            });
        }
        budget.check_record_bytes(size)?;
        budget.charge_record(size)?;
        if size > available {
            return Err(ParseFailure::Truncated {
                offset,
                needed: size,
                available,
            }
            .into());
        }
        let data_bytes = &b[12..12 + data_len];
        let data = if let Some(expected) = fixed_len(kind) {
            if data_len != expected {
                return Err(Error::InvalidRecord {
                    offset,
                    reason: "invalid fixed record DataSize",
                });
            }
            decode_fixed(kind, data_bytes)
        } else if super::drawing::supported(kind) {
            RecordData::Drawing(super::drawing::decode(
                kind, flags, data_bytes, offset, budget,
            )?)
        } else if matches!(kind, 0x401c | 0x4036) {
            RecordData::Text(super::text::decode(kind, data_bytes, offset, budget)?)
        } else if kind == 0x403a && flags & 0x8000 == 0 {
            RecordData::TSClip(super::tsclip::decode(data_bytes, flags, offset, budget)?)
        } else if kind == 0x4039 {
            RecordData::TSGraphics(super::tsgraphics::decode(
                data_bytes, flags, offset, budget,
            )?)
        } else if kind == 0x4038 {
            RecordData::Effect(super::effects::decode(data_bytes, offset, budget)?)
        } else if kind == 0x4008 {
            let (total_size, object_bytes) = if flags & 0x8000 != 0 {
                if data_bytes.len() < 4 {
                    return Err(Error::InvalidRecord {
                        offset,
                        reason: "missing TotalObjectSize",
                    });
                }
                (
                    Some(u32::from_le_bytes(data_bytes[..4].try_into().unwrap())),
                    &data_bytes[4..],
                )
            } else {
                (None, data_bytes)
            };
            RecordData::Object(super::ObjectFragment {
                total_size,
                bytes: copy(object_bytes, budget)?,
            })
        } else {
            RecordData::Opaque(copy(data_bytes, budget)?)
        };
        let padding = copy(&b[12 + data_len..size], budget)?;
        budget.reserve_one(&mut records)?;
        records.push(Record {
            record_type: kind,
            flags,
            data,
            padding,
        });
        offset += size;
    }
    let stream = Stream {
        records,
        segment_lengths: lengths,
    };
    super::objects::visit_chains(&stream, budget, |_, _, _, _| Ok(()))?;
    Ok(stream)
}
fn copy(bytes: &[u8], budget: &mut Budget<'_>) -> Result<Vec<u8>, ParseFailure> {
    budget.charge_alloc(bytes.len())?;
    let mut result = try_vec_with_capacity(bytes.len())?;
    result.extend_from_slice(bytes);
    Ok(result)
}
