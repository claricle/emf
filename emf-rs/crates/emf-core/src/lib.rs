//! Ruby-independent EMF core: checked reads, detection, header and record
//! framing, and exact unchanged serialization.
//!
//! A small typed record slice supports checked edits. The [`wmf`] module adds
//! bounded WMF framing with opaque drawing records and checked raw edits.

mod bitmap;
mod detect;
pub mod emf_plus;
mod error;
mod gradient;
mod limits;
mod model;
mod parse;
mod reader;
mod poly_text;
mod serialize;
pub mod wmf;

pub use detect::{detect_format, Format};
pub use error::{EditFailure, LimitKind, ParseFailure, SerializeFailure};
pub use limits::{Budget as ParseBudget, ParseLimits, SerializeLimits};
pub use model::{
    ColorRef, DesignVector, Diagnostic, DiagnosticKind, Document, EmfHeader, EofRecord,
    ExtCreatePen, ExtTextOut, Float32, Font, FontRecord, LogFont, LogFontEx, LogFontExDv,
    LogFontPanose, PaletteEntry, PixelFormatFields, Point, Point16, RecordData, RecordSpan, Rect,
    RegionData, ScaleFactors, Size, XForm, EMR_EOF, EMR_HEADER, HEADER_FIXED_BYTES,
};
pub use parse::parse;
pub use reader::Reader;
pub use serialize::{serialize, serialize_with_limits};

pub use gradient::{GradientFill, GradientMesh, TriVertex};

pub use bitmap::{
    BitmapBuffer, BitmapBufferKind, BitmapBuffers, BitmapMask, BitmapRecord, BitmapSource,
    BitmapTransfer, BlendFunction, DibTransfer,
};

pub use poly_text::{ColorAdjustment, PolyTextEntry, PolyTextOut};
