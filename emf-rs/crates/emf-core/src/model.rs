//! Owned document model.
//!
//! The document owns one copy of the input. The header and every record are
//! spans into that copy, so unchanged serialization reproduces the original
//! bytes, including padding, unknown payloads and trailing data.

use std::ops::Range;

/// `EMR_HEADER` record type.
pub const EMR_HEADER: u32 = 1;
/// `EMR_EOF` record type.
pub const EMR_EOF: u32 = 14;

/// Fixed part of the EMF header record, in bytes.
pub const HEADER_FIXED_BYTES: usize = 88;

/// Rectangle as stored in the header (left, top, right, bottom).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Rect {
    pub left: i32,
    pub top: i32,
    pub right: i32,
    pub bottom: i32,
}

/// Width and height pair.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Size {
    pub cx: i32,
    pub cy: i32,
}

/// Fields present when the header is longer than 88 bytes.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct PixelFormatFields {
    pub cb_pixel_format: u32,
    pub off_pixel_format: u32,
    pub b_open_gl: u32,
}

/// Decoded EMF header. Values are as stored; none are validated against the
/// records that follow, and none are normalized.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct EmfHeader {
    pub n_size: u32,
    pub bounds: Rect,
    pub frame: Rect,
    pub signature: u32,
    pub version: u32,
    pub n_bytes: u32,
    pub n_records: u32,
    pub n_handles: u16,
    pub reserved: u16,
    pub n_description: u32,
    pub off_description: u32,
    pub n_pal_entries: u32,
    pub device: Size,
    pub millimeters: Size,
    /// Present when `n_size > 88`.
    pub pixel_format: Option<PixelFormatFields>,
    /// Present when `n_size > 100`.
    pub micrometers: Option<Size>,
}

/// One framed record: its type and where its bytes live in the source copy.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct RecordSpan {
    pub(crate) offset: usize,
    pub(crate) size: u32,
    pub(crate) record_type: u32,
}

impl RecordSpan {
    pub fn offset(&self) -> usize {
        self.offset
    }

    /// The record's declared `nSize`, which is also its byte length.
    pub fn size(&self) -> u32 {
        self.size
    }

    pub fn record_type(&self) -> u32 {
        self.record_type
    }

    pub fn is_eof(&self) -> bool {
        self.record_type == EMR_EOF
    }

    pub(crate) fn range(&self) -> Range<usize> {
        self.offset..self.offset + self.size as usize
    }
}

/// Why framing stopped early or a record could not be framed.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum DiagnosticKind {
    /// Fewer than eight bytes remain, too few for a record head.
    TruncatedRecordHead { available: usize },
    /// `nSize` below the eight-byte record head; framing cannot progress.
    RecordSizeTooSmall { size: u32 },
    /// `nSize` runs past the end of the input.
    TruncatedRecord { claimed: u32, available: usize },
}

/// Recoverable framing problem; parsing stopped at `offset`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Diagnostic {
    pub offset: usize,
    pub record_type: Option<u32>,
    pub kind: DiagnosticKind,
}

/// Parsed EMF: header, ordered framed records, diagnostics and leftover bytes.
///
/// Records are not decoded beyond their type and size; all payloads stay raw.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Document {
    pub(crate) source: Vec<u8>,
    pub(crate) header: EmfHeader,
    pub(crate) header_len: usize,
    pub(crate) records: Vec<RecordSpan>,
    pub(crate) diagnostics: Vec<Diagnostic>,
    /// Start of bytes after the last framed record: the data after `EMR_EOF`
    /// when one was framed, otherwise the unframed tail left by a stop.
    pub(crate) tail_offset: usize,
}

impl Document {
    pub fn header(&self) -> &EmfHeader {
        &self.header
    }

    /// Raw bytes of the header record.
    pub fn header_bytes(&self) -> &[u8] {
        &self.source[..self.header_len]
    }

    /// Records after the header, in file order, including `EMR_EOF`.
    pub fn records(&self) -> &[RecordSpan] {
        &self.records
    }

    /// Raw bytes (head and payload) of a record from [`Document::records`].
    pub fn record_bytes(&self, record: &RecordSpan) -> Option<&[u8]> {
        self.source.get(record.range())
    }

    pub fn diagnostics(&self) -> &[Diagnostic] {
        &self.diagnostics
    }

    /// Whether an `EMR_EOF` record was framed.
    pub fn has_eof(&self) -> bool {
        self.records.last().is_some_and(RecordSpan::is_eof)
    }

    /// Bytes after `EMR_EOF`; empty unless the file has data past it.
    pub fn trailing_bytes(&self) -> &[u8] {
        if self.has_eof() {
            &self.source[self.tail_offset..]
        } else {
            &[]
        }
    }

    /// Bytes left unframed after a stop (a diagnostic is present); empty when
    /// an `EMR_EOF` was framed.
    pub fn unframed_bytes(&self) -> &[u8] {
        if self.has_eof() {
            &[]
        } else {
            &self.source[self.tail_offset..]
        }
    }
}
