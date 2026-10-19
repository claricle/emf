//! Signature detection. Mirrors the Ruby detector; detecting a WMF variant does
//! not mean this crate can parse it.

use crate::error::ParseFailure;
use crate::reader::{u16_at, u32_at};

const APM_MAGIC: u32 = 0x9AC6_CDD7;
const EMF_SIGNATURE: u32 = 1;
const EMF_MAGIC_OFFSET: usize = 0x28;
pub(crate) const EMF_MAGIC: u32 = 0x464D_4520;

/// Container format recognised from the leading bytes.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Format {
    Emf,
    /// Aldus placeable metafile.
    WmfApm,
    /// Standard WMF with a metaheader.
    WmfStandard,
}

pub fn detect_format(bytes: &[u8]) -> Result<Format, ParseFailure> {
    let first = u32_at(bytes, 0).ok_or(ParseFailure::TooShort { len: bytes.len() })?;
    match first {
        APM_MAGIC => Ok(Format::WmfApm),
        EMF_SIGNATURE if u32_at(bytes, EMF_MAGIC_OFFSET) == Some(EMF_MAGIC) => Ok(Format::Emf),
        _ if looks_like_wmf_metaheader(bytes) => Ok(Format::WmfStandard),
        _ => Err(ParseFailure::UnrecognizedFormat { first_u32: first }),
    }
}

fn looks_like_wmf_metaheader(bytes: &[u8]) -> bool {
    bytes.len() >= 18 && matches!(u16_at(bytes, 0), Some(1 | 2)) && u16_at(bytes, 2) == Some(9)
}
