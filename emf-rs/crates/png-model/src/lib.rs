//! PNG chunk-tree model: strict decode into the model, and a serializer that
//! emits bytes. The model — not raw bytes — is the artifact: every chunk is
//! retained in file order with its kind and data, and the header fields are
//! parsed into a typed [`Ihdr`].
//!
//! This crate is format-scoped: it contains no EMF or DIB concepts. Pixel
//! access goes through [`surface`]; compression-profile PNG emission
//! (matching the libpng 1.6 default write path byte for byte) goes through
//! [`encode`].
use crate::crc::crc32;

pub mod encode;
pub mod surface;

mod crc;
mod error;
mod zlib;
pub use encode::encode_rgba8;
pub use error::Error;

/// Signature every PNG stream starts with.
pub const SIGNATURE: [u8; 8] = [0x89, b'P', b'N', b'G', 0x0d, 0x0a, 0x1a, 0x0a];

/// Parsed IHDR fields.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Ihdr {
    pub width: u32,
    pub height: u32,
    pub bit_depth: u8,
    pub color_type: u8,
    /// Always 0 (deflate/inflate) in this model; retained as a field.
    pub compression_method: u8,
    /// Always 0 (adaptive filtering) in this model; retained as a field.
    pub filter_method: u8,
    /// 0 (none) or 1 (Adam7).
    pub interlace_method: u8,
}

impl Ihdr {
    pub fn serialize(&self) -> [u8; 13] {
        let mut out = [0u8; 13];
        out[..4].copy_from_slice(&self.width.to_be_bytes());
        out[4..8].copy_from_slice(&self.height.to_be_bytes());
        out[8] = self.bit_depth;
        out[9] = self.color_type;
        out[10] = self.compression_method;
        out[11] = self.filter_method;
        out[12] = self.interlace_method;
        out
    }

    fn parse(data: &[u8]) -> Result<Self, Error> {
        if data.len() != 13 {
            return Err(Error::Format("IHDR must be 13 bytes"));
        }
        let width = u32::from_be_bytes([data[0], data[1], data[2], data[3]]);
        let height = u32::from_be_bytes([data[4], data[5], data[6], data[7]]);
        let bit_depth = data[8];
        let color_type = data[9];
        let compression_method = data[10];
        let filter_method = data[11];
        let interlace_method = data[12];
        if width == 0 || height == 0 {
            return Err(Error::Format("zero image dimension"));
        }
        let depth_ok = match color_type {
            0 => matches!(bit_depth, 1 | 2 | 4 | 8 | 16),
            2 | 6 => matches!(bit_depth, 8 | 16),
            3 => matches!(bit_depth, 1 | 2 | 4 | 8),
            4 => matches!(bit_depth, 8 | 16),
            _ => false,
        };
        if !depth_ok {
            return Err(Error::Format("bit depth invalid for color type"));
        }
        if compression_method != 0 || filter_method != 0 {
            return Err(Error::Format("unknown compression or filter method"));
        }
        if interlace_method > 1 {
            return Err(Error::Format("unknown interlace method"));
        }
        Ok(Self {
            width,
            height,
            bit_depth,
            color_type,
            compression_method,
            filter_method,
            interlace_method,
        })
    }
}

/// A retained chunk: kind, raw data, and the CRC the stream carried.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Chunk {
    pub kind: [u8; 4],
    pub data: Vec<u8>,
}

impl Chunk {
    pub fn crc(&self) -> u32 {
        crc32(&self.kind, &self.data)
    }
}

/// The decoded PNG: the chunk tree in file order, plus the parsed header.
///
/// The model is byte-stable: `decode(bytes)?.serialize() == bytes` for any
/// stream whose CRCs and framing are valid (which strict decoding requires).
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Png {
    pub chunks: Vec<Chunk>,
    pub ihdr: Ihdr,
}

