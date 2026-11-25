//! The pixel surface: RGBA-8 decoding of the IDAT stream. Supports every
//! color type (0/2/3/4/6) at its legal bit depths, with or without Adam7
//! interlacing, plus tRNS alpha.
use crate::zlib::zlib_decompress;
use crate::{Error, Ihdr, Png};

/// A decoded image: row-major RGBA-8 pixels.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Surface {
    pub width: u32,
    pub height: u32,
    /// `width * height * 4` bytes.
    pub rgba: Vec<u8>,
}

const ADAM7_X_START: [usize; 7] = [0, 4, 0, 2, 0, 1, 0];
const ADAM7_Y_START: [usize; 7] = [0, 0, 4, 0, 2, 0, 1];
const ADAM7_X_STEP: [usize; 7] = [8, 8, 4, 4, 2, 2, 1];
const ADAM7_Y_STEP: [usize; 7] = [8, 8, 8, 4, 4, 2, 2];

fn pass_extent(start: usize, step: usize, extent: usize) -> usize {
    if extent > start {
        (extent - start).div_ceil(step)
    } else {
        0
    }
}

fn row_bytes(pixels: usize, pixel_depth: usize) -> usize {
    pixels
        .checked_mul(pixel_depth)
        .map(|n| n.div_ceil(8))
        .unwrap_or(usize::MAX)
}

/// Decode the model's pixels to an RGBA-8 [`Surface`].
pub fn surface(png: &Png) -> Result<Surface, Error> {
    let ihdr = &png.ihdr;
    let channels = channels_for(ihdr.color_type);
    let pixel_depth = usize::from(ihdr.bit_depth) * channels;
    let width = ihdr.width as usize;
    let height = ihdr.height as usize;
    let interlaced = ihdr.interlace_method == 1;

    let compressed = png.idat();
    let raw = zlib_decompress(&compressed)?;

    let mut rgba = vec![
        0u8;
        width
            .checked_mul(height)
            .and_then(|n| n.checked_mul(4))
            .ok_or(Error::ZlibOverflow)?
    ];
    let mut cursor = 0usize;

    let passes = if interlaced { 7 } else { 1 };
    for pass in 0..passes {
        let pw = if interlaced {
            pass_extent(ADAM7_X_START[pass], ADAM7_X_STEP[pass], width)
        } else {
            width
        };
        let ph = if interlaced {
            pass_extent(ADAM7_Y_START[pass], ADAM7_Y_STEP[pass], height)
        } else {
            height
        };
        if pw == 0 || ph == 0 {
            continue;
        }
        let rb = row_bytes(pw, pixel_depth);
        let mut prev = vec![0u8; rb];
        for py in 0..ph {
            let filter = *raw.get(cursor).ok_or(Error::Zlib("missing filter byte"))?;
            let row = raw
                .get(cursor + 1..cursor + 1 + rb)
                .ok_or(Error::Zlib("truncated scanline"))?;
            cursor += 1 + rb;
            let mut unfiltered = vec![0u8; rb];
            unfilter_row(filter, row, &prev, &mut unfiltered, pixel_depth)?;
            prev = unfiltered.clone();
            for px in 0..pw {
                let (r, g, b, a) = sample(&unfiltered, px, pixel_depth, ihdr, png)?;
                let (x, y) = if interlaced {
                    (
                        ADAM7_X_START[pass] + px * ADAM7_X_STEP[pass],
                        ADAM7_Y_START[pass] + py * ADAM7_Y_STEP[pass],
                    )
                } else {
                    (px, py)
                };
                let at = (y * width + x) * 4;
                rgba[at..at + 4].copy_from_slice(&[r, g, b, a]);
            }
        }
    }
    if cursor != raw.len() {
        return Err(Error::Zlib("trailing bytes after final scanline"));
    }
    Ok(Surface {
        width: ihdr.width,
        height: ihdr.height,
        rgba,
    })
}

fn channels_for(color_type: u8) -> usize {
    match color_type {
        0 | 3 => 1,
        2 => 3,
        4 => 2,
        _ => 4,
    }
}

fn unfilter_row(
    filter: u8,
    row: &[u8],
    prev: &[u8],
    out: &mut [u8],
    pixel_depth: usize,
) -> Result<(), Error> {
    let bpp = pixel_depth.div_ceil(8).max(1);
    for i in 0..out.len() {
        let x = row[i];
        let a = if i >= bpp { out[i - bpp] } else { 0 };
        let b = prev[i];
        let c = if i >= bpp { prev[i - bpp] } else { 0 };
        out[i] = match filter {
            0 => x,
            1 => a.wrapping_add(x),
            2 => b.wrapping_add(x),
            3 => ((usize::from(a) + usize::from(b)) / 2).wrapping_add(usize::from(x)) as u8,
            4 => paeth(a, b, c).wrapping_add(x),
            _ => return Err(Error::Zlib("unknown filter type")),
        };
    }
    Ok(())
}

