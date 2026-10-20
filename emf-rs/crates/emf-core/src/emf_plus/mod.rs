//! Bounded structured EMF+ logical streams (MS-EMFPLUS section 2.3).
//!
//! This is an opt-in API alongside the legacy `Document::emf_plus_bytes`.
//! Comment segments contain only bytes after the EMF+ signature; outer EMF
//! comment headers and their padding remain owned by the embedding caller.
mod drawing;
pub use drawing::{Drawing, PointData, Rectangle, RelativeCoordinate};
mod objects;
mod parser;
pub use objects::{ObjectBody, ObjectDefinition, ObjectFragment};
mod records;
mod serializer;
pub use parser::{parse, parse_segments};
pub use records::{Header, Record, RecordData, Stream};
pub use serializer::{serialize, serialize_segments, serialize_with_limits};

use crate::ParseFailure;

/// A framing or typed layout failure. Resource failures retain the core budget kind.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Error {
    Resource(ParseFailure),
    InvalidObject {
        record_index: usize,
        reason: &'static str,
    },
    InvalidRecord {
        offset: usize,
        reason: &'static str,
    },
}
impl From<ParseFailure> for Error {
    fn from(value: ParseFailure) -> Self {
        Self::Resource(value)
    }
}
impl std::fmt::Display for Error {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Resource(e) => e.fmt(f),
            Self::InvalidObject {
                record_index,
                reason,
            } => write!(f, "EMF+ object at record {record_index}: {reason}"),
            Self::InvalidRecord { offset, reason } => {
                write!(f, "EMF+ record at {offset}: {reason}")
            }
        }
    }
}
impl std::error::Error for Error {}
