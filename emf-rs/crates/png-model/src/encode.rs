//! PNG emission matching libpng 1.6's default write path byte for byte.
//!
//! The Ruby ground truth (emfsvg's `PngEncoder`) calls libpng's classic
//! write API with `png_set_compression_level(6)` and `PNG_TRANSFORM_IDENTITY`.
//! This module reproduces that output without linking libpng:
//!
//! * the MAD (minimum sum of absolute differences) per-row filter heuristic
//!   from `png_write_find_filter`, evaluated NONE, SUB, UP, AVG, PAETH with
//!   strict `<` improvement and libpng's early-exit sums;
//! * zlib parameters from libpng's defaults: level 6, memLevel 8,
//!   `Z_FILTERED` strategy, and the `png_deflate_claim` windowBits reduction
//!   for small images (`data_size + 262 <= half_window_size`);
//! * the `optimize_cmf` rewrite of the first two zlib header bytes for
//!   images whose uncompressed scanline stream is at most 16384 bytes;
//! * IDAT chunks split at libpng's 8192-byte zbuffer boundaries.
//!
//! Only the deflate/inflate primitive comes from zlib (`libz-sys`, stock
//! zlib); the heuristic, framing, header optimization, and chunking are
//! implemented here.
use crate::zlib::zlib_compress;
use crate::{Chunk, Error, Ihdr, Png};

const ZBUF_SIZE: usize = 8192;

/// Encode RGBA-8 rows (row-major, `width * height * 4` bytes) as a PNG byte
/// stream using libpng 1.6's default write profile.
pub fn encode_rgba8(width: u32, height: u32, rgba: &[u8]) -> Result<Vec<u8>, Error> {
    encode_rgba8_level(width, height, rgba, 6)
}

/// Same, with an explicit zlib level (libpng's `png_set_compression_level`).
pub fn encode_rgba8_level(
    width: u32,
    height: u32,
    rgba: &[u8],
    level: i32,
) -> Result<Vec<u8>, Error> {
    if width == 0 || height == 0 {
        return Err(Error::Format("zero image dimension"));
    }
    let row_bytes = usize::try_from(width)
        .ok()
        .and_then(|w| w.checked_mul(4))
        .ok_or(Error::Format("row size overflow"))?;
    if rgba.len()
        < row_bytes
            .checked_mul(height as usize)
            .ok_or(Error::Format("image size overflow"))?
    {
        return Err(Error::Format("pixel buffer too short"));
    }

    // png_image_size: uncompressed scanline stream (rowbytes+1 per row),
    // 0xffffffff when out of the interesting range.
    let image_size: u64 = if row_bytes < 32768 && height < 32768 {
        (row_bytes as u64 + 1) * u64::from(height)
    } else {
        0xffff_ffff
    };

    // png_deflate_claim: reduce windowBits while data_size + 262 fits in the
    // smaller half-window.
    let mut window_bits = 15;
    if image_size <= 16384 {
        let mut half_window_size: u64 = 1 << (window_bits - 1);
        while image_size + 262 <= half_window_size {
            half_window_size >>= 1;
            window_bits -= 1;
        }
    }

    // Filter selection per row (libpng: prev_row starts zeroed).
    let mut filtered = Vec::with_capacity(image_size as usize);
    let mut prev = vec![0u8; row_bytes];
    for row in 0..height as usize {
        let start = row * row_bytes;
        let current = &rgba[start..start + row_bytes];
        let (filter_type, data) = find_filter(current, &prev);
        filtered.push(filter_type);
        filtered.extend_from_slice(&data);
        prev.copy_from_slice(current);
    }

    let mut compressed = zlib_compress(&filtered, level, window_bits)?;
    optimize_cmf(&mut compressed, image_size);

    // Chunk assembly: IHDR, IDAT(s) split at the zbuffer size, IEND.
    let ihdr = Ihdr {
        width,
        height,
        bit_depth: 8,
        color_type: 6,
        compression_method: 0,
        filter_method: 0,
        interlace_method: 0,
    };
    let mut chunks = vec![Chunk {
        kind: *b"IHDR",
        data: ihdr.serialize().to_vec(),
    }];
    for idat in compressed.chunks(ZBUF_SIZE) {
        chunks.push(Chunk {
            kind: *b"IDAT",
            data: idat.to_vec(),
        });
    }
    chunks.push(Chunk {
        kind: *b"IEND",
        data: Vec::new(),
    });
    Ok(Png { chunks, ihdr }.serialize())
}

