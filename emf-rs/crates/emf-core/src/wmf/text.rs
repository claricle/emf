//! WMF text bytes and signed logical coordinates, without codepage interpretation.

use super::DecodeError;
use crate::limits::{try_vec_with_capacity, Budget};
use crate::EditFailure;

pub const META_TEXTOUT: u16 = 0x0521;
pub const META_EXTTEXTOUT: u16 = 0x0a32;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct TextRectangle {
    pub left: i16,
    pub top: i16,
    pub right: i16,
    pub bottom: i16,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum TextRecord {
    TextOut {
        function: u16,
        text: Vec<u8>,
        /// Word alignment and any additional string-field padding before Y/X.
        padding: Vec<u8>,
        x: i16,
        y: i16,
    },
    ExtTextOut {
        function: u16,
        text: Vec<u8>,
        /// Empty for even text lengths, exactly one byte for odd lengths.
        padding: Vec<u8>,
        x: i16,
        y: i16,
        options: u16,
        rectangle: Option<TextRectangle>,
        dx: Option<Vec<i16>>,
    },
}

fn word(body: &[u8], offset: usize) -> Result<i16, DecodeError> {
    let bytes = body.get(offset..offset + 2).ok_or(DecodeError::Malformed)?;
    Ok(i16::from_le_bytes([bytes[0], bytes[1]]))
}

fn copy(bytes: &[u8], budget: &mut Budget<'_>) -> Result<Vec<u8>, DecodeError> {
    budget.charge_alloc(bytes.len())?;
    let mut output = try_vec_with_capacity(bytes.len())?;
    output.extend_from_slice(bytes);
    Ok(output)
}

pub(crate) fn decode(
    function: u16,
    body: &[u8],
    budget: &mut Budget<'_>,
) -> Result<Option<(TextRecord, usize)>, DecodeError> {
    let extended = match function & 0xff {
        0x21 => false,
        0x32 => true,
        _ => return Ok(None),
    };
    let count = word(body, if extended { 4 } else { 0 })?;
    if count < 0 {
        return Err(DecodeError::Malformed);
    }
    let count = count as usize;
    let options = if extended { word(body, 6)? as u16 } else { 0 };
    let start = if extended {
        if options & 6 != 0 {
            16
        } else {
            8
        }
    } else {
        2
    };
    let text_end = start + count;
    let aligned_end = text_end + count % 2;
    if body.len() < aligned_end + if extended { 0 } else { 4 } {
        return Err(DecodeError::Malformed);
    }
    let rectangle = if extended && options & 6 != 0 {
        Some(TextRectangle {
            left: word(body, 8)?,
            top: word(body, 10)?,
            right: word(body, 12)?,
            bottom: word(body, 14)?,
        })
    } else {
        None
    };
    let has_dx = extended && count > 0 && body.len() > aligned_end;
    let consumed = if has_dx {
        aligned_end + count * 2
    } else {
        aligned_end
    };
    if extended && body.len() < consumed {
        return Err(DecodeError::Malformed);
    }
    budget.charge_work((count as u64).div_ceil(16) + if has_dx { count as u64 } else { 0 })?;
    let padding_end = if extended {
        aligned_end
    } else {
        body.len() - 4
    };
    budget.charge_work(((padding_end - text_end) as u64).div_ceil(16))?;
    let text = copy(&body[start..text_end], budget)?;
    let padding = copy(&body[text_end..padding_end], budget)?;
    if !extended {
        return Ok(Some((
            TextRecord::TextOut {
                function,
                text,
                padding,
                y: word(body, body.len() - 4)?,
                x: word(body, body.len() - 2)?,
            },
            body.len(),
        )));
    }
    let dx = if has_dx {
        budget.charge_alloc(count * std::mem::size_of::<i16>())?;
        let mut values = try_vec_with_capacity(count)?;
        for offset in (aligned_end..consumed).step_by(2) {
            values.push(word(body, offset)?);
        }
        Some(values)
    } else {
        None
    };
    Ok(Some((
        TextRecord::ExtTextOut {
            function,
            text,
            padding,
            x: word(body, 2)?,
            y: word(body, 0)?,
            options,
            rectangle,
            dx,
        },
        consumed,
    )))
}

pub(crate) fn encode(record: &TextRecord) -> Result<(u16, Vec<u8>), EditFailure> {
    let invalid = || EditFailure::RecordLayout { index: 0 };
    let (function, text, padding, x, y, extended) = match record {
        TextRecord::TextOut {
            function,
            text,
            padding,
            x,
            y,
        } => (*function, text, padding, *x, *y, false),
        TextRecord::ExtTextOut {
            function,
            text,
            padding,
            x,
            y,
            ..
        } => (*function, text, padding, *x, *y, true),
    };
    if function & 0xff != if extended { 0x32 } else { 0x21 }
        || text.len() > i16::MAX as usize
        || padding.len() % 2 != text.len() % 2
        || (extended && padding.len() > 1)
    {
        return Err(invalid());
    }
    let mut size = (if extended { 8usize } else { 6 })
        .checked_add(text.len())
        .and_then(|n| n.checked_add(padding.len()))
        .ok_or(EditFailure::SizeOverflow)?;
    if let TextRecord::ExtTextOut {
        options,
        rectangle,
        dx,
        ..
    } = record
    {
        if (options & 6 != 0) != rectangle.is_some()
            || dx.as_ref().is_some_and(|values| values.len() != text.len())
        {
            return Err(invalid());
        }
        size = size
            .checked_add(if rectangle.is_some() { 8 } else { 0 })
            .and_then(|n| n.checked_add(dx.as_ref().map_or(0, |values| values.len() * 2)))
            .ok_or(EditFailure::SizeOverflow)?;
    }
    let mut body = Vec::new();
    body.try_reserve_exact(size)
        .map_err(|_| EditFailure::SizeOverflow)?;
    if let TextRecord::ExtTextOut {
        options, rectangle, ..
    } = record
    {
        body.extend_from_slice(&y.to_le_bytes());
        body.extend_from_slice(&x.to_le_bytes());
        body.extend_from_slice(&(text.len() as i16).to_le_bytes());
        body.extend_from_slice(&options.to_le_bytes());
        if let Some(rectangle) = rectangle {
            for value in [
                rectangle.left,
                rectangle.top,
                rectangle.right,
                rectangle.bottom,
            ] {
                body.extend_from_slice(&value.to_le_bytes());
            }
        }
    } else {
        body.extend_from_slice(&(text.len() as i16).to_le_bytes());
    }
    body.extend_from_slice(text);
    body.extend_from_slice(padding);
    if let TextRecord::ExtTextOut { dx, .. } = record {
        if let Some(values) = dx {
            for value in values {
                body.extend_from_slice(&value.to_le_bytes());
            }
        }
    } else {
        body.extend_from_slice(&y.to_le_bytes());
        body.extend_from_slice(&x.to_le_bytes());
    }
    Ok((function, body))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{LimitKind, ParseFailure, ParseLimits};

    #[test]
    fn budgets_fail_before_text_or_spacing_allocation() {
        let body = [0, 0, 0, 0, 2, 0, 0, 0, b'a', b'b', 1, 0, 2, 0];
        for (allocation, work, kind) in [
            (0, 100, LimitKind::AllocatedBytes),
            (2, 100, LimitKind::AllocatedBytes),
            (100, 0, LimitKind::WorkUnits),
        ] {
            let limits = ParseLimits {
                max_allocated_bytes: allocation,
                max_work_units: work,
                ..ParseLimits::default()
            };
            assert!(
                matches!(decode(META_EXTTEXTOUT, &body, &mut Budget::new(&limits)),
                Err(DecodeError::Resource(ParseFailure::LimitExceeded { kind: actual, .. })) if actual == kind)
            );
        }
        let limits = ParseLimits {
            max_allocated_bytes: 6,
            max_work_units: 3,
            ..ParseLimits::default()
        };
        assert!(decode(META_EXTTEXTOUT, &body, &mut Budget::new(&limits)).is_ok());
        let limits = ParseLimits {
            max_allocated_bytes: 0,
            max_work_units: 0,
            ..ParseLimits::default()
        };
        assert!(matches!(
            decode(0xfefe, &body, &mut Budget::new(&limits)),
            Ok(None)
        ));
    }
}
