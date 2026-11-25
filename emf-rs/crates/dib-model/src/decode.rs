//! Pixel decode mirroring emfsvg's `DibDecoder` exactly: BI_RGB and
//! BI_BITFIELDS through the plain row decoders, BI_JPEG/BI_PNG as
//! pass-through payloads, everything else undecoded — including the global
//! alpha-zero rule that turns all-zero alpha into 255.
use crate::{BitmapInfoHeader, PaletteEntry, BI_JPEG, BI_PNG};

/// What `DibDecoder#decode` returns, one variant per `color_type`.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Decoded {
    Rgba(RgbaDecode),
    /// BI_JPEG: embedded JPEG bytes, passed through uninterpreted.
    Jpeg(Vec<u8>),
    /// BI_PNG: embedded PNG bytes, passed through uninterpreted.
    Png(Vec<u8>),
}

/// A decoded RGBA surface (row-major, top-down, `width * height * 4` bytes).
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RgbaDecode {
    pub width: i32,
    pub height: i32,
    pub rgba: Vec<u8>,
}

/// Decode DIB bytes exactly as the Ruby ground truth does.
///
/// * `bits_offset`: the cb_bmi from the EMF record (the padded form reads
///   pixels from that offset into `dib`).
/// * `mono_palette`: the 1-bpp brush override (text/bk colors from the
///   device context), replacing the palette wholesale.
///
/// `None` mirrors the Ruby decoder returning nil (short input, unknown
/// compression, or an unsupported bit depth).
pub fn decode(
    dib: &[u8],
    bits_offset: Option<usize>,
    mono_palette: Option<[[u8; 4]; 2]>,
) -> Option<Decoded> {
    if dib.len() < 40 {
        return None;
    }
    let header = BitmapInfoHeader::parse(dib);
    match header.compression {
        crate::BI_RGB | crate::BI_BITFIELDS => {
            decode_bi_rgb(dib, &header, bits_offset, mono_palette).map(Decoded::Rgba)
        }
        BI_JPEG => Some(Decoded::Jpeg(payload_after_header(dib, &header))),
        BI_PNG => Some(Decoded::Png(payload_after_header(dib, &header))),
        _ => None,
    }
}

fn payload_after_header(dib: &[u8], header: &BitmapInfoHeader) -> Vec<u8> {
    let start = usize::try_from(header.header_size).unwrap_or(usize::MAX);
    if start > dib.len() {
        Vec::new()
    } else {
        dib[start..].to_vec()
    }
}

/// Ruby `decode_bi_rgb`. A negative width raises in the Ruby decoder
/// (`Array.new` with a negative count) and is mirrored as `None`.
pub fn decode_bi_rgb(
    dib: &[u8],
    header: &BitmapInfoHeader,
    bits_offset: Option<usize>,
    mono_palette: Option<[[u8; 4]; 2]>,
) -> Option<RgbaDecode> {
    if header.width < 0 {
        return None;
    }
    let width = header.width as usize;
    let height_abs = header.height.unsigned_abs() as usize;
    let top_down = header.height < 0;
    let bit_count = usize::from(header.bit_count);

    let pal_start = header.header_size as usize;
    let pal_entries = header.real_palette_size() as usize;
    let palette: Vec<[u8; 4]> = match mono_palette {
        Some(mono) => mono.to_vec(),
        None => (0..pal_entries)
            .map(|i| {
                let entry = PaletteEntry::parse_wire(dib, pal_start + i * 4);
                [entry.red, entry.green, entry.blue, entry.alpha]
            })
            .collect(),
    };

    let pixel_offset = bits_offset.unwrap_or(pal_start + pal_entries * 4);
    let row_stride = (bit_count * width).div_ceil(32) * 4;
    let mut pixels = crate::try_zeroed(width.checked_mul(height_abs)?.checked_mul(4)?)?;

    for row in 0..height_abs {
        let src_row = if top_down { row } else { height_abs - 1 - row };
        let row_start = pixel_offset + src_row * row_stride;
        match bit_count {
            24 => decode_rgb24_row(dib, row_start, width, &mut pixels, row * width * 4),
            32 => decode_rgb32_row(dib, row_start, width, &mut pixels, row * width * 4),
            16 => decode_rgb16_row(dib, row_start, width, &mut pixels, row * width * 4),
            8 => decode_indexed_row(
                dib,
                row_start,
                width,
                1,
                &palette,
                &mut pixels,
                row * width * 4,
            ),
            4 => decode_indexed_row(
                dib,
                row_start,
                width,
                2,
                &palette,
                &mut pixels,
                row * width * 4,
            ),
            1 => decode_indexed_row(
                dib,
                row_start,
                width,
                8,
                &palette,
                &mut pixels,
                row * width * 4,
            ),
            _ => return None,
        }
    }

    // libemf2svg's rgb2png global alpha check: if every alpha byte is zero,
    // force all alpha to 0xFF. Applies to every depth (16-bpp is always
    // opaque through this rule).
    let alpha_all_zero = pixels.iter().skip(3).step_by(4).all(|a| *a == 0);
    if alpha_all_zero {
        for a in pixels.iter_mut().skip(3).step_by(4) {
            *a = 255;
        }
    }

    Some(RgbaDecode {
        width: header.width,
        height: header.height.unsigned_abs() as i32,
        rgba: pixels,
    })
}

