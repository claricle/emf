//! Text payloads (MS-EMFPLUS 2.3.4): raw UTF-16/glyphs and IEEE coordinate bits.
use super::Error;
use crate::{
    limits::{try_vec_with_capacity, Budget},
    ParseFailure,
};

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Text {
    String {
        brush: u32,
        format_id: u32,
        layout: [u32; 4],
        utf16: Vec<u16>,
        data_padding: Vec<u8>,
    },
    Driver {
        brush: u32,
        options: u32,
        glyphs: Vec<u16>,
        positions: Vec<[u32; 2]>,
        matrix: Option<[u32; 6]>,
        data_padding: Vec<u8>,
    },
}
impl Text {
    pub(crate) fn element_work(&self) -> u64 {
        match self {
            Self::String { utf16, .. } => utf16.len() as u64,
            Self::Driver {
                glyphs, positions, ..
            } => (glyphs.len() as u64).saturating_add(positions.len() as u64),
        }
    }
    pub(crate) fn len(&self) -> usize {
        match self {
            Self::String {
                utf16,
                data_padding,
                ..
            } => 28 + utf16.len() * 2 + data_padding.len(),
            Self::Driver {
                glyphs,
                positions,
                matrix,
                data_padding,
                ..
            } => {
                16 + glyphs.len() * 2
                    + positions.len() * 8
                    + matrix.map_or(0, |_| 24)
                    + data_padding.len()
            }
        }
    }
    pub(crate) fn valid(&self, kind: u16) -> bool {
        match self {
            Self::String {
                utf16,
                data_padding,
                ..
            } => kind == 0x401c && utf16.len() <= u32::MAX as usize && data_padding.len() <= 3,
            Self::Driver {
                options,
                glyphs,
                positions,
                data_padding,
                ..
            } => {
                kind == 0x4036
                    && glyphs.len() <= u32::MAX as usize
                    && positions.len() == position_count(*options, glyphs.len())
                    && data_padding.len() <= 3
            }
        }
    }
    pub(crate) fn write(&self, out: &mut Vec<u8>) {
        match self {
            Self::String {
                brush,
                format_id,
                layout,
                utf16,
                data_padding,
            } => {
                words(out, &[*brush, *format_id, utf16.len() as u32]);
                words(out, layout);
                shorts(out, utf16);
                out.extend_from_slice(data_padding);
            }
            Self::Driver {
                brush,
                options,
                glyphs,
                positions,
                matrix,
                data_padding,
            } => {
                words(
                    out,
                    &[
                        *brush,
                        *options,
                        u32::from(matrix.is_some()),
                        glyphs.len() as u32,
                    ],
                );
                shorts(out, glyphs);
                for p in positions {
                    words(out, p);
                }
                if let Some(m) = matrix {
                    words(out, m);
                }
                out.extend_from_slice(data_padding);
            }
        }
    }
}
fn position_count(options: u32, count: usize) -> usize {
    if options & 4 != 0 && count != 0 {
        1
    } else {
        count
    }
}
fn words(out: &mut Vec<u8>, v: &[u32]) {
    for n in v {
        out.extend_from_slice(&n.to_le_bytes());
    }
}
fn shorts(out: &mut Vec<u8>, v: &[u16]) {
    for n in v {
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
            reason: "invalid text count/layout",
        }
    }
    fn take(&mut self, count: usize) -> Result<&[u8], Error> {
        let end = self.pos.checked_add(count).ok_or_else(|| self.error())?;
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
    fn vector<T>(&self, count: usize, budget: &mut Budget<'_>) -> Result<Vec<T>, Error> {
        let size = count.checked_mul(std::mem::size_of::<T>()).ok_or(
            ParseFailure::ArithmeticOverflow {
                offset: self.offset,
            },
        )?;
        budget.charge_alloc(size)?;
        budget.charge_work(count as u64)?;
        Ok(try_vec_with_capacity(count)?)
    }
    fn utf16(&mut self, count: usize, budget: &mut Budget<'_>) -> Result<Vec<u16>, Error> {
        if count > (self.bytes.len() - self.pos) / 2 {
            return Err(self.error());
        }
        let mut v = self.vector(count, budget)?;
        for _ in 0..count {
            v.push(u16::from_le_bytes(self.take(2)?.try_into().unwrap()));
        }
        Ok(v)
    }
    fn padding(&mut self, budget: &mut Budget<'_>) -> Result<Vec<u8>, Error> {
        let count = self.bytes.len() - self.pos;
        if count > 3 {
            return Err(self.error());
        }
        let mut v = self.vector(count, budget)?;
        v.extend_from_slice(self.take(count)?);
        Ok(v)
    }
}
pub(crate) fn decode(
    kind: u16,
    bytes: &[u8],
    offset: usize,
    budget: &mut Budget<'_>,
) -> Result<Text, Error> {
    let mut r = Reader {
        bytes,
        pos: 0,
        offset,
    };
    let brush = r.word()?;
    Ok(if kind == 0x401c {
        let format_id = r.word()?;
        let count = r.word()? as usize;
        let layout = [r.word()?, r.word()?, r.word()?, r.word()?];
        let utf16 = r.utf16(count, budget)?;
        let data_padding = r.padding(budget)?;
        Text::String {
            brush,
            format_id,
            layout,
            utf16,
            data_padding,
        }
    } else {
        let options = r.word()?;
        let present = r.word()?;
        if present > 1 {
            return Err(r.error());
        }
        let count = r.word()? as usize;
        let positions_count = position_count(options, count);
        let needed = count
            .checked_mul(2)
            .and_then(|n| {
                positions_count
                    .checked_mul(8)
                    .and_then(|p| n.checked_add(p))
            })
            .and_then(|n| n.checked_add(if present == 1 { 24 } else { 0 }))
            .ok_or_else(|| r.error())?;
        if needed > bytes.len() - r.pos {
            return Err(r.error());
        }
        let glyphs = r.utf16(count, budget)?;
        let mut positions = r.vector(positions_count, budget)?;
        for _ in 0..positions_count {
            positions.push([r.word()?, r.word()?]);
        }
        let matrix = if present == 1 {
            Some([
                r.word()?,
                r.word()?,
                r.word()?,
                r.word()?,
                r.word()?,
                r.word()?,
            ])
        } else {
            None
        };
        let data_padding = r.padding(budget)?;
        Text::Driver {
            brush,
            options,
            glyphs,
            positions,
            matrix,
            data_padding,
        }
    })
}
