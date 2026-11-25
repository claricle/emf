use std::fmt;

/// Model-level failure modes.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Error {
    /// Leading signature missing or wrong.
    Signature,
    /// A chunk's stored CRC does not match its contents.
    Crc { kind: [u8; 4], stored_crc: u32 },
    /// Any other structural violation of the chunk grammar.
    Format(&'static str),
    /// The zlib pixel stream is malformed or truncated.
    Zlib(&'static str),
    /// Length mismatch while inflating (decompressed size not derivable).
    ZlibOverflow,
}

impl fmt::Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Signature => write!(f, "PNG signature missing or invalid"),
            Self::Crc { kind, stored_crc } => {
                let kind: String = kind.iter().map(|b| char::from(*b)).collect();
                write!(
                    f,
                    "chunk {kind} stored CRC {stored_crc:#010x} does not match contents"
                )
            }
            Self::Format(msg) => write!(f, "invalid chunk stream: {msg}"),
            Self::Zlib(msg) => write!(f, "zlib pixel stream error: {msg}"),
            Self::ZlibOverflow => write!(f, "inflated pixel stream larger than image"),
        }
    }
}

impl std::error::Error for Error {}
