//! WMF region objects and drawing payloads (MS-WMF sections 2.2.1.5 and 2.2.2.21).

use super::DecodeError;
use crate::limits::{try_vec_with_capacity, Budget};
use crate::{EditFailure, ParseFailure};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Rect {
    pub left: i16,
    pub top: i16,
    pub right: i16,
    pub bottom: i16,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ScanLine {
    pub left: u16,
    pub right: u16,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Scan {
    pub top: u16,
    pub bottom: u16,
    pub lines: Vec<ScanLine>,
}

/// Wire counts, maximum scan length and byte size are derived from `scans`.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Region {
    /// Ignored during playback, retained during editing.
    pub next_in_chain: u16,
    /// Ignored during playback, retained during editing.
    pub object_count: u32,
    pub bounds: Rect,
    pub scans: Vec<Scan>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum RegionRecord {
    CreateRegion(Region),
    FillRegion {
        region: u16,
        brush: u16,
    },
    FrameRegion {
        region: u16,
        brush: u16,
        height: i16,
        width: i16,
    },
    InvertRegion(u16),
    PaintRegion(u16),
}

fn word(body: &[u8], offset: usize) -> u16 {
    u16::from_le_bytes([body[offset], body[offset + 1]])
}

pub(crate) fn decode(
    function: u16,
    body: &[u8],
    budget: &mut Budget<'_>,
) -> Result<Option<(RegionRecord, usize)>, DecodeError> {
    use RegionRecord::*;
    let size = match function & 0xff {
        0xff => {
            return decode_region(body, budget)
                .map(|(region, used)| Some((CreateRegion(region), used)))
        }
        0x28 => 4,
        0x29 => 8,
        0x2a | 0x2b => 2,
        _ => return Ok(None),
    };
    if body.len() < size {
        return Err(DecodeError::Malformed);
    }
    let region = word(body, 0);
    let record = match function & 0xff {
        0x28 => FillRegion {
            region,
            brush: word(body, 2),
        },
        0x29 => FrameRegion {
            region,
            brush: word(body, 2),
            height: word(body, 4) as i16,
            width: word(body, 6) as i16,
        },
        0x2a => InvertRegion(region),
        _ => PaintRegion(region),
    };
    Ok(Some((record, size)))
}

fn decode_region(body: &[u8], budget: &mut Budget<'_>) -> Result<(Region, usize), DecodeError> {
    if body.len() < 22 || word(body, 2) != 6 {
        return Err(DecodeError::Malformed);
    }
    let size = word(body, 8) as i16;
    let count = word(body, 10) as i16;
    let max_scan = word(body, 12) as i16;
    if size < 22 || count < 0 || max_scan < 0 {
        return Err(DecodeError::Malformed);
    }
    let size = size as usize;
    let count = count as usize;
    if size > body.len() || count > (size - 22) / 8 {
        return Err(DecodeError::Malformed);
    }
    // Preflight all nested boundaries and budgets before allocating typed data.
    let mut offset = 22usize;
    let mut total_lines = 0usize;
    let mut observed_max = 0;
    for _ in 0..count {
        budget.charge_work(1)?;
        if size - offset < 8 {
            return Err(DecodeError::Malformed);
        }
        let points = usize::from(word(body, offset));
        if points % 2 != 0 {
            return Err(DecodeError::Malformed);
        }
        let scan_size = points
            .checked_mul(2)
            .and_then(|n| n.checked_add(8))
            .ok_or(DecodeError::Malformed)?;
        if scan_size > size - offset {
            return Err(DecodeError::Malformed);
        }
        budget.charge_work(points as u64)?;
        if word(body, offset + scan_size - 2) as usize != points {
            return Err(DecodeError::Malformed);
        }
        observed_max = observed_max.max(points);
        total_lines = total_lines
            .checked_add(points / 2)
            .ok_or(DecodeError::Malformed)?;
        offset += scan_size;
    }
    if offset != size || observed_max != max_scan as usize {
        return Err(DecodeError::Malformed);
    }
    let allocated = count
        .checked_mul(std::mem::size_of::<Scan>())
        .and_then(|n| {
            total_lines
                .checked_mul(std::mem::size_of::<ScanLine>())
                .and_then(|m| n.checked_add(m))
        })
        .ok_or(ParseFailure::ArithmeticOverflow { offset: 0 })?;
    budget.charge_alloc(allocated)?;
    let mut scans = try_vec_with_capacity(count)?;
    offset = 22;
    for _ in 0..count {
        let points = usize::from(word(body, offset));
        let mut lines = try_vec_with_capacity(points / 2)?;
        for i in 0..points / 2 {
            lines.push(ScanLine {
                left: word(body, offset + 6 + i * 4),
                right: word(body, offset + 8 + i * 4),
            });
        }
        scans.push(Scan {
            top: word(body, offset + 2),
            bottom: word(body, offset + 4),
            lines,
        });
        offset += 8 + points * 2;
    }
    Ok((
        Region {
            next_in_chain: word(body, 0),
            object_count: u32::from_le_bytes(body[4..8].try_into().unwrap()),
            bounds: Rect {
                left: word(body, 14) as i16,
                top: word(body, 16) as i16,
                right: word(body, 18) as i16,
                bottom: word(body, 20) as i16,
            },
            scans,
        },
        size,
    ))
}

pub(crate) fn encode(record: &RegionRecord) -> Result<(u16, Vec<u8>), EditFailure> {
    use RegionRecord::*;
    let (function, size, max_scan) = match record {
        CreateRegion(region) => {
            i16::try_from(region.scans.len()).map_err(|_| EditFailure::SizeOverflow)?;
            let mut size = 22usize;
            let mut max_scan = 0usize;
            for scan in &region.scans {
                let points = scan
                    .lines
                    .len()
                    .checked_mul(2)
                    .ok_or(EditFailure::SizeOverflow)?;
                i16::try_from(points).map_err(|_| EditFailure::SizeOverflow)?;
                max_scan = max_scan.max(points);
                size = points
                    .checked_mul(2)
                    .and_then(|n| n.checked_add(8))
                    .and_then(|n| size.checked_add(n))
                    .ok_or(EditFailure::SizeOverflow)?;
            }
            i16::try_from(size).map_err(|_| EditFailure::SizeOverflow)?;
            (0x06ff, size, max_scan)
        }
        FillRegion { .. } => (0x0228, 4, 0),
        FrameRegion { .. } => (0x0429, 8, 0),
        InvertRegion(_) => (0x012a, 2, 0),
        PaintRegion(_) => (0x012b, 2, 0),
    };
    let mut out = Vec::new();
    out.try_reserve_exact(size)
        .map_err(|_| EditFailure::SizeOverflow)?;
    match record {
        CreateRegion(region) => {
            out.extend_from_slice(&region.next_in_chain.to_le_bytes());
            out.extend_from_slice(&6i16.to_le_bytes());
            out.extend_from_slice(&region.object_count.to_le_bytes());
            for value in [
                size as i16,
                region.scans.len() as i16,
                max_scan as i16,
                region.bounds.left,
                region.bounds.top,
                region.bounds.right,
                region.bounds.bottom,
            ] {
                out.extend_from_slice(&value.to_le_bytes());
            }
            for scan in &region.scans {
                let count = (scan.lines.len() * 2) as u16;
                for value in [count, scan.top, scan.bottom] {
                    out.extend_from_slice(&value.to_le_bytes());
                }
                for line in &scan.lines {
                    out.extend_from_slice(&line.left.to_le_bytes());
                    out.extend_from_slice(&line.right.to_le_bytes());
                }
                out.extend_from_slice(&count.to_le_bytes());
            }
        }
        FillRegion { region, brush } | FrameRegion { region, brush, .. } => {
            out.extend_from_slice(&region.to_le_bytes());
            out.extend_from_slice(&brush.to_le_bytes());
            if let FrameRegion { height, width, .. } = record {
                out.extend_from_slice(&height.to_le_bytes());
                out.extend_from_slice(&width.to_le_bytes());
            }
        }
        InvertRegion(region) | PaintRegion(region) => out.extend_from_slice(&region.to_le_bytes()),
    }
    debug_assert_eq!(out.len(), size);
    Ok((function, out))
}
