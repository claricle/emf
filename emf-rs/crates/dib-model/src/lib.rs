//! Windows DIB (Device-Independent Bitmap) model: the header zoo from
//! BITMAPCOREHEADER through BITMAPV5HEADER, palette, and pixel bits, plus a
//! pixel decode that mirrors the Ruby ground truth (emfsvg's `DibDecoder`)
//! exactly, and a serializer that round-trips well-formed streams.
//!
//! This crate is format-scoped: it contains no EMF or PNG concepts. The
//! RLE8/RLE4 decoders and the explicit bit-fields decoder are model
//! capabilities beyond the Ruby decoder's coverage (which returns nothing
//! for RLE and routes BI_BITFIELDS through its plain BI_RGB row decoders);
//! they are exposed for the model's completeness and tested independently.
mod bitfields;
mod decode;
mod rle;
mod serialize;

pub use bitfields::{decode_bitfields, RgbaBits};
pub use decode::{decode, Decoded, RgbaDecode};
pub use rle::{decode_rle4, decode_rle8, IndexedBitmap};
pub use serialize::{encode_rgba_as_bgra_rgb32, serialize_image};

use std::fmt;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Error {
    /// Fewer than the 40-byte BITMAPINFOHEADER the decoder requires.
    TooShort,
    /// A header field combination the model rejects.
    Format(&'static str),
}

impl fmt::Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::TooShort => write!(f, "DIB shorter than BITMAPINFOHEADER"),
            Self::Format(msg) => write!(f, "invalid DIB: {msg}"),
        }
    }
}

impl std::error::Error for Error {}

/// BITMAPINFOHEADER fields (the 40-byte window every decode reads).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct BitmapInfoHeader {
    pub header_size: u32,
    pub width: i32,
    /// Positive height is bottom-up; negative height is top-down.
    pub height: i32,
    pub planes: u16,
    pub bit_count: u16,
    /// 0 BI_RGB, 1 BI_RLE8, 2 BI_RLE4, 3 BI_BITFIELDS, 4 BI_JPEG, 5 BI_PNG.
    pub compression: u32,
    pub image_size: u32,
    pub x_ppm: i32,
    pub y_ppm: i32,
    pub clr_used: u32,
    pub clr_important: u32,
}

pub const INFO_HEADER_SIZE: u32 = 40;
pub const BI_RGB: u32 = 0;
pub const BI_RLE8: u32 = 1;
pub const BI_RLE4: u32 = 2;
pub const BI_BITFIELDS: u32 = 3;
pub const BI_JPEG: u32 = 4;
pub const BI_PNG: u32 = 5;

impl BitmapInfoHeader {
    /// Byte-safe read of the first 40 bytes (short reads yield zeros, as in
    /// the Ruby decoder).
    pub fn parse(bytes: &[u8]) -> Self {
        let u32_at = |at: usize| read_u32(bytes, at);
        let i32_at = |at: usize| u32_at(at) as i32;
        Self {
            header_size: u32_at(0),
            width: i32_at(4),
            height: i32_at(8),
            planes: u16::try_from(u32_at(12) & 0xffff).unwrap_or(0),
            bit_count: u16::try_from(u32_at(14) & 0xffff).unwrap_or(0),
            compression: u32_at(16),
            image_size: u32_at(20),
            x_ppm: i32_at(24),
            y_ppm: i32_at(28),
            clr_used: u32_at(32),
            clr_important: u32_at(36),
        }
    }

