//! Object table definitions and bounded continuation assembly (2.3.5.1).
use super::{Error, RecordData, Stream};
use crate::{
    limits::{try_vec_with_capacity, Budget},
    ParseFailure, ParseLimits,
};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ObjectFragment {
    pub total_size: Option<u32>,
    pub bytes: Vec<u8>,
}

/// One completed definition. Later definitions of the same ID replace it in the
/// playback table; this list retains *all* definitions in stream order.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ObjectDefinition {
    pub id: u8,
    pub object_type: u8,
    pub first_record: usize,
    pub last_record: usize,
    pub bytes: Vec<u8>,
}

/// Borrowed, allocation-free interpretation of an object's body. Float fields
/// retain their original IEEE bits; UTF-16 names retain unpaired surrogates.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ObjectBody<'a> {
    SolidBrush {
        version: u32,
        argb: u32,
    },
    HatchBrush {
        version: u32,
        style: u32,
        foreground: u32,
        background: u32,
    },
    Font {
        version: u32,
        em_size: u32,
        size_unit: u32,
        style: i32,
        reserved: u32,
        family_name_utf16le: &'a [u8],
        suffix: &'a [u8],
    },
    ImageAttributes {
        version: u32,
        reserved1: u32,
        wrap_mode: u32,
        clamp_argb: u32,
        object_clamp: i32,
        reserved2: u32,
    },
    Opaque {
        object_type: u8,
        bytes: &'a [u8],
    },
}
impl ObjectDefinition {
    pub fn body(&self) -> Result<ObjectBody<'_>, Error> {
        let b = &self.bytes;
        let invalid = || Error::InvalidObject {
            record_index: self.first_record,
            reason: "invalid object body length",
        };
        let word = |i: usize| u32::from_le_bytes(b[i..i + 4].try_into().unwrap());
        Ok(match self.object_type {
            1 => {
                if b.len() < 8 {
                    return Err(invalid());
                }
                match word(4) {
                    0 => {
                        if b.len() != 12 {
                            return Err(invalid());
                        }
                        ObjectBody::SolidBrush {
                            version: word(0),
                            argb: word(8),
                        }
                    }
                    1 => {
                        if b.len() != 20 {
                            return Err(invalid());
                        }
                        ObjectBody::HatchBrush {
                            version: word(0),
                            style: word(8),
                            foreground: word(12),
                            background: word(16),
                        }
                    }
                    _ => ObjectBody::Opaque {
                        object_type: self.object_type,
                        bytes: b,
                    },
                }
            }
            6 => {
                if b.len() < 24 {
                    return Err(invalid());
                }
                let length = (word(20) as usize)
                    .checked_mul(2)
                    .and_then(|n| n.checked_add(24))
                    .ok_or_else(invalid)?;
                if length > b.len() {
                    return Err(invalid());
                }
                ObjectBody::Font {
                    version: word(0),
                    em_size: word(4),
                    size_unit: word(8),
                    style: word(12) as i32,
                    reserved: word(16),
                    family_name_utf16le: &b[24..length],
                    suffix: &b[length..],
                }
            }
            8 => {
                if b.len() != 24 {
                    return Err(invalid());
                }
                ObjectBody::ImageAttributes {
                    version: word(0),
                    reserved1: word(4),
                    wrap_mode: word(8),
                    clamp_argb: word(12),
                    object_clamp: word(16) as i32,
                    reserved2: word(20),
                }
            }
            _ => ObjectBody::Opaque {
                object_type: self.object_type,
                bytes: b,
            },
        })
    }
}

