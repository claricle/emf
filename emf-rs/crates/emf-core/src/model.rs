//! Owned document model.
//!
//! The document owns one copy of the input. The header and every record are
//! spans into that copy, so unchanged serialization reproduces the original
//! bytes, including padding, unknown payloads and trailing data.

use crate::error::EditFailure;
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

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Point {
    pub x: i32,
    pub y: i32,
}

/// COLORREF bytes as stored, including the unmodified reserved byte.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ColorRef {
    pub red: u8,
    pub green: u8,
    pub blue: u8,
    pub reserved: u8,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct EofRecord {
    pub n_pal_entries: u32,
    pub off_pal_entries: u32,
    /// EOF record size, including its header and optional palette buffer.
    pub n_size_last: u32,
}

/// Supported payloads. Raw records retain all their original bytes.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum RecordData {
    Raw,
    Eof(EofRecord),
    SetWindowExtEx {
        extent: Size,
    },
    SetWindowOrgEx {
        origin: Point,
    },
    SetViewportExtEx {
        extent: Size,
    },
    SetViewportOrgEx {
        origin: Point,
    },
    SetBrushOrgEx {
        origin: Point,
    },
    OffsetClipRgn {
        offset: Point,
    },
    MoveToEx {
        origin: Point,
    },
    SetMapMode {
        map_mode: u32,
    },
    SetBkMode {
        bk_mode: u32,
    },
    SetPolyFillMode {
        poly_fill_mode: u32,
    },
    SetRop2 {
        rop2: u32,
    },
    SetStretchBltMode {
        stretch_mode: u32,
    },
    SetTextColor {
        color: ColorRef,
    },
    SetBkColor {
        color: ColorRef,
    },
    Polyline {
        bounds: Rect,
        points: Vec<Point>,
    },
    Comment {
        data: Vec<u8>,
    },
    Ellipse {
        bounds: Rect,
    },
    Rectangle {
        bounds: Rect,
    },
    RoundRect {
        bounds: Rect,
        corner: Size,
    },
    SetTextAlign {
        text_align_mode: u32,
    },
    RestoreDc {
        saved_dc: i32,
    },
    SelectObject {
        ih_object: u32,
    },
    DeleteObject {
        ih_object: u32,
    },
    SetArcDirection {
        arc_direction: u32,
    },
    SelectClipPath {
        region_mode: u32,
    },
    SaveDc,
    BeginPath,
    EndPath,
    CloseFigure,
    AbortPath,
    FillPath {
        bounds: Rect,
    },
    StrokeAndFillPath {
        bounds: Rect,
    },
    StrokePath {
        bounds: Rect,
    },
    LineTo {
        origin: Point,
    },
    Arc {
        bounds: Rect,
        start: Point,
        end: Point,
    },
    ArcTo {
        bounds: Rect,
        start: Point,
        end: Point,
    },
    Chord {
        bounds: Rect,
        start: Point,
        end: Point,
    },
    Pie {
        bounds: Rect,
        start: Point,
        end: Point,
    },
    ExcludeClipRect {
        clip: Rect,
    },
    IntersectClipRect {
        clip: Rect,
    },
    CreatePen {
        ih_pen: u32,
        pen_style: u32,
        width: Point,
        color: ColorRef,
    },
    CreateBrushIndirect {
        ih_brush: u32,
        brush_style: u32,
        color: ColorRef,
        brush_hatch: u32,
    },
    SetPixelV {
        pixel: Point,
        color: ColorRef,
    },
}
impl RecordData {
    pub(crate) fn record_type(&self) -> Option<u32> {
        match self {
            Self::Raw => None,
            Self::Eof(_) => Some(14),
            Self::SetWindowExtEx { .. } => Some(9),
            Self::SetWindowOrgEx { .. } => Some(10),
            Self::SetViewportExtEx { .. } => Some(11),
            Self::SetViewportOrgEx { .. } => Some(12),
            Self::SetBrushOrgEx { .. } => Some(13),
            Self::OffsetClipRgn { .. } => Some(26),
            Self::MoveToEx { .. } => Some(27),
            Self::SetMapMode { .. } => Some(17),
            Self::SetBkMode { .. } => Some(18),
            Self::SetPolyFillMode { .. } => Some(19),
            Self::SetRop2 { .. } => Some(20),
            Self::SetStretchBltMode { .. } => Some(21),
            Self::SetTextColor { .. } => Some(24),
            Self::SetBkColor { .. } => Some(25),
            Self::Polyline { .. } => Some(4),
            Self::Comment { .. } => Some(70),
            Self::Ellipse { .. } => Some(42),
            Self::Rectangle { .. } => Some(43),
            Self::RoundRect { .. } => Some(44),
            Self::SetTextAlign { .. } => Some(22),
            Self::RestoreDc { .. } => Some(34),
            Self::SelectObject { .. } => Some(37),
            Self::DeleteObject { .. } => Some(40),
            Self::SetArcDirection { .. } => Some(57),
            Self::SelectClipPath { .. } => Some(67),
            Self::SaveDc => Some(33),
            Self::BeginPath => Some(59),
            Self::EndPath => Some(60),
            Self::CloseFigure => Some(61),
            Self::AbortPath => Some(68),
            Self::FillPath { .. } => Some(62),
            Self::StrokeAndFillPath { .. } => Some(63),
            Self::StrokePath { .. } => Some(64),
            Self::LineTo { .. } => Some(54),
            Self::Arc { .. } => Some(45),
            Self::ArcTo { .. } => Some(55),
            Self::Chord { .. } => Some(46),
            Self::Pie { .. } => Some(47),
            Self::ExcludeClipRect { .. } => Some(29),
            Self::IntersectClipRect { .. } => Some(30),
            Self::CreatePen { .. } => Some(38),
            Self::CreateBrushIndirect { .. } => Some(39),
            Self::SetPixelV { .. } => Some(15),
        }
    }
    pub(crate) fn payload_len(&self) -> Option<usize> {
        match self {
            Self::LineTo { .. } => Some(8),
            Self::Arc { .. } => Some(32),
            Self::ArcTo { .. } => Some(32),
            Self::Chord { .. } => Some(32),
            Self::Pie { .. } => Some(32),
            Self::ExcludeClipRect { .. } => Some(16),
            Self::IntersectClipRect { .. } => Some(16),
            Self::CreatePen { .. } => Some(20),
            Self::CreateBrushIndirect { .. } => Some(16),
            Self::SetPixelV { .. } => Some(12),
            Self::Raw => None,
            Self::Eof(_) => Some(12),
            Self::SetWindowExtEx { .. }
            | Self::SetWindowOrgEx { .. }
            | Self::SetViewportExtEx { .. }
            | Self::SetViewportOrgEx { .. }
            | Self::SetBrushOrgEx { .. }
            | Self::OffsetClipRgn { .. }
            | Self::MoveToEx { .. } => Some(8),
            Self::SetMapMode { .. }
            | Self::SetBkMode { .. }
            | Self::SetPolyFillMode { .. }
            | Self::SetRop2 { .. }
            | Self::SetStretchBltMode { .. }
            | Self::SetTextColor { .. }
            | Self::SetBkColor { .. } => Some(4),
            Self::Polyline { points, .. } => points.len().checked_mul(8)?.checked_add(20),
            Self::Comment { data } => data.len().checked_add(4),
            Self::Ellipse { .. } | Self::Rectangle { .. } => Some(16),
            Self::RoundRect { .. } => Some(24),
            Self::SetTextAlign { .. }
            | Self::RestoreDc { .. }
            | Self::SelectObject { .. }
            | Self::DeleteObject { .. }
            | Self::SetArcDirection { .. }
            | Self::SelectClipPath { .. } => Some(4),
            Self::SaveDc
            | Self::BeginPath
            | Self::EndPath
            | Self::CloseFigure
            | Self::AbortPath => Some(0),
            Self::FillPath { .. } | Self::StrokeAndFillPath { .. } | Self::StrokePath { .. } => {
                Some(16)
            }
        }
    }
}

