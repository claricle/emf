use super::EscapeRecord;
use crate::EditFailure;

/// Inert ENCAPSULATED_POSTSCRIPT wire data. Coordinates retain signed 28.4
/// fixed-point bits; neither coordinates nor PostScript bytes are interpreted.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct EncapsulatedPostScriptPayload<'a> {
    pub version: u32,
    pub points: [[i32; 2]; 3],
    /// Bytes covered by the inner Size, after the fixed 32-byte header.
    pub data: &'a [u8],
    /// Bytes counted by the outer ByteCount but outside the inner Size.
    pub extra: &'a [u8],
}

impl EscapeRecord {
    /// Borrows the inner Size-bounded data and remaining counted bytes separately.
    pub fn typed_encapsulated_postscript_payload(
        &self,
    ) -> Option<EncapsulatedPostScriptPayload<'_>> {
        if self.function & 0xff != 0x26
            || self.escape_function != 0x1014
            || self.padding.is_some() != (self.data.len() % 2 != 0)
            || self.data.len() > usize::from(u16::MAX)
            || self.data.len() < 32
        {
            return None;
        }
        let size = usize::try_from(u32::from_le_bytes(self.data[..4].try_into().ok()?)).ok()?;
        if !(32..=self.data.len()).contains(&size) {
            return None;
        }
        let version = u32::from_le_bytes(self.data[4..8].try_into().ok()?);
        let mut points = [[0; 2]; 3];
        for (coordinate, bytes) in points
            .iter_mut()
            .flatten()
            .zip(self.data[8..32].chunks_exact(4))
        {
            *coordinate = i32::from_le_bytes(bytes.try_into().ok()?);
        }
        Some(EncapsulatedPostScriptPayload {
            version,
            points,
            data: &self.data[32..size],
            extra: &self.data[size..],
        })
    }

    /// Replaces the inert payload atomically, deriving both size fields. The outer
    /// alignment byte follows the same preservation policy as counted escapes.
    pub fn replace_encapsulated_postscript_payload(
        &mut self,
        payload: EncapsulatedPostScriptPayload<'_>,
    ) -> Result<(), EditFailure> {
        if self.function & 0xff != 0x26 {
            return Err(EditFailure::RecordLayout { index: 0 });
        }
        let size = 32usize
            .checked_add(payload.data.len())
            .ok_or(EditFailure::SizeOverflow)?;
        let total = size
            .checked_add(payload.extra.len())
            .ok_or(EditFailure::SizeOverflow)?;
        u16::try_from(total).map_err(|_| EditFailure::SizeOverflow)?;
        let mut data = Vec::new();
        data.try_reserve_exact(total)
            .map_err(|_| EditFailure::SizeOverflow)?;
        data.extend_from_slice(&(size as u32).to_le_bytes());
        data.extend_from_slice(&payload.version.to_le_bytes());
        for coordinate in payload.points.iter().flatten() {
            data.extend_from_slice(&coordinate.to_le_bytes());
        }
        data.extend_from_slice(payload.data);
        data.extend_from_slice(payload.extra);
        let padding = if total % 2 != 0 {
            Some(self.padding.unwrap_or(0))
        } else {
            None
        };
        self.escape_function = 0x1014;
        self.data = data;
        self.padding = padding;
        Ok(())
    }
}
