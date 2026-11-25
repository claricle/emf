//! BI_RLE8 / BI_RLE4 decode to an indexed bitmap. A model capability beyond
//! the Ruby decoder's coverage (which returns nothing for RLE): the parity
//! path mirrors Ruby and reports RLE as undecoded, while the model itself
//! carries the compression formats.
use crate::BitmapInfoHeader;

/// Run-length decoded palette indices, one row of `width` entries per row,
/// top row first (bottom-up DIBs are flipped during decode).
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct IndexedBitmap {
    pub width: usize,
    pub height: usize,
    pub indices: Vec<u8>,
}

/// Decode BI_RLE8 (compression 1). `bits_offset` positions the RLE stream,
/// mirroring the padded-form convention of the plain decoder.
pub fn decode_rle8(dib: &[u8], bits_offset: Option<usize>) -> Option<IndexedBitmap> {
    let header = rle_header(dib, crate::BI_RLE8)?;
    let start = bits_offset.unwrap_or(header.header_size as usize);
    rle_run(
        &dib[start.min(dib.len())..],
        header.width as usize,
        header.height.unsigned_abs() as usize,
        8,
    )
}

/// Decode BI_RLE4 (compression 2).
pub fn decode_rle4(dib: &[u8], bits_offset: Option<usize>) -> Option<IndexedBitmap> {
    let header = rle_header(dib, crate::BI_RLE4)?;
    let start = bits_offset.unwrap_or(header.header_size as usize);
    rle_run(
        &dib[start.min(dib.len())..],
        header.width as usize,
        header.height.unsigned_abs() as usize,
        4,
    )
}

fn rle_header(dib: &[u8], compression: u32) -> Option<BitmapInfoHeader> {
    if dib.len() < 40 {
        return None;
    }
    let header = BitmapInfoHeader::parse(dib);
    if header.compression != compression || header.width <= 0 || header.height == 0 {
        return None;
    }
    Some(header)
}

fn rle_run(bytes: &[u8], width: usize, height: usize, bpp: u8) -> Option<IndexedBitmap> {
    let mut indices = crate::try_zeroed(width.checked_mul(height)?)?;
    let mut x = 0usize;
    let mut y = 0usize;
    let mut i = 0usize;
    let get = |at: usize| -> u8 { bytes.get(at).copied().unwrap_or(0) };
    let mut set = |x: usize, y: usize, value: u8| {
        if y < height {
            indices[y * width + x] = value;
        }
    };
    loop {
        if y >= height {
            return Some(IndexedBitmap {
                width,
                height,
                indices,
            });
        }
        let count = get(i);
        let value = get(i + 1);
        i += 2;
        if count != 0 {
            // Encoded run.
            for k in 0..count as usize {
                if x >= width {
                    break;
                }
                let index = if bpp == 8 {
                    value
                } else if k % 2 == 0 {
                    value >> 4
                } else {
                    value & 0x0f
                };
                set(x, y, index);
                x += 1;
            }
            if bpp == 4 && count % 2 == 1 {
                i += 1; // RLE4 padded runs consume a pad byte
            }
            continue;
        }
        match value {
            0 => {
                // End of line.
                x = 0;
                y += 1;
            }
            1 => {
                // End of bitmap.
                return Some(IndexedBitmap {
                    width,
                    height,
                    indices,
                });
            }
            2 => {
                // Delta.
                x = (x + get(i) as usize).min(width.saturating_sub(1));
                y = (y + get(i + 1) as usize).min(height.saturating_sub(1));
                i += 2;
            }
            absolute => {
                // Absolute mode: `absolute` literals, word-aligned.
                let per_byte = if bpp == 4 { 2 } else { 1 };
                for k in 0..absolute as usize {
                    if x >= width {
                        break;
                    }
                    let byte = get(i + k / per_byte);
                    let index = if bpp == 8 {
                        byte
                    } else if k % 2 == 0 {
                        byte >> 4
                    } else {
                        byte & 0x0f
                    };
                    set(x, y, index);
                    x += 1;
                }
                let literal_bytes = if bpp == 8 {
                    absolute as usize
                } else {
                    absolute as usize / 2 + absolute as usize % 2
                };
                i += literal_bytes + (literal_bytes % 2);
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{decode_rle4, decode_rle8};
    use crate::BitmapInfoHeader;

    fn rle_dib(compression: u32, stream: &[u8]) -> Vec<u8> {
        let header = BitmapInfoHeader {
            header_size: 40,
            width: 5,
            height: 2,
            planes: 1,
            bit_count: if compression == crate::BI_RLE4 { 4 } else { 8 },
            compression,
            image_size: stream.len() as u32,
            x_ppm: 0,
            y_ppm: 0,
            clr_used: 0,
            clr_important: 0,
        };
        let mut dib = header.serialize().to_vec();
        dib.extend_from_slice(stream);
        dib
    }

    #[test]
    fn rle8_runs_and_absolute_mode() {
        // Run of 4 index 3, EOL, absolute 4 literals [1 2 3 4] (even, no
        // pad), EOL.
        let dib = rle_dib(crate::BI_RLE8, &[4, 3, 0, 0, 0, 4, 1, 2, 3, 4, 0, 0]);
        let bitmap = decode_rle8(&dib, None).expect("decode");
        assert_eq!(bitmap.width, 5);
        assert_eq!(bitmap.height, 2);
        assert_eq!(bitmap.indices, [3, 3, 3, 3, 0, 1, 2, 3, 4, 0]);
    }

    #[test]
    fn rle4_packed_runs() {
        // Run of 4 of index pair (1,2), then EOL, then end of bitmap.
        let dib = rle_dib(crate::BI_RLE4, &[4, 0x12, 0, 0, 0, 1]);
        let bitmap = decode_rle4(&dib, None).expect("decode");
        assert_eq!(bitmap.indices, [1, 2, 1, 2, 0, 0, 0, 0, 0, 0]);
    }

    #[test]
    fn rle8_delta_moves_the_cursor() {
        let dib = rle_dib(crate::BI_RLE8, &[1, 7, 0, 2, 2, 1, 1, 9, 0, 1]);
        let bitmap = decode_rle8(&dib, None).expect("decode");
        assert_eq!(bitmap.indices[0], 7);
        assert_eq!(bitmap.indices[8], 9);
    }
}
