//! Terminal-server graphics state (MS-EMFPLUS 2.3.8.2).
use super::Error;
use crate::limits::{try_vec_with_capacity, Budget};

/// Palette colors retain ARGB words and uninterpreted style flags.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Palette {
    pub style_flags: u32,
    pub entries: Vec<u32>,
}

/// Raw rendering enums and transform float bits, without rendering interpretation.
/// The record's T flag must agree with `palette` presence; V and ignored flags
/// remain in the enclosing Record. PaletteCount derives from the entries on write.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct TSGraphics {
    pub anti_alias_mode: u8,
    pub text_render_hint: u8,
    pub compositing_mode: u8,
    pub compositing_quality: u8,
    pub render_origin: [i16; 2],
    pub text_contrast: u16,
    pub filter_type: u8,
    pub pixel_offset: u8,
    pub world_to_device: [u32; 6],
    pub palette: Option<Palette>,
}
impl TSGraphics {
    pub(crate) fn element_work(&self) -> u64 {
        self.palette.as_ref().map_or(0, |p| p.entries.len() as u64)
    }
    pub(crate) fn len(&self) -> usize {
        36usize.saturating_add(
            self.palette
                .as_ref()
                .map_or(0, |p| p.entries.len().saturating_mul(4).saturating_add(8)),
        )
    }
    pub(crate) fn valid(&self, kind: u16, flags: u16) -> bool {
        kind == 0x4039
            && (flags & 1 != 0) == self.palette.is_some()
            && self
                .palette
                .as_ref()
                .map_or(true, |p| p.entries.len() <= u32::MAX as usize)
    }
    pub(crate) fn write(&self, out: &mut Vec<u8>) {
        out.extend([
            self.anti_alias_mode,
            self.text_render_hint,
            self.compositing_mode,
            self.compositing_quality,
        ]);
        for n in self.render_origin {
            out.extend(n.to_le_bytes());
        }
        out.extend(self.text_contrast.to_le_bytes());
        out.extend([self.filter_type, self.pixel_offset]);
        for n in self.world_to_device {
            out.extend(n.to_le_bytes());
        }
        if let Some(p) = &self.palette {
            out.extend(p.style_flags.to_le_bytes());
            out.extend((p.entries.len() as u32).to_le_bytes());
            for n in &p.entries {
                out.extend(n.to_le_bytes());
            }
        }
    }
}
pub(crate) fn decode(
    bytes: &[u8],
    flags: u16,
    offset: usize,
    budget: &mut Budget<'_>,
) -> Result<TSGraphics, Error> {
    let invalid = || Error::InvalidRecord {
        offset,
        reason: "invalid terminal-server graphics layout",
    };
    if bytes.len() < 36 {
        return Err(invalid());
    }
    let word = |i: usize| u32::from_le_bytes(bytes[i..i + 4].try_into().unwrap());
    let palette = if flags & 1 != 0 {
        if bytes.len() < 44 || (bytes.len() - 44) % 4 != 0 {
            return Err(invalid());
        }
        let count = word(40) as usize;
        if count != (bytes.len() - 44) / 4 {
            return Err(invalid());
        }
        budget.charge_alloc(bytes.len() - 44)?;
        budget.charge_work(count as u64)?;
        let mut entries = try_vec_with_capacity(count)?;
        for i in 0..count {
            entries.push(word(44 + i * 4));
        }
        Some(Palette {
            style_flags: word(36),
            entries,
        })
    } else {
        if bytes.len() != 36 {
            return Err(invalid());
        }
        None
    };
    Ok(TSGraphics {
        anti_alias_mode: bytes[0],
        text_render_hint: bytes[1],
        compositing_mode: bytes[2],
        compositing_quality: bytes[3],
        render_origin: [
            i16::from_le_bytes(bytes[4..6].try_into().unwrap()),
            i16::from_le_bytes(bytes[6..8].try_into().unwrap()),
        ],
        text_contrast: u16::from_le_bytes(bytes[8..10].try_into().unwrap()),
        filter_type: bytes[10],
        pixel_offset: bytes[11],
        world_to_device: std::array::from_fn(|i| word(12 + i * 4)),
        palette,
    })
}
