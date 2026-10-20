//! Checked serialization with preservation of opaque source bytes.

use crate::error::{LimitKind, SerializeFailure};
use crate::limits::SerializeLimits;
use crate::model::{
    Document, EmfHeader, ExtCreatePen, ExtTextOut, Font, FontRecord, LogFont, LogFontPanose,
    RecordData, Rect, RegionData,
};

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
                RecordData::CreatePalette { entries, .. }
                | RecordData::SetPaletteEntries { entries, .. } => entries.len(),
                RecordData::CreateFontIndirectW(font) => match &font.font {
                    Font::ExDv(font) => font.design_vector.values.len(),
                    _ => 0,
                },
                RecordData::ExtCreatePen(pen) => {
                    pen.work_len().ok_or(SerializeFailure::SizeOverflow)?
                }
                RecordData::ExtTextOutA(text) => {
                    text.work_len().ok_or(SerializeFailure::SizeOverflow)?
                }
                RecordData::ExtTextOutW(text) => {
                    text.work_len().ok_or(SerializeFailure::SizeOverflow)?
                }
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
                RecordData::FillRgn { region, .. }
                | RecordData::FrameRgn { region, .. }
                | RecordData::InvertRgn { region, .. }
                | RecordData::PaintRgn { region, .. }
                | RecordData::ExtSelectClipRgn {
                    region: Some(region),
                    ..
                } => region
                    .rectangles
                    .len()
                    .checked_add(region.trailing_bytes.len().div_ceil(16))
                    .ok_or(SerializeFailure::SizeOverflow)?,
                RecordData::ExtFloodFill { body } | RecordData::SetTextJustification { body } => {
                    body.len().div_ceil(16)
                }
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
            RecordData::ExtTextOutA(text) => {
                append_text(&mut out, start, text, |out, value| out.push(*value))?
            }
            RecordData::ExtTextOutW(text) => append_text(&mut out, start, text, |out, value| {
                out.extend_from_slice(&value.to_le_bytes())
            })?,
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
            RecordData::SetMapperFlags { flags } => append(&mut out, *flags),
            RecordData::SetLayout { mode } | RecordData::SetIcmMode { mode } => {
                append(&mut out, *mode)
            }
            RecordData::ExtFloodFill { body } | RecordData::SetTextJustification { body } => {
                out.extend_from_slice(body)
            }
            RecordData::SetMetaRgn
            | RecordData::FlattenPath
            | RecordData::WidenPath
            | RecordData::SaveDc
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
            RecordData::RealizePalette => {}
            RecordData::SelectPalette { ih_pal } => append(&mut out, *ih_pal),
            RecordData::ResizePalette {
                ih_pal,
                entry_count,
            } => {
                append(&mut out, *ih_pal);
                append(&mut out, *entry_count);
            }
            RecordData::CreatePalette {
                ih_pal,
                version,
                entries,
            } => {
                append(&mut out, *ih_pal);
                out.extend_from_slice(&version.to_le_bytes());
                let count =
                    u16::try_from(entries.len()).map_err(|_| SerializeFailure::SizeOverflow)?;
                out.extend_from_slice(&count.to_le_bytes());
                for entry in entries {
                    out.extend_from_slice(&[entry.red, entry.green, entry.blue, entry.flags]);
                }
            }
            RecordData::SetPaletteEntries {
                ih_pal,
                start,
                entries,
            } => {
                append(&mut out, *ih_pal);
                append(&mut out, *start);
                append(
                    &mut out,
                    u32::try_from(entries.len()).map_err(|_| SerializeFailure::SizeOverflow)?,
                );
                for entry in entries {
                    out.extend_from_slice(&[entry.red, entry.green, entry.blue, entry.flags]);
                }
            }
            RecordData::CreateFontIndirectW(font) => append_font(&mut out, font),
            RecordData::ExtCreatePen(pen) => append_extended_pen(&mut out, start, pen)?,
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
            RecordData::ScaleViewportExtEx { scale } | RecordData::ScaleWindowExtEx { scale } => {
                for value in [scale.x_num, scale.x_denom, scale.y_num, scale.y_denom] {
                    append(&mut out, value as u32);
                }
            }
            RecordData::SetWorldTransform { xform }
            | RecordData::ModifyWorldTransform { xform, .. } => {
                for value in [
                    xform.m11, xform.m12, xform.m21, xform.m22, xform.dx, xform.dy,
                ] {
                    append(&mut out, value.to_bits());
                }
                if let RecordData::ModifyWorldTransform { modify_mode, .. } = &record.data {
                    append(&mut out, *modify_mode);
                }
            }
            RecordData::AngleArc {
                center,
                radius,
                start_angle,
                sweep_angle,
            } => {
                append(&mut out, center.x as u32);
                append(&mut out, center.y as u32);
                append(&mut out, *radius);
                append(&mut out, start_angle.to_bits());
                append(&mut out, sweep_angle.to_bits());
            }
            RecordData::SetMiterLimit { miter_limit } => append(&mut out, miter_limit.to_bits()),
            RecordData::SetPixelV { pixel, color } => {
                append(&mut out, pixel.x as u32);
                append(&mut out, pixel.y as u32);
                out.extend_from_slice(&[color.red, color.green, color.blue, color.reserved]);
            }
            RecordData::FillRgn {
                bounds,
                ih_brush,
                region,
            } => {
                append_rect(&mut out, *bounds);
                append_region_size(&mut out, region)?;
                append(&mut out, *ih_brush);
                append_region(&mut out, region)?;
            }
            RecordData::FrameRgn {
                bounds,
                ih_brush,
                stroke,
                region,
            } => {
                append_rect(&mut out, *bounds);
                append_region_size(&mut out, region)?;
                append(&mut out, *ih_brush);
                append(&mut out, stroke.cx as u32);
                append(&mut out, stroke.cy as u32);
                append_region(&mut out, region)?;
            }
            RecordData::InvertRgn { bounds, region } | RecordData::PaintRgn { bounds, region } => {
                append_rect(&mut out, *bounds);
                append_region_size(&mut out, region)?;
                append_region(&mut out, region)?;
            }
            RecordData::ExtSelectClipRgn {
                region_mode,
                region,
            } => {
                if let Some(region) = region {
                    append_region_size(&mut out, region)?;
                } else {
                    append(&mut out, 0);
                }
                append(&mut out, *region_mode);
                if let Some(region) = region {
                    append_region(&mut out, region)?;
                }
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
        if matches!(
            record.data,
            RecordData::ExtTextOutA(_) | RecordData::ExtTextOutW(_) | RecordData::ExtCreatePen(_)
        ) {
            let padding = (4 - (out.len() - start) % 4) % 4;
            out.resize(out.len() + padding, 0);
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

fn append_text<T>(
    out: &mut Vec<u8>,
    start: usize,
    text: &ExtTextOut<T>,
    write: fn(&mut Vec<u8>, &T),
) -> Result<(), SerializeFailure> {
    let (string, dx, _) = text.layout().ok_or(SerializeFailure::SizeOverflow)?;
    append_rect(out, text.bounds);
    append(out, text.graphics_mode);
    append(out, text.ex_scale.to_bits());
    append(out, text.ey_scale.to_bits());
    append(out, text.reference.x as u32);
    append(out, text.reference.y as u32);
    append(
        out,
        u32::try_from(text.text.len()).map_err(|_| SerializeFailure::SizeOverflow)?,
    );
    append(
        out,
        u32::try_from(string).map_err(|_| SerializeFailure::SizeOverflow)?,
    );
    append(out, text.options);
    if let Some(rectangle) = text.rectangle {
        append_rect(out, rectangle);
    }
    append(
        out,
        u32::try_from(dx).map_err(|_| SerializeFailure::SizeOverflow)?,
    );
    for is_dx in [text.dx_first, !text.dx_first] {
        if is_dx {
            if let Some(values) = &text.dx {
                out.extend_from_slice(&text.dx_padding);
                out.resize(start + dx, 0);
                for value in values {
                    append(out, *value);
                }
            }
        } else if string != 0 {
            out.extend_from_slice(&text.string_padding);
            out.resize(start + string, 0);
            for value in &text.text {
                write(out, value);
            }
        }
    }
    Ok(())
}

fn append_region_size(out: &mut Vec<u8>, region: &RegionData) -> Result<(), SerializeFailure> {
    let len = region.encoded_len().ok_or(SerializeFailure::SizeOverflow)?;
    append(
        out,
        u32::try_from(len).map_err(|_| SerializeFailure::SizeOverflow)?,
    );
    Ok(())
}

fn append_region(out: &mut Vec<u8>, region: &RegionData) -> Result<(), SerializeFailure> {
    append(out, 32);
    append(out, region.region_type);
    append(
        out,
        u32::try_from(region.rectangles.len()).map_err(|_| SerializeFailure::SizeOverflow)?,
    );
    let bytes = region
        .rectangles
        .len()
        .checked_mul(16)
        .ok_or(SerializeFailure::SizeOverflow)?;
    append(
        out,
        u32::try_from(bytes).map_err(|_| SerializeFailure::SizeOverflow)?,
    );
    append_rect(out, region.bounds);
    for rect in &region.rectangles {
        append_rect(out, *rect);
    }
    out.extend_from_slice(&region.trailing_bytes);
    Ok(())
}

fn append_extended_pen(
    out: &mut Vec<u8>,
    start: usize,
    pen: &ExtCreatePen,
) -> Result<(), SerializeFailure> {
    let (info, bits, _) = pen.layout().ok_or(SerializeFailure::SizeOverflow)?;
    let checked = |n| u32::try_from(n).map_err(|_| SerializeFailure::SizeOverflow);
    for value in [
        pen.ih_pen,
        checked(info)?,
        checked(pen.bitmap_info.as_ref().map_or(0, Vec::len))?,
        checked(bits)?,
        checked(pen.bitmap_bits.as_ref().map_or(0, Vec::len))?,
        pen.pen_style,
        pen.width,
        pen.brush_style,
    ] {
        append(out, value);
    }
    out.extend_from_slice(&[
        pen.color.red,
        pen.color.green,
        pen.color.blue,
        pen.color.reserved,
    ]);
    append(out, pen.brush_hatch);
    append(out, checked(pen.style_entries.len())?);
    for entry in &pen.style_entries {
        append(out, *entry);
    }
    for is_bits in [pen.bits_first, !pen.bits_first] {
        let (data, padding, offset) = if is_bits {
            (&pen.bitmap_bits, &pen.bits_padding, bits)
        } else {
            (&pen.bitmap_info, &pen.info_padding, info)
        };
        if let Some(data) = data {
            out.extend_from_slice(padding);
            out.resize(start + offset, 0);
            out.extend_from_slice(data);
        }
    }
    Ok(())
}

fn append_font_units(out: &mut Vec<u8>, units: &[u16]) {
    for unit in units {
        out.extend_from_slice(&unit.to_le_bytes());
    }
}
fn append_log_font(out: &mut Vec<u8>, font: &LogFont) {
    for value in [
        font.height,
        font.width,
        font.escapement,
        font.orientation,
        font.weight,
    ] {
        append(out, value as u32);
    }
    out.extend_from_slice(&[
        font.italic,
        font.underline,
        font.strike_out,
        font.char_set,
        font.out_precision,
        font.clip_precision,
        font.quality,
        font.pitch_and_family,
    ]);
    append_font_units(out, &font.face_name);
}
pub(crate) fn panose_bytes(font: &LogFontPanose) -> Vec<u8> {
    let mut out = Vec::with_capacity(320);
    append_log_font(&mut out, &font.log_font);
    append_font_units(&mut out, &font.full_name);
    append_font_units(&mut out, &font.style);
    for value in [
        font.version,
        font.style_size,
        font.match_value,
        font.reserved,
    ] {
        append(&mut out, value);
    }
    out.extend_from_slice(&font.vendor_id);
    append(&mut out, font.culture);
    out.extend_from_slice(&font.panose);
    out.extend_from_slice(&font.padding);
    out
}
fn append_font(out: &mut Vec<u8>, record: &FontRecord) {
    append(out, record.ih_object);
    match &record.font {
        Font::LogFont(font) => append_log_font(out, font),
        Font::Panose(font) => out.extend_from_slice(&panose_bytes(font)[..font.encoded_size]),
        Font::ExDv(font) => {
            let ex = &font.log_font_ex;
            append_log_font(out, &ex.log_font);
            append_font_units(out, &ex.full_name);
            append_font_units(out, &ex.style);
            append_font_units(out, &ex.script);
            append(out, font.design_vector.signature);
            append(out, font.design_vector.values.len() as u32);
            for value in &font.design_vector.values {
                append(out, *value as u32);
            }
        }
    }
}
