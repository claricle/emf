//! Structural serialization: `DibImage` round-trips (decode → serialize is
//! byte-stable for well-formed streams), and the RGBA → BI_RGB 32-bpp
//! bottom-up BGRA encoder mirroring emfsvg's `DibEncoder` (the PNG→DIB
//! direction of the transformer).
use crate::{BitmapInfoHeader, DibHeader, DibImage, PaletteEntry, BI_RGB, INFO_HEADER_SIZE};

impl DibImage {
    /// Structural decode: header zoo, palette, trailing pixel bits.
    pub fn parse(bytes: &[u8]) -> Result<Self, crate::Error> {
        let header = DibHeader::parse(bytes)?;
        let header_len = match &header {
            DibHeader::Core(core) => core.header_size as usize,
            DibHeader::Info(info) => info.header_size.max(40) as usize,
            DibHeader::Extended(extended) => extended.info.header_size.max(40) as usize,
        };
        let info = header.info_fields();
        let palette: Vec<PaletteEntry> = match &header {
            DibHeader::Core(core) => {
                let entries = 1usize << core.bit_count.min(8);
                (0..entries)
                    .map(|i| {
                        let at = header_len + i * 3;
                        let get = |k: usize| bytes.get(at + k).copied().unwrap_or(0);
                        PaletteEntry {
                            blue: get(0),
                            green: get(1),
                            red: get(2),
                            alpha: 0,
                        }
                    })
                    .collect()
            }
            _ => {
                let entries = match info.bit_count {
                    1 | 4 | 8 => {
                        if info.clr_used > 0 {
                            info.clr_used as usize
                        } else {
                            1 << info.bit_count
                        }
                    }
                    _ => 0,
                };
                (0..entries)
                    .map(|i| PaletteEntry::parse_wire(bytes, header_len + i * 4))
                    .collect()
            }
        };
        let palette_wire = if matches!(header, DibHeader::Core(_)) {
            3
        } else {
            4
        };
        let bits_start = header_len.saturating_add(palette.len() * palette_wire);
        let pixel_bits = if bytes.len() > bits_start {
            bytes[bits_start..].to_vec()
        } else {
            Vec::new()
        };
        Ok(Self {
            header,
            palette,
            pixel_bits,
        })
    }
}

/// Emit the structural model back to bytes (recomputed palette order; a
/// strictly-parsed image round-trips byte-stably).
pub fn serialize_image(image: &DibImage) -> Vec<u8> {
    let mut out = Vec::new();
    match &image.header {
        DibHeader::Core(core) => {
            out.extend_from_slice(&core.header_size.to_le_bytes());
            out.extend_from_slice(&core.width.to_le_bytes());
            out.extend_from_slice(&core.height.to_le_bytes());
            out.extend_from_slice(&core.planes.to_le_bytes());
            out.extend_from_slice(&core.bit_count.to_le_bytes());
            for entry in &image.palette {
                out.extend_from_slice(&[entry.blue, entry.green, entry.red]);
            }
        }
        DibHeader::Info(info) => {
            out.extend_from_slice(&info.serialize());
            for entry in &image.palette {
                out.extend_from_slice(&entry.serialize_wire());
            }
        }
        DibHeader::Extended(extended) => {
            let mut info_bytes = extended.info.serialize().to_vec();
            push_opt(&mut info_bytes, extended.red_mask);
            push_opt(&mut info_bytes, extended.green_mask);
            push_opt(&mut info_bytes, extended.blue_mask);
            push_opt(&mut info_bytes, extended.alpha_mask);
            push_opt(&mut info_bytes, extended.cs_type);
            if let Some(endpoints) = &extended.endpoints {
                for channel in [&endpoints.red, &endpoints.green, &endpoints.blue] {
                    for value in channel {
                        info_bytes.extend_from_slice(&value.to_le_bytes());
                    }
                }
            }
            if let Some([red, green, blue]) = extended.gamma {
                info_bytes.extend_from_slice(&red.to_le_bytes());
                info_bytes.extend_from_slice(&green.to_le_bytes());
                info_bytes.extend_from_slice(&blue.to_le_bytes());
            }
            push_opt(&mut info_bytes, extended.intent.map(|v| v as u32));
            push_opt(&mut info_bytes, extended.profile_data);
            push_opt(&mut info_bytes, extended.profile_size);
            push_opt(&mut info_bytes, extended.reserved);
            out.extend_from_slice(&info_bytes);
            for entry in &image.palette {
                out.extend_from_slice(&entry.serialize_wire());
            }
        }
    }
    out.extend_from_slice(&image.pixel_bits);
    out
}