fn paeth(a: u8, b: u8, c: u8) -> u8 {
    let p = i16::from(a) + i16::from(b) - i16::from(c);
    let pa = p.abs_diff(i16::from(a));
    let pb = p.abs_diff(i16::from(b));
    let pc = p.abs_diff(i16::from(c));
    if pa <= pb && pa <= pc {
        a
    } else if pb <= pc {
        b
    } else {
        c
    }
}

fn sample(
    row: &[u8],
    x: usize,
    pixel_depth: usize,
    ihdr: &Ihdr,
    png: &Png,
) -> Result<(u8, u8, u8, u8), Error> {
    let depth = usize::from(ihdr.bit_depth);
    let get = |index: usize| -> Result<u64, Error> {
        let bit =
            (x * pixel_depth / usize::from(ihdr.bit_depth) + index) * usize::from(ihdr.bit_depth);
        let byte_index = bit / 8;
        if depth == 16 {
            let hi = *row
                .get(byte_index)
                .ok_or(Error::Zlib("scanline too short"))?;
            let lo = *row
                .get(byte_index + 1)
                .ok_or(Error::Zlib("scanline too short"))?;
            return Ok(u64::from(hi) << 8 | u64::from(lo));
        }
        let byte = *row
            .get(byte_index)
            .ok_or(Error::Zlib("scanline too short"))?;
        let shift = 8 - depth - (bit % 8);
        Ok(u64::from(byte >> shift) & ((1 << depth) - 1))
    };
    // 8-bit rendering of a raw sample: 16-bit truncates to the high byte,
    // sub-byte depths scale across the full range (per the PNG spec), 8-bit
    // passes through.
    let to8 = |v: u64| -> u8 {
        match depth {
            16 => (v >> 8) as u8,
            8 => v as u8,
            _ => ((v * 255) / ((1 << depth) - 1)) as u8,
        }
    };
    match ihdr.color_type {
        0 => {
            let g = get(0)?;
            let alpha = match trns_sample(png) {
                Some(key) if g == key => 0,
                _ => 255,
            };
            let v = to8(g);
            Ok((v, v, v, alpha))
        }
        2 => {
            let r = get(0)?;
            let g = get(1)?;
            let b = get(2)?;
            let alpha = match trns_sample(png) {
                Some(key) if r == key => 0,
                _ => 255,
            };
            Ok((to8(r), to8(g), to8(b), alpha))
        }
        3 => {
            let index = get(0)? as usize;
            let plte = png
                .chunks
                .iter()
                .find(|c| &c.kind == b"PLTE")
                .ok_or(Error::Format("palette color type without PLTE"))?;
            let entry = index * 3;
            let r = *plte
                .data
                .get(entry)
                .ok_or(Error::Format("palette index out of range"))?;
            let g = *plte
                .data
                .get(entry + 1)
                .ok_or(Error::Format("palette index out of range"))?;
            let b = *plte
                .data
                .get(entry + 2)
                .ok_or(Error::Format("palette index out of range"))?;
            let a = match png.chunks.iter().find(|c| &c.kind == b"tRNS") {
                Some(trns) => trns.data.get(index).copied().unwrap_or(255),
                None => 255,
            };
            Ok((r, g, b, a))
        }
        4 => {
            let g = get(0)?;
            let a = get(1)?;
            let v = to8(g);
            Ok((v, v, v, to8(a)))
        }
        _ => {
            let r = get(0)?;
            let g = get(1)?;
            let b = get(2)?;
            let a = get(3)?;
            Ok((to8(r), to8(g), to8(b), to8(a)))
        }
    }
}

/// The tRNS key sample for color types 0 and 2, always stored as a 16-bit
/// big-endian value regardless of the image bit depth.
fn trns_sample(png: &Png) -> Option<u64> {
    let trns = png.chunks.iter().find(|c| &c.kind == b"tRNS")?;
    let hi = *trns.data.first()?;
    let lo = *trns.data.get(1).unwrap_or(&0);
    Some(u64::from(u16::from_be_bytes([hi, lo])))
}

#[cfg(test)]
mod tests {
    use crate::{encode_rgba8, Png};

    #[test]
    fn decode_matches_encode() {
        let mut rgba = Vec::new();
        for y in 0..9u8 {
            for x in 0..13u8 {
                rgba.extend_from_slice(&[x.wrapping_mul(17), y.wrapping_mul(23), x ^ y, 255 - x]);
            }
        }
        let png = encode_rgba8(13, 9, &rgba).expect("encode");
        let model = Png::decode(&png).expect("decode");
        let surface = crate::surface::surface(&model).expect("surface");
        assert_eq!(surface.rgba, rgba);
    }
}
