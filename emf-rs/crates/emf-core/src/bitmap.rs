//! Editable bitmap records. DIB metadata and compressed/uncompressed pixels remain
//! byte arrays: interpreting their image formats is independent of EMF framing.
use crate::limits::{try_vec_with_capacity, Budget};
use crate::{ColorRef, Float32, ParseFailure, Point, RecordData, Rect, XForm};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum BitmapBufferKind {
    SourceInfo,
    SourceBits,
    MaskInfo,
    MaskBits,
}
impl BitmapBufferKind {
    fn index(self) -> usize {
        match self {
            Self::SourceInfo => 0,
            Self::SourceBits => 1,
            Self::MaskInfo => 2,
            Self::MaskBits => 3,
        }
    }
}
/// A present buffer, including present-but-empty buffers with a nonzero offset.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct BitmapBuffer {
    pub data: Vec<u8>,
    /// Ignored wire bytes immediately preceding this buffer.
    pub padding: Vec<u8>,
}
/// Buffer order is a permutation of all four kinds, including absent buffers.
/// This retains reversed source buffers and interleaved source/mask buffers.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct BitmapBuffers {
    pub source_info: Option<BitmapBuffer>,
    pub source_bits: Option<BitmapBuffer>,
    pub mask_info: Option<BitmapBuffer>,
    pub mask_bits: Option<BitmapBuffer>,
    pub order: [BitmapBufferKind; 4],
}
impl Default for BitmapBuffers {
    fn default() -> Self {
        Self {
            source_info: None,
            source_bits: None,
            mask_info: None,
            mask_bits: None,
            order: [
                BitmapBufferKind::SourceInfo,
                BitmapBufferKind::SourceBits,
                BitmapBufferKind::MaskInfo,
                BitmapBufferKind::MaskBits,
            ],
        }
    }
}
impl BitmapBuffers {
    pub fn get(&self, kind: BitmapBufferKind) -> Option<&BitmapBuffer> {
        match kind {
            BitmapBufferKind::SourceInfo => self.source_info.as_ref(),
            BitmapBufferKind::SourceBits => self.source_bits.as_ref(),
            BitmapBufferKind::MaskInfo => self.mask_info.as_ref(),
            BitmapBufferKind::MaskBits => self.mask_bits.as_ref(),
        }
    }
    fn set(&mut self, kind: BitmapBufferKind, buffer: BitmapBuffer) {
        *match kind {
            BitmapBufferKind::SourceInfo => &mut self.source_info,
            BitmapBufferKind::SourceBits => &mut self.source_bits,
            BitmapBufferKind::MaskInfo => &mut self.mask_info,
            BitmapBufferKind::MaskBits => &mut self.mask_bits,
        } = Some(buffer);
    }
    fn layout(&self, fixed: usize) -> Option<([(u32, u32); 4], usize)> {
        let mut positions = [(0, 0); 4];
        let mut end = fixed;
        let mut seen = 0u8;
        for kind in self.order {
            let i = kind.index();
            if seen & (1 << i) != 0 {
                return None;
            }
            seen |= 1 << i;
            if let Some(b) = self.get(kind) {
                end = end.checked_add(b.padding.len())?;
                let offset = u32::try_from(end).ok()?;
                let len = u32::try_from(b.data.len()).ok()?;
                positions[i] = (offset, len);
                end = end.checked_add(b.data.len())?;
            }
        }
        u32::try_from(end).ok()?;
        Some((positions, end))
    }
    pub(crate) fn work_len(&self) -> Option<usize> {
        self.order.iter().try_fold(0usize, |sum, kind| {
            let Some(b) = self.get(*kind) else {
                return Some(sum);
            };
            sum.checked_add(b.data.len().div_ceil(16))?
                .checked_add(b.padding.len().div_ceil(16))
        })
    }
    fn append(&self, out: &mut Vec<u8>) {
        for kind in self.order {
            if let Some(b) = self.get(kind) {
                out.extend_from_slice(&b.padding);
                out.extend_from_slice(&b.data);
            }
        }
    }
}
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct BitmapSource {
    pub position: Point,
    pub transform: XForm,
    pub background_color: ColorRef,
    pub usage: u32,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct BitmapMask {
    pub position: Point,
    pub usage: u32,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct BitmapTransfer {
    pub bounds: Rect,
    pub destination: Point,
    pub destination_extent: Point,
    pub source: BitmapSource,
    pub buffers: BitmapBuffers,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DibTransfer {
    pub bounds: Rect,
    pub destination: Point,
    pub source: Point,
    pub source_extent: Point,
    pub usage: u32,
    pub buffers: BitmapBuffers,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct BlendFunction {
    pub operation: u8,
    pub flags: u8,
    pub source_constant_alpha: u8,
    pub alpha_format: u8,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum BitmapRecord {
    BitBlt {
        transfer: BitmapTransfer,
        raster_operation: u32,
    },
    StretchBlt {
        transfer: BitmapTransfer,
        raster_operation: u32,
        source_extent: Point,
    },
    MaskBlt {
        transfer: BitmapTransfer,
        raster_operation: u32,
        mask: BitmapMask,
    },
    PlgBlt {
        bounds: Rect,
        destination: [Point; 3],
        source: BitmapSource,
        source_extent: Point,
        mask: BitmapMask,
        buffers: BitmapBuffers,
    },
    SetDibitsToDevice {
        transfer: DibTransfer,
        start_scan: u32,
        scan_count: u32,
    },
    StretchDibits {
        transfer: DibTransfer,
        raster_operation: u32,
        destination_extent: Point,
    },
    AlphaBlend {
        transfer: BitmapTransfer,
        blend: BlendFunction,
        source_extent: Point,
    },
    TransparentBlt {
        transfer: BitmapTransfer,
        transparent_color: ColorRef,
        source_extent: Point,
    },
    CreateMonoBrush {
        ih_brush: u32,
        usage: u32,
        buffers: BitmapBuffers,
    },
    CreateDibPatternBrushPt {
        ih_brush: u32,
        usage: u32,
        buffers: BitmapBuffers,
    },
}
impl BitmapRecord {
    pub fn record_type(&self) -> u32 {
        match self {
            Self::BitBlt { .. } => 76,
            Self::StretchBlt { .. } => 77,
            Self::MaskBlt { .. } => 78,
            Self::PlgBlt { .. } => 79,
            Self::SetDibitsToDevice { .. } => 80,
            Self::StretchDibits { .. } => 81,
            Self::CreateMonoBrush { .. } => 93,
            Self::CreateDibPatternBrushPt { .. } => 94,
            Self::AlphaBlend { .. } => 114,
            Self::TransparentBlt { .. } => 116,
        }
    }
    pub fn buffers(&self) -> &BitmapBuffers {
        match self {
            Self::BitBlt { transfer, .. }
            | Self::StretchBlt { transfer, .. }
            | Self::MaskBlt { transfer, .. }
            | Self::AlphaBlend { transfer, .. }
            | Self::TransparentBlt { transfer, .. } => &transfer.buffers,
            Self::SetDibitsToDevice { transfer, .. } | Self::StretchDibits { transfer, .. } => {
                &transfer.buffers
            }
            Self::PlgBlt { buffers, .. }
            | Self::CreateMonoBrush { buffers, .. }
            | Self::CreateDibPatternBrushPt { buffers, .. } => buffers,
        }
    }
    pub fn buffers_mut(&mut self) -> &mut BitmapBuffers {
        match self {
            Self::BitBlt { transfer, .. }
            | Self::StretchBlt { transfer, .. }
            | Self::MaskBlt { transfer, .. }
            | Self::AlphaBlend { transfer, .. }
            | Self::TransparentBlt { transfer, .. } => &mut transfer.buffers,
            Self::SetDibitsToDevice { transfer, .. } | Self::StretchDibits { transfer, .. } => {
                &mut transfer.buffers
            }
            Self::PlgBlt { buffers, .. }
            | Self::CreateMonoBrush { buffers, .. }
            | Self::CreateDibPatternBrushPt { buffers, .. } => buffers,
        }
    }
    pub(crate) fn valid(&self) -> bool {
        let mask = matches!(self, Self::MaskBlt { .. } | Self::PlgBlt { .. });
        (mask || (self.buffers().mask_info.is_none() && self.buffers().mask_bits.is_none()))
            && self.buffers().layout(shape(self.record_type()).0).is_some()
    }
    pub(crate) fn payload_len(&self) -> Option<usize> {
        self.buffers()
            .layout(shape(self.record_type()).0)?
            .1
            .checked_sub(8)
    }
    pub(crate) fn append(&self, out: &mut Vec<u8>) {
        let (fixed, _, _) = shape(self.record_type());
        let (positions, _) = self
            .buffers()
            .layout(fixed)
            .expect("validated bitmap layout");
        match self {
            Self::BitBlt {
                transfer,
                raster_operation,
            }
            | Self::StretchBlt {
                transfer,
                raster_operation,
                ..
            }
            | Self::MaskBlt {
                transfer,
                raster_operation,
                ..
            } => append_transfer(out, transfer, *raster_operation, positions),
            Self::AlphaBlend {
                transfer, blend, ..
            } => append_transfer(
                out,
                transfer,
                u32::from_le_bytes([
                    blend.operation,
                    blend.flags,
                    blend.source_constant_alpha,
                    blend.alpha_format,
                ]),
                positions,
            ),
            Self::TransparentBlt {
                transfer,
                transparent_color,
                ..
            } => append_transfer(out, transfer, color_word(*transparent_color), positions),
            Self::PlgBlt {
                bounds,
                destination,
                source,
                source_extent,
                mask,
                ..
            } => {
                rect(out, *bounds);
                for p in destination {
                    point(out, *p);
                }
                point(out, source.position);
                point(out, *source_extent);
                source_tail(out, source, positions);
                append_mask(out, mask, positions);
            }
            Self::SetDibitsToDevice {
                transfer,
                start_scan,
                scan_count,
            } => {
                append_dib(out, transfer, positions);
                word(out, *start_scan);
                word(out, *scan_count);
            }
            Self::StretchDibits {
                transfer,
                raster_operation,
                destination_extent,
            } => {
                append_dib(out, transfer, positions);
                word(out, *raster_operation);
                point(out, *destination_extent);
            }
            Self::CreateMonoBrush {
                ih_brush, usage, ..
            }
            | Self::CreateDibPatternBrushPt {
                ih_brush, usage, ..
            } => {
                word(out, *ih_brush);
                word(out, *usage);
                pair(out, positions[0]);
                pair(out, positions[1]);
            }
        }
        match self {
            Self::StretchBlt { source_extent, .. }
            | Self::AlphaBlend { source_extent, .. }
            | Self::TransparentBlt { source_extent, .. } => point(out, *source_extent),
            Self::MaskBlt { mask, .. } => append_mask(out, mask, positions),
            _ => {}
        }
        self.buffers().append(out);
    }
}
fn shape(kind: u32) -> (usize, usize, Option<usize>) {
    match kind {
        76 => (100, 84, None),
        77 | 114 | 116 => (108, 84, None),
        78 => (128, 84, Some(112)),
        79 => (140, 96, Some(124)),
        80 => (76, 48, None),
        81 => (80, 48, None),
        93 | 94 => (32, 16, None),
        _ => unreachable!(),
    }
}
fn word(out: &mut Vec<u8>, v: u32) {
    out.extend_from_slice(&v.to_le_bytes());
}
fn point(out: &mut Vec<u8>, p: Point) {
    word(out, p.x as u32);
    word(out, p.y as u32);
}
fn rect(out: &mut Vec<u8>, r: Rect) {
    for v in [r.left, r.top, r.right, r.bottom] {
        word(out, v as u32);
    }
}
fn color_word(c: ColorRef) -> u32 {
    u32::from_le_bytes([c.red, c.green, c.blue, c.reserved])
}
fn pair(out: &mut Vec<u8>, p: (u32, u32)) {
    word(out, p.0);
    word(out, p.1);
}
fn source_tail(out: &mut Vec<u8>, s: &BitmapSource, p: [(u32, u32); 4]) {
    for f in [
        s.transform.m11,
        s.transform.m12,
        s.transform.m21,
        s.transform.m22,
        s.transform.dx,
        s.transform.dy,
    ] {
        word(out, f.to_bits());
    }
    word(out, color_word(s.background_color));
    word(out, s.usage);
    pair(out, p[0]);
    pair(out, p[1]);
}
fn append_transfer(out: &mut Vec<u8>, t: &BitmapTransfer, op: u32, p: [(u32, u32); 4]) {
    rect(out, t.bounds);
    point(out, t.destination);
    point(out, t.destination_extent);
    word(out, op);
    point(out, t.source.position);
    source_tail(out, &t.source, p);
}
fn append_mask(out: &mut Vec<u8>, m: &BitmapMask, p: [(u32, u32); 4]) {
    point(out, m.position);
    word(out, m.usage);
    pair(out, p[2]);
    pair(out, p[3]);
}
fn append_dib(out: &mut Vec<u8>, t: &DibTransfer, p: [(u32, u32); 4]) {
    rect(out, t.bounds);
    point(out, t.destination);
    point(out, t.source);
    point(out, t.source_extent);
    pair(out, p[0]);
    pair(out, p[1]);
    word(out, t.usage);
}
fn read_word(p: &[u8], at: usize) -> u32 {
    u32::from_le_bytes(p[at..at + 4].try_into().expect("checked fixed payload"))
}
fn read_point(p: &[u8], at: usize) -> Point {
    Point {
        x: read_word(p, at) as i32,
        y: read_word(p, at + 4) as i32,
    }
}
fn read_rect(p: &[u8]) -> Rect {
    Rect {
        left: read_word(p, 0) as i32,
        top: read_word(p, 4) as i32,
        right: read_word(p, 8) as i32,
        bottom: read_word(p, 12) as i32,
    }
}
fn read_color(n: u32) -> ColorRef {
    let [red, green, blue, reserved] = n.to_le_bytes();
    ColorRef {
        red,
        green,
        blue,
        reserved,
    }
}
fn read_source(p: &[u8], pos: usize, xf: usize) -> BitmapSource {
    let f = |at| Float32::from_bits(read_word(p, at));
    BitmapSource {
        position: read_point(p, pos),
        transform: XForm {
            m11: f(xf),
            m12: f(xf + 4),
            m21: f(xf + 8),
            m22: f(xf + 12),
            dx: f(xf + 16),
            dy: f(xf + 20),
        },
        background_color: read_color(read_word(p, xf + 24)),
        usage: read_word(p, xf + 28),
    }
}
fn copy(bytes: &[u8], budget: &mut Budget<'_>) -> Result<Vec<u8>, ParseFailure> {
    budget.charge_alloc(bytes.len())?;
    budget.charge_work((bytes.len() as u64).div_ceil(16))?;
    let mut v = try_vec_with_capacity(bytes.len())?;
    v.extend_from_slice(bytes);
    Ok(v)
}
pub(crate) fn decode(
    kind: u32,
    p: &[u8],
    budget: &mut Budget<'_>,
) -> Result<(RecordData, usize), ParseFailure> {
    let raw = || Ok((RecordData::Raw, 0));
    let (fixed, source_at, mask_at) = shape(kind);
    if p.len() < fixed - 8 {
        return raw();
    }
    let mut spans: [Option<std::ops::Range<usize>>; 4] = [None, None, None, None];
    for (i, at) in [
        Some(source_at),
        Some(source_at + 8),
        mask_at,
        mask_at.map(|n| n + 8),
    ]
    .into_iter()
    .enumerate()
    {
        let Some(at) = at else { continue };
        let offset = read_word(p, at - 8) as usize;
        let len = read_word(p, at - 4) as usize;
        if offset == 0 && len == 0 {
            continue;
        }
        let Some(start) = offset.checked_sub(8) else {
            return raw();
        };
        let Some(end) = start.checked_add(len) else {
            return raw();
        };
        if start < fixed - 8 || end > p.len() {
            return raw();
        }
        spans[i] = Some(start..end);
    }
    let mut order = BitmapBuffers::default().order;
    order.sort_by_key(|k| {
        spans[k.index()]
            .as_ref()
            .map(|r| (r.start, r.len()))
            .unwrap_or((usize::MAX, 0))
    });
    // Validate all ranges before any allocation. Empty ranges at a shared boundary
    // precede nonempty ranges; overlapping nonempty buffers recover as Raw.
    let mut end = fixed - 8;
    for k in order {
        if let Some(r) = &spans[k.index()] {
            if r.start < end {
                return raw();
            }
            end = r.end;
        }
    }
    let mut buffers = BitmapBuffers {
        order,
        ..BitmapBuffers::default()
    };
    let mut cursor = fixed - 8;
    for k in order {
        if let Some(r) = &spans[k.index()] {
            let padding = copy(&p[cursor..r.start], budget)?;
            let data = copy(&p[r.clone()], budget)?;
            buffers.set(k, BitmapBuffer { padding, data });
            cursor = r.end;
        }
    }
    let data = match kind {
        93 | 94 => {
            let ih_brush = read_word(p, 0);
            let usage = read_word(p, 4);
            if kind == 93 {
                BitmapRecord::CreateMonoBrush {
                    ih_brush,
                    usage,
                    buffers,
                }
            } else {
                BitmapRecord::CreateDibPatternBrushPt {
                    ih_brush,
                    usage,
                    buffers,
                }
            }
        }
        80 | 81 => {
            let transfer = DibTransfer {
                bounds: read_rect(p),
                destination: read_point(p, 16),
                source: read_point(p, 24),
                source_extent: read_point(p, 32),
                usage: read_word(p, 56),
                buffers,
            };
            if kind == 80 {
                BitmapRecord::SetDibitsToDevice {
                    transfer,
                    start_scan: read_word(p, 60),
                    scan_count: read_word(p, 64),
                }
            } else {
                BitmapRecord::StretchDibits {
                    transfer,
                    raster_operation: read_word(p, 60),
                    destination_extent: read_point(p, 64),
                }
            }
        }
        79 => BitmapRecord::PlgBlt {
            bounds: read_rect(p),
            destination: [read_point(p, 16), read_point(p, 24), read_point(p, 32)],
            source: read_source(p, 40, 56),
            source_extent: read_point(p, 48),
            mask: BitmapMask {
                position: read_point(p, 104),
                usage: read_word(p, 112),
            },
            buffers,
        },
        _ => {
            let transfer = BitmapTransfer {
                bounds: read_rect(p),
                destination: read_point(p, 16),
                destination_extent: read_point(p, 24),
                source: read_source(p, 36, 44),
                buffers,
            };
            let op = read_word(p, 32);
            match kind {
                76 => BitmapRecord::BitBlt {
                    transfer,
                    raster_operation: op,
                },
                77 => BitmapRecord::StretchBlt {
                    transfer,
                    raster_operation: op,
                    source_extent: read_point(p, 92),
                },
                78 => BitmapRecord::MaskBlt {
                    transfer,
                    raster_operation: op,
                    mask: BitmapMask {
                        position: read_point(p, 92),
                        usage: read_word(p, 100),
                    },
                },
                114 => {
                    let [operation, flags, source_constant_alpha, alpha_format] = op.to_le_bytes();
                    BitmapRecord::AlphaBlend {
                        transfer,
                        blend: BlendFunction {
                            operation,
                            flags,
                            source_constant_alpha,
                            alpha_format,
                        },
                        source_extent: read_point(p, 92),
                    }
                }
                116 => BitmapRecord::TransparentBlt {
                    transfer,
                    transparent_color: read_color(op),
                    source_extent: read_point(p, 92),
                },
                _ => unreachable!(),
            }
        }
    };
    Ok((RecordData::Bitmap(data), end))
}