/// Validate/visit chains without allocating their expanded bytes. The spec's
/// clear-C final chunk and Windows' C-set final chunk are both length-delimited.
pub(crate) fn visit_chains(
    stream: &Stream,
    budget: &mut Budget<'_>,
    mut visit: impl FnMut(usize, usize, usize, &mut Budget<'_>) -> Result<(), Error>,
) -> Result<(), Error> {
    let mut index = 0;
    while index < stream.records.len() {
        let first = index;
        let r = &stream.records[first];
        let RecordData::Object(fragment) = &r.data else {
            index += 1;
            continue;
        };
        if r.flags & 0xff > 63 {
            return Err(chain_error(first, "object ID exceeds 63"));
        }
        if (r.flags & 0x8000 != 0) != fragment.total_size.is_some() {
            return Err(chain_error(first, "object continuation flag/data mismatch"));
        }
        let total = fragment
            .total_size
            .map(|n| n as usize)
            .unwrap_or(fragment.bytes.len());
        budget.check_record_bytes(total)?;
        let mut accumulated = fragment.bytes.len();
        if accumulated > total {
            return Err(chain_error(first, "object exceeds TotalObjectSize"));
        }
        while accumulated < total {
            index += 1;
            let next = stream
                .records
                .get(index)
                .ok_or_else(|| chain_error(first, "unterminated object continuation"))?;
            let RecordData::Object(part) = &next.data else {
                return Err(chain_error(index, "object continuation interrupted"));
            };
            if next.flags & 0x7fff != r.flags & 0x7fff
                || part.total_size.is_some_and(|n| n as usize != total)
                || (next.flags & 0x8000 != 0) != part.total_size.is_some()
            {
                return Err(chain_error(
                    index,
                    "object continuation identity/size mismatch",
                ));
            }
            accumulated = accumulated
                .checked_add(part.bytes.len())
                .ok_or(ParseFailure::ArithmeticOverflow { offset: index })?;
            if accumulated > total || (part.total_size.is_none() && accumulated != total) {
                return Err(chain_error(index, "object continuation length mismatch"));
            }
        }
        visit(first, index, total, budget)?;
        index += 1;
    }
    Ok(())
}
fn chain_error(offset: usize, reason: &'static str) -> Error {
    Error::InvalidObject {
        record_index: offset,
        reason,
    }
}

fn check_stream(
    stream: &Stream,
    budget: &mut Budget<'_>,
    count_records: bool,
) -> Result<(), Error> {
    let mut input = 0usize;
    for r in &stream.records {
        let size = 12usize
            .checked_add(r.data.len())
            .and_then(|n| n.checked_add(r.padding.len()))
            .ok_or(ParseFailure::ArithmeticOverflow { offset: input })?;
        input = input
            .checked_add(size)
            .ok_or(ParseFailure::ArithmeticOverflow { offset: input })?;
        budget.check_input(input)?;
        budget.check_record_bytes(size)?;
        if count_records {
            budget.charge_record(size)?;
        } else {
            budget.charge_work(1 + (size as u64).div_ceil(16))?;
        }
    }
    Ok(())
}

impl Stream {
    /// Assemble definitions under an independent budget. No allocation is based
    /// solely on TotalObjectSize before all fragment lengths have been checked.
    pub fn object_definitions(&self, limits: &ParseLimits) -> Result<Vec<ObjectDefinition>, Error> {
        let mut budget = Budget::new(limits);
        check_stream(self, &mut budget, true)?;
        self.assemble_budget(&mut budget)
    }

    /// Assemble using the extraction budget; records are already framed, so only
    /// the additional scan work is charged (not the record count a second time).
    pub fn object_definitions_with_budget(
        &self,
        budget: &mut Budget<'_>,
    ) -> Result<Vec<ObjectDefinition>, Error> {
        check_stream(self, budget, false)?;
        self.assemble_budget(budget)
    }

    fn assemble_budget(&self, budget: &mut Budget<'_>) -> Result<Vec<ObjectDefinition>, Error> {
        let mut output = Vec::new();
        visit_chains(self, budget, |first, last, len, budget| {
            budget.charge_alloc(len)?;
            budget.charge_work((len as u64).div_ceil(16))?;
            let mut bytes = try_vec_with_capacity(len)?;
            for r in &self.records[first..=last] {
                if let RecordData::Object(p) = &r.data {
                    bytes.extend_from_slice(&p.bytes);
                }
            }
            budget.reserve_one(&mut output)?;
            let flags = self.records[first].flags;
            output.push(ObjectDefinition {
                id: flags as u8,
                object_type: ((flags >> 8) & 0x7f) as u8,
                first_record: first,
                last_record: last,
                bytes,
            });
            Ok(())
        })?;
        Ok(output)
    }
}

impl Stream {
    /// Atomically replace a logical object's bytes, preserving every fragment's
    /// size/flags/padding and every comment boundary. Length changes require an
    /// explicit stream record edit and explicit embedding segmentation policy.
    pub fn replace_object_bytes(
        &mut self,
        first_record: usize,
        bytes: &[u8],
        limits: &ParseLimits,
    ) -> Result<(), Error> {
        let mut budget = Budget::new(limits);
        budget.check_input(bytes.len())?;
        check_stream(self, &mut budget, true)?;
        let mut range = None;
        visit_chains(self, &mut budget, |first, last, len, _| {
            if first == first_record {
                range = Some((last, len));
            }
            Ok(())
        })?;
        let (last, len) =
            range.ok_or_else(|| chain_error(first_record, "no object definition at index"))?;
        if len != bytes.len() {
            return Err(chain_error(
                first_record,
                "replacement changes logical object length",
            ));
        }
        let mut replacements = Vec::new();
        let mut offset = 0;
        for record in &self.records[first_record..=last] {
            budget.charge_work((record.data.len() as u64).div_ceil(16))?;
            let RecordData::Object(fragment) = &record.data else {
                unreachable!()
            };
            budget.charge_alloc(fragment.bytes.len())?;
            let mut part = try_vec_with_capacity(fragment.bytes.len())?;
            part.extend_from_slice(&bytes[offset..offset + fragment.bytes.len()]);
            offset += fragment.bytes.len();
            budget.reserve_one(&mut replacements)?;
            replacements.push(part);
        }
        for (record, bytes) in self.records[first_record..=last]
            .iter_mut()
            .zip(replacements)
        {
            if let RecordData::Object(fragment) = &mut record.data {
                fragment.bytes = bytes;
            }
        }
        Ok(())
    }
}
