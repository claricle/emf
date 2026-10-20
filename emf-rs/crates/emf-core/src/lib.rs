//! Ruby-independent EMF core: checked reads, detection, header and record
//! framing, and exact unchanged serialization.
//!
//! A small typed record slice supports checked edits. WMF signatures
//! are detected but WMF is not parsed.

mod detect;
mod error;
mod limits;
mod model;
mod parse;
mod reader;
mod serialize;

pub use detect::{detect_format, Format};
pub use error::{EditFailure, LimitKind, ParseFailure, SerializeFailure};
pub use limits::{ParseLimits, SerializeLimits};
pub use model::{
    ColorRef, DesignVector, Diagnostic, DiagnosticKind, Document, EmfHeader, EofRecord,
    ExtCreatePen, ExtTextOut, Float32, Font, FontRecord, LogFont, LogFontEx, LogFontExDv,
    LogFontPanose, PaletteEntry, PixelFormatFields, Point, Point16, RecordData, RecordSpan, Rect, RegionData,
    ScaleFactors, Size, XForm, EMR_EOF, EMR_HEADER, HEADER_FIXED_BYTES,
};
pub use parse::parse;
pub use reader::Reader;
pub use serialize::{serialize, serialize_with_limits};
