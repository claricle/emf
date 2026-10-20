//! Drawing payloads, MS-EMFPLUS 2.3.4; coordinates retain their wire encoding.
use super::Error;
use crate::{
    limits::{try_vec_with_capacity, Budget},
    ParseFailure,
};

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Rectangle {
    Integer([i16; 4]),
    Float([u32; 4]),
}
impl Rectangle {
    fn len(&self) -> usize {
        match self {
            Self::Integer(_) => 8,
            Self::Float(_) => 16,
        }
    }
    fn compressed(&self) -> bool {
        matches!(self, Self::Integer(_))
    }
    fn write(&self, out: &mut Vec<u8>) {
        match self {
            Self::Integer(v) => {
                for n in v {
                    out.extend_from_slice(&n.to_le_bytes());
                }
            }
            Self::Float(v) => words(out, v),
        }
    }
}

/// Explicit width preserves non-minimal encodings of relative coordinates.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum RelativeCoordinate {
    Seven(i8),
    Fifteen(i16),
}
impl RelativeCoordinate {
    fn len(self) -> usize {
        if matches!(self, Self::Seven(_)) {
            1
        } else {
            2
        }
    }
    fn valid(self) -> bool {
        match self {
            Self::Seven(n) => (-64..=63).contains(&n),
            Self::Fifteen(n) => (-16384..=16383).contains(&n),
        }
    }
    fn write(self, out: &mut Vec<u8>) {
        match self {
            Self::Seven(n) => out.push(n as u8 & 0x7f),
            Self::Fifteen(n) => {
                out.push(0x80 | ((n as u16 >> 8) as u8 & 0x7f));
                out.push(n as u8);
            }
        }
    }
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum PointData {
    Integer(Vec<[i16; 2]>),
    Float(Vec<[u32; 2]>),
    Relative(Vec<[RelativeCoordinate; 2]>),
}
impl PointData {
    pub fn count(&self) -> usize {
        match self {
            Self::Integer(v) => v.len(),
            Self::Float(v) => v.len(),
            Self::Relative(v) => v.len(),
        }
    }
    fn len(&self) -> usize {
        match self {
            Self::Integer(v) => v.len().saturating_mul(4),
            Self::Float(v) => v.len().saturating_mul(8),
            Self::Relative(v) => v.iter().map(|p| p[0].len() + p[1].len()).sum(),
        }
    }
    fn valid(&self, flags: u16) -> bool {
        match self {
            Self::Integer(_) => flags & 0x4800 == 0x4000,
            Self::Float(_) => flags & 0x4800 == 0,
            Self::Relative(v) => flags & 0x0800 != 0 && v.iter().flatten().all(|n| n.valid()),
        }
    }
    fn write(&self, out: &mut Vec<u8>) {
        match self {
            Self::Integer(v) => {
                for p in v {
                    for n in p {
                        out.extend_from_slice(&n.to_le_bytes());
                    }
                }
            }
            Self::Float(v) => {
                for p in v {
                    words(out, p);
                }
            }
            Self::Relative(v) => {
                for p in v {
                    for n in p {
                        n.write(out);
                    }
                }
            }
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Drawing {
    /// FillRects includes a brush/color word; DrawRects uses a pen ID in flags.
    Rectangles {
        brush: Option<u32>,
        rectangles: Vec<Rectangle>,
    },
    Ellipse {
        brush: Option<u32>,
        rectangle: Rectangle,
    },
    /// FillPie includes brush; DrawPie and DrawArc do not.
    Arc {
        brush: Option<u32>,
        start_angle: u32,
        sweep_angle: u32,
        rectangle: Rectangle,
    },
    /// FillPolygon includes brush; DrawLines and DrawBeziers do not.
    Points {
        brush: Option<u32>,
        points: PointData,
        data_padding: Vec<u8>,
    },
    /// FillRegion/FillPath brush/color word or DrawPath pen ID.
    ObjectReference { value: u32 },
}
impl Drawing {
    pub(crate) fn len(&self) -> usize {
        match self {
            Self::Rectangles { brush, rectangles } => {
                4 + brush.map_or(0, |_| 4) + rectangles.iter().map(Rectangle::len).sum::<usize>()
            }
            Self::Ellipse { brush, rectangle } => brush.map_or(0, |_| 4) + rectangle.len(),
            Self::Arc {
                brush, rectangle, ..
            } => 8 + brush.map_or(0, |_| 4) + rectangle.len(),
            Self::Points {
                brush,
                points,
                data_padding,
            } => 4 + brush.map_or(0, |_| 4) + points.len() + data_padding.len(),
            Self::ObjectReference { .. } => 4,
        }
    }
    pub(crate) fn valid(&self, kind: u16, flags: u16) -> bool {
        let compressed = flags & 0x4000 != 0;
        match self {
            Self::Rectangles { brush, rectangles } => {
                matches!(kind, 0x400a | 0x400b)
                    && brush.is_some() == (kind == 0x400a)
                    && !rectangles.is_empty()
                    && rectangles.len() <= u32::MAX as usize
                    && rectangles.iter().all(|r| r.compressed() == compressed)
            }
            Self::Ellipse { brush, rectangle } => {
                matches!(kind, 0x400e | 0x400f)
                    && brush.is_some() == (kind == 0x400e)
                    && rectangle.compressed() == compressed
            }
            Self::Arc {
                brush, rectangle, ..
            } => {
                matches!(kind, 0x4010..=0x4012)
                    && brush.is_some() == (kind == 0x4010)
                    && rectangle.compressed() == compressed
            }
            Self::Points {
                brush,
                points,
                data_padding,
            } => {
                matches!(kind, 0x400c | 0x400d | 0x4019)
                    && brush.is_some() == (kind == 0x400c)
                    && points.count() >= minimum_points(kind)
                    && points.count() <= u32::MAX as usize
                    && points.valid(flags)
                    && data_padding.len() <= 3
                    && (data_padding.is_empty() || matches!(points, PointData::Relative(_)))
            }
            Self::ObjectReference { .. } => matches!(kind, 0x4013..=0x4015),
        }
    }
    pub(crate) fn write(&self, out: &mut Vec<u8>) {
        let brush = match self {
            Self::Rectangles { brush, .. }
            | Self::Ellipse { brush, .. }
            | Self::Arc { brush, .. }
            | Self::Points { brush, .. } => *brush,
            _ => None,
        };
        if let Some(n) = brush {
            words(out, &[n]);
        }
        match self {
            Self::Rectangles { rectangles, .. } => {
                words(out, &[rectangles.len() as u32]);
                for r in rectangles {
                    r.write(out);
                }
            }
            Self::Ellipse { rectangle, .. } => rectangle.write(out),
            Self::Arc {
                start_angle,
                sweep_angle,
                rectangle,
                ..
            } => {
                words(out, &[*start_angle, *sweep_angle]);
                rectangle.write(out);
            }
            Self::Points {
                points,
                data_padding,
                ..
            } => {
                words(out, &[points.count() as u32]);
                points.write(out);
                out.extend_from_slice(data_padding);
            }
            Self::ObjectReference { value } => words(out, &[*value]),
        }
    }
}
pub(crate) fn supported(kind: u16) -> bool {
    matches!(kind, 0x400a..=0x4015 | 0x4019)
}
fn minimum_points(kind: u16) -> usize {
    match kind {
        0x400c => 3,
        0x4019 => 4,
        _ => 2,
    }
}
fn words(out: &mut Vec<u8>, values: &[u32]) {
    for n in values {
        out.extend_from_slice(&n.to_le_bytes());
    }
}

struct Reader<'a> {
    bytes: &'a [u8],
    pos: usize,
    offset: usize,
}
impl Reader<'_> {
    fn error(&self) -> Error {
        Error::InvalidRecord {
            offset: self.offset,
            reason: "invalid drawing count/coordinate layout",
        }
    }
    fn take(&mut self, n: usize) -> Result<&[u8], Error> {
        let end = self.pos.checked_add(n).ok_or_else(|| self.error())?;
        if end > self.bytes.len() {
            return Err(self.error());
        }
        let b = &self.bytes[self.pos..end];
        self.pos = end;
        Ok(b)
    }
    fn word(&mut self) -> Result<u32, Error> {
        Ok(u32::from_le_bytes(self.take(4)?.try_into().unwrap()))
    }
    fn short(&mut self) -> Result<i16, Error> {
        Ok(i16::from_le_bytes(self.take(2)?.try_into().unwrap()))
    }
    fn relative(&mut self) -> Result<RelativeCoordinate, Error> {
        let lead = self.take(1)?[0];
        if lead & 0x80 == 0 {
            Ok(RelativeCoordinate::Seven(((lead << 1) as i8) >> 1))
        } else {
            let raw = ((lead as u16 & 0x7f) << 8) | self.take(1)?[0] as u16;
            Ok(RelativeCoordinate::Fifteen(((raw << 1) as i16) >> 1))
        }
    }
    fn rectangle(&mut self, compressed: bool) -> Result<Rectangle, Error> {
        Ok(if compressed {
            Rectangle::Integer([self.short()?, self.short()?, self.short()?, self.short()?])
        } else {
            Rectangle::Float([self.word()?, self.word()?, self.word()?, self.word()?])
        })
    }
    fn count(&mut self, minimum: usize, stride: usize) -> Result<usize, Error> {
        let n = self.word()? as usize;
        if n < minimum || n > (self.bytes.len() - self.pos) / stride {
            return Err(self.error());
        }
        Ok(n)
    }
}
fn vector<T>(count: usize, budget: &mut Budget<'_>) -> Result<Vec<T>, Error> {
    budget.charge_alloc(
        count
            .checked_mul(std::mem::size_of::<T>())
            .ok_or(ParseFailure::ArithmeticOverflow { offset: 0 })?,
    )?;
    budget.charge_work(count as u64)?;
    Ok(try_vec_with_capacity(count)?)
}
pub(crate) fn decode(
    kind: u16,
    flags: u16,
    bytes: &[u8],
    offset: usize,
    budget: &mut Budget<'_>,
) -> Result<Drawing, Error> {
    let mut r = Reader {
        bytes,
        pos: 0,
        offset,
    };
    let compressed = flags & 0x4000 != 0;
    let brush = if matches!(kind, 0x400a | 0x400c | 0x400e | 0x4010) {
        Some(r.word()?)
    } else {
        None
    };
    let result = match kind {
        0x400a | 0x400b => {
            let count = r.count(1, if compressed { 8 } else { 16 })?;
            let mut rectangles = vector(count, budget)?;
            for _ in 0..count {
                rectangles.push(r.rectangle(compressed)?);
            }
            Drawing::Rectangles { brush, rectangles }
        }
        0x400e | 0x400f => Drawing::Ellipse {
            brush,
            rectangle: r.rectangle(compressed)?,
        },
        0x4010..=0x4012 => Drawing::Arc {
            brush,
            start_angle: r.word()?,
            sweep_angle: r.word()?,
            rectangle: r.rectangle(compressed)?,
        },
        0x4013..=0x4015 => Drawing::ObjectReference { value: r.word()? },
        0x400c | 0x400d | 0x4019 => {
            let relative = flags & 0x0800 != 0;
            let count = r.count(
                minimum_points(kind),
                if relative {
                    2
                } else if compressed {
                    4
                } else {
                    8
                },
            )?;
            let points = if relative {
                let mut points = vector(count, budget)?;
                for _ in 0..count {
                    points.push([r.relative()?, r.relative()?]);
                }
                PointData::Relative(points)
            } else if compressed {
                let mut points = vector(count, budget)?;
                for _ in 0..count {
                    points.push([r.short()?, r.short()?]);
                }
                PointData::Integer(points)
            } else {
                let mut points = vector(count, budget)?;
                for _ in 0..count {
                    points.push([r.word()?, r.word()?]);
                }
                PointData::Float(points)
            };
            let tail = bytes.len() - r.pos;
            if tail > 3 || (!relative && tail != 0) {
                return Err(r.error());
            }
            budget.charge_alloc(tail)?;
            let mut data_padding = try_vec_with_capacity(tail)?;
            data_padding.extend_from_slice(r.take(tail)?);
            Drawing::Points {
                brush,
                points,
                data_padding,
            }
        }
        _ => unreachable!(),
    };
    if r.pos != bytes.len() {
        return Err(r.error());
    }
    Ok(result)
}