    pub fn serialize(&self) -> [u8; 40] {
        let mut out = [0u8; 40];
        out[0..4].copy_from_slice(&self.header_size.to_le_bytes());
        out[4..8].copy_from_slice(&self.width.to_le_bytes());
        out[8..12].copy_from_slice(&self.height.to_le_bytes());
        out[12..14].copy_from_slice(&self.planes.to_le_bytes());
        out[14..16].copy_from_slice(&self.bit_count.to_le_bytes());
        out[16..20].copy_from_slice(&self.compression.to_le_bytes());
        out[20..24].copy_from_slice(&self.image_size.to_le_bytes());
        out[24..28].copy_from_slice(&self.x_ppm.to_le_bytes());
        out[28..32].copy_from_slice(&self.y_ppm.to_le_bytes());
        out[32..36].copy_from_slice(&self.clr_used.to_le_bytes());
        out[36..40].copy_from_slice(&self.clr_important.to_le_bytes());
        out
    }

    /// libuemf's `get_real_color_icount`: nominal palette size capped at the
    /// pixel area.
    pub fn real_palette_size(&self) -> u32 {
        let nominal = self.nominal_palette_size();
        if nominal == 0 {
            return 0;
        }
        let area = i64::from(self.width.abs()) * i64::from(self.height.abs());
        u32::try_from(i64::from(nominal).min(area)).unwrap_or(nominal)
    }

    fn nominal_palette_size(&self) -> u32 {
        match self.bit_count {
            1 | 4 | 8 => {
                if self.clr_used > 0 {
                    self.clr_used
                } else {
                    1 << self.bit_count
                }
            }
            _ => 0,
        }
    }
}

fn read_u32(bytes: &[u8], at: usize) -> u32 {
    if at + 4 > bytes.len() {
        return 0;
    }
    u32::from_le_bytes([bytes[at], bytes[at + 1], bytes[at + 2], bytes[at + 3]])
}

/// BITMAPCOREHEADER (the 12-byte OS/2-era header).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct BitmapCoreHeader {
    pub header_size: u32,
    pub width: u16,
    pub height: u16,
    pub planes: u16,
    pub bit_count: u16,
}

/// The bit-fields family headers (52/56/64/108/124 bytes): INFO fields plus
/// the channel masks, color space, endpoint and profile fields, each present
/// only when the declared header size reaches it.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ExtendedHeader {
    pub info: BitmapInfoHeader,
    pub red_mask: Option<u32>,
    pub green_mask: Option<u32>,
    pub blue_mask: Option<u32>,
    pub alpha_mask: Option<u32>,
    pub cs_type: Option<u32>,
    pub endpoints: Option<CieXyzTriple>,
    pub gamma: Option<[u32; 3]>,
    pub intent: Option<i32>,
    pub profile_data: Option<u32>,
    pub profile_size: Option<u32>,
    pub reserved: Option<u32>,
}

/// CIEXYZTRIPLE endpoints, each channel an FXPT2DOT30 fixed-point value.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct CieXyzTriple {
    pub red: [u32; 3],
    pub green: [u32; 3],
    pub blue: [u32; 3],
}

/// The header zoo.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum DibHeader {
    Core(BitmapCoreHeader),
    Info(BitmapInfoHeader),
    /// 52 (V2), 56 (V3), 64/108 (V4) and 124 (V5) byte headers.
    Extended(ExtendedHeader),
}

impl DibHeader {
    /// Parse the header zoo by `biSize`/`bcSize`-style leading word.
    pub fn parse(bytes: &[u8]) -> Result<Self, Error> {
        if bytes.len() < 12 {
            return Err(Error::Format("shorter than BITMAPCOREHEADER"));
        }
        let declared = read_u32(bytes, 0);
        match declared {
            12 => Ok(Self::Core(BitmapCoreHeader {
                header_size: declared,
                width: u16::from_le_bytes([bytes[4], bytes[5]]),
                height: u16::from_le_bytes([bytes[6], bytes[7]]),
                planes: u16::from_le_bytes([bytes[8], bytes[9]]),
                bit_count: u16::from_le_bytes([bytes[10], bytes[11]]),
            })),
            40 => Ok(Self::Info(BitmapInfoHeader::parse(bytes))),
            52 | 56 | 64 | 108 | 124 => Ok(Self::Extended(parse_extended(bytes, declared))),
            _ => Err(Error::Format("unknown header size")),
        }
    }

