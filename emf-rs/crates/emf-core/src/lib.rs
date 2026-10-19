//! Ruby-independent EMF core: checked reads, detection, header and record
//! framing, and exact unchanged serialization.
//!
//! Records are framed but not decoded: every payload stays raw. WMF signatures
//! are detected but WMF is not parsed.

mod detect;
mod error;
mod limits;
mod model;
mod parse;
mod reader;
mod serialize;

pub use detect::{detect_format, Format};
pub use error::{LimitKind, ParseFailure, SerializeFailure};
pub use limits::ParseLimits;
pub use model::{
    Diagnostic, DiagnosticKind, Document, EmfHeader, PixelFormatFields, RecordSpan, Rect, Size,
    EMR_EOF, EMR_HEADER, HEADER_FIXED_BYTES,
};
pub use parse::parse;
pub use reader::Reader;
pub use serialize::serialize;
