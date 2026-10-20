//! Pen optional data, MS-EMFPLUS 2.2.1.7 and 2.2.2.33–34.
use super::{line_cap, linear_brush, words, CustomLineCap, LinearGradient, Reader};
use crate::{emf_plus::Error, SerializeFailure};

/// Floating-point fields retain their IEEE bits. Option presence must match flags.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Pen {
    pub version: u32,
    pub flags: u32,
    pub unit: u32,
    pub width: u32,
    pub transform: Option<[u32; 6]>,
    pub start_cap: Option<i32>,
    pub end_cap: Option<i32>,
    pub join: Option<i32>,
    pub miter_limit: Option<u32>,
    pub line_style: Option<i32>,
    pub dashed_line_cap: Option<i32>,
    pub dash_offset: Option<u32>,
    pub dash_pattern: Option<Vec<u32>>,
    pub alignment: Option<i32>,
    pub compound_line: Option<Vec<u32>>,
    /// Selected caps in wire order: custom start (0x800), then end (0x1000).
    /// The length must equal the number of selected custom cap flags.
    pub custom_caps: Vec<CustomLineCap>,
    pub brush: PenBrush,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PenBrush {
    pub version: u32,
    pub data: PenBrushData,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum PenBrushData {
    LinearGradient(LinearGradient),
    Solid {
        argb: u32,
    },
    Hatch {
        style: u32,
        foreground: u32,
        background: u32,
    },
}
impl Pen {
    pub(super) fn layout(&self) -> Result<(usize, u64), SerializeFailure> {
        let present = [
            self.transform.is_some(),
            self.start_cap.is_some(),
            self.end_cap.is_some(),
            self.join.is_some(),
            self.miter_limit.is_some(),
            self.line_style.is_some(),
            self.dashed_line_cap.is_some(),
            self.dash_offset.is_some(),
            self.dash_pattern.is_some(),
            self.alignment.is_some(),
            self.compound_line.is_some(),
        ];
        if self.flags & !0x1fff != 0
            || present
                .iter()
                .enumerate()
                .any(|(i, p)| *p != (self.flags & (1 << i) != 0))
            || self.custom_caps.len() != (self.flags & 0x1800).count_ones() as usize
        {
            return Err(SerializeFailure::Inconsistent { offset: 0 });
        }
        let (brush_size, mut work) = match &self.brush.data {
            PenBrushData::LinearGradient(v) => {
                let (size, work) = v.layout()?;
                (
                    size.checked_add(8).ok_or(SerializeFailure::SizeOverflow)?,
                    work,
                )
            }
            PenBrushData::Solid { .. } => (12, 0),
            PenBrushData::Hatch { .. } => (20, 0),
        };
        let mut size = 20usize
            .checked_add(brush_size)
            .ok_or(SerializeFailure::SizeOverflow)?;

        for (i, p) in present.iter().enumerate() {
            if *p {
                size = size
                    .checked_add(if i == 0 { 24 } else { 4 })
                    .ok_or(SerializeFailure::SizeOverflow)?;
            }
        }
        for array in [&self.dash_pattern, &self.compound_line]
            .into_iter()
            .flatten()
        {
            if array.len() > u32::MAX as usize {
                return Err(SerializeFailure::SizeOverflow);
            }
            size = array
                .len()
                .checked_mul(4)
                .and_then(|n| size.checked_add(n))
                .ok_or(SerializeFailure::SizeOverflow)?;
            work = work
                .checked_add(array.len() as u64)
                .ok_or(SerializeFailure::SizeOverflow)?;
        }
        for cap in &self.custom_caps {
            let (len, units) = cap.layout()?;
            if len > u32::MAX as usize {
                return Err(SerializeFailure::SizeOverflow);
            }
            size = size
                .checked_add(4)
                .and_then(|n| n.checked_add(len))
                .ok_or(SerializeFailure::SizeOverflow)?;
            work = work
                .checked_add(1)
                .and_then(|n| n.checked_add(units))
                .ok_or(SerializeFailure::SizeOverflow)?;
        }
        Ok((size, work))
    }
    pub(super) fn write(&self, out: &mut Vec<u8>) {
        words(out, &[self.version, 0, self.flags, self.unit, self.width]);
        if let Some(v) = self.transform {
            words(out, &v);
        }
        for v in [
            self.start_cap.map(|n| n as u32),
            self.end_cap.map(|n| n as u32),
            self.join.map(|n| n as u32),
            self.miter_limit,
            self.line_style.map(|n| n as u32),
            self.dashed_line_cap.map(|n| n as u32),
            self.dash_offset,
        ]
        .into_iter()
        .flatten()
        {
            words(out, &[v]);
        }
        if let Some(v) = &self.dash_pattern {
            words(out, &[v.len() as u32]);
            words(out, v);
        }
        if let Some(v) = self.alignment {
            words(out, &[v as u32]);
        }
        if let Some(v) = &self.compound_line {
            words(out, &[v.len() as u32]);
            words(out, v);
        }
        for cap in &self.custom_caps {
            let start = out.len();
            words(out, &[0]);
            cap.write(out);
            let len = (out.len() - start - 4) as u32;
            out[start..start + 4].copy_from_slice(&len.to_le_bytes());
        }
        match &self.brush.data {
            PenBrushData::Solid { argb } => words(out, &[self.brush.version, 0, *argb]),
            PenBrushData::LinearGradient(v) => {
                words(out, &[self.brush.version, 4]);
                v.write(out);
            }
            PenBrushData::Hatch {
                style,
                foreground,
                background,
            } => words(
                out,
                &[self.brush.version, 1, *style, *foreground, *background],
            ),
        }
    }
}
fn array(r: &mut Reader<'_, '_, '_>) -> Result<Vec<u32>, Error> {
    let count = r.word()? as usize;
    r.require_count(count, 4)?;
    let mut values = r.vector(count)?;
    for _ in 0..count {
        values.push(r.word()?);
    }
    Ok(values)
}
pub(super) fn read(r: &mut Reader<'_, '_, '_>) -> Result<Option<Pen>, Error> {
    let version = r.word()?;
    if r.word()? != 0 {
        return Ok(None);
    }
    let flags = r.word()?;
    if flags & !0x1fff != 0 {
        return Ok(None);
    }
    let unit = r.word()?;
    let width = r.word()?;
    let transform = if flags & 1 != 0 {
        Some(r.words()?)
    } else {
        None
    };
    let mut fields = [None; 7];
    for (i, v) in fields.iter_mut().enumerate() {
        if flags & (2 << i) != 0 {
            *v = Some(r.word()?);
        }
    }
    let dash_pattern = if flags & 0x100 != 0 {
        Some(array(r)?)
    } else {
        None
    };
    let alignment = if flags & 0x200 != 0 {
        Some(r.word()? as i32)
    } else {
        None
    };
    let compound_line = if flags & 0x400 != 0 {
        Some(array(r)?)
    } else {
        None
    };
    let mut custom_caps = r.vector((flags & 0x1800).count_ones() as usize)?;
    for _ in 0..(flags & 0x1800).count_ones() {
        let len = r.word()? as usize;
        let bytes = r.bytes;
        let start = r.pos;
        r.take(len)?;
        let mut nested = Reader {
            bytes: &bytes[start..start + len],
            pos: 0,
            index: r.index,
            budget: r.budget,
        };
        let Some(cap) = line_cap::read(&mut nested)? else {
            return Ok(None);
        };
        if nested.remaining() != 0 {
            return Err(nested.error());
        }
        custom_caps.push(cap);
    }
    let brush_version = r.word()?;
    let data = match r.word()? {
        0 => PenBrushData::Solid { argb: r.word()? },
        1 => PenBrushData::Hatch {
            style: r.word()?,
            foreground: r.word()?,
            background: r.word()?,
        },
        4 => match linear_brush::read(r)? {
            Some(v) => PenBrushData::LinearGradient(v),
            None => return Ok(None),
        },
        _ => return Ok(None),
    };
    Ok(Some(Pen {
        version,
        flags,
        unit,
        width,
        transform,
        start_cap: fields[0].map(|n| n as i32),
        end_cap: fields[1].map(|n| n as i32),
        join: fields[2].map(|n| n as i32),
        miter_limit: fields[3],
        line_style: fields[4].map(|n| n as i32),
        dashed_line_cap: fields[5].map(|n| n as i32),
        dash_offset: fields[6],
        dash_pattern,
        alignment,
        compound_line,
        custom_caps,
        brush: PenBrush {
            version: brush_version,
            data,
        },
    }))
}
