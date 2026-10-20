//! Signed WMF geometry and coordinate mapping payloads.

use super::DecodeError;
use crate::limits::{try_vec_with_capacity, Budget};
use crate::EditFailure;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Point {
    pub x: i16,
    pub y: i16,
}

// Fields follow their wire order, which differs from PointS and Rect objects.
macro_rules! geometry_records {
    ($($code:literal => $variant:ident { $($field:ident: $ty:ident),* }),* $(,)?) => {
        #[derive(Clone, Debug, PartialEq, Eq)]
        pub enum GeometryRecord {
            $($variant { $($field: $ty),* },)*
            Polygon { points: Vec<Point> },
            Polyline { points: Vec<Point> },
            PolyPolygon { poly_counts: Vec<u16>, points: Vec<Point> },
        }

        pub(crate) fn decode(function: u16, body: &[u8], budget: &mut Budget<'_>)
            -> Result<Option<(GeometryRecord, usize)>, DecodeError>
        {
            let mut cursor = Cursor { body, offset: 0 };
            let record = match function & 0xff {
                $(code if code == ($code & 0xff) => GeometryRecord::$variant { $($field: cursor.$ty()?),* },)*
                0x24 | 0x25 | 0x38 => return decode_points(function & 0xff, body, budget),
                _ => return Ok(None),
            };
            if !valid(&record) { return Err(DecodeError::Malformed); }
            Ok(Some((record, cursor.offset)))
        }

        pub(crate) fn encode(record: &GeometryRecord) -> Result<(u16, Vec<u8>), EditFailure> {
            if !valid(record) { return Err(EditFailure::RecordLayout { index: 0 }); }
            match record {
                $(GeometryRecord::$variant { $($field),* } => {
                    let size = 0 $(+ std::mem::size_of::<$ty>())*;
                    let mut body = output(size)?;
                    $(body.extend_from_slice(&$field.to_le_bytes());)*
                    Ok(($code, body))
                },)*
                _ => encode_points(record),
            }
        }
    };
}

geometry_records! {
    0x0214 => MoveTo { y: i16, x: i16 },
    0x0213 => LineTo { y: i16, x: i16 },
    0x020b => SetWindowOrg { y: i16, x: i16 },
    0x020c => SetWindowExt { y: i16, x: i16 },
    0x020d => SetViewportOrg { y: i16, x: i16 },
    0x020e => SetViewportExt { y: i16, x: i16 },
    0x020f => OffsetWindowOrg { y: i16, x: i16 },
    0x0211 => OffsetViewportOrg { y: i16, x: i16 },
    0x0220 => OffsetClipRgn { y: i16, x: i16 },
    0x0410 => ScaleWindowExt { y_denom: i16, y_num: i16, x_denom: i16, x_num: i16 },
    0x0412 => ScaleViewportExt { y_denom: i16, y_num: i16, x_denom: i16, x_num: i16 },
    0x0415 => ExcludeClipRect { bottom: i16, right: i16, top: i16, left: i16 },
    0x0416 => IntersectClipRect { bottom: i16, right: i16, top: i16, left: i16 },
    0x0418 => Ellipse { bottom: i16, right: i16, top: i16, left: i16 },
    0x041b => Rectangle { bottom: i16, right: i16, top: i16, left: i16 },
    0x061c => RoundRect { ellipse_height: i16, ellipse_width: i16, bottom: i16, right: i16, top: i16, left: i16 },
    0x0817 => Arc { y_end: i16, x_end: i16, y_start: i16, x_start: i16, bottom: i16, right: i16, top: i16, left: i16 },
    0x081a => Pie { y_end: i16, x_end: i16, y_start: i16, x_start: i16, bottom: i16, right: i16, top: i16, left: i16 },
    0x0830 => Chord { y_end: i16, x_end: i16, y_start: i16, x_start: i16, bottom: i16, right: i16, top: i16, left: i16 },
    0x0419 => FloodFill { color: u32, y: i16, x: i16 },
    0x041f => SetPixel { color: u32, y: i16, x: i16 },
    0x0548 => ExtFloodFill { mode: u16, color: u32, y: i16, x: i16 },
    0x061d => PatBlt { raster_operation: u32, height: i16, width: i16, y_left: i16, x_left: i16 },
}

fn valid(record: &GeometryRecord) -> bool {
    !matches!(record, GeometryRecord::ExtFloodFill { mode, .. } if *mode > 1)
}

struct Cursor<'a> {
    body: &'a [u8],
    offset: usize,
}

impl Cursor<'_> {
    fn u16(&mut self) -> Result<u16, DecodeError> {
        let bytes = self
            .body
            .get(self.offset..self.offset + 2)
            .ok_or(DecodeError::Malformed)?;
        self.offset += 2;
        Ok(u16::from_le_bytes([bytes[0], bytes[1]]))
    }
    fn i16(&mut self) -> Result<i16, DecodeError> {
        Ok(self.u16()? as i16)
    }
    fn u32(&mut self) -> Result<u32, DecodeError> {
        Ok(u32::from(self.u16()?) | (u32::from(self.u16()?) << 16))
    }
}

