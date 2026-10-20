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

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Point16 {
    pub x: i16,
    pub y: i16,
}

/// IEEE 754 single-precision wire value. Equality compares bits, preserving
/// distinct NaNs and signed zero even when documents are cloned or edited.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Float32(u32);

impl Float32 {
    pub const fn from_bits(bits: u32) -> Self {
        Self(bits)
    }

    pub const fn to_bits(self) -> u32 {
        self.0
    }

    /// Convert without performing floating-point arithmetic.
    pub fn from_f32(value: f32) -> Self {
        Self(value.to_bits())
    }

    pub fn to_f32(self) -> f32 {
        f32::from_bits(self.0)
    }
}

/// Signed viewport or window extent scaling ratios, without normalization.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ScaleFactors {
    pub x_num: i32,
    pub x_denom: i32,
    pub y_num: i32,
    pub y_denom: i32,
}

/// World transform coefficients in wire order, retaining every float bit.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct XForm {
    pub m11: Float32,
    pub m12: Float32,
    pub m21: Float32,
    pub m22: Float32,
    pub dx: Float32,
    pub dy: Float32,
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

/// Extended text output. A text unit is an uninterpreted byte (A) or UTF-16
/// code unit (W); neither encoding nor glyph indexes are normalized.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ExtTextOut<T> {
    pub bounds: Rect,
    pub graphics_mode: u32,
    pub ex_scale: Float32,
    pub ey_scale: Float32,
    pub reference: Point,
    pub options: u32,
    /// Absent when ETO_NO_RECT is set.
    pub rectangle: Option<Rect>,
    pub text: Vec<T>,
    /// Wire values; ETO_PDY interleaves horizontal and vertical displacements.
    pub dx: Option<Vec<u32>>,
    /// Unused bytes immediately before each buffer, retained when editing.
    pub string_padding: Vec<u8>,
    pub dx_padding: Vec<u8>,
    pub dx_first: bool,
    /// Retains a zero offString for empty strings.
    pub string_present: bool,
}

impl<T> ExtTextOut<T> {
    pub(crate) fn layout(&self) -> Option<(usize, usize, usize)> {
        let mut end: usize = if self.rectangle.is_some() { 76 } else { 60 };
        let mut string = 0;
        let mut dx = 0;
        for is_dx in [self.dx_first, !self.dx_first] {
            if is_dx {
                if let Some(values) = &self.dx {
                    end = end.checked_add(self.dx_padding.len())?;
                    end = end.checked_add((4 - end % 4) % 4)?;
                    dx = end;
                    end = end.checked_add(values.len().checked_mul(4)?)?;
                }
            } else if self.string_present || !self.text.is_empty() {
                let width = std::mem::size_of::<T>();
                end = end.checked_add(self.string_padding.len())?;
                end = end.checked_add((width - end % width) % width)?;
                string = end;
                end = end.checked_add(self.text.len().checked_mul(width)?)?;
            }
        }
        Some((string, dx, end))
    }

    pub(crate) fn work_len(&self) -> Option<usize> {
        self.text
            .len()
            .checked_add(self.dx.as_ref().map_or(0, Vec::len))?
            .checked_add(self.string_padding.len().div_ceil(16))?
            .checked_add(self.dx_padding.len().div_ceil(16))
    }

    fn valid(&self) -> bool {
        self.rectangle.is_none() == (self.options & 0x100 != 0)
            && match &self.dx {
                Some(dx) => {
                    self.text
                        .len()
                        .checked_mul(if self.options & 0x2000 != 0 { 2 } else { 1 })
                        == Some(dx.len())
                }
                None => true,
            }
            && (self.dx.is_some() || (self.dx_padding.is_empty() && !self.dx_first))
            && (self.string_present || self.string_padding.is_empty())
    }
}

/// Region rectangles and their original metadata. Rectangle count and buffer size
/// are derived from `rectangles` when encoding; opaque data stays after them.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RegionData {
    /// Wire region type, including unknown values.
    pub region_type: u32,
    pub bounds: Rect,
    pub rectangles: Vec<Rect>,
    /// Bytes inside RgnDataSize after the rectangle array.
    pub trailing_bytes: Vec<u8>,
}

impl RegionData {
    pub(crate) fn encoded_len(&self) -> Option<usize> {
        let rect_bytes = self.rectangles.len().checked_mul(16)?;
        u32::try_from(rect_bytes).ok()?;
        let len = 32usize
            .checked_add(rect_bytes)?
            .checked_add(self.trailing_bytes.len())?;
        u32::try_from(len).ok()?;
        Some(len)
    }
}