impl Png {
    /// Strictly decode a PNG stream into the model.
    ///
    /// Verifies the signature, chunk framing (length bounds, kind characters,
    /// CRCs), IHDR validity and position, IEND position, and IDAT contiguity.
    pub fn decode(bytes: &[u8]) -> Result<Self, Error> {
        if bytes.len() < 8 || bytes[..8] != SIGNATURE {
            return Err(Error::Signature);
        }
        let mut rest = &bytes[8..];
        let mut chunks = Vec::new();
        let mut ihdr: Option<Ihdr> = None;
        let mut seen_iend = false;
        let mut seen_idat = false;
        let mut after_idat = false;
        while !rest.is_empty() {
            if rest.len() < 12 {
                return Err(Error::Format("truncated chunk header"));
            }
            let len = u32::from_be_bytes([rest[0], rest[1], rest[2], rest[3]]) as usize;
            if len > 0x7fff_ffff {
                return Err(Error::Format("chunk length exceeds 2^31-1"));
            }
            let kind = [rest[4], rest[5], rest[6], rest[7]];
            if !kind.iter().all(|b| b.is_ascii_alphabetic()) {
                return Err(Error::Format("chunk kind not ASCII letters"));
            }
            let end = 8usize
                .checked_add(len)
                .and_then(|n| n.checked_add(4))
                .filter(|n| *n <= rest.len())
                .ok_or(Error::Format("chunk data out of bounds"))?;
            let data = &rest[8..8 + len];
            let stored_crc =
                u32::from_be_bytes([rest[8 + len], rest[9 + len], rest[10 + len], rest[11 + len]]);
            let chunk = Chunk {
                kind,
                data: data.to_vec(),
            };
            if chunk.crc() != stored_crc {
                return Err(Error::Crc { kind, stored_crc });
            }
            match &kind {
                b"IHDR" => {
                    if !chunks.is_empty() {
                        return Err(Error::Format("IHDR not first"));
                    }
                    ihdr = Some(Ihdr::parse(data)?);
                }
                b"IEND" => {
                    if !data.is_empty() {
                        return Err(Error::Format("IEND carries data"));
                    }
                    seen_iend = true;
                }
                b"IDAT" => {
                    if ihdr.is_none() {
                        return Err(Error::Format("IDAT before IHDR"));
                    }
                    if after_idat {
                        return Err(Error::Format("non-contiguous IDAT"));
                    }
                    seen_idat = true;
                }
                _ => {
                    if seen_idat {
                        after_idat = true;
                    }
                }
            }
            if seen_iend && !rest[end..].is_empty() {
                return Err(Error::Format("data after IEND"));
            }
            chunks.push(chunk);
            rest = &rest[end..];
        }
        let ihdr = ihdr.ok_or(Error::Format("missing IHDR"))?;
        if !seen_iend {
            return Err(Error::Format("missing IEND"));
        }
        if ihdr.color_type == 3 && !chunks.iter().any(|c| &c.kind == b"PLTE") {
            return Err(Error::Format("palette color type without PLTE"));
        }
        if ihdr.color_type != 3 && chunks.iter().any(|c| &c.kind == b"PLTE") {
            return Err(Error::Format("PLTE on non-palette color type"));
        }
        if !seen_idat {
            return Err(Error::Format("missing IDAT"));
        }
        Ok(Self { chunks, ihdr })
    }

    /// Emit the chunk tree as a byte stream (recomputed CRCs; identical to
    /// the source stream for any strictly-decoded model).
    pub fn serialize(&self) -> Vec<u8> {
        let mut out = Vec::new();
        out.extend_from_slice(&SIGNATURE);
        for chunk in &self.chunks {
            let len = u32::try_from(chunk.data.len()).expect("strict decode bounds lengths");
            out.extend_from_slice(&len.to_be_bytes());
            out.extend_from_slice(&chunk.kind);
            out.extend_from_slice(&chunk.data);
            out.extend_from_slice(&chunk.crc().to_be_bytes());
        }
        out
    }

    /// Concatenated IDAT payload (the zlib-compressed pixel stream).
    pub fn idat(&self) -> Vec<u8> {
        let mut out = Vec::new();
        for chunk in &self.chunks {
            if &chunk.kind == b"IDAT" {
                out.extend_from_slice(&chunk.data);
            }
        }
        out
    }
}

#[cfg(test)]
mod tests {
    use super::{Chunk, Ihdr, Png, SIGNATURE};

    fn build(width: u32, height: u32) -> Vec<u8> {
        let ihdr_data = Ihdr {
            width,
            height,
            bit_depth: 8,
            color_type: 6,
            compression_method: 0,
            filter_method: 0,
            interlace_method: 0,
        }
        .serialize();
        let mut chunks = vec![Chunk {
            kind: *b"IHDR",
            data: ihdr_data.to_vec(),
        }];
        // Minimal valid IDAT: an empty stored zlib stream is not valid, so
        // encode a real one-pixel image and take its IDAT.
        let png = crate::encode::encode_rgba8(1, 1, &[1, 2, 3, 4]).expect("encode");
        let decoded = Png::decode(&png).expect("decode");
        chunks.push(decoded.chunks[1].clone());
        chunks.push(Chunk {
            kind: *b"IEND",
            data: Vec::new(),
        });
        Png {
            chunks,
            ihdr: Ihdr::parse(&ihdr_data).expect("parse"),
        }
        .serialize()
    }

    #[test]
    fn round_trip_is_byte_stable() {
        let bytes = build(7, 3);
        let model = Png::decode(&bytes).expect("decode");
        assert_eq!(model.serialize(), bytes);
        assert_eq!(model.ihdr.width, 7);
        assert_eq!(model.ihdr.height, 3);
    }

    #[test]
    fn rejects_corrupted_crc() {
        let bytes = build(2, 2);
        let mut corrupted = bytes.clone();
        let n = corrupted.len();
        corrupted[n - 1] ^= 0xff;
        assert!(matches!(
            Png::decode(&corrupted),
            Err(super::Error::Crc { .. })
        ));
    }

    #[test]
    fn rejects_bad_signature() {
        let mut bytes = build(2, 2);
        bytes[0] ^= 0xff;
        assert_eq!(Png::decode(&bytes), Err(super::Error::Signature));
        assert_ne!(bytes[..8], SIGNATURE);
    }
}
