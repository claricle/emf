//! Structured failures for detection, parsing and serialization.

use std::fmt;

use crate::detect::Format;

/// Which budget a [`ParseFailure::LimitExceeded`] refers to.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum LimitKind {
    InputBytes,
    RecordBytes,
    RecordCount,
    AllocatedBytes,
    WorkUnits,
}

/// Unrecoverable failure: no usable document can be produced.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ParseFailure {
    /// Fewer than four bytes: no signature can be read.
    TooShort { len: usize },
    /// No known EMF/WMF signature.
    UnrecognizedFormat { first_u32: u32 },
    /// Detected, but this crate does not parse that format.
    UnsupportedFormat(Format),
    /// A read ran past the end of the available bytes.
    Truncated {
        offset: usize,
        needed: usize,
        available: usize,
    },
    /// The header record declares a size that cannot hold the fixed header.
    HeaderSizeTooSmall { declared: u32, minimum: u32 },
    /// The first record is not `EMR_HEADER` (type 1).
    BadHeaderType { found: u32 },
    /// Header size fields do not fit or overflow arithmetic.
    ArithmeticOverflow { offset: usize },
    /// A configured budget was exceeded.
    LimitExceeded {
        kind: LimitKind,
        limit: u64,
        requested: u64,
    },
    /// A fallible reservation was refused by the allocator.
    AllocationFailed { bytes: usize },
}

impl fmt::Display for ParseFailure {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::TooShort { len } => write!(f, "input too short ({len} bytes)"),
            Self::UnrecognizedFormat { first_u32 } => {
                write!(f, "unrecognised format (first uint32=0x{first_u32:08X})")
            }
            Self::UnsupportedFormat(format) => write!(f, "format {format:?} is not parsed"),
            Self::Truncated {
                offset,
                needed,
                available,
            } => write!(
                f,
                "truncated at offset {offset}: needed {needed}, available {available}"
            ),
            Self::HeaderSizeTooSmall { declared, minimum } => {
                write!(f, "EMF header nSize too small: {declared} < {minimum}")
            }
            Self::BadHeaderType { found } => {
                write!(f, "first record type {found} is not EMR_HEADER")
            }
            Self::ArithmeticOverflow { offset } => {
                write!(f, "arithmetic overflow at offset {offset}")
            }
            Self::LimitExceeded {
                kind,
                limit,
                requested,
            } => write!(f, "{kind:?} limit exceeded ({requested} > {limit})"),
            Self::AllocationFailed { bytes } => write!(f, "allocation of {bytes} bytes failed"),
        }
    }
}

impl std::error::Error for ParseFailure {}

/// Failure while serializing a document.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum SerializeFailure {
    /// The document's pieces are not contiguous and in order.
    Inconsistent { offset: usize },
    /// A fallible reservation was refused by the allocator.
    AllocationFailed { bytes: usize },
}

impl fmt::Display for SerializeFailure {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Inconsistent { offset } => {
                write!(f, "document pieces inconsistent at offset {offset}")
            }
            Self::AllocationFailed { bytes } => write!(f, "allocation of {bytes} bytes failed"),
        }
    }
}

impl std::error::Error for SerializeFailure {}
