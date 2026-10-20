//! Pattern brush headers and bounded pattern bytes.

use super::DecodeError;
use crate::limits::{try_vec_with_capacity, Budget};
use crate::{EditFailure, ParseFailure, ParseLimits};

pub const META_CREATEPATTERNBRUSH: u16 = 0x01f9;
pub const META_DIBCREATEPATTERNBRUSH: u16 = 0x0142;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PatternBrush {
    pub function: u16,
    pub bitmap_type: i16,
    pub width: i16,
    pub height: i16,
    pub width_bytes: i16,
    pub planes: u8,
    pub bits_pixel: u8,
    /// Ignored pointer bytes, retained verbatim.
    pub bits: [u8; 4],
    pub reserved: [u8; 18],
    pub pattern: Vec<u8>,
}

/// Raw target bytes remain authoritative; a packed DIB view is available on demand.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DibPatternBrush {
    pub function: u16,
    pub style: u16,
    pub color_usage: u16,
    pub target: Vec<u8>,
}

impl DibPatternBrush {
    /// Unsupported or malformed targets return `None`; resource failures remain errors.
    pub fn target_dib(
        &self,
        limits: &ParseLimits,
    ) -> Result<Option<super::dib::Dib>, ParseFailure> {
        super::dib::Dib::parse(&self.target, self.effective_color_usage(), limits)
    }

    /// Encode a DIB before replacing the raw target, preserving the brush headers.
    pub fn replace_target_dib(&mut self, dib: &super::dib::Dib) -> Result<(), EditFailure> {
        use super::dib::ColorTable;
        let compatible = matches!(
            (self.effective_color_usage(), &dib.colors),
            (0, ColorTable::RgbTriples(_) | ColorTable::RgbQuads(_))
                | (1, ColorTable::PaletteIndices(_))
                | (2, ColorTable::None)
        );
        if !compatible {
            return Err(EditFailure::RecordLayout { index: 0 });
        }
        let target = dib.encode()?;
        if target.len() % 2 != 0 {
            return Err(EditFailure::RecordLayout { index: 0 });
        }
        self.target = target;
        Ok(())
    }

