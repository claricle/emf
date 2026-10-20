//! MS-EMFPLUS 2.2.2.2–3: known bitmap formats, without pixel expansion.
use super::{texture::TextureImage, words, Reader};
use crate::{
    emf_plus::{Error, Palette},
    SerializeFailure,
};

/// Bitmap metadata and a typed optional palette. Pixel bytes, row padding and
/// signed dimensions/stride are preserved as supplied, without raster validation.
/// The palette is present exactly when PixelFormat's I flag is set. Type is 0.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PixelBitmap {
    pub version: u32,
    pub width: i32,
    pub height: i32,
    pub stride: i32,
    pub pixel_format: u32,
    pub palette: Option<Palette>,
    pub pixels: Vec<u8>,
}
fn known(format: u32) -> bool {
    // The upper ten bits are reserved and ignored, but retained on write.
    matches!(
        format & 0x003fffff,
        0x00030101
            | 0x00030402
            | 0x00030803
            | 0x00101004
            | 0x00021005
            | 0x00021006
            | 0x00061007
            | 0x00021808
            | 0x00022009
            | 0x0026200a
            | 0x000e200b
            | 0x0010300c
            | 0x0034400d
            | 0x001a400e
    )
}
impl PixelBitmap {
    pub(super) fn layout(&self) -> Result<(usize, u64), SerializeFailure> {
        if !known(self.pixel_format) || (self.pixel_format & 0x10000 != 0) != self.palette.is_some()
        {
            return Err(SerializeFailure::Inconsistent { offset: 0 });
        }
        let mut size = 28usize
            .checked_add(self.pixels.len())
            .ok_or(SerializeFailure::SizeOverflow)?;
        let mut elements = 0;
        if let Some(p) = &self.palette {
            if p.entries.len() > u32::MAX as usize {
                return Err(SerializeFailure::SizeOverflow);
            }
            size = p
                .entries
                .len()
                .checked_mul(4)
                .and_then(|n| n.checked_add(8))
                .and_then(|n| n.checked_add(size))
                .ok_or(SerializeFailure::SizeOverflow)?;
            elements = p.entries.len() as u64;
        }
        Ok((size, elements))
    }
    pub(super) fn write(&self, out: &mut Vec<u8>) {
        words(
            out,
            &[
                self.version,
                1,
                self.width as u32,
                self.height as u32,
                self.stride as u32,
                self.pixel_format,
                0,
            ],
        );
        if let Some(p) = &self.palette {
            words(out, &[p.style_flags, p.entries.len() as u32]);
            words(out, &p.entries);
        }
        out.extend_from_slice(&self.pixels);
    }
}
pub(super) fn read(r: &mut Reader<'_, '_, '_>, version: u32) -> Result<TextureImage, Error> {
    let width = r.word()? as i32;
    let height = r.word()? as i32;
    let stride = r.word()? as i32;
    let pixel_format = r.word()?;
    let bitmap_type = r.word()?;
    if bitmap_type != 0 || !known(pixel_format) {
        return Ok(TextureImage::Bitmap {
            version,
            width,
            height,
            stride,
            pixel_format,
            bitmap_type,
            data: r.rest()?,
        });
    }
    let palette = if pixel_format & 0x10000 != 0 {
        let style_flags = r.word()?;
        let count = r.word()? as usize;
        r.require_count(count, 4)?;
        let mut entries = r.vector(count)?;
        for _ in 0..count {
            entries.push(r.word()?);
        }
        Some(Palette {
            style_flags,
            entries,
        })
    } else {
        None
    };
    Ok(TextureImage::PixelBitmap(PixelBitmap {
        version,
        width,
        height,
        stride,
        pixel_format,
        palette,
        pixels: r.rest()?,
    }))
}
