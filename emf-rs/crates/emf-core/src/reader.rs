//! Checked little-endian reads over a byte slice.

use crate::error::ParseFailure;

/// Cursor over borrowed bytes. Every read is bounds- and overflow-checked.
#[derive(Clone, Debug)]
pub struct Reader<'a> {
    data: &'a [u8],
    pos: usize,
}

impl<'a> Reader<'a> {
    pub fn new(data: &'a [u8]) -> Self {
        Self { data, pos: 0 }
    }

    pub fn position(&self) -> usize {
        self.pos
    }

    pub fn remaining(&self) -> usize {
        self.data.len() - self.pos
    }

    pub fn is_empty(&self) -> bool {
        self.remaining() == 0
    }

    /// Borrow the next `len` bytes and advance.
    pub fn take(&mut self, len: usize) -> Result<&'a [u8], ParseFailure> {
        let end = self
            .pos
            .checked_add(len)
            .ok_or(ParseFailure::ArithmeticOverflow { offset: self.pos })?;
        let slice = self
            .data
            .get(self.pos..end)
            .ok_or(ParseFailure::Truncated {
                offset: self.pos,
                needed: len,
                available: self.remaining(),
            })?;
        self.pos = end;
        Ok(slice)
    }

    pub fn skip(&mut self, len: usize) -> Result<(), ParseFailure> {
        self.take(len).map(|_| ())
    }

    pub fn u16(&mut self) -> Result<u16, ParseFailure> {
        let b = self.take(2)?;
        Ok(u16::from_le_bytes([b[0], b[1]]))
    }

    pub fn u32(&mut self) -> Result<u32, ParseFailure> {
        let b = self.take(4)?;
        Ok(u32::from_le_bytes([b[0], b[1], b[2], b[3]]))
    }

    pub fn i32(&mut self) -> Result<i32, ParseFailure> {
        self.u32().map(|v| v as i32)
    }
}

/// Read a little-endian `u32` at an absolute offset without a cursor.
pub fn u32_at(data: &[u8], offset: usize) -> Option<u32> {
    let end = offset.checked_add(4)?;
    let b = data.get(offset..end)?;
    Some(u32::from_le_bytes([b[0], b[1], b[2], b[3]]))
}

/// Read a little-endian `u16` at an absolute offset without a cursor.
pub fn u16_at(data: &[u8], offset: usize) -> Option<u16> {
    let end = offset.checked_add(2)?;
    let b = data.get(offset..end)?;
    Some(u16::from_le_bytes([b[0], b[1]]))
}
