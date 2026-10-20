//! Editable graphics objects, MS-EMFPLUS 2.2.1 and referenced 2.2.2 structures.
use super::{Error, ObjectDefinition};
use crate::{
    limits::{try_vec_with_capacity, Budget},
    LimitKind, ParseLimits, SerializeFailure, SerializeLimits,
};
mod line_cap;
mod linear_brush;
mod path;
mod path_brush;
mod pen;
mod region;
mod texture;
pub use line_cap::{ArrowLineCap, CustomLineCap, CustomLineCapData, DefaultLineCap};
pub use linear_brush::LinearGradient;
pub use path::{Path, PathPointRun, PathPointTypes};
pub use path_brush::{GradientBoundary, PathGradient};
pub use pen::{Pen, PenBrush, PenBrushData};
pub use region::{Region, RegionNode};
pub use texture::{Texture, TextureImage};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct StringFormat {
    pub version: u32,
    pub flags: u32,
    pub language: u32,
    pub alignment: u32,
    pub line_alignment: u32,
    pub digit_substitution: u32,
    pub digit_language: u32,
    pub first_tab_offset: u32,
    pub hotkey_prefix: i32,
    pub leading_margin: u32,
    pub trailing_margin: u32,
    pub tracking: u32,
    pub trimming: u32,
    pub tab_stops: Vec<u32>,
    pub character_ranges: Vec<[i32; 2]>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ObjectData {
    Pen(Pen),
    TextureBrush {
        version: u32,
        data: Texture,
    },
    PathGradientBrush {
        version: u32,
        data: PathGradient,
    },
    LinearGradientBrush {
        version: u32,
        data: LinearGradient,
    },
    CustomLineCap(CustomLineCap),
    Path(Path),
    Region(Region),
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
        family_name: Vec<u16>,
        suffix: Vec<u8>,
    },
    ImageAttributes {
        version: u32,
        reserved1: u32,
        wrap_mode: u32,
        clamp_argb: u32,
        object_clamp: i32,
        reserved2: u32,
    },
    StringFormat(StringFormat),
    /// BitmapData is preserved without pixel expansion or image decompression.
    BitmapImage {
        version: u32,
        width: i32,
        height: i32,
        stride: i32,
        pixel_format: u32,
        bitmap_type: u32,
        data: Vec<u8>,
    },
    /// The nested metafile is preserved without recursive format detection.
    MetafileImage {
        version: u32,
        metafile_type: u32,
        data: Vec<u8>,
        suffix: Vec<u8>,
    },
    Opaque {
        object_type: u8,
        bytes: Vec<u8>,
    },
}
impl ObjectDefinition {
    /// Decode independently under the supplied budgets, including input and all
    /// owned buffers. Unknown object/brush/image types remain visibly opaque.
    pub fn decode(&self, limits: &ParseLimits) -> Result<ObjectData, Error> {
        let mut budget = Budget::new(limits);
        budget.check_input(self.bytes.len())?;
        budget.check_record_bytes(self.bytes.len())?;
        budget.charge_record(self.bytes.len())?;
        let mut r = Reader {
            bytes: &self.bytes,
            pos: 0,
            index: self.first_record,
            budget: &mut budget,
        };
        let value = match self.object_type {
            2 => match pen::read(&mut r)? {
                Some(v) => ObjectData::Pen(v),
                None => return opaque(self, r.budget),
            },
            9 => match line_cap::read(&mut r)? {
                Some(v) => ObjectData::CustomLineCap(v),
                None => return opaque(self, r.budget),
            },
            3 => ObjectData::Path(path::read(&mut r)?),
            4 => match region::read(&mut r)? {
                Some(v) => ObjectData::Region(v),
                None => return opaque(self, r.budget),
            },
            1 => {
                let version = r.word()?;
                match r.word()? {
                    0 => ObjectData::SolidBrush {
                        version,
                        argb: r.word()?,
                    },
                    1 => ObjectData::HatchBrush {
                        version,
                        style: r.word()?,
                        foreground: r.word()?,
                        background: r.word()?,
                    },
                    2 => match texture::read(&mut r)? {
                        Some(data) => ObjectData::TextureBrush { version, data },
                        None => return opaque(self, r.budget),
                    },
                    3 => match path_brush::read(&mut r)? {
                        Some(data) => ObjectData::PathGradientBrush { version, data },
                        None => return opaque(self, r.budget),
                    },
                    4 => match linear_brush::read(&mut r)? {
                        Some(data) => ObjectData::LinearGradientBrush { version, data },
                        None => return opaque(self, r.budget),
                    },
                    _ => return opaque(self, &mut budget),
                }
            }
            5 => {
                let version = r.word()?;
                match r.word()? {
                    1 => ObjectData::BitmapImage {
                        version,
                        width: r.word()? as i32,
                        height: r.word()? as i32,
                        stride: r.word()? as i32,
                        pixel_format: r.word()?,
                        bitmap_type: r.word()?,
                        data: r.rest()?,
                    },
                    2 => {
                        let metafile_type = r.word()?;
                        let count = r.word()? as usize;
                        let data = r.bytes(count)?;
                        if r.remaining() > 3 {
                            return Err(r.error());
                        }
                        ObjectData::MetafileImage {
                            version,
                            metafile_type,
                            data,
                            suffix: r.rest()?,
                        }
                    }
                    _ => return opaque(self, &mut budget),
                }
            }
            6 => {
                let version = r.word()?;
                let em_size = r.word()?;
                let size_unit = r.word()?;
                let style = r.word()? as i32;
                let reserved = r.word()?;
                let count = r.word()? as usize;
                r.require_count(count, 2)?;
                let mut family_name = r.vector(count)?;
                for _ in 0..count {
                    family_name.push(u16::from_le_bytes(r.take(2)?.try_into().unwrap()));
                }
                ObjectData::Font {
                    version,
                    em_size,
                    size_unit,
                    style,
                    reserved,
                    family_name,
                    suffix: r.rest()?,
                }
            }
            7 => {
                let fields = r.words::<13>()?;
                let tabs = r.word()? as i32;
                let ranges = r.word()? as i32;
                if tabs < 0 || ranges < 0 {
                    return Err(r.error());
                }
                let (tabs, ranges) = (tabs as usize, ranges as usize);
                let needed = tabs
                    .checked_mul(4)
                    .and_then(|n| ranges.checked_mul(8).and_then(|m| n.checked_add(m)))
                    .ok_or_else(|| r.error())?;
                if needed != r.remaining() {
                    return Err(r.error());
                }
                let mut tab_stops = r.vector(tabs)?;
                for _ in 0..tabs {
                    tab_stops.push(r.word()?);
                }
                let mut character_ranges = r.vector(ranges)?;
                for _ in 0..ranges {
                    character_ranges.push([r.word()? as i32, r.word()? as i32]);
                }
                ObjectData::StringFormat(StringFormat {
                    version: fields[0],
                    flags: fields[1],
                    language: fields[2],
                    alignment: fields[3],
                    line_alignment: fields[4],
                    digit_substitution: fields[5],
                    digit_language: fields[6],
                    first_tab_offset: fields[7],
                    hotkey_prefix: fields[8] as i32,
                    leading_margin: fields[9],
                    trailing_margin: fields[10],
                    tracking: fields[11],
                    trimming: fields[12],
                    tab_stops,
                    character_ranges,
                })
            }
            8 => ObjectData::ImageAttributes {
                version: r.word()?,
                reserved1: r.word()?,
                wrap_mode: r.word()?,
                clamp_argb: r.word()?,
                object_clamp: r.word()? as i32,
                reserved2: r.word()?,
            },
            _ => return opaque(self, &mut budget),
        };
        if r.remaining() != 0 {
            return Err(r.error());
        }
        Ok(value)
    }
}
fn opaque(def: &ObjectDefinition, budget: &mut Budget<'_>) -> Result<ObjectData, Error> {
    let mut r = Reader {
        bytes: &def.bytes,
        pos: 0,
        index: def.first_record,
        budget,
    };
    Ok(ObjectData::Opaque {
        object_type: def.object_type,
        bytes: r.rest()?,
    })
}
impl ObjectData {
    pub fn object_type(&self) -> u8 {
        match self {
            Self::Pen(_) => 2,
            Self::CustomLineCap(_) => 9,
            Self::Path(_) => 3,
            Self::Region(_) => 4,
            Self::SolidBrush { .. }
            | Self::HatchBrush { .. }
            | Self::LinearGradientBrush { .. }
            | Self::PathGradientBrush { .. }
            | Self::TextureBrush { .. } => 1,
            Self::BitmapImage { .. } | Self::MetafileImage { .. } => 5,
            Self::Font { .. } => 6,
            Self::StringFormat(_) => 7,
            Self::ImageAttributes { .. } => 8,
            Self::Opaque { object_type, .. } => *object_type,
        }
    }
    /// Produce the complete body for `Stream::replace_object_bytes` or explicit
    /// fragment creation. Counts are derived from edited vectors.
    pub fn serialize(&self, limits: &SerializeLimits) -> Result<Vec<u8>, SerializeFailure> {
        let overflow = || SerializeFailure::SizeOverflow;
        let (base, parts, elements): (usize, [usize; 3], u64) = match self {
            Self::Pen(v) => {
                let (size, work) = v.layout()?;
                (size, [0; 3], work)
            }
            Self::CustomLineCap(v) => {
                let (size, work) = v.layout()?;
                (size, [0; 3], work)
            }
            Self::Region(v) => {
                let (size, work) = v.layout()?;
                (size, [0; 3], work)
            }
            Self::Path(v) => {
                let (size, work) = v.layout()?;
                (size, [0; 3], work)
            }
            Self::TextureBrush { data, .. } => {
                let (size, work) = data.layout()?;
                (size.checked_add(8).ok_or_else(overflow)?, [0; 3], work)
            }
            Self::PathGradientBrush { data, .. } => {
                let (size, work) = data.layout()?;
                (size.checked_add(8).ok_or_else(overflow)?, [0; 3], work)
            }
            Self::LinearGradientBrush { data, .. } => {
                let (size, work) = data.layout()?;
                (size.checked_add(8).ok_or_else(overflow)?, [0; 3], work)
            }
            Self::SolidBrush { .. } => (12, [0; 3], 0),
            Self::HatchBrush { .. } => (20, [0; 3], 0),
            Self::ImageAttributes { .. } => (24, [0; 3], 0),
            Self::Font {
                family_name,
                suffix,
                ..
            } => {
                if family_name.len() > u32::MAX as usize {
                    return Err(overflow());
                }
                (
                    24,
                    [
                        family_name.len().checked_mul(2).ok_or_else(overflow)?,
                        suffix.len(),
                        0,
                    ],
                    family_name.len() as u64,
                )
            }
            Self::StringFormat(v) => {
                if v.tab_stops.len() > i32::MAX as usize
                    || v.character_ranges.len() > i32::MAX as usize
                {
                    return Err(overflow());
                }
                (
                    60,
                    [
                        v.tab_stops.len().checked_mul(4).ok_or_else(overflow)?,
                        v.character_ranges
                            .len()
                            .checked_mul(8)
                            .ok_or_else(overflow)?,
                        0,
                    ],
                    (v.tab_stops.len() as u64).saturating_add(v.character_ranges.len() as u64),
                )
            }
            Self::BitmapImage { data, .. } => (28, [data.len(), 0, 0], 0),
            Self::MetafileImage { data, suffix, .. } => {
                if data.len() > u32::MAX as usize || suffix.len() > 3 {
                    return Err(SerializeFailure::Inconsistent { offset: 0 });
                }
                (16, [data.len(), suffix.len(), 0], 0)
            }
            Self::Opaque { bytes, .. } => (0, [bytes.len(), 0, 0], 0),
        };
        let size = parts
            .into_iter()
            .try_fold(base, |n, p| n.checked_add(p).ok_or_else(overflow))?;
        let work = 1u64
            .checked_add((size as u64).div_ceil(16))
            .and_then(|n| n.checked_add(elements))
            .ok_or_else(overflow)?;
        for (kind, requested, limit) in [
            (
                LimitKind::OutputBytes,
                size as u64,
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
        let mut out = Vec::new();
        out.try_reserve_exact(size)
            .map_err(|_| SerializeFailure::AllocationFailed { bytes: size })?;
        match self {
            Self::TextureBrush { version, data } => {
                words(&mut out, &[*version, 2]);
                data.write(&mut out);
            }
            Self::PathGradientBrush { version, data } => {
                words(&mut out, &[*version, 3]);
                data.write(&mut out);
            }
            Self::LinearGradientBrush { version, data } => {
                words(&mut out, &[*version, 4]);
                data.write(&mut out);
            }
            Self::Pen(v) => v.write(&mut out),
            Self::CustomLineCap(v) => v.write(&mut out),
            Self::Path(v) => v.write(&mut out),
            Self::Region(v) => v.write(&mut out),
            Self::SolidBrush { version, argb } => words(&mut out, &[*version, 0, *argb]),
            Self::HatchBrush {
                version,
                style,
                foreground,
                background,
            } => words(&mut out, &[*version, 1, *style, *foreground, *background]),
            Self::ImageAttributes {
                version,
                reserved1,
                wrap_mode,
                clamp_argb,
                object_clamp,
                reserved2,
            } => words(
                &mut out,
                &[
                    *version,
                    *reserved1,
                    *wrap_mode,
                    *clamp_argb,
                    *object_clamp as u32,
                    *reserved2,
                ],
            ),
            Self::Font {
                version,
                em_size,
                size_unit,
                style,
                reserved,
                family_name,
                suffix,
            } => {
                words(
                    &mut out,
                    &[
                        *version,
                        *em_size,
                        *size_unit,
                        *style as u32,
                        *reserved,
                        family_name.len() as u32,
                    ],
                );
                for n in family_name {
                    out.extend_from_slice(&n.to_le_bytes());
                }
                out.extend_from_slice(suffix);
            }
            Self::StringFormat(v) => {
                words(
                    &mut out,
                    &[
                        v.version,
                        v.flags,
                        v.language,
                        v.alignment,
                        v.line_alignment,
                        v.digit_substitution,
                        v.digit_language,
                        v.first_tab_offset,
                        v.hotkey_prefix as u32,
                        v.leading_margin,
                        v.trailing_margin,
                        v.tracking,
                        v.trimming,
                        v.tab_stops.len() as u32,
                        v.character_ranges.len() as u32,
                    ],
                );
                words(&mut out, &v.tab_stops);
                for range in &v.character_ranges {
                    words(&mut out, &[range[0] as u32, range[1] as u32]);
                }
            }
            Self::BitmapImage {
                version,
                width,
                height,
                stride,
                pixel_format,
                bitmap_type,
                data,
            } => {
                words(
                    &mut out,
                    &[
                        *version,
                        1,
                        *width as u32,
                        *height as u32,
                        *stride as u32,
                        *pixel_format,
                        *bitmap_type,
                    ],
                );
                out.extend_from_slice(data);
            }
            Self::MetafileImage {
                version,
                metafile_type,
                data,
                suffix,
            } => {
                words(&mut out, &[*version, 2, *metafile_type, data.len() as u32]);
                out.extend_from_slice(data);
                out.extend_from_slice(suffix);
            }
            Self::Opaque { bytes, .. } => out.extend_from_slice(bytes),
        }
        Ok(out)
    }
}
fn words(out: &mut Vec<u8>, values: &[u32]) {
    for v in values {
        out.extend_from_slice(&v.to_le_bytes());
    }
}
struct Reader<'a, 'b, 'c> {
    bytes: &'a [u8],
    pos: usize,
    index: usize,
    budget: &'b mut Budget<'c>,
}
impl Reader<'_, '_, '_> {
    fn error(&self) -> Error {
        Error::InvalidObject {
            record_index: self.index,
            reason: "invalid object count/layout",
        }
    }
    fn remaining(&self) -> usize {
        self.bytes.len() - self.pos
    }
    fn take(&mut self, count: usize) -> Result<&[u8], Error> {
        if count > self.remaining() {
            return Err(self.error());
        }
        let start = self.pos;
        self.pos += count;
        Ok(&self.bytes[start..self.pos])
    }
    fn word(&mut self) -> Result<u32, Error> {
        Ok(u32::from_le_bytes(self.take(4)?.try_into().unwrap()))
    }
    fn words<const N: usize>(&mut self) -> Result<[u32; N], Error> {
        let mut out = [0; N];
        for v in &mut out {
            *v = self.word()?;
        }
        Ok(out)
    }
    fn require_count(&self, count: usize, stride: usize) -> Result<(), Error> {
        if count > self.remaining() / stride {
            Err(self.error())
        } else {
            Ok(())
        }
    }
    fn vector<T>(&mut self, count: usize) -> Result<Vec<T>, Error> {
        let bytes = count
            .checked_mul(std::mem::size_of::<T>())
            .ok_or_else(|| self.error())?;
        self.budget.charge_alloc(bytes)?;
        self.budget.charge_work(count as u64)?;
        Ok(try_vec_with_capacity(count)?)
    }
    fn bytes(&mut self, count: usize) -> Result<Vec<u8>, Error> {
        self.require_count(count, 1)?;
        self.budget.charge_alloc(count)?;
        self.budget.charge_work((count as u64).div_ceil(16))?;
        let mut out = try_vec_with_capacity(count)?;
        out.extend_from_slice(self.take(count)?);
        Ok(out)
    }
    fn rest(&mut self) -> Result<Vec<u8>, Error> {
        self.bytes(self.remaining())
    }
}
