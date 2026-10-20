//! MS-EMFPLUS 2.2.2.29–30: path gradient brushes.
use super::{path, words, Path, Reader};
use crate::{emf_plus::Error, SerializeFailure};
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GradientBoundary {
    Path(Path),
    /// EmfPlusPointF coordinates as raw IEEE words.
    Points(Vec<[u32; 2]>),
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PathGradient {
    pub flags: u32,
    pub wrap_mode: i32,
    pub center_color: u32,
    pub center_point: [u32; 2],
    pub surrounding_colors: Vec<u32>,
    pub boundary: GradientBoundary,
    pub transform: Option<[u32; 6]>,
    /// Position bits paired with ARGB (flag 0x4) or factor bits (flag 0x8).
    pub blend: Option<Vec<[u32; 2]>>,
    /// Raw IEEE words. The serialized FocusScaleCount is always two.
    pub focus_scales: Option<[u32; 2]>,
}
fn valid(flags: u32) -> bool {
    flags & !0xcf == 0 && flags & 0xc != 0xc
}
impl PathGradient {
    pub(super) fn layout(&self) -> Result<(usize, u64), SerializeFailure> {
        if !valid(self.flags)
            || matches!(self.boundary, GradientBoundary::Path(_)) != (self.flags & 1 != 0)
            || self.transform.is_some() != (self.flags & 2 != 0)
            || self.blend.is_some() != (self.flags & 0xc != 0)
            || self.focus_scales.is_some() != (self.flags & 0x40 != 0)
            || (self.flags & 8 != 0 && self.blend.as_ref().is_some_and(|v| v.len() < 2))
        {
            return Err(SerializeFailure::Inconsistent { offset: 0 });
        }
        let overflow = || SerializeFailure::SizeOverflow;
        if self.surrounding_colors.len() > u32::MAX as usize {
            return Err(overflow());
        }
        let mut size = self
            .surrounding_colors
            .len()
            .checked_mul(4)
            .and_then(|n| n.checked_add(24))
            .ok_or_else(overflow)?;
        let mut work = self.surrounding_colors.len() as u64;
        let (boundary_size, boundary_work) = match &self.boundary {
            GradientBoundary::Path(p) => {
                let (n, w) = p.layout()?;
                if n > i32::MAX as usize {
                    return Err(overflow());
                }
                (n, w)
            }
            GradientBoundary::Points(v) => {
                if v.len() > i32::MAX as usize {
                    return Err(overflow());
                }
                (v.len().checked_mul(8).ok_or_else(overflow)?, v.len() as u64)
            }
        };
        size = size
            .checked_add(4)
            .and_then(|n| n.checked_add(boundary_size))
            .ok_or_else(overflow)?;
        work = work.checked_add(boundary_work).ok_or_else(overflow)?;
        if self.transform.is_some() {
            size = size.checked_add(24).ok_or_else(overflow)?;
        }
        if let Some(v) = &self.blend {
            if v.len() > u32::MAX as usize {
                return Err(overflow());
            }
            size = v
                .len()
                .checked_mul(8)
                .and_then(|n| n.checked_add(4))
                .and_then(|n| size.checked_add(n))
                .ok_or_else(overflow)?;
            work = work.checked_add(v.len() as u64).ok_or_else(overflow)?;
        }
        if self.focus_scales.is_some() {
            size = size.checked_add(12).ok_or_else(overflow)?;
        }
        Ok((size, work))
    }
    pub(super) fn write(&self, out: &mut Vec<u8>) {
        words(out, &[self.flags, self.wrap_mode as u32, self.center_color]);
        words(out, &self.center_point);
        words(out, &[self.surrounding_colors.len() as u32]);
        words(out, &self.surrounding_colors);
        match &self.boundary {
            GradientBoundary::Path(p) => {
                let start = out.len();
                words(out, &[0]);
                p.write(out);
                let n = (out.len() - start - 4) as u32;
                out[start..start + 4].copy_from_slice(&n.to_le_bytes());
            }
            GradientBoundary::Points(v) => {
                words(out, &[v.len() as u32]);
                for p in v {
                    words(out, p);
                }
            }
        }
        if let Some(v) = self.transform {
            words(out, &v);
        }
        if let Some(v) = &self.blend {
            words(out, &[v.len() as u32]);
            for column in 0..2 {
                for p in v {
                    words(out, &[p[column]]);
                }
            }
        }
        if let Some(v) = self.focus_scales {
            words(out, &[2]);
            words(out, &v);
        }
    }
}
pub(super) fn read(r: &mut Reader<'_, '_, '_>) -> Result<Option<PathGradient>, Error> {
    let flags = r.word()?;
    if flags & !0xcf != 0 {
        return Ok(None);
    }
    if !valid(flags) {
        return Err(r.error());
    }
    let wrap_mode = r.word()? as i32;
    let center_color = r.word()?;
    let center_point = r.words()?;
    let count = r.word()? as usize;
    r.require_count(count, 4)?;
    let mut surrounding_colors = r.vector(count)?;
    for _ in 0..count {
        surrounding_colors.push(r.word()?);
    }
    let count = r.word()? as i32;
    if count < 0 {
        return Err(r.error());
    }
    let count = count as usize;
    let boundary = if flags & 1 != 0 {
        let bytes = r.bytes;
        let start = r.pos;
        r.take(count)?;
        let mut nested = Reader {
            bytes: &bytes[start..start + count],
            pos: 0,
            index: r.index,
            budget: r.budget,
        };
        GradientBoundary::Path(path::read(&mut nested)?)
    } else {
        r.require_count(count, 8)?;
        let mut v = r.vector(count)?;
        for _ in 0..count {
            v.push(r.words()?);
        }
        GradientBoundary::Points(v)
    };
    let transform = if flags & 2 != 0 {
        Some(r.words()?)
    } else {
        None
    };
    let blend = if flags & 0xc != 0 {
        let count = r.word()? as usize;
        if flags & 8 != 0 && count < 2 {
            return Err(r.error());
        }
        r.require_count(count, 8)?;
        let mut v = r.vector(count)?;
        for _ in 0..count {
            v.push([r.word()?, 0]);
        }
        for p in &mut v {
            p[1] = r.word()?;
        }
        Some(v)
    } else {
        None
    };
    let focus_scales = if flags & 0x40 != 0 {
        if r.word()? != 2 {
            return Err(r.error());
        }
        Some(r.words()?)
    } else {
        None
    };
    Ok(Some(PathGradient {
        flags,
        wrap_mode,
        center_color,
        center_point,
        surrounding_colors,
        boundary,
        transform,
        blend,
        focus_scales,
    }))
}