    /// BS_PATTERN ignores the stored color usage and always uses RGB colors.
    pub fn effective_color_usage(&self) -> u16 {
        if self.style == 3 {
            0
        } else {
            self.color_usage
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum BrushRecord {
    CreatePatternBrush(PatternBrush),
    DibCreatePatternBrush(DibPatternBrush),
}

fn word(body: &[u8], offset: usize) -> Result<u16, DecodeError> {
    let bytes = body.get(offset..offset + 2).ok_or(DecodeError::Malformed)?;
    Ok(u16::from_le_bytes([bytes[0], bytes[1]]))
}

fn pattern_len(value: &PatternBrush) -> Option<usize> {
    if value.width <= 0 || value.height <= 0 || value.planes != 1 || value.bits_pixel == 0 {
        return None;
    }
    usize::try_from(value.width)
        .ok()?
        .checked_mul(usize::from(value.bits_pixel))?
        .checked_add(15)?
        .checked_div(16)?
        .checked_mul(2)?
        .checked_mul(usize::try_from(value.height).ok()?)
}

fn copy(bytes: &[u8], budget: &mut Budget<'_>) -> Result<Vec<u8>, DecodeError> {
    budget.charge_work((bytes.len() as u64).div_ceil(16))?;
    budget.charge_alloc(bytes.len())?;
    let mut output = try_vec_with_capacity(bytes.len())?;
    output.extend_from_slice(bytes);
    Ok(output)
}

pub(crate) fn decode(
    function: u16,
    body: &[u8],
    budget: &mut Budget<'_>,
) -> Result<Option<(BrushRecord, usize)>, DecodeError> {
    match function & 0xff {
        0xf9 => {
            let header = body.get(..32).ok_or(DecodeError::Malformed)?;
            let mut value = PatternBrush {
                function,
                bitmap_type: word(body, 0)? as i16,
                width: word(body, 2)? as i16,
                height: word(body, 4)? as i16,
                width_bytes: word(body, 6)? as i16,
                planes: header[8],
                bits_pixel: header[9],
                bits: header[10..14]
                    .try_into()
                    .map_err(|_| DecodeError::Malformed)?,
                reserved: header[14..32]
                    .try_into()
                    .map_err(|_| DecodeError::Malformed)?,
                pattern: Vec::new(),
            };
            let end = 32usize
                .checked_add(pattern_len(&value).ok_or(DecodeError::Malformed)?)
                .ok_or(DecodeError::Malformed)?;
            value.pattern = copy(body.get(32..end).ok_or(DecodeError::Malformed)?, budget)?;
            Ok(Some((BrushRecord::CreatePatternBrush(value), end)))
        }
        0x42 => {
            let style = word(body, 0)?;
            let color_usage = word(body, 2)?;
            if style != 3 && color_usage > 2 {
                return Err(DecodeError::Malformed);
            }
            let target = body
                .get(4..)
                .filter(|b| !b.is_empty() && b.len() % 2 == 0)
                .ok_or(DecodeError::Malformed)?;
            Ok(Some((
                BrushRecord::DibCreatePatternBrush(DibPatternBrush {
                    function,
                    style,
                    color_usage,
                    target: copy(target, budget)?,
                }),
                body.len(),
            )))
        }
        _ => Ok(None),
    }
}

pub(crate) fn encode(record: &BrushRecord) -> Result<(u16, Vec<u8>), EditFailure> {
    let invalid = || EditFailure::RecordLayout { index: 0 };
    let mut header = [0u8; 32];
    let (function, header_len, data) = match record {
        BrushRecord::CreatePatternBrush(value) => {
            if value.function & 0xff != 0xf9 || pattern_len(value) != Some(value.pattern.len()) {
                return Err(invalid());
            }
            for (offset, word) in [
                value.bitmap_type,
                value.width,
                value.height,
                value.width_bytes,
            ]
            .into_iter()
            .enumerate()
            {
                header[offset * 2..offset * 2 + 2].copy_from_slice(&word.to_le_bytes());
            }
            header[8] = value.planes;
            header[9] = value.bits_pixel;
            header[10..14].copy_from_slice(&value.bits);
            header[14..32].copy_from_slice(&value.reserved);
            (value.function, 32usize, value.pattern.as_slice())
        }
        BrushRecord::DibCreatePatternBrush(value) => {
            if value.function & 0xff != 0x42
                || (value.style != 3 && value.color_usage > 2)
                || value.target.is_empty()
                || value.target.len() % 2 != 0
            {
                return Err(invalid());
            }
            header[..2].copy_from_slice(&value.style.to_le_bytes());
            header[2..4].copy_from_slice(&value.color_usage.to_le_bytes());
            (value.function, 4usize, value.target.as_slice())
        }
    };
    let size = header_len
        .checked_add(data.len())
        .ok_or(EditFailure::SizeOverflow)?;
    let mut output = Vec::new();
    output
        .try_reserve_exact(size)
        .map_err(|_| EditFailure::SizeOverflow)?;
    output.extend_from_slice(&header[..header_len]);
    output.extend_from_slice(data);
    Ok((function, output))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{LimitKind, ParseFailure, ParseLimits};

    #[test]
    fn copying_patterns_charges_allocation_and_work_before_copy() {
        let mut pattern = [0; 64];
        pattern[2] = 16;
        pattern[4] = 16;
        pattern[6] = 2;
        pattern[8] = 1;
        pattern[9] = 1;
        let dib = [0u8; 64];
        for (function, body, size) in [(0x01f9, &pattern[..], 32), (0x0142, &dib[..], 60)] {
            for (allocated, work, expected) in [
                (size - 1, 100, LimitKind::AllocatedBytes),
                (100, 0, LimitKind::WorkUnits),
            ] {
                let limits = ParseLimits {
                    max_allocated_bytes: allocated,
                    max_work_units: work,
                    ..ParseLimits::default()
                };
                assert!(matches!(decode(function, body, &mut Budget::new(&limits)),
                    Err(DecodeError::Resource(ParseFailure::LimitExceeded { kind, .. })) if kind == expected));
            }
        }
        let limits = ParseLimits {
            max_allocated_bytes: 0,
            max_work_units: 0,
            ..ParseLimits::default()
        };
        assert!(matches!(
            decode(0xffff, &pattern, &mut Budget::new(&limits)),
            Ok(None)
        ));
    }
}