    /// The INFO-fields view every pixel decoder consults.
    pub fn info_fields(&self) -> BitmapInfoHeader {
        match self {
            Self::Core(core) => BitmapInfoHeader {
                header_size: core.header_size,
                width: i32::from(core.width),
                height: i32::from(core.height),
                planes: core.planes,
                bit_count: core.bit_count,
                compression: BI_RGB,
                image_size: 0,
                x_ppm: 0,
                y_ppm: 0,
                clr_used: 0,
                clr_important: 0,
            },
            Self::Info(info) => *info,
            Self::Extended(extended) => extended.info,
        }
    }
}

fn parse_extended(bytes: &[u8], declared: u32) -> ExtendedHeader {
    let need = declared as usize;
    let mask = |at: usize| -> Option<u32> {
        if at + 4 <= need && at + 4 <= bytes.len() {
            Some(read_u32(bytes, at))
        } else {
            None
        }
    };
    let triple = |base: usize| -> Option<[u32; 3]> {
        if base + 12 <= need && base + 12 <= bytes.len() {
            Some([
                read_u32(bytes, base),
                read_u32(bytes, base + 4),
                read_u32(bytes, base + 8),
            ])
        } else {
            None
        }
    };
    let at = |t: usize| -> usize { 40 + t };
    ExtendedHeader {
        info: BitmapInfoHeader::parse(bytes),
        red_mask: mask(at(0)),
        green_mask: mask(at(4)),
        blue_mask: mask(at(8)),
        alpha_mask: mask(at(12)),
        cs_type: mask(at(16)),
        endpoints: if triple(at(20)).is_some()
            && triple(at(32)).is_some()
            && triple(at(44)).is_some()
        {
            Some(CieXyzTriple {
                red: triple(at(20)).expect("checked"),
                green: triple(at(32)).expect("checked"),
                blue: triple(at(44)).expect("checked"),
            })
        } else {
            None
        },
        gamma: if need >= 108 && bytes.len() >= 108 {
            Some([
                read_u32(bytes, 96),
                read_u32(bytes, 100),
                read_u32(bytes, 104),
            ])
        } else {
            None
        },
        intent: if need >= 124 && bytes.len() >= 112 {
            Some(read_u32(bytes, 108) as i32)
        } else {
            None
        },
        profile_data: if need >= 124 && bytes.len() >= 116 {
            Some(read_u32(bytes, 112))
        } else {
            None
        },
        profile_size: if need >= 124 && bytes.len() >= 120 {
            Some(read_u32(bytes, 116))
        } else {
            None
        },
        reserved: if need >= 124 && bytes.len() >= 124 {
            Some(read_u32(bytes, 120))
        } else {
            None
        },
    }
}

/// A palette RGBQUAD stored as four bytes (blue, green, red, alpha on the
/// wire; modeled in channel order).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct PaletteEntry {
    pub red: u8,
    pub green: u8,
    pub blue: u8,
    pub alpha: u8,
}

impl PaletteEntry {
    pub fn parse_wire(bytes: &[u8], at: usize) -> Self {
        let get = |i: usize| -> u8 { bytes.get(at + i).copied().unwrap_or(0) };
        Self {
            blue: get(0),
            green: get(1),
            red: get(2),
            alpha: get(3),
        }
    }

    pub fn serialize_wire(&self) -> [u8; 4] {
        [self.blue, self.green, self.red, self.alpha]
    }
}

/// Structural DIB image: header zoo, palette, and the raw pixel bits.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DibImage {
    pub header: DibHeader,
    /// RGBQUAD entries (RGBTRIPLE for core headers is widened to quads with
    /// zero alpha; serialization knows the core layout).
    pub palette: Vec<PaletteEntry>,
    pub pixel_bits: Vec<u8>,
}
