//! MS-EMFPLUS 2.2.2.24–25: linear gradient data shared by brushes and pens.
use super::{words, Reader};
use crate::{emf_plus::Error, SerializeFailure};

/// Floating-point fields retain IEEE bits; reserved words are preserved.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct LinearGradient {
    pub flags: u32,
    pub wrap_mode: i32,
    pub rectangle: [u32; 4],
    pub start_color: u32,
    pub end_color: u32,
    pub reserved: [u32; 2],
    pub transform: Option<[u32; 6]>,
    /// One preset-color blend (0x4), or vertical (0x10) then horizontal
    /// (0x8) factor blends, selecting only the flags present. Each pair is
    /// [position bits, ARGB or factor bits]. Wire arrays are stored separately.
    pub blends: Vec<Vec<[u32; 2]>>,
}
fn valid(flags: u32) -> bool {
    flags & !0x9e == 0 && (flags & 4 == 0 || flags & 0x18 == 0)
}
impl LinearGradient {
    pub(super) fn layout(&self) -> Result<(usize, u64), SerializeFailure> {
        if !valid(self.flags)
            || self.transform.is_some() != (self.flags & 2 != 0)
            || self.blends.len() != (self.flags & 0x1c).count_ones() as usize
            || (self.flags & 4 == 0 && self.blends.iter().any(|b| b.len() < 2))
        {
            return Err(SerializeFailure::Inconsistent { offset: 0 });
        }
        let mut size = 40usize + if self.transform.is_some() { 24 } else { 0 };
        let mut work = self.blends.len() as u64;
        for blend in &self.blends {
            if blend.len() > u32::MAX as usize {
                return Err(SerializeFailure::SizeOverflow);
            }
            size = blend
                .len()
                .checked_mul(8)
                .and_then(|n| n.checked_add(4))
                .and_then(|n| size.checked_add(n))
                .ok_or(SerializeFailure::SizeOverflow)?;
            work = work
                .checked_add(blend.len() as u64)
                .ok_or(SerializeFailure::SizeOverflow)?;
        }
        Ok((size, work))
    }
    pub(super) fn write(&self, out: &mut Vec<u8>) {
        words(out, &[self.flags, self.wrap_mode as u32]);
        words(out, &self.rectangle);
        words(out, &[self.start_color, self.end_color]);
        words(out, &self.reserved);
        if let Some(v) = self.transform {
            words(out, &v);
        }
        for blend in &self.blends {
            words(out, &[blend.len() as u32]);
            for column in 0..2 {
                for pair in blend {
                    words(out, &[pair[column]]);
                }
            }
        }
    }
}
pub(super) fn read(r: &mut Reader<'_, '_, '_>) -> Result<Option<LinearGradient>, Error> {
    let flags = r.word()?;
    if flags & !0x9e != 0 {
        return Ok(None);
    }
    if !valid(flags) {
        return Err(r.error());
    }
    let wrap_mode = r.word()? as i32;
    let rectangle = r.words()?;
    let start_color = r.word()?;
    let end_color = r.word()?;
    let reserved = r.words()?;
    let transform = if flags & 2 != 0 {
        Some(r.words()?)
    } else {
        None
    };
    let mut blends = r.vector((flags & 0x1c).count_ones() as usize)?;
    for _ in 0..(flags & 0x1c).count_ones() {
        let count = r.word()? as usize;
        if flags & 4 == 0 && count < 2 {
            return Err(r.error());
        }
        r.require_count(count, 8)?;
        let mut blend = r.vector(count)?;
        for _ in 0..count {
            blend.push([r.word()?, 0]);
        }
        for pair in &mut blend {
            pair[1] = r.word()?;
        }
        blends.push(blend);
    }
    Ok(Some(LinearGradient {
        flags,
        wrap_mode,
        rectangle,
        start_color,
        end_color,
        reserved,
        transform,
        blends,
    }))
}