/// One framed record: its type and where its bytes live in the source copy.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RecordSpan {
    pub(crate) offset: usize,
    pub(crate) size: u32,
    pub(crate) record_type: u32,
    pub(crate) data: RecordData,
    pub(crate) decoded_len: usize,
    pub(crate) edited: bool,
}

impl RecordSpan {
    pub(crate) fn edited_size(&self, data: &RecordData) -> Option<usize> {
        let size = data.payload_len()?.checked_add(8)?;
        if matches!(data, RecordData::Comment { .. }) {
            size.checked_add((4 - size % 4) % 4)
        } else {
            size.checked_add(self.size as usize - 8 - self.decoded_len)
        }
    }

    pub fn data(&self) -> &RecordData {
        &self.data
    }
    pub fn is_edited(&self) -> bool {
        self.edited
    }
    pub fn offset(&self) -> usize {
        self.offset
    }

    /// Original declared `nSize`; edited output can have a different length.
    pub fn size(&self) -> u32 {
        self.size
    }

    pub fn record_type(&self) -> u32 {
        self.record_type
    }

    /// Whether this record decoded as EOF; malformed type-14 records remain raw.
    pub fn is_eof(&self) -> bool {
        matches!(self.data, RecordData::Eof(_))
    }

    pub(crate) fn range(&self) -> Range<usize> {
        self.offset..self.offset + self.size as usize
    }
}

