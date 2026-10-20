//! Bounded structured EMF+ logical streams (MS-EMFPLUS section 2.3).
//!
//! This is an opt-in API alongside the legacy raw `Document::emf_plus_chunks`.
//! Comment segments contain only bytes after the EMF+ signature; outer EMF
//! comment headers and their padding remain owned by the embedding caller.
mod container;
pub use container::{EmbedError, EmbeddedStream};
mod object_data;
pub use object_data::{
    ArrowLineCap, CustomLineCap, CustomLineCapData, DefaultLineCap, GradientBoundary,
    LinearGradient, ObjectData, Path, PathGradient, PathPointRun, PathPointTypes, Pen, PenBrush,
    PenBrushData, PixelBitmap, Region, RegionNode, StringFormat, Texture, TextureImage,
};
mod tsclip;
pub use tsclip::TSClip;
mod tsgraphics;
pub use tsgraphics::{Palette, TSGraphics};
mod effects;
pub use effects::Effect;
mod text;
pub use text::Text;
mod drawing;
pub use drawing::{Drawing, ImageSource, PointData, Rectangle, RelativeCoordinate};
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