fn push_opt(out: &mut Vec<u8>, value: Option<u32>) {
    if let Some(value) = value {
        out.extend_from_slice(&value.to_le_bytes());
    }
}

/// Encode RGBA pixels as a DIB (BI_RGB, 32-bpp, bottom-up BGRA), byte-exact
/// with emfsvg's `DibEncoder`: BITMAPINFOHEADER then the pixel array, rows
/// reversed, red/blue swapped per pixel.
pub fn encode_rgba_as_bgra_rgb32(width: i32, height: i32, rgba: &[u8]) -> Vec<u8> {
    if width <= 0 || height <= 0 {
        return Vec::new();
    }
    let w = width as usize;
    let h = height as usize;
    let pixel_bytes = w.checked_mul(h).and_then(|n| n.checked_mul(4));
    let Some(pixel_bytes) = pixel_bytes else {
        return Vec::new();
    };
    if rgba.len() < pixel_bytes {
        return Vec::new();
    }
    let header = BitmapInfoHeader {
        header_size: INFO_HEADER_SIZE,
        width,
        height,
        planes: 1,
        bit_count: 32,
        compression: BI_RGB,
        image_size: u32::try_from(pixel_bytes).unwrap_or(u32::MAX),
        x_ppm: 2835,
        y_ppm: 2835,
        clr_used: 0,
        clr_important: 0,
    };
    let mut out = header.serialize().to_vec();
    let row_size = w * 4;
    for src_row in (0..h).rev() {
        let start = src_row * row_size;
        let row = &rgba[start..start + row_size];
        for pixel in row.chunks_exact(4) {
            out.extend_from_slice(&[pixel[2], pixel[1], pixel[0], pixel[3]]);
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use crate::{decode, encode_rgba_as_bgra_rgb32, serialize_image, Decoded, DibHeader, DibImage};

    #[test]
    fn dib_encoder_shape_matches_ruby_layout() {
        // 2x2 RGBA: rows bottom-up, BGRA on the wire.
        let rgba = [1u8, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16];
        let dib = encode_rgba_as_bgra_rgb32(2, 2, &rgba);
        assert_eq!(dib.len(), 40 + 16);
        assert_eq!(&dib[..4], &40u32.to_le_bytes());
        // First wire row is source row 1 (bottom-up): BGRA of 9,10,11,12.
        assert_eq!(&dib[40..44], &[11, 10, 9, 12]);
        // Decoding it back yields the original RGBA (alpha forced opaque if
        // all zero; here alpha is nonzero).
        match decode(&dib, None, None).expect("decode") {
            Decoded::Rgba(surface) => assert_eq!(surface.rgba, rgba),
            other => panic!("expected rgba, got {other:?}"),
        }
    }

    #[test]
    fn structural_round_trip_is_byte_stable() {
        let rgba = [1u8, 2, 3, 4, 5, 6, 7, 8];
        let dib = encode_rgba_as_bgra_rgb32(2, 1, &rgba);
        let image = DibImage::parse(&dib).expect("parse");
        assert!(matches!(image.header, DibHeader::Info(_)));
        assert_eq!(serialize_image(&image), dib);
    }
}
