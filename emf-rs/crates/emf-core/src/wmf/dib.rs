//! Packed WMF bitmap interiors. Compressed pixels and header extensions are retained.
//!
//! No image decompression or color conversion is performed. Non-packed DIBs with
//! arbitrary pixel offsets are not supported by this interface.

use super::DecodeError;
use crate::limits::{try_vec_with_capacity, Budget};
use crate::{EditFailure, ParseFailure, ParseLimits};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct BitmapCoreHeader {
    pub width: u16,
    pub height: u16,
    pub planes: u16,
    pub bit_count: u16,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct BitmapInfoHeader {
    pub width: i32,
    pub height: i32,
    pub planes: u16,
    pub bit_count: u16,
    pub compression: u32,
    pub image_size: u32,
    pub x_pels_per_meter: i32,
    pub y_pels_per_meter: i32,
    pub colors_used: u32,
    pub colors_important: u32,
    /// Bytes after the 40-byte INFO header, including V4/V5 fields and masks.
    pub extension: Vec<u8>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum DibHeader {
    Core(BitmapCoreHeader),
    Info(BitmapInfoHeader),
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ColorTable {
    None,
    RgbTriples(Vec<[u8; 3]>),
    RgbQuads(Vec<[u8; 4]>),
    PaletteIndices(Vec<u16>),
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Dib {
    pub header: DibHeader,
    /// Present for a 40-byte INFO header with BI_BITFIELDS compression.
    pub bitfield_masks: Option<[u32; 3]>,
    pub colors: ColorTable,
    pub pixels: Vec<u8>,
    /// Bytes after the calculated/declared pixel extent, including WMF padding.
    pub trailing: Vec<u8>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Bitmap16 {
    pub bitmap_type: i16,
    pub width: i16,
    pub height: i16,
    pub width_bytes: i16,
    pub planes: u8,
    pub bits_pixel: u8,
    pub pixels: Vec<u8>,
    pub trailing: Vec<u8>,
}

fn word(bytes: &[u8], offset: usize) -> Result<u16, DecodeError> {
    let b = bytes
        .get(offset..offset + 2)
        .ok_or(DecodeError::Malformed)?;
    Ok(u16::from_le_bytes([b[0], b[1]]))
}
fn dword(bytes: &[u8], offset: usize) -> Result<u32, DecodeError> {
    Ok(u32::from(word(bytes, offset)?) | (u32::from(word(bytes, offset + 2)?) << 16))
}
fn sum(a: usize, b: usize) -> Result<usize, DecodeError> {
    a.checked_add(b).ok_or(DecodeError::Malformed)
}
fn product(a: usize, b: usize) -> Result<usize, DecodeError> {
    a.checked_mul(b).ok_or(DecodeError::Malformed)
}
fn copy(bytes: &[u8], budget: &mut Budget<'_>) -> Result<Vec<u8>, DecodeError> {
    budget.charge_work((bytes.len() as u64).div_ceil(16))?;
    budget.charge_alloc(bytes.len())?;
    let mut result = try_vec_with_capacity(bytes.len())?;
    result.extend_from_slice(bytes);
    Ok(result)
}
fn public_result<T>(result: Result<T, DecodeError>) -> Result<Option<T>, ParseFailure> {
    match result {
        Ok(value) => Ok(Some(value)),
        Err(DecodeError::Malformed) => Ok(None),
        Err(DecodeError::Resource(error)) => Err(error),
    }
}

impl Dib {
    /// Malformed or unsupported packed layouts return `None`; resource failures
    /// remain errors so callers cannot hide exhausted budgets behind raw fallback.
    pub fn parse(
        bytes: &[u8],
        color_usage: u16,
        limits: &ParseLimits,
    ) -> Result<Option<Self>, ParseFailure> {
        let mut budget = Budget::new(limits);
        budget.check_input(bytes.len())?;
        public_result(decode(bytes, color_usage, &mut budget).map(|(value, _)| value))
    }

    pub fn encode(&self) -> Result<Vec<u8>, EditFailure> {
        if matches!(
            (&self.header, &self.colors),
            (DibHeader::Core(_), ColorTable::RgbQuads(_))
                | (DibHeader::Info(_), ColorTable::RgbTriples(_))
        ) {
            return Err(EditFailure::RecordLayout { index: 0 });
        }
        let color_bytes = match &self.colors {
            ColorTable::None => Some(0),
            ColorTable::RgbTriples(v) => v.len().checked_mul(3),
            ColorTable::RgbQuads(v) => v.len().checked_mul(4),
            ColorTable::PaletteIndices(v) => v.len().checked_mul(2),
        }
        .ok_or(EditFailure::SizeOverflow)?;
        let header_size = match &self.header {
            DibHeader::Core(_) => 12,
            DibHeader::Info(h) => 40usize
                .checked_add(h.extension.len())
                .ok_or(EditFailure::SizeOverflow)?,
        };
        let size = [
            header_size,
            if self.bitfield_masks.is_some() { 12 } else { 0 },
            color_bytes,
            self.pixels.len(),
            self.trailing.len(),
        ]
        .into_iter()
        .try_fold(0usize, |a, b| a.checked_add(b))
        .ok_or(EditFailure::SizeOverflow)?;
        let mut output = try_vec_with_capacity(size).map_err(|_| EditFailure::SizeOverflow)?;
        output.extend_from_slice(
            &u32::try_from(header_size)
                .map_err(|_| EditFailure::SizeOverflow)?
                .to_le_bytes(),
        );
        match &self.header {
            DibHeader::Core(h) => {
                for value in [h.width, h.height, h.planes, h.bit_count] {
                    output.extend_from_slice(&value.to_le_bytes());
                }
            }
            DibHeader::Info(h) => {
                output.extend_from_slice(&h.width.to_le_bytes());
                output.extend_from_slice(&h.height.to_le_bytes());
                output.extend_from_slice(&h.planes.to_le_bytes());
                output.extend_from_slice(&h.bit_count.to_le_bytes());
                for value in [
                    h.compression,
                    h.image_size,
                    h.x_pels_per_meter as u32,
                    h.y_pels_per_meter as u32,
                    h.colors_used,
                    h.colors_important,
                ] {
                    output.extend_from_slice(&value.to_le_bytes());
                }
                output.extend_from_slice(&h.extension);
            }
        }
        if let Some(masks) = self.bitfield_masks {
            for value in masks {
                output.extend_from_slice(&value.to_le_bytes());
            }
        }
        let usage = match &self.colors {
            ColorTable::None => 2,
            ColorTable::RgbTriples(values) => {
                for value in values {
                    output.extend_from_slice(value);
                }
                0
            }
            ColorTable::RgbQuads(values) => {
                for value in values {
                    output.extend_from_slice(value);
                }
                0
            }
            ColorTable::PaletteIndices(values) => {
                for value in values {
                    output.extend_from_slice(&value.to_le_bytes());
                }
                1
            }
        };
        output.extend_from_slice(&self.pixels);
        output.extend_from_slice(&self.trailing);
        let layout = layout(&output, usage).map_err(|_| EditFailure::RecordLayout { index: 0 })?;
        if layout.header != header_size
            || layout.pixel_start
                != header_size + (if self.bitfield_masks.is_some() { 12 } else { 0 }) + color_bytes
            || layout.pixel_size != self.pixels.len()
        {
            return Err(EditFailure::RecordLayout { index: 0 });
        }
        Ok(output)
    }
}

struct Layout {
    header: usize,
    masks: usize,
    color_count: usize,
    entry_size: usize,
    pixel_start: usize,
    pixel_size: usize,
}

fn layout(bytes: &[u8], usage: u16) -> Result<Layout, DecodeError> {
    let header = usize::try_from(dword(bytes, 0)?).map_err(|_| DecodeError::Malformed)?;
    if (header != 12 && header < 40) || header > bytes.len() || usage > 2 {
        return Err(DecodeError::Malformed);
    }
    let (width, height, planes, bits, compression, image_size, used) = if header == 12 {
        (
            i32::from(word(bytes, 4)?),
            i32::from(word(bytes, 6)?),
            word(bytes, 8)?,
            word(bytes, 10)?,
            0,
            0,
            0,
        )
    } else {
        (
            dword(bytes, 4)? as i32,
            dword(bytes, 8)? as i32,
            word(bytes, 12)?,
            word(bytes, 14)?,
            dword(bytes, 16)?,
            dword(bytes, 20)?,
            dword(bytes, 32)?,
        )
    };
    if width <= 0 || height == 0 || planes != 1 || !matches!(bits, 0 | 1 | 4 | 8 | 16 | 24 | 32) {
        return Err(DecodeError::Malformed);
    }
    if !matches!(compression, 0 | 1 | 2 | 3 | 4 | 5 | 11 | 12 | 13)
        || (height < 0 && !matches!(compression, 0 | 3))
        || (bits == 0 && !matches!(compression, 4 | 5))
        || (matches!(compression, 1 | 12) && bits != 8)
        || (matches!(compression, 2 | 13) && bits != 4)
        || (compression == 3 && !matches!(bits, 16 | 32))
    {
        return Err(DecodeError::Malformed);
    }
    // Embedded masks occupy the extension in V4/V5 and later headers.
    let masks = if compression == 3 {
        if header == 40 {
            12
        } else if header >= 52 {
            0
        } else {
            return Err(DecodeError::Malformed);
        }
    } else {
        0
    };
    let max_colors = if (1..=8).contains(&bits) {
        1usize << bits
    } else {
        0
    };
    let color_count = if usage == 2 {
        0
    } else if used == 0 {
        max_colors
    } else {
        let used = usize::try_from(used).map_err(|_| DecodeError::Malformed)?;
        if max_colors > 0 && used > max_colors {
            return Err(DecodeError::Malformed);
        }
        used
    };
    let entry_size = if usage == 1 {
        2
    } else if header == 12 {
        3
    } else {
        4
    };
    let pixel_start = sum(sum(header, masks)?, product(color_count, entry_size)?)?;
    let pixel_size = if matches!(compression, 0 | 3 | 11) {
        let row_bits = product(width as usize, usize::from(bits))?;
        let stride = product(sum(row_bits, 31)? / 32, 4)?;
        product(stride, height.unsigned_abs() as usize)?
    } else {
        if image_size == 0 {
            return Err(DecodeError::Malformed);
        }
        usize::try_from(image_size).map_err(|_| DecodeError::Malformed)?
    };
    if sum(pixel_start, pixel_size)? > bytes.len() {
        return Err(DecodeError::Malformed);
    }
    // A packed V5 profile may follow pixels, but may not overlap header/table/pixels.
    if header >= 124 && matches!(dword(bytes, 56)?, 0x4c49_4e4b | 0x4d42_4544) {
        let profile = dword(bytes, 112)? as usize;
        let profile_size = dword(bytes, 116)? as usize;
        if profile_size > 0
            && (profile < sum(pixel_start, pixel_size)?
                || sum(profile, profile_size)? > bytes.len())
        {
            return Err(DecodeError::Malformed);
        }
    }
    Ok(Layout {
        header,
        masks,
        color_count,
        entry_size,
        pixel_start,
        pixel_size,
    })
}

pub(crate) fn decode(
    bytes: &[u8],
    color_usage: u16,
    budget: &mut Budget<'_>,
) -> Result<(Dib, usize), DecodeError> {
    budget.charge_work(1)?;
    let l = layout(bytes, color_usage)?;
    let header = if l.header == 12 {
        DibHeader::Core(BitmapCoreHeader {
            width: word(bytes, 4)?,
            height: word(bytes, 6)?,
            planes: word(bytes, 8)?,
            bit_count: word(bytes, 10)?,
        })
    } else {
        DibHeader::Info(BitmapInfoHeader {
            width: dword(bytes, 4)? as i32,
            height: dword(bytes, 8)? as i32,
            planes: word(bytes, 12)?,
            bit_count: word(bytes, 14)?,
            compression: dword(bytes, 16)?,
            image_size: dword(bytes, 20)?,
            x_pels_per_meter: dword(bytes, 24)? as i32,
            y_pels_per_meter: dword(bytes, 28)? as i32,
            colors_used: dword(bytes, 32)?,
            colors_important: dword(bytes, 36)?,
            extension: copy(&bytes[40..l.header], budget)?,
        })
    };
    let bitfield_masks = if l.masks > 0 {
        Some([
            dword(bytes, l.header)?,
            dword(bytes, l.header + 4)?,
            dword(bytes, l.header + 8)?,
        ])
    } else {
        None
    };
    let colors_start = l.header + l.masks;
    let color_bytes = &bytes[colors_start..l.pixel_start];
    budget.charge_work((color_bytes.len() as u64).div_ceil(16))?;
    budget.charge_alloc(color_bytes.len())?;
    let colors = if color_usage == 2 {
        ColorTable::None
    } else if l.entry_size == 2 {
        let mut entries = try_vec_with_capacity(l.color_count)?;
        for b in color_bytes.chunks_exact(2) {
            entries.push(u16::from_le_bytes([b[0], b[1]]));
        }
        ColorTable::PaletteIndices(entries)
    } else if l.entry_size == 3 {
        let mut entries = try_vec_with_capacity(l.color_count)?;
        for b in color_bytes.chunks_exact(3) {
            entries.push([b[0], b[1], b[2]]);
        }
        ColorTable::RgbTriples(entries)
    } else {
        let mut entries = try_vec_with_capacity(l.color_count)?;
        for b in color_bytes.chunks_exact(4) {
            entries.push([b[0], b[1], b[2], b[3]]);
        }
        ColorTable::RgbQuads(entries)
    };
    let end = l.pixel_start + l.pixel_size;
    Ok((
        Dib {
            header,
            bitfield_masks,
            colors,
            pixels: copy(&bytes[l.pixel_start..end], budget)?,
            trailing: copy(&bytes[end..], budget)?,
        },
        bytes.len(),
    ))
}

fn bitmap16_size(bytes: &[u8]) -> Result<usize, DecodeError> {
    let width = word(bytes, 2)? as i16;
    let height = word(bytes, 4)? as i16;
    let planes = *bytes.get(8).ok_or(DecodeError::Malformed)?;
    let bits = *bytes.get(9).ok_or(DecodeError::Malformed)?;
    if width <= 0 || height <= 0 || planes != 1 || bits == 0 {
        return Err(DecodeError::Malformed);
    }
    // MS-WMF defines the extent from Width/BitsPixel, independently of WidthBytes.
    // Preserve WidthBytes verbatim, including values inconsistent with this stride.
    let stride = product(
        sum(product(width as usize, usize::from(bits))?, 15)? / 16,
        2,
    )?;
    let size = product(stride, height as usize)?;
    if sum(10, size)? > bytes.len() {
        return Err(DecodeError::Malformed);
    }
    Ok(size)
}

pub(crate) fn decode_bitmap16(
    bytes: &[u8],
    budget: &mut Budget<'_>,
) -> Result<(Bitmap16, usize), DecodeError> {
    budget.charge_work(1)?;
    let size = bitmap16_size(bytes)?;
    Ok((
        Bitmap16 {
            bitmap_type: word(bytes, 0)? as i16,
            width: word(bytes, 2)? as i16,
            height: word(bytes, 4)? as i16,
            width_bytes: word(bytes, 6)? as i16,
            planes: bytes[8],
            bits_pixel: bytes[9],
            pixels: copy(&bytes[10..10 + size], budget)?,
            trailing: copy(&bytes[10 + size..], budget)?,
        },
        bytes.len(),
    ))
}

impl Bitmap16 {
    pub fn parse(bytes: &[u8], limits: &ParseLimits) -> Result<Option<Self>, ParseFailure> {
        let mut budget = Budget::new(limits);
        budget.check_input(bytes.len())?;
        public_result(decode_bitmap16(bytes, &mut budget).map(|(value, _)| value))
    }

    pub fn encode(&self) -> Result<Vec<u8>, EditFailure> {
        let size = 10usize
            .checked_add(self.pixels.len())
            .and_then(|v| v.checked_add(self.trailing.len()))
            .ok_or(EditFailure::SizeOverflow)?;
        let mut output = try_vec_with_capacity(size).map_err(|_| EditFailure::SizeOverflow)?;
        for value in [self.bitmap_type, self.width, self.height, self.width_bytes] {
            output.extend_from_slice(&value.to_le_bytes());
        }
        output.extend_from_slice(&[self.planes, self.bits_pixel]);
        output.extend_from_slice(&self.pixels);
        output.extend_from_slice(&self.trailing);
        if bitmap16_size(&output).map_err(|_| EditFailure::RecordLayout { index: 0 })?
            != self.pixels.len()
        {
            return Err(EditFailure::RecordLayout { index: 0 });
        }
        Ok(output)
    }
}
