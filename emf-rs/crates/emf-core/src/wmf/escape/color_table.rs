use super::EscapeRecord;
use crate::EditFailure;

/// Borrowed GETCOLORTABLE bytes. The color table remains opaque because the
/// format does not require its buffer to use a particular entry stride.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct GetColorTablePayload<'a> {
    pub undefined_space: &'a [u8],
    pub color_table: &'a [u8],
}

impl EscapeRecord {
    /// Borrows the optional gap and color table using Start's whole-record offset.
    pub fn typed_get_color_table_payload(&self) -> Option<GetColorTablePayload<'_>> {
        if self.function & 0xff != 0x26
            || self.escape_function != 0x0005
            || self.padding.is_some() != (self.data.len() % 2 != 0)
            || self.data.len() > usize::from(u16::MAX)
            || self.data.len() < 2
        {
            return None;
        }
        let start = usize::from(u16::from_le_bytes(self.data[..2].try_into().ok()?));
        let record_end = 10usize.checked_add(self.data.len())?;
        if !(12..=record_end).contains(&start) {
            return None;
        }
        let index = start - 10;
        Some(GetColorTablePayload {
            undefined_space: &self.data[2..index],
            color_table: &self.data[index..],
        })
    }

    /// Replaces GETCOLORTABLE atomically, deriving Start from the gap length.
    /// Start uses a whole-record offset; the full function and alignment policy
    /// follow the other escape payload editors.
    pub fn replace_get_color_table_payload(
        &mut self,
        payload: GetColorTablePayload<'_>,
    ) -> Result<(), EditFailure> {
        if self.function & 0xff != 0x26 {
            return Err(EditFailure::RecordLayout { index: 0 });
        }
        let start = 12usize
            .checked_add(payload.undefined_space.len())
            .ok_or(EditFailure::SizeOverflow)?;
        let start = u16::try_from(start).map_err(|_| EditFailure::SizeOverflow)?;
        let size = 2usize
            .checked_add(payload.undefined_space.len())
            .and_then(|size| size.checked_add(payload.color_table.len()))
            .ok_or(EditFailure::SizeOverflow)?;
        u16::try_from(size).map_err(|_| EditFailure::SizeOverflow)?;

        let mut data = Vec::new();
        data.try_reserve_exact(size)
            .map_err(|_| EditFailure::SizeOverflow)?;
        data.extend_from_slice(&start.to_le_bytes());
        data.extend_from_slice(payload.undefined_space);
        data.extend_from_slice(payload.color_table);
        let padding = if size % 2 != 0 {
            Some(self.padding.unwrap_or(0))
        } else {
            None
        };
        self.escape_function = 0x0005;
        self.data = data;
        self.padding = padding;
        Ok(())
    }
}
