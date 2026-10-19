//! Checked serialization with preservation of opaque source bytes.

use crate::error::{LimitKind, SerializeFailure};
use crate::limits::SerializeLimits;
use crate::model::{Document, EmfHeader, RecordData, Rect};

/// Write unchanged bytes exactly; encode edited fields and preserve opaque suffixes.
/// Comment padding is resized; EOF palette bytes stay before the final SizeLast.
/// Uses [`SerializeLimits::default`] to bound output and encoding work.
/// On any edit, refresh the header's total byte and record counts.
pub fn serialize(document: &Document) -> Result<Vec<u8>, SerializeFailure> {
    serialize_with_limits(document, &SerializeLimits::default())
}

/// Serialize with explicit inclusive output and work ceilings.
pub fn serialize_with_limits(
    document: &Document,
    limits: &SerializeLimits,
) -> Result<Vec<u8>, SerializeFailure> {
    let mut total = document.source.len();
    let mut next = document.header_len;
    let mut edited = document.header_edited;
    let mut work = 2u64;
    check_limit(LimitKind::WorkUnits, limits.max_work_units, work)?;
    for record in document.records() {
        work = work.checked_add(2).ok_or(SerializeFailure::SizeOverflow)?;
        check_limit(LimitKind::WorkUnits, limits.max_work_units, work)?;
        if record.offset() != next {
            return Err(SerializeFailure::Inconsistent { offset: next });
        }
        let bytes = document
            .record_bytes(record)
            .ok_or(SerializeFailure::Inconsistent { offset: next })?;
        next = next
            .checked_add(bytes.len())
            .ok_or(SerializeFailure::SizeOverflow)?;
        if record.edited {
            edited = true;
            let element_count = match &record.data {
                RecordData::PolyBezier { points, .. }
                | RecordData::Polygon { points, .. }
                | RecordData::Polyline { points, .. }
                | RecordData::PolyBezierTo { points, .. }
                | RecordData::PolylineTo { points, .. } => points.len(),
                RecordData::PolyBezier16 { points, .. }
                | RecordData::Polygon16 { points, .. }
                | RecordData::Polyline16 { points, .. }
                | RecordData::PolyBezierTo16 { points, .. }
                | RecordData::PolylineTo16 { points, .. } => points.len(),
                RecordData::PolyPolyline {
                    poly_counts,
                    points,
                    ..
                }
                | RecordData::PolyPolygon {
                    poly_counts,
                    points,
                    ..
                } => poly_counts
                    .len()
                    .checked_add(points.len())
                    .ok_or(SerializeFailure::SizeOverflow)?,
                RecordData::PolyPolyline16 {
                    poly_counts,
                    points,
                    ..
                }
                | RecordData::PolyPolygon16 {
                    poly_counts,
                    points,
                    ..
                } => poly_counts
                    .len()
                    .checked_add(points.len())
                    .ok_or(SerializeFailure::SizeOverflow)?,
                RecordData::PolyDraw {
                    points, ab_types, ..
                } => points
                    .len()
                    .checked_add(ab_types.len())
                    .ok_or(SerializeFailure::SizeOverflow)?,
                RecordData::PolyDraw16 {
                    points, ab_types, ..
                } => points
                    .len()
                    .checked_add(ab_types.len())
                    .ok_or(SerializeFailure::SizeOverflow)?,
                _ => 0,
            };
            if element_count != 0 {
                work = work
                    .checked_add(element_count as u64)
                    .ok_or(SerializeFailure::SizeOverflow)?;
                check_limit(LimitKind::WorkUnits, limits.max_work_units, work)?;
            }
            total = total
                .checked_sub(record.size as usize)
                .and_then(|n| n.checked_add(record.edited_size(&record.data)?))
                .ok_or(SerializeFailure::SizeOverflow)?;
        }
    }
    if next != document.tail_offset {
        return Err(SerializeFailure::Inconsistent { offset: next });
    }
    if edited {
        u32::try_from(total).map_err(|_| SerializeFailure::SizeOverflow)?;
    }
    check_limit(
        LimitKind::OutputBytes,
        limits.max_output_bytes as u64,
        total as u64,
    )?;
    work = work
        .checked_add((total as u64).div_ceil(16))
        .ok_or(SerializeFailure::SizeOverflow)?;
    check_limit(LimitKind::WorkUnits, limits.max_work_units, work)?;
    let record_count = document
        .records
        .len()
        .checked_add(1)
        .ok_or(SerializeFailure::SizeOverflow)?;
    let record_count = u32::try_from(record_count).map_err(|_| SerializeFailure::SizeOverflow)?;
    let mut out = Vec::new();
    out.try_reserve_exact(total)
        .map_err(|_| SerializeFailure::AllocationFailed { bytes: total })?;
    out.extend_from_slice(document.header_bytes());
    if document.header_edited {
        write_header(&mut out, &document.header);
    }
    if edited {
        put(&mut out, 48, total as u32);
        put(&mut out, 52, record_count);
    }
    for record in document.records() {
        let bytes = document
            .record_bytes(record)
            .ok_or(SerializeFailure::Inconsistent {
                offset: record.offset(),
            })?;
        if !record.edited {
            out.extend_from_slice(bytes);
            continue;
        }
        let start = out.len();
        out.extend_from_slice(&record.record_type.to_le_bytes());
        out.extend_from_slice(&[0; 4]);
        match &record.data {
            RecordData::Raw => {
                return Err(SerializeFailure::Inconsistent {
                    offset: record.offset(),
                })
            }
            RecordData::Eof(eof) => {
                append(&mut out, eof.n_pal_entries);
                append(&mut out, eof.off_pal_entries);
                out.extend_from_slice(&bytes[16..bytes.len() - 4]);
                append(&mut out, eof.n_size_last);
            }
            RecordData::SetWindowExtEx { extent } | RecordData::SetViewportExtEx { extent } => {
                append(&mut out, extent.cx as u32);
                append(&mut out, extent.cy as u32);
            }
            RecordData::SetWindowOrgEx { origin }
            | RecordData::SetViewportOrgEx { origin }
            | RecordData::SetBrushOrgEx { origin }
            | RecordData::MoveToEx { origin } => {
                append(&mut out, origin.x as u32);
                append(&mut out, origin.y as u32);
            }
            RecordData::OffsetClipRgn { offset } => {
                append(&mut out, offset.x as u32);
                append(&mut out, offset.y as u32);
            }
            RecordData::SetMapMode { map_mode } => append(&mut out, *map_mode),
            RecordData::SetBkMode { bk_mode } => append(&mut out, *bk_mode),
            RecordData::SetPolyFillMode { poly_fill_mode } => append(&mut out, *poly_fill_mode),
            RecordData::SetRop2 { rop2 } => append(&mut out, *rop2),
            RecordData::SetStretchBltMode { stretch_mode } => append(&mut out, *stretch_mode),
            RecordData::SetTextColor { color } | RecordData::SetBkColor { color } => {
                out.extend_from_slice(&[color.red, color.green, color.blue, color.reserved]);
            }
            RecordData::PolyBezier { bounds, points }
            | RecordData::Polygon { bounds, points }
            | RecordData::Polyline { bounds, points }
            | RecordData::PolyBezierTo { bounds, points }
            | RecordData::PolylineTo { bounds, points } => {
                append_rect(&mut out, *bounds);
                append(
                    &mut out,
                    u32::try_from(points.len()).map_err(|_| SerializeFailure::SizeOverflow)?,
                );
                for point in points {
                    append(&mut out, point.x as u32);
                    append(&mut out, point.y as u32);
                }
            }
            RecordData::PolyBezier16 { bounds, points }
            | RecordData::Polygon16 { bounds, points }
            | RecordData::Polyline16 { bounds, points }
            | RecordData::PolyBezierTo16 { bounds, points }
            | RecordData::PolylineTo16 { bounds, points } => {
                append_rect(&mut out, *bounds);
                append(
                    &mut out,
                    u32::try_from(points.len()).map_err(|_| SerializeFailure::SizeOverflow)?,
                );
                for point in points {
                    out.extend_from_slice(&point.x.to_le_bytes());
                    out.extend_from_slice(&point.y.to_le_bytes());
                }
            }
            RecordData::PolyPolyline {
                bounds,
                poly_counts,
                points,
            }
            | RecordData::PolyPolygon {
                bounds,
                poly_counts,
                points,
            } => {
                append_rect(&mut out, *bounds);
                append(
                    &mut out,
                    u32::try_from(poly_counts.len()).map_err(|_| SerializeFailure::SizeOverflow)?,
                );
                append(
                    &mut out,
                    u32::try_from(points.len()).map_err(|_| SerializeFailure::SizeOverflow)?,
                );
                for count in poly_counts {
                    append(&mut out, *count);
                }
                for point in points {
                    append(&mut out, point.x as u32);
                    append(&mut out, point.y as u32);
                }
            }
            RecordData::PolyPolyline16 {
                bounds,
                poly_counts,
                points,
            }
            | RecordData::PolyPolygon16 {
                bounds,
                poly_counts,
                points,
            } => {
                append_rect(&mut out, *bounds);
                append(
                    &mut out,
                    u32::try_from(poly_counts.len()).map_err(|_| SerializeFailure::SizeOverflow)?,
                );
                append(
                    &mut out,
                    u32::try_from(points.len()).map_err(|_| SerializeFailure::SizeOverflow)?,
                );
                for count in poly_counts {
                    append(&mut out, *count);
                }
                for point in points {
                    out.extend_from_slice(&point.x.to_le_bytes());
                    out.extend_from_slice(&point.y.to_le_bytes());
                }
            }
            RecordData::PolyDraw {
                bounds,
                points,
                ab_types,
            } => {
                append_rect(&mut out, *bounds);
                append(
                    &mut out,
                    u32::try_from(points.len()).map_err(|_| SerializeFailure::SizeOverflow)?,
                );
                for point in points {
                    append(&mut out, point.x as u32);
                    append(&mut out, point.y as u32);
                }
                out.extend_from_slice(ab_types);
            }
            RecordData::PolyDraw16 {
                bounds,
                points,
                ab_types,
            } => {
                append_rect(&mut out, *bounds);
                append(
                    &mut out,
                    u32::try_from(points.len()).map_err(|_| SerializeFailure::SizeOverflow)?,
                );
                for point in points {
                    out.extend_from_slice(&point.x.to_le_bytes());
                    out.extend_from_slice(&point.y.to_le_bytes());
                }
                out.extend_from_slice(ab_types);
            }
            RecordData::Ellipse { bounds } | RecordData::Rectangle { bounds } => {
                append_rect(&mut out, *bounds);
            }
            RecordData::RoundRect { bounds, corner } => {
                append_rect(&mut out, *bounds);
                append(&mut out, corner.cx as u32);
                append(&mut out, corner.cy as u32);
            }
            RecordData::SetTextAlign { text_align_mode } => append(&mut out, *text_align_mode),
            RecordData::RestoreDc { saved_dc } => append(&mut out, *saved_dc as u32),
            RecordData::SelectObject { ih_object } => append(&mut out, *ih_object),
            RecordData::DeleteObject { ih_object } => append(&mut out, *ih_object),
            RecordData::SetArcDirection { arc_direction } => append(&mut out, *arc_direction),
            RecordData::SelectClipPath { region_mode } => append(&mut out, *region_mode),
            RecordData::SaveDc
            | RecordData::BeginPath
            | RecordData::EndPath
            | RecordData::CloseFigure
            | RecordData::AbortPath => {}
            RecordData::FillPath { bounds }
            | RecordData::StrokeAndFillPath { bounds }
            | RecordData::StrokePath { bounds } => append_rect(&mut out, *bounds),
            RecordData::LineTo { origin } => {
                append(&mut out, origin.x as u32);
                append(&mut out, origin.y as u32);
            }
            RecordData::Arc { bounds, start, end }
            | RecordData::ArcTo { bounds, start, end }
            | RecordData::Chord { bounds, start, end }
            | RecordData::Pie { bounds, start, end } => {
                append_rect(&mut out, *bounds);
                append(&mut out, start.x as u32);
                append(&mut out, start.y as u32);
                append(&mut out, end.x as u32);
                append(&mut out, end.y as u32);
            }
            RecordData::ExcludeClipRect { clip } | RecordData::IntersectClipRect { clip } => {
                append_rect(&mut out, *clip)
            }
            RecordData::CreatePen {
                ih_pen,
                pen_style,
                width,
                color,
            } => {
                append(&mut out, *ih_pen);
                append(&mut out, *pen_style);
                append(&mut out, width.x as u32);
                append(&mut out, width.y as u32);
                out.extend_from_slice(&[color.red, color.green, color.blue, color.reserved]);
            }
            RecordData::CreateBrushIndirect {
                ih_brush,
                brush_style,
                color,
                brush_hatch,
            } => {
                append(&mut out, *ih_brush);
                append(&mut out, *brush_style);
                out.extend_from_slice(&[color.red, color.green, color.blue, color.reserved]);
                append(&mut out, *brush_hatch);
            }
            RecordData::SetPixelV { pixel, color } => {
                append(&mut out, pixel.x as u32);
                append(&mut out, pixel.y as u32);
                out.extend_from_slice(&[color.red, color.green, color.blue, color.reserved]);
            }
            RecordData::Comment { data } => {
                append(
                    &mut out,
                    u32::try_from(data.len()).map_err(|_| SerializeFailure::SizeOverflow)?,
                );
                out.extend_from_slice(data);
            }
        }
        match &record.data {
            RecordData::Comment { data } => {
                let padding = (4 - data.len() % 4) % 4;
                let original_padding = &bytes[8 + record.decoded_len..];
                let preserved = original_padding.len().min(padding);
                out.extend_from_slice(&original_padding[..preserved]);
                out.resize(out.len() + padding - preserved, 0);
            }
            RecordData::Eof(_) => {}
            _ => out.extend_from_slice(&bytes[8 + record.decoded_len..]),
        }
        let size = u32::try_from(out.len() - start).map_err(|_| SerializeFailure::SizeOverflow)?;
        put(&mut out, start + 4, size);
    }
    out.extend_from_slice(&document.source[next..]);
    Ok(out)
}
fn check_limit(kind: LimitKind, limit: u64, requested: u64) -> Result<(), SerializeFailure> {
    if requested > limit {
        return Err(SerializeFailure::LimitExceeded {
            kind,
            limit,
            requested,
        });
    }
    Ok(())
}