/// libpng's `png_write_find_filter` MAD heuristic for the full filter set.
/// Returns the chosen filter type and its filtered bytes.
fn find_filter(row: &[u8], prev: &[u8]) -> (u8, Vec<u8>) {
    let bpp = 4; // RGBA-8
    let row_bytes = row.len();
    // mins starts at PNG_SIZE_MAX - 256; the row-length overflow guard
    // (PNG_SIZE_MAX/128 <= row_bytes) cannot trigger for in-memory rows.
    let mut mins: u64 = u64::MAX - 256;
    let mut best: Option<(u8, Vec<u8>)> = None;

    let mad = |v: u8| -> u64 {
        if v < 128 {
            u64::from(v)
        } else {
            u64::from(256 - u16::from(v))
        }
    };

    // NONE
    {
        let sum: u64 = row.iter().copied().map(mad).sum();
        if sum < mins {
            mins = sum;
            best = Some((0, row.to_vec()));
        }
    }

    // SUB
    {
        let mut data = Vec::with_capacity(row_bytes);
        let mut sum: u64 = 0;
        for (i, &x) in row.iter().enumerate() {
            let left = if i >= bpp { row[i - bpp] } else { 0 };
            let v = x.wrapping_sub(left);
            data.push(v);
            sum += mad(v);
        }
        if sum < mins {
            mins = sum;
            best = Some((1, data));
        }
    }

    // UP
    {
        let mut data = Vec::with_capacity(row_bytes);
        let mut sum: u64 = 0;
        for (i, &x) in row.iter().enumerate() {
            let v = x.wrapping_sub(prev[i]);
            data.push(v);
            sum += mad(v);
            if sum > mins {
                break;
            }
        }
        if sum < mins {
            mins = sum;
            best = Some((2, data));
        }
    }

    // AVG
    {
        let mut data = Vec::with_capacity(row_bytes);
        let mut sum: u64 = 0;
        for (i, &x) in row.iter().enumerate() {
            let a = if i >= bpp { row[i - bpp] } else { 0 };
            let b = prev[i];
            let v = x.wrapping_sub((((u16::from(a)) + u16::from(b)) / 2) as u8);
            data.push(v);
            sum += mad(v);
            if i >= bpp && sum > mins {
                break;
            }
        }
        if sum < mins {
            mins = sum;
            best = Some((3, data));
        }
    }

    // PAETH
    {
        let mut data = Vec::with_capacity(row_bytes);
        let mut sum: u64 = 0;
        for (i, &x) in row.iter().enumerate() {
            let a = if i >= bpp { row[i - bpp] } else { 0 };
            let b = prev[i];
            let c = if i >= bpp { prev[i - bpp] } else { 0 };
            let v = x.wrapping_sub(paeth_predictor(a, b, c));
            data.push(v);
            sum += mad(v);
            if i >= bpp && sum > mins {
                break;
            }
        }
        if sum < mins {
            best = Some((4, data));
        }
    }

    best.unwrap_or_else(|| (0, row.to_vec()))
}

fn paeth_predictor(a: u8, b: u8, c: u8) -> u8 {
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

/// libpng's `optimize_cmf`: shrink the zlib header's window-size field when
/// the uncompressed data fits a smaller window.
fn optimize_cmf(data: &mut [u8], data_size: u64) {
    if data_size <= 16384 && data.len() >= 2 {
        let z_cmf = data[0];
        if (z_cmf & 0x0f) == 8 && (z_cmf & 0xf0) <= 0x70 {
            let mut z_cinfo = z_cmf >> 4;
            let mut half_z_window_size: u64 = 1 << (z_cinfo + 7);
            if data_size <= half_z_window_size {
                loop {
                    half_z_window_size >>= 1;
                    z_cinfo -= 1;
                    if z_cinfo == 0 || data_size > half_z_window_size {
                        break;
                    }
                }
                let z_cmf = (z_cmf & 0x0f) | (z_cinfo << 4);
                data[0] = z_cmf;
                let mut tmp = u32::from(data[1] & 0xe0);
                tmp += 0x1f - ((u32::from(z_cmf) << 8) + tmp) % 0x1f;
                data[1] = tmp as u8;
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use crate::{encode_rgba8, surface, Png};

    #[test]
    fn encode_decode_round_trip() {
        let mut rgba = Vec::new();
        for y in 0..7u8 {
            for _ in 0..11u8 {
                rgba.extend_from_slice(&[y * 30, 128, 200, 255]);
            }
        }
        let bytes = encode_rgba8(11, 7, &rgba).expect("encode");
        let model = Png::decode(&bytes).expect("decode");
        assert_eq!(surface::surface(&model).expect("surface").rgba, rgba);
    }

    #[test]
    fn single_pixel_chunk_layout() {
        let bytes = encode_rgba8(1, 1, &[1, 2, 3, 4]).expect("encode");
        let model = Png::decode(&bytes).expect("decode");
        assert_eq!(model.chunks.len(), 3);
        assert_eq!(&model.chunks[0].kind, b"IHDR");
        assert_eq!(&model.chunks[1].kind, b"IDAT");
        assert_eq!(&model.chunks[2].kind, b"IEND");
    }
}
