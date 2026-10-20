//! Bitmap record headers with lossless image bytes and optional typed views.
//!
//! Raster operations are retained without interpretation. Typed interior views
//! preserve pixel bytes, padding and unrecognized extension bytes.

use super::dib::{Bitmap16, ColorTable, Dib};
use super::DecodeError;
use crate::limits::{try_vec_with_capacity, Budget};
use crate::{EditFailure, ParseFailure, ParseLimits};

pub const META_BITBLT: u16 = 0x0922;
pub const META_DIBBITBLT: u16 = 0x0940;
pub const META_STRETCHBLT: u16 = 0x0b23;
pub const META_DIBSTRETCHBLT: u16 = 0x0b41;
pub const META_SETDIBTODEV: u16 = 0x0d33;
pub const META_STRETCHDIB: u16 = 0x0f43;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Blt {
    pub function: u16,
    pub raster_operation: u32,
    pub source_y: i16,
    pub source_x: i16,
    pub height: i16,
    pub width: i16,
    pub destination_y: i16,
    pub destination_x: i16,
    /// Retained ignored word in the form without a bitmap.
    pub reserved: u16,
    pub bitmap: Option<Vec<u8>>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct StretchBlt {
    pub function: u16,
    pub raster_operation: u32,
    pub source_height: i16,
    pub source_width: i16,
    pub source_y: i16,
    pub source_x: i16,
    pub destination_height: i16,
    pub destination_width: i16,
    pub destination_y: i16,
    pub destination_x: i16,
    pub reserved: u16,
    pub bitmap: Option<Vec<u8>>,
}

/// These fields are unsigned WORDs in MS-WMF, including coordinates.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SetDibToDev {
    pub function: u16,
    pub color_usage: u16,
    pub scan_count: u16,
    pub start_scan: u16,
    pub source_y: u16,
    pub source_x: u16,
    pub height: u16,
    pub width: u16,
    pub destination_y: u16,
    pub destination_x: u16,
    pub bitmap: Vec<u8>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct StretchDib {
    pub function: u16,
    pub raster_operation: u32,
    pub color_usage: u16,
    pub source_height: i16,
    pub source_width: i16,
    pub source_y: i16,
    pub source_x: i16,
    pub destination_height: i16,
    pub destination_width: i16,
    pub destination_y: i16,
    pub destination_x: i16,
    pub bitmap: Vec<u8>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum BitmapRecord {
    BitBlt(Blt),
    DibBitBlt(Blt),
    StretchBlt(StretchBlt),
    DibStretchBlt(StretchBlt),
    SetDibToDev(SetDibToDev),
    StretchDib(StretchDib),
}

/// A decoded bitmap interior, including the optional source's absent form.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum BitmapImage {
    Absent,
    Bitmap16(Bitmap16),
    Dib(Dib),
}

impl BitmapRecord {
    /// Decode the retained image without changing its wire representation.
    ///
    /// `Some(Absent)` identifies an absent optional source; `None` identifies a
    /// malformed or unsupported interior. Resource failures remain errors.
    /// Limits apply to the image bytes and allocations for this view.
    pub fn typed_image(&self, limits: &ParseLimits) -> Result<Option<BitmapImage>, ParseFailure> {
        match self {
            Self::BitBlt(value) => match &value.bitmap {
                Some(bytes) => Ok(Bitmap16::parse(bytes, limits)?.map(BitmapImage::Bitmap16)),
                None => Ok(Some(BitmapImage::Absent)),
            },
            Self::StretchBlt(value) => match &value.bitmap {
                Some(bytes) => Ok(Bitmap16::parse(bytes, limits)?.map(BitmapImage::Bitmap16)),
                None => Ok(Some(BitmapImage::Absent)),
            },
            Self::DibBitBlt(value) => match &value.bitmap {
                Some(bytes) => Ok(Dib::parse(bytes, 0, limits)?.map(BitmapImage::Dib)),
                None => Ok(Some(BitmapImage::Absent)),
            },
            Self::DibStretchBlt(value) => match &value.bitmap {
                Some(bytes) => Ok(Dib::parse(bytes, 0, limits)?.map(BitmapImage::Dib)),
                None => Ok(Some(BitmapImage::Absent)),
            },
            Self::SetDibToDev(value) => {
                Ok(Dib::parse(&value.bitmap, value.color_usage, limits)?.map(BitmapImage::Dib))
            }
            Self::StretchDib(value) => {
                Ok(Dib::parse(&value.bitmap, value.color_usage, limits)?.map(BitmapImage::Dib))
            }
        }
    }

    /// Replace an image atomically, preserving the record's kind and color usage.
    /// Invalid interiors, incompatible image kinds and ambiguous source forms
    /// return an error without changing the record.
    pub fn replace_image(&mut self, image: BitmapImage) -> Result<(), EditFailure> {
        let invalid = || EditFailure::RecordLayout { index: 0 };
        let dib_usage = match self {
            Self::DibBitBlt(_) | Self::DibStretchBlt(_) => Some(0),
            Self::SetDibToDev(value) => Some(value.color_usage),
            Self::StretchDib(value) => Some(value.color_usage),
            _ => None,
        };
        let bytes = match image {
            BitmapImage::Absent => None,
            BitmapImage::Bitmap16(value) if dib_usage.is_none() => Some(value.encode()?),
            BitmapImage::Dib(value) if dib_usage.is_some() => {
                if !matches!(
                    (dib_usage, &value.colors),
                    (Some(0), ColorTable::RgbTriples(_) | ColorTable::RgbQuads(_))
                        | (Some(1), ColorTable::PaletteIndices(_))
                        | (Some(2), ColorTable::None)
                ) {
                    return Err(invalid());
                }
                Some(value.encode()?)
            }
            _ => return Err(invalid()),
        };
        let mut candidate = self.clone();
        match &mut candidate {
            Self::BitBlt(value) | Self::DibBitBlt(value) => value.bitmap = bytes,
            Self::StretchBlt(value) | Self::DibStretchBlt(value) => value.bitmap = bytes,
            Self::SetDibToDev(value) => value.bitmap = bytes.ok_or_else(invalid)?,
            Self::StretchDib(value) => value.bitmap = bytes.ok_or_else(invalid)?,
        }
        let (function, body) = encode(&candidate)?;
        if !validate_layout(&candidate, function, body.len() / 2) {
            return Err(invalid());
        }
        *self = candidate;
        Ok(())
    }
}

fn word(body: &[u8], offset: usize) -> Result<u16, DecodeError> {
    let bytes = body.get(offset..offset + 2).ok_or(DecodeError::Malformed)?;
    Ok(u16::from_le_bytes([bytes[0], bytes[1]]))
}

fn dword(body: &[u8]) -> Result<u32, DecodeError> {
    Ok(u32::from(word(body, 0)?) | (u32::from(word(body, 2)?) << 16))
}

fn payload(body: &[u8], start: usize, budget: &mut Budget<'_>) -> Result<Vec<u8>, DecodeError> {
    let bytes = body
        .get(start..)
        .filter(|b| !b.is_empty())
        .ok_or(DecodeError::Malformed)?;
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
) -> Result<Option<(BitmapRecord, usize)>, DecodeError> {
    let kind = function & 0xff;
    if !matches!(kind, 0x22 | 0x23 | 0x33 | 0x40 | 0x41 | 0x43) {
        return Ok(None);
    }
    if body.len() % 2 != 0 {
        return Err(DecodeError::Malformed);
    }
    let absent = body.len() / 2 == usize::from(function >> 8);
    let value = match kind {
        0x22 | 0x40 => {
            let destination = if absent { 10 } else { 8 };
            let value = Blt {
                function,
                raster_operation: dword(body)?,
                source_y: word(body, 4)? as i16,
                source_x: word(body, 6)? as i16,
                height: word(body, destination)? as i16,
                width: word(body, destination + 2)? as i16,
                destination_y: word(body, destination + 4)? as i16,
                destination_x: word(body, destination + 6)? as i16,
                reserved: if absent { word(body, 8)? } else { 0 },
                bitmap: if absent {
                    None
                } else {
                    Some(payload(body, 16, budget)?)
                },
            };
            return Ok(Some((
                if kind == 0x22 {
                    BitmapRecord::BitBlt(value)
                } else {
                    BitmapRecord::DibBitBlt(value)
                },
                if absent { 18 } else { body.len() },
            )));
        }
        0x23 | 0x41 => {
            let destination = if absent { 14 } else { 12 };
            let value = StretchBlt {
                function,
                raster_operation: dword(body)?,
                source_height: word(body, 4)? as i16,
                source_width: word(body, 6)? as i16,
                source_y: word(body, 8)? as i16,
                source_x: word(body, 10)? as i16,
                destination_height: word(body, destination)? as i16,
                destination_width: word(body, destination + 2)? as i16,
                destination_y: word(body, destination + 4)? as i16,
                destination_x: word(body, destination + 6)? as i16,
                reserved: if absent { word(body, 12)? } else { 0 },
                bitmap: if absent {
                    None
                } else {
                    Some(payload(body, 20, budget)?)
                },
            };
            return Ok(Some((
                if kind == 0x23 {
                    BitmapRecord::StretchBlt(value)
                } else {
                    BitmapRecord::DibStretchBlt(value)
                },
                if absent { 22 } else { body.len() },
            )));
        }
        0x33 => BitmapRecord::SetDibToDev(SetDibToDev {
            function,
            color_usage: word(body, 0)?,
            scan_count: word(body, 2)?,
            start_scan: word(body, 4)?,
            source_y: word(body, 6)?,
            source_x: word(body, 8)?,
            height: word(body, 10)?,
            width: word(body, 12)?,
            destination_y: word(body, 14)?,
            destination_x: word(body, 16)?,
            bitmap: payload(body, 18, budget)?,
        }),
        _ => BitmapRecord::StretchDib(StretchDib {
            function,
            raster_operation: dword(body)?,
            color_usage: word(body, 4)?,
            source_height: word(body, 6)? as i16,
            source_width: word(body, 8)? as i16,
            source_y: word(body, 10)? as i16,
            source_x: word(body, 12)? as i16,
            destination_height: word(body, 14)? as i16,
            destination_width: word(body, 16)? as i16,
            destination_y: word(body, 18)? as i16,
            destination_x: word(body, 20)? as i16,
            bitmap: payload(body, 22, budget)?,
        }),
    };
    Ok(Some((value, body.len())))
}

pub(crate) fn encode(record: &BitmapRecord) -> Result<(u16, Vec<u8>), EditFailure> {
    let invalid = || EditFailure::RecordLayout { index: 0 };
    // Fixed fields fit on the stack; only the final output is allocated.
    let mut header = [0u8; 22];
    let mut position = 0;
    let mut put = |value: u16| {
        header[position..position + 2].copy_from_slice(&value.to_le_bytes());
        position += 2;
    };
    let (function, kind, image, optional) = match record {
        BitmapRecord::BitBlt(value) | BitmapRecord::DibBitBlt(value) => {
            put(value.raster_operation as u16);
            put((value.raster_operation >> 16) as u16);
            put(value.source_y as u16);
            put(value.source_x as u16);
            if value.bitmap.is_none() {
                put(value.reserved);
            }
            put(value.height as u16);
            put(value.width as u16);
            put(value.destination_y as u16);
            put(value.destination_x as u16);
            (
                value.function,
                if matches!(record, BitmapRecord::BitBlt(_)) {
                    0x22
                } else {
                    0x40
                },
                value.bitmap.as_deref(),
                true,
            )
        }
        BitmapRecord::StretchBlt(value) | BitmapRecord::DibStretchBlt(value) => {
            put(value.raster_operation as u16);
            put((value.raster_operation >> 16) as u16);
            put(value.source_height as u16);
            put(value.source_width as u16);
            put(value.source_y as u16);
            put(value.source_x as u16);
            if value.bitmap.is_none() {
                put(value.reserved);
            }
            put(value.destination_height as u16);
            put(value.destination_width as u16);
            put(value.destination_y as u16);
            put(value.destination_x as u16);
            (
                value.function,
                if matches!(record, BitmapRecord::StretchBlt(_)) {
                    0x23
                } else {
                    0x41
                },
                value.bitmap.as_deref(),
                true,
            )
        }
        BitmapRecord::SetDibToDev(value) => {
            for word in [
                value.color_usage,
                value.scan_count,
                value.start_scan,
                value.source_y,
                value.source_x,
                value.height,
                value.width,
                value.destination_y,
                value.destination_x,
            ] {
                put(word);
            }
            (value.function, 0x33, Some(value.bitmap.as_slice()), false)
        }
        BitmapRecord::StretchDib(value) => {
            put(value.raster_operation as u16);
            put((value.raster_operation >> 16) as u16);
            put(value.color_usage);
            for word in [
                value.source_height,
                value.source_width,
                value.source_y,
                value.source_x,
                value.destination_height,
                value.destination_width,
                value.destination_y,
                value.destination_x,
            ] {
                put(word as u16);
            }
            (value.function, 0x43, Some(value.bitmap.as_slice()), false)
        }
    };
    if function & 0xff != kind
        || image.is_some_and(|bytes| bytes.is_empty() || bytes.len() % 2 != 0)
    {
        return Err(invalid());
    }
    let image = image.unwrap_or(&[]);
    let size = position
        .checked_add(image.len())
        .ok_or(EditFailure::SizeOverflow)?;
    if optional && !image.is_empty() && !validate_layout(record, function, size / 2) {
        return Err(invalid());
    }
    let mut output = Vec::new();
    output
        .try_reserve_exact(size)
        .map_err(|_| EditFailure::SizeOverflow)?;
    output.extend_from_slice(&header[..position]);
    output.extend_from_slice(image);
    Ok((function, output))
}

/// Check the source discriminator using the final body size, after parent suffixes.
pub(crate) fn validate_layout(record: &BitmapRecord, function: u16, body_words: usize) -> bool {
    let present = match record {
        BitmapRecord::BitBlt(value) | BitmapRecord::DibBitBlt(value) => value.bitmap.is_some(),
        BitmapRecord::StretchBlt(value) | BitmapRecord::DibStretchBlt(value) => {
            value.bitmap.is_some()
        }
        _ => return true,
    };
    present != (body_words == usize::from(function >> 8))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{LimitKind, ParseFailure, ParseLimits};

    #[test]
    fn opaque_payload_copy_obeys_allocation_and_work_budgets() {
        let body = [0u8; 48];
        for (allocated, work, expected) in [
            (29, 100, LimitKind::AllocatedBytes),
            (100, 1, LimitKind::WorkUnits),
        ] {
            let limits = ParseLimits {
                max_allocated_bytes: allocated,
                max_work_units: work,
                ..ParseLimits::default()
            };
            let mut budget = Budget::new(&limits);
            assert!(
                matches!(decode(META_SETDIBTODEV, &body, &mut budget), Err(DecodeError::Resource(ParseFailure::LimitExceeded { kind, .. })) if kind == expected)
            );
        }
        let limits = ParseLimits {
            max_allocated_bytes: 30,
            max_work_units: 2,
            ..ParseLimits::default()
        };
        assert!(decode(META_SETDIBTODEV, &body, &mut Budget::new(&limits))
            .ok()
            .unwrap()
            .is_some());
    }

    #[test]
    fn unknown_function_does_not_spend_budget_and_source_discriminator_uses_high_byte() {
        let limits = ParseLimits {
            max_allocated_bytes: 0,
            max_work_units: 0,
            ..ParseLimits::default()
        };
        assert!(decode(0xffff, &[0; 100], &mut Budget::new(&limits))
            .ok()
            .unwrap()
            .is_none());
        let (value, used) = decode(META_BITBLT, &[0; 18], &mut Budget::new(&limits))
            .ok()
            .unwrap()
            .unwrap();
        assert_eq!(used, 18);
        assert!(matches!(
            &value,
            BitmapRecord::BitBlt(Blt { bitmap: None, .. })
        ));
        assert!(validate_layout(&value, META_BITBLT, 9));
        assert!(!validate_layout(&value, META_BITBLT, 10));
    }
}
