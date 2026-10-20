//! Custom line caps (2.2.1.2, 2.2.2.12–14). Float fields retain IEEE bits.
use super::{path, words, Path, Reader};
use crate::{emf_plus::Error, SerializeFailure};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CustomLineCap {
    pub version: u32,
    pub data: CustomLineCapData,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum CustomLineCapData {
    Default(DefaultLineCap),
    AdjustableArrow(ArrowLineCap),
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DefaultLineCap {
    /// Bits 1/2 select fill/line paths; flags and option presence must agree.
    pub flags: u32,
    pub base_cap: u32,
    pub base_inset: u32,
    pub stroke_start_cap: u32,
    pub stroke_end_cap: u32,
    pub stroke_join: u32,
    pub stroke_miter_limit: u32,
    pub width_scale: u32,
    pub fill_hot_spot: [u32; 2],
    pub stroke_hot_spot: [u32; 2],
    pub fill_path: Option<Path>,
    pub line_path: Option<Path>,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ArrowLineCap {
    pub width: u32,
    pub height: u32,
    pub middle_inset: u32,
    /// Raw Boolean, including noncanonical nonzero values.
    pub fill_state: u32,
    pub line_start_cap: u32,
    pub line_end_cap: u32,
    pub line_join: u32,
    pub line_miter_limit: u32,
    pub width_scale: u32,
    pub fill_hot_spot: [u32; 2],
    pub line_hot_spot: [u32; 2],
}
impl CustomLineCap {
    pub(super) fn layout(&self) -> Result<(usize, u64), SerializeFailure> {
        match &self.data {
            CustomLineCapData::AdjustableArrow(_) => Ok((60, 0)),
            CustomLineCapData::Default(v) => {
                if v.flags & !3 != 0
                    || (v.flags & 1 != 0) != v.fill_path.is_some()
                    || (v.flags & 2 != 0) != v.line_path.is_some()
                {
                    return Err(SerializeFailure::Inconsistent { offset: 0 });
                }
                let mut size = 56usize;
                let mut work = 0u64;
                for p in [&v.fill_path, &v.line_path].into_iter().flatten() {
                    let (len, units) = p.layout()?;
                    if len > i32::MAX as usize {
                        return Err(SerializeFailure::SizeOverflow);
                    }
                    size = size
                        .checked_add(4)
                        .and_then(|n| n.checked_add(len))
                        .ok_or(SerializeFailure::SizeOverflow)?;
                    work = work
                        .checked_add(units)
                        .ok_or(SerializeFailure::SizeOverflow)?;
                }
                Ok((size, work))
            }
        }
    }
    pub(super) fn write(&self, out: &mut Vec<u8>) {
        match &self.data {
            CustomLineCapData::Default(v) => {
                words(
                    out,
                    &[
                        self.version,
                        0,
                        v.flags,
                        v.base_cap,
                        v.base_inset,
                        v.stroke_start_cap,
                        v.stroke_end_cap,
                        v.stroke_join,
                        v.stroke_miter_limit,
                        v.width_scale,
                    ],
                );
                words(out, &v.fill_hot_spot);
                words(out, &v.stroke_hot_spot);
                for p in [&v.fill_path, &v.line_path].into_iter().flatten() {
                    let start = out.len();
                    words(out, &[0]);
                    p.write(out);
                    let len = (out.len() - start - 4) as u32;
                    out[start..start + 4].copy_from_slice(&len.to_le_bytes());
                }
            }
            CustomLineCapData::AdjustableArrow(v) => {
                words(
                    out,
                    &[
                        self.version,
                        1,
                        v.width,
                        v.height,
                        v.middle_inset,
                        v.fill_state,
                        v.line_start_cap,
                        v.line_end_cap,
                        v.line_join,
                        v.line_miter_limit,
                        v.width_scale,
                    ],
                );
                words(out, &v.fill_hot_spot);
                words(out, &v.line_hot_spot);
            }
        }
    }
}
fn read_path(r: &mut Reader<'_, '_, '_>) -> Result<Path, Error> {
    let len = r.word()?;
    if len > i32::MAX as u32 {
        return Err(r.error());
    }
    let len = len as usize;
    let bytes = r.bytes;
    let start = r.pos;
    r.take(len)?;
    let mut nested = Reader {
        bytes: &bytes[start..start + len],
        pos: 0,
        index: r.index,
        budget: r.budget,
    };
    path::read(&mut nested)
}
pub(super) fn read(r: &mut Reader<'_, '_, '_>) -> Result<Option<CustomLineCap>, Error> {
    let version = r.word()?;
    let data = match r.word()? {
        0 => {
            let flags = r.word()?;
            // Unknown flags can introduce unframed fields. Preserve the entire body.
            if flags & !3 != 0 {
                return Ok(None);
            }
            CustomLineCapData::Default(DefaultLineCap {
                flags,
                base_cap: r.word()?,
                base_inset: r.word()?,
                stroke_start_cap: r.word()?,
                stroke_end_cap: r.word()?,
                stroke_join: r.word()?,
                stroke_miter_limit: r.word()?,
                width_scale: r.word()?,
                fill_hot_spot: r.words()?,
                stroke_hot_spot: r.words()?,
                fill_path: if flags & 1 != 0 {
                    Some(read_path(r)?)
                } else {
                    None
                },
                line_path: if flags & 2 != 0 {
                    Some(read_path(r)?)
                } else {
                    None
                },
            })
        }
        1 => CustomLineCapData::AdjustableArrow(ArrowLineCap {
            width: r.word()?,
            height: r.word()?,
            middle_inset: r.word()?,
            fill_state: r.word()?,
            line_start_cap: r.word()?,
            line_end_cap: r.word()?,
            line_join: r.word()?,
            line_miter_limit: r.word()?,
            width_scale: r.word()?,
            fill_hot_spot: r.words()?,
            line_hot_spot: r.words()?,
        }),
        _ => return Ok(None),
    };
    Ok(Some(CustomLineCap { version, data }))
}