/// A framing failure or a malformed supported payload.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum DiagnosticKind {
    /// A supported payload has missing fields or a count outside its record.
    InvalidRecordPayload,
    /// Fewer than eight bytes remain, too few for a record head.
    TruncatedRecordHead { available: usize },
    /// `nSize` below the eight-byte record head; framing cannot progress.
    RecordSizeTooSmall { size: u32 },
    /// `nSize` runs past the end of the input.
    TruncatedRecord { claimed: u32, available: usize },
}

/// Recoverable problem at `offset`. Invalid payloads do not stop framing.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Diagnostic {
    pub offset: usize,
    pub record_type: Option<u32>,
    pub kind: DiagnosticKind,
}

/// Parsed EMF: header, ordered framed records, diagnostics and leftover bytes.
///
/// Original bytes remain available even when supported payloads are edited.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Document {
    pub(crate) source: Vec<u8>,
    pub(crate) header: EmfHeader,
    pub(crate) header_len: usize,
    pub(crate) header_edited: bool,
    pub(crate) records: Vec<RecordSpan>,
    pub(crate) diagnostics: Vec<Diagnostic>,
    /// Start of bytes after the last framed record: the data after `EMR_EOF`
    /// when one was framed, otherwise the unframed tail left by a stop.
    pub(crate) tail_offset: usize,
}

impl Document {
    pub fn is_edited(&self) -> bool {
        self.header_edited || self.records.iter().any(RecordSpan::is_edited)
    }

    /// Replace decoded header fields while preserving its original layout and opaque bytes.
    pub fn edit_header(&mut self, header: EmfHeader) -> Result<(), EditFailure> {
        if header.n_size as usize != self.header_len
            || header.signature != self.header.signature
            || header.pixel_format.is_some() != self.header.pixel_format.is_some()
            || header.micrometers.is_some() != self.header.micrometers.is_some()
        {
            return Err(EditFailure::HeaderLayout);
        }
        self.header = header;
        self.header_edited = true;
        Ok(())
    }

    /// Replace a supported payload; raw records and record families cannot change.
    /// Comments require a canonical source padding layout; edited padding is resized
    /// to at most three bytes. EOF size must still equal its unchanged record size.
    pub fn edit_record(&mut self, index: usize, data: RecordData) -> Result<(), EditFailure> {
        let record = self
            .records
            .get_mut(index)
            .ok_or(EditFailure::RecordIndex { index })?;
        if record.data == RecordData::Raw || data.record_type() != Some(record.record_type) {
            return Err(EditFailure::RecordFamily { index });
        }
        if matches!(data, RecordData::Comment { .. }) {
            let suffix_len = record.size as usize - 8 - record.decoded_len;
            let padding = (4 - record.decoded_len % 4) % 4;
            if suffix_len != padding {
                return Err(EditFailure::RecordLayout { index });
            }
        }
        if let RecordData::Eof(eof) = &data {
            if eof.n_size_last != record.size {
                return Err(EditFailure::RecordLayout { index });
            }
        }
        let len = record.edited_size(&data).ok_or(EditFailure::SizeOverflow)?;
        u32::try_from(len).map_err(|_| EditFailure::SizeOverflow)?;
        record.data = data;
        record.edited = true;
        Ok(())
    }

    /// EMF+ streams carried in comments, without their four-byte identifier.
    pub fn emf_plus_chunks(&self) -> impl Iterator<Item = &[u8]> {
        self.records
            .iter()
            .filter_map(|record| match record.data() {
                RecordData::Comment { data } if data.starts_with(b"EMF+") => Some(&data[4..]),
                _ => None,
            })
    }

    pub fn header(&self) -> &EmfHeader {
        &self.header
    }

    /// Original raw bytes of the header record, including after an edit.
    pub fn header_bytes(&self) -> &[u8] {
        &self.source[..self.header_len]
    }

    /// Records after the header, in file order, including `EMR_EOF`.
    pub fn records(&self) -> &[RecordSpan] {
        &self.records
    }

    /// Original raw bytes of a record from [`Document::records`], including after an edit.
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