/// Extended logical pen (EMR_EXTCREATEPEN). Style flags, brush values and
/// COLORREF bits are retained without interpreting their combinations.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ExtCreatePen {
    pub ih_pen: u32,
    pub pen_style: u32,
    pub width: u32,
    pub brush_style: u32,
    pub color: ColorRef,
    pub brush_hatch: u32,
    /// Alternating dash and gap lengths; the wire count is derived on encoding.
    pub style_entries: Vec<u32>,
    /// DIB header and bits, retained as uninterpreted bytes. Some(empty) retains
    /// a present, zero-length buffer and its offset.
    pub bitmap_info: Option<Vec<u8>>,
    pub bitmap_bits: Option<Vec<u8>>,
    /// Unused bytes immediately before each buffer, retained when editing.
    pub info_padding: Vec<u8>,
    pub bits_padding: Vec<u8>,
    pub bits_first: bool,
}

impl ExtCreatePen {
    pub(crate) fn layout(&self) -> Option<(usize, usize, usize)> {
        u32::try_from(self.style_entries.len()).ok()?;
        let mut end = 52usize.checked_add(self.style_entries.len().checked_mul(4)?)?;
        let mut info = 0;
        let mut bits = 0;
        for is_bits in [self.bits_first, !self.bits_first] {
            let (data, padding) = if is_bits {
                (&self.bitmap_bits, &self.bits_padding)
            } else {
                (&self.bitmap_info, &self.info_padding)
            };
            if let Some(data) = data {
                u32::try_from(data.len()).ok()?;
                end = end.checked_add(padding.len())?;
                end = end.checked_add((4 - end % 4) % 4)?;
                if is_bits {
                    bits = end;
                } else {
                    info = end;
                }
                end = end.checked_add(data.len())?;
            }
        }
        u32::try_from(end).ok()?;
        Some((info, bits, end))
    }

    pub(crate) fn work_len(&self) -> Option<usize> {
        self.style_entries
            .len()
            .checked_add(
                self.bitmap_info
                    .as_ref()
                    .map_or(0, |v| v.len().div_ceil(16)),
            )?
            .checked_add(
                self.bitmap_bits
                    .as_ref()
                    .map_or(0, |v| v.len().div_ceil(16)),
            )?
            .checked_add(self.info_padding.len().div_ceil(16))?
            .checked_add(self.bits_padding.len().div_ceil(16))
    }

    fn valid(&self) -> bool {
        (self.bitmap_info.is_some() || self.info_padding.is_empty())
            && (self.bitmap_bits.is_some() || (self.bits_padding.is_empty() && !self.bits_first))
    }
}

/// PALETTEENTRY channels and flags retained as raw wire bytes.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct PaletteEntry {
    pub red: u8,
    pub green: u8,
    pub blue: u8,
    pub flags: u8,
}

