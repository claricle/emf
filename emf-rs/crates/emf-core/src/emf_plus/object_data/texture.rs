//! Texture brushes, MS-EMFPLUS 2.2.2.45–46. Image bytes stay unexpanded.
use super::{words, Reader};
use crate::{emf_plus::Error, SerializeFailure};
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum TextureImage {
    PixelBitmap(super::PixelBitmap),
    Bitmap {
        version: u32,
        width: i32,
        height: i32,
        stride: i32,
        pixel_format: u32,
        bitmap_type: u32,
        data: Vec<u8>,
    },
    Metafile {
        version: u32,
        metafile_type: u32,
        data: Vec<u8>,
        suffix: Vec<u8>,
    },
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Texture {
    pub flags: u32,
    pub wrap_mode: i32,
    pub transform: Option<[u32; 6]>,
    pub image: Option<TextureImage>,
}
impl Texture {
    pub(super) fn layout(&self) -> Result<(usize, u64), SerializeFailure> {
        if self.flags & !0x182 != 0 || self.transform.is_some() != (self.flags & 2 != 0) {
            return Err(SerializeFailure::Inconsistent { offset: 0 });
        }
        let mut size = if self.transform.is_some() {
            32usize
        } else {
            8usize
        };
        let mut elements = 0;
        let image_size = match &self.image {
            Some(TextureImage::PixelBitmap(v)) => {
                let (size, work) = v.layout()?;
                elements = work;
                size
            }
            None => 0,
            Some(TextureImage::Bitmap { data, .. }) => 28usize
                .checked_add(data.len())
                .ok_or(SerializeFailure::SizeOverflow)?,
            Some(TextureImage::Metafile { data, suffix, .. }) => {
                if data.len() > u32::MAX as usize || suffix.len() > 3 {
                    return Err(SerializeFailure::Inconsistent { offset: 0 });
                }
                16usize
                    .checked_add(data.len())
                    .and_then(|n| n.checked_add(suffix.len()))
                    .ok_or(SerializeFailure::SizeOverflow)?
            }
        };
        size = size
            .checked_add(image_size)
            .ok_or(SerializeFailure::SizeOverflow)?;
        Ok((size, elements))
    }
    pub(super) fn write(&self, out: &mut Vec<u8>) {
        words(out, &[self.flags, self.wrap_mode as u32]);
        if let Some(v) = self.transform {
            words(out, &v);
        }
        match &self.image {
            None => {}
            Some(TextureImage::PixelBitmap(v)) => v.write(out),
            Some(TextureImage::Bitmap {
                version,
                width,
                height,
                stride,
                pixel_format,
                bitmap_type,
                data,
            }) => {
                words(
                    out,
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
            Some(TextureImage::Metafile {
                version,
                metafile_type,
                data,
                suffix,
            }) => {
                words(out, &[*version, 2, *metafile_type, data.len() as u32]);
                out.extend_from_slice(data);
                out.extend_from_slice(suffix);
            }
        }
    }
}
pub(super) fn read(r: &mut Reader<'_, '_, '_>) -> Result<Option<Texture>, Error> {
    let flags = r.word()?;
    if flags & !0x182 != 0 {
        return Ok(None);
    }
    let wrap_mode = r.word()? as i32;
    let transform = if flags & 2 != 0 {
        Some(r.words()?)
    } else {
        None
    };
    let image = if r.remaining() == 0 {
        None
    } else {
        let version = r.word()?;
        Some(match r.word()? {
            1 => super::bitmap::read(r, version)?,
            2 => {
                let metafile_type = r.word()?;
                let count = r.word()? as usize;
                let data = r.bytes(count)?;
                if r.remaining() > 3 {
                    return Err(r.error());
                }
                TextureImage::Metafile {
                    version,
                    metafile_type,
                    data,
                    suffix: r.rest()?,
                }
            }
            _ => return Ok(None),
        })
    };
    Ok(Some(Texture {
        flags,
        wrap_mode,
        transform,
        image,
    }))
}