fn append(out: &mut Vec<u8>, value: u32) {
    out.extend_from_slice(&value.to_le_bytes());
}
fn put(out: &mut [u8], offset: usize, value: u32) {
    out[offset..offset + 4].copy_from_slice(&value.to_le_bytes());
}
fn append_rect(out: &mut Vec<u8>, r: Rect) {
    for v in [r.left, r.top, r.right, r.bottom] {
        append(out, v as u32);
    }
}
fn write_header(out: &mut [u8], h: &EmfHeader) {
    let mut offset = 8;
    for value in [
        h.bounds.left,
        h.bounds.top,
        h.bounds.right,
        h.bounds.bottom,
        h.frame.left,
        h.frame.top,
        h.frame.right,
        h.frame.bottom,
    ] {
        put(out, offset, value as u32);
        offset += 4;
    }
    for (offset, value) in [
        (40, h.signature),
        (44, h.version),
        (48, h.n_bytes),
        (52, h.n_records),
        (60, h.n_description),
        (64, h.off_description),
        (68, h.n_pal_entries),
        (72, h.device.cx as u32),
        (76, h.device.cy as u32),
        (80, h.millimeters.cx as u32),
        (84, h.millimeters.cy as u32),
    ] {
        put(out, offset, value);
    }
    out[56..58].copy_from_slice(&h.n_handles.to_le_bytes());
    out[58..60].copy_from_slice(&h.reserved.to_le_bytes());
    if let Some(p) = h.pixel_format {
        put(out, 88, p.cb_pixel_format);
        put(out, 92, p.off_pixel_format);
        put(out, 96, p.b_open_gl);
    }
    if let Some(s) = h.micrometers {
        put(out, 100, s.cx as u32);
        put(out, 104, s.cy as u32);
    }
}