/// Logical font fields retain all UTF-16 code units, including data after a NUL.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct LogFont {
    pub height: i32,
    pub width: i32,
    pub escapement: i32,
    pub orientation: i32,
    pub weight: i32,
    pub italic: u8,
    pub underline: u8,
    pub strike_out: u8,
    pub char_set: u8,
    pub out_precision: u8,
    pub clip_precision: u8,
    pub quality: u8,
    pub pitch_and_family: u8,
    pub face_name: [u16; 32],
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct LogFontEx {
    pub log_font: LogFont,
    pub full_name: [u16; 64],
    pub style: [u16; 32],
    pub script: [u16; 32],
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct LogFontPanose {
    /// Original field length, including compatibility records shorter than 320 bytes.
    pub encoded_size: usize,
    pub log_font: LogFont,
    pub full_name: [u16; 64],
    pub style: [u16; 32],
    pub version: u32,
    pub style_size: u32,
    pub match_value: u32,
    pub reserved: u32,
    pub vendor_id: [u8; 4],
    pub culture: u32,
    pub panose: [u8; 10],
    pub padding: [u8; 2],
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DesignVector {
    pub signature: u32,
    pub values: Vec<i32>,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct LogFontExDv {
    pub log_font_ex: LogFontEx,
    pub design_vector: DesignVector,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Font {
    LogFont(LogFont),
    Panose(LogFontPanose),
    ExDv(LogFontExDv),
}
impl Font {
    pub(crate) fn encoded_len(&self) -> Option<usize> {
        match self {
            Self::LogFont(_) => Some(92),
            Self::Panose(font) => Some(font.encoded_size),
            Self::ExDv(font) => {
                356usize.checked_add(font.design_vector.values.len().checked_mul(4)?)
            }
        }
    }
    pub(crate) fn valid(&self) -> bool {
        match self {
            Self::ExDv(font) => {
                font.design_vector.signature == 0x08007664 && font.design_vector.values.len() <= 16
            }
            Self::Panose(font) => {
                (93..=320).contains(&font.encoded_size)
                    && crate::serialize::panose_bytes(font)[font.encoded_size..]
                        .iter()
                        .all(|b| *b == 0)
            }
            _ => true,
        }
    }
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct FontRecord {
    pub ih_object: u32,
    pub font: Font,
}

/// Supported payloads. Raw records retain all their original bytes.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum RecordData {
    Raw,
    GradientFill(crate::GradientFill),
    CreateFontIndirectW(Box<FontRecord>),
    ExtCreatePen(ExtCreatePen),
    RealizePalette,
    SelectPalette {
        ih_pal: u32,
    },
    CreatePalette {
        ih_pal: u32,
        /// Raw logical palette version.
        version: u16,
        /// The u16 wire count is derived from these entries.
        entries: Vec<PaletteEntry>,
    },
    SetPaletteEntries {
        ih_pal: u32,
        start: u32,
        /// The u32 wire count is derived from these entries.
        entries: Vec<PaletteEntry>,
    },
    ResizePalette {
        ih_pal: u32,
        entry_count: u32,
    },
    ExtTextOutA(ExtTextOut<u8>),
    ExtTextOutW(ExtTextOut<u16>),
    Eof(EofRecord),
    ScaleViewportExtEx {
        scale: ScaleFactors,
    },
    ScaleWindowExtEx {
        scale: ScaleFactors,
    },
    SetWorldTransform {
        xform: XForm,
    },
    ModifyWorldTransform {
        xform: XForm,
        /// Raw mode value; unknown values are preserved.
        modify_mode: u32,
    },
    AngleArc {
        center: Point,
        radius: u32,
        start_angle: Float32,
        sweep_angle: Float32,
    },
    SetMiterLimit {
        miter_limit: Float32,
    },
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
    PolyBezier {
        bounds: Rect,
        points: Vec<Point>,
    },
    Polygon {
        bounds: Rect,
        points: Vec<Point>,
    },
    PolyBezierTo {
        bounds: Rect,
        points: Vec<Point>,
    },
    PolylineTo {
        bounds: Rect,
        points: Vec<Point>,
    },
    PolyBezier16 {
        bounds: Rect,
        points: Vec<Point16>,
    },
    Polygon16 {
        bounds: Rect,
        points: Vec<Point16>,
    },
    Polyline16 {
        bounds: Rect,
        points: Vec<Point16>,
    },
    PolyBezierTo16 {
        bounds: Rect,
        points: Vec<Point16>,
    },
    PolylineTo16 {
        bounds: Rect,
        points: Vec<Point16>,
    },
    Polyline {
        bounds: Rect,
        points: Vec<Point>,
    },
    PolyPolyline {
        bounds: Rect,
        poly_counts: Vec<u32>,
        points: Vec<Point>,
    },
    PolyPolygon {
        bounds: Rect,
        poly_counts: Vec<u32>,
        points: Vec<Point>,
    },
    PolyPolyline16 {
        bounds: Rect,
        poly_counts: Vec<u32>,
        points: Vec<Point16>,
    },
    PolyPolygon16 {
        bounds: Rect,
        poly_counts: Vec<u32>,
        points: Vec<Point16>,
    },
    PolyDraw {
        bounds: Rect,
        points: Vec<Point>,
        ab_types: Vec<u8>,
    },
    PolyDraw16 {
        bounds: Rect,
        points: Vec<Point16>,
        ab_types: Vec<u8>,
    },
    FillRgn {
        bounds: Rect,
        ih_brush: u32,
        region: RegionData,
    },
    FrameRgn {
        bounds: Rect,
        ih_brush: u32,
        stroke: Size,
        region: RegionData,
    },
    InvertRgn {
        bounds: Rect,
        region: RegionData,
    },
    PaintRgn {
        bounds: Rect,
        region: RegionData,
    },
    ExtSelectClipRgn {
        /// Wire RegionMode; unknown values are preserved with nonempty data.
        region_mode: u32,
        /// None resets clipping to the default region and requires RGN_COPY (5).
        region: Option<RegionData>,
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
    SetMapperFlags {
        flags: u32,
    },
    SetLayout {
        mode: u32,
    },
    SetIcmMode {
        mode: u32,
    },
    ExtFloodFill {
        start: Point,
        color: ColorRef,
        flood_fill_mode: u32,
    },
    SetTextJustification {
        break_extra: i32,
        break_count: i32,
    },
    SetMetaRgn,
    FlattenPath,
    WidenPath,
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
            Self::GradientFill(_) => Some(118),
            Self::RealizePalette => Some(52),
            Self::SelectPalette { .. } => Some(48),
            Self::CreatePalette { .. } => Some(49),
            Self::SetPaletteEntries { .. } => Some(50),
            Self::ResizePalette { .. } => Some(51),
            Self::CreateFontIndirectW(_) => Some(82),
            Self::ExtCreatePen(_) => Some(95),
            Self::ExtTextOutA(_) => Some(83),
            Self::ExtTextOutW(_) => Some(84),
            Self::Raw => None,
            Self::Eof(_) => Some(14),
            Self::ScaleViewportExtEx { .. } => Some(31),
            Self::ScaleWindowExtEx { .. } => Some(32),
            Self::SetWorldTransform { .. } => Some(35),
            Self::ModifyWorldTransform { .. } => Some(36),
            Self::AngleArc { .. } => Some(41),
            Self::SetMiterLimit { .. } => Some(58),
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
            Self::PolyBezier { .. } => Some(2),
            Self::Polygon { .. } => Some(3),
            Self::Polyline { .. } => Some(4),
            Self::PolyBezierTo { .. } => Some(5),
            Self::PolylineTo { .. } => Some(6),
            Self::PolyPolyline { .. } => Some(7),
            Self::PolyPolygon { .. } => Some(8),
            Self::PolyPolyline16 { .. } => Some(90),
            Self::PolyPolygon16 { .. } => Some(91),
            Self::PolyBezier16 { .. } => Some(85),
            Self::Polygon16 { .. } => Some(86),
            Self::Polyline16 { .. } => Some(87),
            Self::PolyBezierTo16 { .. } => Some(88),
            Self::PolylineTo16 { .. } => Some(89),
            Self::PolyDraw { .. } => Some(56),
            Self::PolyDraw16 { .. } => Some(92),
            Self::FillRgn { .. } => Some(71),
            Self::FrameRgn { .. } => Some(72),
            Self::InvertRgn { .. } => Some(73),
            Self::PaintRgn { .. } => Some(74),
            Self::ExtSelectClipRgn { .. } => Some(75),
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
            Self::SetMapperFlags { .. } => Some(16),
            Self::SetLayout { .. } => Some(115),
            Self::SetIcmMode { .. } => Some(98),
            Self::ExtFloodFill { .. } => Some(53),
            Self::SetTextJustification { .. } => Some(120),
            Self::SetMetaRgn => Some(28),
            Self::FlattenPath => Some(65),
            Self::WidenPath => Some(66),
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
            Self::GradientFill(g) => g.payload_len(),
            Self::RealizePalette => Some(0),
            Self::SelectPalette { .. } => Some(4),
            Self::ResizePalette { .. } => Some(8),
            Self::CreatePalette { entries, .. } => {
                u16::try_from(entries.len()).ok()?;
                8usize.checked_add(entries.len().checked_mul(4)?)
            }
            Self::SetPaletteEntries { entries, .. } => {
                u32::try_from(entries.len()).ok()?;
                12usize.checked_add(entries.len().checked_mul(4)?)
            }
            Self::CreateFontIndirectW(font) => font.font.encoded_len()?.checked_add(4),
            Self::ExtCreatePen(pen) => pen.layout()?.2.checked_sub(8),
            Self::ExtTextOutA(text) => text.layout()?.2.checked_sub(8),
            Self::ExtTextOutW(text) => text.layout()?.2.checked_sub(8),
            Self::ScaleViewportExtEx { .. } | Self::ScaleWindowExtEx { .. } => Some(16),
            Self::SetWorldTransform { .. } => Some(24),
            Self::ModifyWorldTransform { .. } => Some(28),
            Self::AngleArc { .. } => Some(20),
            Self::SetMiterLimit { .. } => Some(4),
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
            Self::PolyBezier { points, .. }
            | Self::Polygon { points, .. }
            | Self::Polyline { points, .. }
            | Self::PolyBezierTo { points, .. }
            | Self::PolylineTo { points, .. } => points.len().checked_mul(8)?.checked_add(20),
            Self::PolyBezier16 { points, .. }
            | Self::Polygon16 { points, .. }
            | Self::Polyline16 { points, .. }
            | Self::PolyBezierTo16 { points, .. }
            | Self::PolylineTo16 { points, .. } => points.len().checked_mul(4)?.checked_add(20),
            Self::PolyPolyline {
                poly_counts,
                points,
                ..
            }
            | Self::PolyPolygon {
                poly_counts,
                points,
                ..
            } => poly_counts
                .len()
                .checked_mul(4)?
                .checked_add(points.len().checked_mul(8)?)?
                .checked_add(24),
            Self::PolyPolyline16 {
                poly_counts,
                points,
                ..
            }
            | Self::PolyPolygon16 {
                poly_counts,
                points,
                ..
            } => poly_counts
                .len()
                .checked_mul(4)?
                .checked_add(points.len().checked_mul(4)?)?
                .checked_add(24),
            Self::PolyDraw {
                points, ab_types, ..
            } => points
                .len()
                .checked_mul(8)?
                .checked_add(ab_types.len())?
                .checked_add(20),
            Self::PolyDraw16 {
                points, ab_types, ..
            } => points
                .len()
                .checked_mul(4)?
                .checked_add(ab_types.len())?
                .checked_add(20),
            Self::ExtFloodFill { .. } => Some(16),
            Self::SetTextJustification { .. } => Some(8),
            Self::FillRgn { region, .. } => region.encoded_len()?.checked_add(24),
            Self::FrameRgn { region, .. } => region.encoded_len()?.checked_add(32),
            Self::InvertRgn { region, .. } | Self::PaintRgn { region, .. } => {
                region.encoded_len()?.checked_add(20)
            }
            Self::ExtSelectClipRgn { region, .. } => region
                .as_ref()
                .map_or(Some(0), RegionData::encoded_len)?
                .checked_add(8),
            Self::Comment { data } => data.len().checked_add(4),
            Self::Ellipse { .. } | Self::Rectangle { .. } => Some(16),
            Self::RoundRect { .. } => Some(24),
            Self::SetMapperFlags { .. }
            | Self::SetLayout { .. }
            | Self::SetIcmMode { .. }
            | Self::SetTextAlign { .. }
            | Self::RestoreDc { .. }
            | Self::SelectObject { .. }
            | Self::DeleteObject { .. }
            | Self::SetArcDirection { .. }
            | Self::SelectClipPath { .. } => Some(4),
            Self::SetMetaRgn
            | Self::FlattenPath
            | Self::WidenPath
            | Self::SaveDc
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
            let size = size.checked_add(self.size as usize - 8 - self.decoded_len)?;
            if matches!(
                data,
                RecordData::ExtTextOutA(_)
                    | RecordData::ExtTextOutW(_)
                    | RecordData::ExtCreatePen(_)
            ) {
                size.checked_add((4 - size % 4) % 4)
            } else {
                Some(size)
            }
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
    /// PolyDraw point and type arrays must have equal lengths.
    pub fn edit_record(&mut self, index: usize, data: RecordData) -> Result<(), EditFailure> {
        let record = self
            .records
            .get_mut(index)
            .ok_or(EditFailure::RecordIndex { index })?;
        if record.data == RecordData::Raw || data.record_type() != Some(record.record_type) {
            return Err(EditFailure::RecordFamily { index });
        }
        let invalid_layout = match &data {
            RecordData::GradientFill(g) => !g.valid(),
            RecordData::CreateFontIndirectW(font) => !font.font.valid(),
            RecordData::ExtCreatePen(pen) => !pen.valid(),
            RecordData::ExtTextOutA(text) => !text.valid(),
            RecordData::ExtTextOutW(text) => !text.valid(),
            _ => false,
        };
        if invalid_layout {
            return Err(EditFailure::RecordLayout { index });
        }
        let mismatched_arrays = match &data {
            RecordData::PolyDraw {
                points, ab_types, ..
            } => points.len() != ab_types.len(),
            RecordData::PolyDraw16 {
                points, ab_types, ..
            } => points.len() != ab_types.len(),
            _ => false,
        };
        if matches!(&data, RecordData::ExtSelectClipRgn { region_mode, region: None } if *region_mode != 5)
        {
            return Err(EditFailure::RecordLayout { index });
        }
        if mismatched_arrays {
            return Err(EditFailure::RecordLayout { index });
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
        if let RecordData::CreateFontIndirectW(font) = &data {
            let field_len = len - 12;
            let valid_variant = match &font.font {
                Font::LogFont(_) => field_len == 92,
                Font::Panose(font) => field_len == font.encoded_size,
                Font::ExDv(_) => field_len > 320,
            };
            if !valid_variant {
                return Err(EditFailure::RecordLayout { index });
            }
        }
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