fn getbyte(bytes: &[u8], at: usize) -> u8 {
    bytes.get(at).copied().unwrap_or(0)
}

fn decode_rgb24_row(dib: &[u8], row_start: usize, width: usize, pixels: &mut [u8], out: usize) {
    for x in 0..width {
        let b = getbyte(dib, row_start + x * 3);
        let g = getbyte(dib, row_start + x * 3 + 1);
        let r = getbyte(dib, row_start + x * 3 + 2);
        let at = out + x * 4;
        pixels[at] = r;
        pixels[at + 1] = g;
        pixels[at + 2] = b;
        pixels[at + 3] = 255;
    }
}

fn decode_rgb32_row(dib: &[u8], row_start: usize, width: usize, pixels: &mut [u8], out: usize) {
    for x in 0..width {
        let b = getbyte(dib, row_start + x * 4);
        let g = getbyte(dib, row_start + x * 4 + 1);
        let r = getbyte(dib, row_start + x * 4 + 2);
        let a = getbyte(dib, row_start + x * 4 + 3);
        let at = out + x * 4;
        pixels[at] = r;
        pixels[at + 1] = g;
        pixels[at + 2] = b;
        pixels[at + 3] = a;
    }
}

/// 16-bpp BI_RGB is always 5:5:5 per GDI semantics (see the Ruby decoder's
/// `decode_rgb16_row`, including libuemf's shift shape).
fn decode_rgb16_row(dib: &[u8], row_start: usize, width: usize, pixels: &mut [u8], out: usize) {
    for x in 0..width {
        let lo = getbyte(dib, row_start + x * 2);
        let hi = getbyte(dib, row_start + x * 2 + 1);
        let b = (lo & 0x1F) << 3;
        let mut g = (lo >> 5) | ((hi & 0x03) << 3);
        g <<= 3;
        let r = (hi & 0x7C) << 1;
        let at = out + x * 4;
        pixels[at] = r;
        pixels[at + 1] = g;
        pixels[at + 2] = b;
        pixels[at + 3] = 0;
    }
}

/// `pixels_per_byte` is 8 (1-bpp), 2 (4-bpp) or 1 (8-bpp), as in Ruby.
fn decode_indexed_row(
    dib: &[u8],
    row_start: usize,
    width: usize,
    pixels_per_byte: usize,
    palette: &[[u8; 4]],
    pixels: &mut [u8],
    out: usize,
) {
    for x in 0..width {
        let idx = match pixels_per_byte {
            8 => {
                let byte = getbyte(dib, row_start + x / 8);
                let shift = 7 - (x % 8);
                (byte >> shift) & 0x01
            }
            2 => {
                let byte = getbyte(dib, row_start + x / 2);
                let shift = if x % 2 == 0 { 4 } else { 0 };
                (byte >> shift) & 0x0F
            }
            _ => getbyte(dib, row_start + x),
        };
        let entry = palette
            .get(usize::from(idx))
            .copied()
            .unwrap_or([0, 0, 0, 255]);
        let at = out + x * 4;
        pixels[at..at + 4].copy_from_slice(&entry);
    }
}
