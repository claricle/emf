//! Explicit BI_BITFIELDS decode (channel masks scaled to 8 bits), kept as a
//! model capability. The Ruby ground truth routes compression 3 through its
//! plain BI_RGB row decoders, and the parity path does the same; this module
//! documents the masked decode the Ruby file defines but never calls
//! (including its 16-bpp quirk of reading a full uint32 per pixel).
use crate::{BitmapInfoHeader, BI_BITFIELDS};

/// A decoded masked surface.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RgbaBits {
    pub width: i32,
    pub height: i32,
    pub rgba: Vec<u8>,
}

/// Ruby `decode_bi_bitfields`. `None` for unsupported bit depths or
/// non-bit-fields headers.
pub fn decode_bitfields(dib: &[u8], bits_offset: Option<usize>) -> Option<RgbaBits> {
    if dib.len() < 40 {
        return None;
    }
    let header = BitmapInfoHeader::parse(dib);
    if header.compression != BI_BITFIELDS || ![16, 32].contains(&header.bit_count) {
        return None;
    }
    if header.width < 0 {
        return None;
    }
    let width = header.width as usize;
    let height_abs = header.height.unsigned_abs() as usize;
    let bit_count = usize::from(header.bit_count);

    let mask_offset = header.header_size as usize;
    let r_mask = read_u32(dib, mask_offset);
    let g_mask = read_u32(dib, mask_offset + 4);
    let b_mask = read_u32(dib, mask_offset + 8);
    let a_mask = if header.header_size >= 56 {
        Some(read_u32(dib, mask_offset + 12))
    } else {
        None
    };

    let mask_bytes = if header.header_size >= 56 { 16 } else { 12 };
    let pixel_offset = bits_offset.unwrap_or(mask_offset + mask_bytes);
    let row_stride = (bit_count * width).div_ceil(32) * 4;
    let mut pixels = crate::try_zeroed(width.checked_mul(height_abs)?.checked_mul(4)?)?;

    for row in 0..height_abs {
        let src_row = if header.height < 0 {
            row
        } else {
            height_abs - 1 - row
        };
        let row_start = pixel_offset + src_row * row_stride;
        for x in 0..width {
            // Ruby reads a full uint32 per pixel even at 16 bpp; mirrored.
            let value = read_u32(dib, row_start + x * (bit_count / 8));
            let r = scale_masked(value, r_mask);
            let g = scale_masked(value, g_mask);
            let b = scale_masked(value, b_mask);
            let a = a_mask.map_or(255, |mask| scale_masked(value, mask));
            let at = ((row * width) + x) * 4;
            pixels[at] = r;
            pixels[at + 1] = g;
            pixels[at + 2] = b;
            pixels[at + 3] = a;
        }
    }

    Some(RgbaBits {
        width: header.width,
        height: header.height.unsigned_abs() as i32,
        rgba: pixels,
    })
}

fn read_u32(bytes: &[u8], at: usize) -> u32 {
    if at + 4 > bytes.len() {
        return 0;
    }
    u32::from_le_bytes([bytes[at], bytes[at + 1], bytes[at + 2], bytes[at + 3]])
}

/// Ruby `scale_masked`: lowest set bit of the mask is the shift, the
/// contiguous run of set bits from there the width, and the value scales to
/// `width` bits across 0..255 with round-half-up.
fn scale_masked(value: u32, mask: u32) -> u8 {
    if mask == 0 {
        return 0;
    }
    let mut shift = 0u32;
    let mut tmp = mask;
    while tmp & 1 == 0 && tmp != 0 {
        shift += 1;
        tmp >>= 1;
    }
    let mut bits = 0u32;
    while tmp & 1 == 1 {
        bits += 1;
        tmp >>= 1;
    }
    let max = (1u64 << bits) - 1;
    let scaled = (u64::from((value & mask) >> shift)) as f64 / max as f64 * 255.0;
    // Ruby Float#round: half away from zero; values are non-negative.
    scaled.round().clamp(0.0, 255.0) as u8
}

#[cfg(test)]
mod tests {
    use super::{decode_bitfields, scale_masked};
    use crate::BitmapInfoHeader;

    #[test]
    fn scales_masks_across_their_width() {
        assert_eq!(scale_masked(0xF800, 0xF800), 255);
        assert_eq!(scale_masked(0x0000, 0xF800), 0);
        assert_eq!(scale_masked(0x07C0, 0x07C0), 255);
        assert_eq!(scale_masked(0, 0), 0);
        // 5-bit field: one step of 31 scales to 8 (1/31 * 255 = 8.23).
        assert_eq!(scale_masked(0x0020, 0x03E0), 8);
    }

    #[test]
    fn decodes_a_32bpp_bitfields_surface() {
        // The Ruby decoder reads the masks at header_size..header_size+16
        // and pixels right after; mirror that layout here (a 56-byte header
        // declaration, the 16-byte mask block, then one pixel).
        let mut dib = Vec::new();
        let header = BitmapInfoHeader {
            header_size: 56,
            width: 1,
            height: 1,
            planes: 1,
            bit_count: 32,
            compression: crate::BI_BITFIELDS,
            image_size: 4,
            x_ppm: 0,
            y_ppm: 0,
            clr_used: 0,
            clr_important: 0,
        };
        dib.extend_from_slice(&header.serialize());
        dib.extend_from_slice(&[0u8; 16]); // header body through biSize 56
        dib.extend_from_slice(&0x00FF_0000u32.to_le_bytes()); // R mask
        dib.extend_from_slice(&0x0000_FF00u32.to_le_bytes()); // G mask
        dib.extend_from_slice(&0x0000_00FFu32.to_le_bytes()); // B mask
        dib.extend_from_slice(&0xFF00_0000u32.to_le_bytes()); // A mask
        dib.extend_from_slice(&0x1234_5678u32.to_le_bytes()); // one pixel
        let bits = decode_bitfields(&dib, None).expect("decode");
        // Masks select bytes 2, 1, 0 and 3 of the big-endian value.
        assert_eq!(bits.rgba, [0x34, 0x56, 0x78, 0x12]);
    }
}