fn decode_points(
    function: u16,
    body: &[u8],
    budget: &mut Budget<'_>,
) -> Result<Option<(GeometryRecord, usize)>, DecodeError> {
    let mut cursor = Cursor { body, offset: 0 };
    let count = cursor.u16()?;
    let polygons = function == 0x38;
    let (point_count, counts_end) = if polygons {
        let end = 2 + usize::from(count) * 2;
        if body.len() < end {
            return Err(DecodeError::Malformed);
        }
        budget
            .charge_work(u64::from(count))
            .map_err(DecodeError::Resource)?;
        let mut sum = 0usize;
        for _ in 0..count {
            sum = sum
                .checked_add(usize::from(cursor.u16()?))
                .ok_or(DecodeError::Malformed)?;
        }
        (sum, end)
    } else {
        if count > i16::MAX as u16 || (function == 0x24 && count < 2) {
            return Err(DecodeError::Malformed);
        }
        (usize::from(count), 2)
    };
    let consumed = point_count
        .checked_mul(4)
        .and_then(|n| n.checked_add(counts_end))
        .ok_or(DecodeError::Malformed)?;
    if body.len() < consumed {
        return Err(DecodeError::Malformed);
    }
    budget
        .charge_work(point_count as u64)
        .map_err(DecodeError::Resource)?;
    let mut poly_counts = Vec::new();
    if polygons {
        budget
            .charge_alloc(usize::from(count) * 2)
            .map_err(DecodeError::Resource)?;
        poly_counts = try_vec_with_capacity(usize::from(count)).map_err(DecodeError::Resource)?;
        for bytes in body[2..counts_end].chunks_exact(2) {
            poly_counts.push(u16::from_le_bytes([bytes[0], bytes[1]]));
        }
    }
    let bytes = point_count
        .checked_mul(std::mem::size_of::<Point>())
        .ok_or(DecodeError::Malformed)?;
    budget.charge_alloc(bytes).map_err(DecodeError::Resource)?;
    let mut points = try_vec_with_capacity(point_count).map_err(DecodeError::Resource)?;
    for _ in 0..point_count {
        points.push(Point {
            x: cursor.i16()?,
            y: cursor.i16()?,
        });
    }
    let record = match function {
        0x24 => GeometryRecord::Polygon { points },
        0x25 => GeometryRecord::Polyline { points },
        _ => GeometryRecord::PolyPolygon {
            poly_counts,
            points,
        },
    };
    Ok(Some((record, consumed)))
}

fn output(size: usize) -> Result<Vec<u8>, EditFailure> {
    let mut body = Vec::new();
    body.try_reserve_exact(size)
        .map_err(|_| EditFailure::SizeOverflow)?;
    Ok(body)
}

fn encode_points(record: &GeometryRecord) -> Result<(u16, Vec<u8>), EditFailure> {
    let (function, points, poly_counts) = match record {
        GeometryRecord::Polygon { points } if points.len() >= 2 => (0x0324, points, None),
        GeometryRecord::Polyline { points } => (0x0325, points, None),
        GeometryRecord::PolyPolygon {
            poly_counts,
            points,
        } => (0x0538, points, Some(poly_counts)),
        _ => return Err(EditFailure::RecordLayout { index: 0 }),
    };
    let count = match poly_counts {
        Some(counts) => {
            let sum = counts
                .iter()
                .try_fold(0usize, |sum, &n| sum.checked_add(usize::from(n)))
                .ok_or(EditFailure::SizeOverflow)?;
            if sum != points.len() {
                return Err(EditFailure::RecordLayout { index: 0 });
            }
            u16::try_from(counts.len()).map_err(|_| EditFailure::SizeOverflow)?
        }
        None => i16::try_from(points.len()).map_err(|_| EditFailure::SizeOverflow)? as u16,
    };
    let counts_len = poly_counts.map_or(0, |v| v.len());
    let size = points
        .len()
        .checked_mul(4)
        .and_then(|n| counts_len.checked_mul(2).and_then(|c| n.checked_add(c)))
        .and_then(|n| n.checked_add(2))
        .ok_or(EditFailure::SizeOverflow)?;
    let mut body = output(size)?;
    body.extend_from_slice(&count.to_le_bytes());
    if let Some(counts) = poly_counts {
        for n in counts {
            body.extend_from_slice(&n.to_le_bytes());
        }
    }
    for point in points {
        body.extend_from_slice(&point.x.to_le_bytes());
        body.extend_from_slice(&point.y.to_le_bytes());
    }
    Ok((function, body))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{LimitKind, ParseFailure, ParseLimits};

    #[test]
    fn array_allocation_is_charged_before_reserving_and_uses_shared_totals() {
        let limits = ParseLimits {
            max_allocated_bytes: 8,
            ..ParseLimits::default()
        };
        let mut budget = Budget::new(&limits);
        let body = [2, 0, 1, 0, 2, 0, 3, 0, 4, 0];
        assert!(matches!(decode(0x0325, &body, &mut budget), Ok(Some(_))));
        assert!(matches!(
            decode(0x0325, &body, &mut budget),
            Err(DecodeError::Resource(ParseFailure::LimitExceeded {
                kind: LimitKind::AllocatedBytes,
                requested: 16,
                ..
            }))
        ));
        let limits = ParseLimits {
            max_allocated_bytes: 9,
            ..ParseLimits::default()
        };
        let mut budget = Budget::new(&limits);
        let body = [1, 0, 2, 0, 1, 0, 2, 0, 3, 0, 4, 0];
        assert!(matches!(
            decode(0x0538, &body, &mut budget),
            Err(DecodeError::Resource(ParseFailure::LimitExceeded {
                kind: LimitKind::AllocatedBytes,
                requested: 10,
                ..
            }))
        ));
    }
}
