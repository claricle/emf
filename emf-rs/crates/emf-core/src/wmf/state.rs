//! WMF state and object wire layouts (MS-WMF sections 2.2 and 2.3.4–2.3.5).
//!
//! Values retain their raw wire representation. These types do not validate
//! object-table lifetimes, enum membership, or device-context playback rules.

use super::DecodeError;
use crate::limits::{try_vec_with_capacity, Budget};
use crate::{EditFailure, PaletteEntry};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Pen {
    pub style: u16,
    pub width_x: i16,
    /// Ignored by playback, retained on the wire.
    pub width_y: i16,
    pub color: u32,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Brush {
    pub style: u16,
    pub color: u32,
    pub hatch: u16,
}

/// Fixed 50-byte Font object; bytes after a face-name NUL are retained.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Font {
    pub height: i16,
    pub width: i16,
    pub escapement: i16,
    pub orientation: i16,
    pub weight: i16,
    pub italic: u8,
    pub underline: u8,
    pub strike_out: u8,
    pub char_set: u8,
    pub out_precision: u8,
    pub clip_precision: u8,
    pub quality: u8,
    pub pitch_and_family: u8,
    pub face_name: [u8; 32],
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Palette {
    /// Version for CREATEPALETTE, entry offset for palette updates.
    pub start: u16,
    pub entries: Vec<PaletteEntry>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum StateRecord {
    SaveDc,
    RestoreDc(i16),
    SelectObject(u16),
    DeleteObject(u16),
    SelectPalette(u16),
    SelectClipRegion(u16),
    CreatePenIndirect(Pen),
    CreateBrushIndirect(Brush),
    CreateFontIndirect(Font),
    CreatePalette(Palette),
    SetPalEntries(Palette),
    AnimatePalette(Palette),
    RealizePalette,
    ResizePalette(u16),
    SetBkColor(u32),
    SetBkMode(u16),
    SetMapMode(u16),
    SetMapperFlags(u32),
    SetPolyFillMode(u16),
    /// Reserved record whose playback effect MUST be ignored.
    SetRelAbs,
    SetRop2(u16),
    SetStretchBltMode(u16),
    SetTextAlign(u16),
    /// Unsigned wire value per MS-WMF section 2.3.5.25.
    SetTextCharExtra(u16),
    SetTextColor(u32),
    /// Both fields are unsigned wire values per MS-WMF section 2.3.5.27.
    SetTextJustification {
        break_count: u16,
        break_extra: u16,
    },
    SetLayout {
        layout: u16,
        reserved: u16,
    },
}

/// Decode a known prefix, leaving optional reserved fields and suffixes owned
/// by the container. MS-WMF identifies these functions by their low byte.
pub(crate) fn decode(
    function: u16,
    body: &[u8],
    budget: &mut Budget<'_>,
) -> Result<Option<(StateRecord, usize)>, DecodeError> {
    use StateRecord::*;
    let function = function & 0xff;
    let size = match function {
        0x1e | 0x35 | 0x05 => 0,
        0x27 | 0x2d | 0xf0 | 0x34 | 0x2c | 0x39 | 0x02 | 0x03 | 0x06 | 0x04 | 0x07 | 0x2e
        | 0x08 => 2,
        0x01 | 0x31 | 0x09 | 0x0a | 0x49 => 4,
        0xfa => 10,
        0xfc => 8,
        0xfb => 50,
        0xf7 | 0x37 | 0x36 => 4,
        _ => return Ok(None),
    };
    if body.len() < size {
        return Err(DecodeError::Malformed);
    }
    let word = |i| u16::from_le_bytes([body[i], body[i + 1]]);
    let dword = |i| u32::from_le_bytes([body[i], body[i + 1], body[i + 2], body[i + 3]]);
    let mut consumed = size;
    let record = match function {
        0x1e => SaveDc,
        0x35 => RealizePalette,
        0x05 => SetRelAbs,
        0x27 => RestoreDc(word(0) as i16),
        0x2d => SelectObject(word(0)),
        0xf0 => DeleteObject(word(0)),
        0x34 => SelectPalette(word(0)),
        0x2c => SelectClipRegion(word(0)),
        0x39 => ResizePalette(word(0)),
        0x02 => SetBkMode(word(0)),
        0x03 => SetMapMode(word(0)),
        0x06 => SetPolyFillMode(word(0)),
        0x04 => SetRop2(word(0)),
        0x07 => SetStretchBltMode(word(0)),
        0x2e => SetTextAlign(word(0)),
        0x08 => SetTextCharExtra(word(0)),
        0x01 => SetBkColor(dword(0)),
        0x31 => SetMapperFlags(dword(0)),
        0x09 => SetTextColor(dword(0)),
        0x0a => SetTextJustification {
            break_count: word(0),
            break_extra: word(2),
        },
        0x49 => SetLayout {
            layout: word(0),
            reserved: word(2),
        },
        0xfa => CreatePenIndirect(Pen {
            style: word(0),
            width_x: word(2) as i16,
            width_y: word(4) as i16,
            color: dword(6),
        }),
        0xfc => CreateBrushIndirect(Brush {
            style: word(0),
            color: dword(2),
            hatch: word(6),
        }),
        0xfb => {
            let mut face_name = [0; 32];
            face_name.copy_from_slice(&body[18..50]);
            CreateFontIndirect(Font {
                height: word(0) as i16,
                width: word(2) as i16,
                escapement: word(4) as i16,
                orientation: word(6) as i16,
                weight: word(8) as i16,
                italic: body[10],
                underline: body[11],
                strike_out: body[12],
                char_set: body[13],
                out_precision: body[14],
                clip_precision: body[15],
                quality: body[16],
                pitch_and_family: body[17],
                face_name,
            })
        }
        0xf7 | 0x37 | 0x36 => {
            let count = usize::from(word(2));
            // count is u16 and entries are exactly four bytes, so this cannot
            // overflow usize on supported targets. Check before any allocation.
            consumed = count
                .checked_mul(4)
                .and_then(|n| n.checked_add(4))
                .ok_or(DecodeError::Malformed)?;
            if body.len() < consumed {
                return Err(DecodeError::Malformed);
            }
            budget
                .charge_work(count as u64)
                .map_err(DecodeError::Resource)?;
            let allocated = count
                .checked_mul(std::mem::size_of::<PaletteEntry>())
                .ok_or(DecodeError::Resource(
                    crate::ParseFailure::ArithmeticOverflow { offset: 0 },
                ))?;
            budget
                .charge_alloc(allocated)
                .map_err(DecodeError::Resource)?;
            let mut entries = try_vec_with_capacity(count).map_err(DecodeError::Resource)?;
            for entry in body[4..consumed].chunks_exact(4) {
                entries.push(PaletteEntry {
                    red: entry[0],
                    green: entry[1],
                    blue: entry[2],
                    flags: entry[3],
                });
            }
            let palette = Palette {
                start: word(0),
                entries,
            };
            match function {
                0xf7 => CreatePalette(palette),
                0x37 => SetPalEntries(palette),
                _ => AnimatePalette(palette),
            }
        }
        _ => unreachable!(),
    };
    Ok(Some((record, consumed)))
}

/// Encode a canonical function number and its typed prefix. The container adds
/// any preserved suffix. Fallible reservation precedes writes to the output.
pub(crate) fn encode(record: &StateRecord) -> Result<(u16, Vec<u8>), EditFailure> {
    use StateRecord::*;
    let (function, size) = match record {
        SaveDc => (0x001e, 0),
        RealizePalette => (0x0035, 0),
        SetRelAbs => (0x0105, 0),
        RestoreDc(_) => (0x0127, 2),
        SelectObject(_) => (0x012d, 2),
        DeleteObject(_) => (0x01f0, 2),
        SelectPalette(_) => (0x0234, 2),
        SelectClipRegion(_) => (0x012c, 2),
        ResizePalette(_) => (0x0139, 2),
        SetBkMode(_) => (0x0102, 2),
        SetMapMode(_) => (0x0103, 2),
        SetPolyFillMode(_) => (0x0106, 2),
        SetRop2(_) => (0x0104, 2),
        SetStretchBltMode(_) => (0x0107, 2),
        SetTextAlign(_) => (0x012e, 2),
        SetTextCharExtra(_) => (0x0108, 2),
        SetBkColor(_) => (0x0201, 4),
        SetMapperFlags(_) => (0x0231, 4),
        SetTextColor(_) => (0x0209, 4),
        SetTextJustification { .. } => (0x020a, 4),
        SetLayout { .. } => (0x0149, 4),
        CreatePenIndirect(_) => (0x02fa, 10),
        CreateBrushIndirect(_) => (0x02fc, 8),
        CreateFontIndirect(_) => (0x02fb, 50),
        CreatePalette(p) | SetPalEntries(p) | AnimatePalette(p) => {
            u16::try_from(p.entries.len()).map_err(|_| EditFailure::SizeOverflow)?;
            let size = p
                .entries
                .len()
                .checked_mul(4)
                .and_then(|n| n.checked_add(4))
                .ok_or(EditFailure::SizeOverflow)?;
            let function = match record {
                CreatePalette(_) => 0x00f7,
                SetPalEntries(_) => 0x0037,
                _ => 0x0436,
            };
            (function, size)
        }
    };
    let mut out = Vec::new();
    out.try_reserve_exact(size)
        .map_err(|_| EditFailure::SizeOverflow)?;
    match record {
        SaveDc | RealizePalette | SetRelAbs => {}
        RestoreDc(value) => out.extend_from_slice(&value.to_le_bytes()),
        SelectObject(v) | DeleteObject(v) | SelectPalette(v) | SelectClipRegion(v)
        | ResizePalette(v) | SetBkMode(v) | SetMapMode(v) | SetPolyFillMode(v) | SetRop2(v)
        | SetStretchBltMode(v) | SetTextAlign(v) | SetTextCharExtra(v) => {
            out.extend_from_slice(&v.to_le_bytes())
        }
        SetBkColor(v) | SetMapperFlags(v) | SetTextColor(v) => {
            out.extend_from_slice(&v.to_le_bytes())
        }
        SetTextJustification {
            break_count,
            break_extra,
        } => {
            out.extend_from_slice(&break_count.to_le_bytes());
            out.extend_from_slice(&break_extra.to_le_bytes());
        }
        SetLayout { layout, reserved } => {
            out.extend_from_slice(&layout.to_le_bytes());
            out.extend_from_slice(&reserved.to_le_bytes());
        }
        CreatePenIndirect(p) => {
            out.extend_from_slice(&p.style.to_le_bytes());
            out.extend_from_slice(&p.width_x.to_le_bytes());
            out.extend_from_slice(&p.width_y.to_le_bytes());
            out.extend_from_slice(&p.color.to_le_bytes());
        }
        CreateBrushIndirect(b) => {
            out.extend_from_slice(&b.style.to_le_bytes());
            out.extend_from_slice(&b.color.to_le_bytes());
            out.extend_from_slice(&b.hatch.to_le_bytes());
        }
        CreateFontIndirect(f) => {
            for value in [f.height, f.width, f.escapement, f.orientation, f.weight] {
                out.extend_from_slice(&value.to_le_bytes());
            }
            out.extend_from_slice(&[
                f.italic,
                f.underline,
                f.strike_out,
                f.char_set,
                f.out_precision,
                f.clip_precision,
                f.quality,
                f.pitch_and_family,
            ]);
            out.extend_from_slice(&f.face_name);
        }
        CreatePalette(p) | SetPalEntries(p) | AnimatePalette(p) => {
            out.extend_from_slice(&p.start.to_le_bytes());
            out.extend_from_slice(&(p.entries.len() as u16).to_le_bytes());
            for entry in &p.entries {
                out.extend_from_slice(&[entry.red, entry.green, entry.blue, entry.flags]);
            }
        }
    }
    debug_assert_eq!(out.len(), size);
    Ok((function, out))
}
