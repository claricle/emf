//! EMF header decoding and record framing.

use crate::detect::{detect_format, Format, EMF_MAGIC};
use crate::error::ParseFailure;
use crate::limits::{try_vec_with_capacity, Budget, ParseLimits};
use crate::model::{
    ColorRef, Diagnostic, DiagnosticKind, Document, EmfHeader, EofRecord, Float32,
    PixelFormatFields, Point, Point16, RecordData, RecordSpan, Rect, ScaleFactors, Size, XForm,
    EMR_HEADER, HEADER_FIXED_BYTES,
};
use crate::reader::{u32_at, Reader};

const RECORD_HEAD_BYTES: usize = 8;

/// Parse an EMF file into an owned [`Document`].
///
/// Only a damaged or oversize header, an unsupported container or an exceeded
/// budget is fatal. A bad record head ends framing with a [`Diagnostic`].
/// Invalid supported payloads stay raw and framing continues. Original bytes
/// remain available so unchanged serialization stays exact.
pub fn parse(input: &[u8], limits: &ParseLimits) -> Result<Document, ParseFailure> {
    let mut budget = Budget::new(limits);
    budget.check_input(input.len())?;
    match detect_format(input)? {
        Format::Emf => {}
        other => return Err(ParseFailure::UnsupportedFormat(other)),
    }

    let mut reader = Reader::new(input);
    let (header, header_len) = read_header(&mut reader, &mut budget)?;

    budget.charge_work((input.len() as u64).div_ceil(16))?;
    budget.charge_alloc(input.len())?;
    let mut source = try_vec_with_capacity::<u8>(input.len())?;
    source.extend_from_slice(input);

    let mut records: Vec<RecordSpan> = Vec::new();
    let mut diagnostics = Vec::new();

    while !reader.is_empty() {
        let offset = reader.position();
        let available = reader.remaining();
        let (Some(record_type), Some(size)) = (u32_at(input, offset), u32_at(input, offset + 4))
        else {
            budget.reserve_one(&mut diagnostics)?;
            diagnostics.push(Diagnostic {
                offset,
                record_type: None,
                kind: DiagnosticKind::TruncatedRecordHead { available },
            });
            break;
        };
        if (size as usize) < RECORD_HEAD_BYTES {
            budget.reserve_one(&mut diagnostics)?;
            diagnostics.push(Diagnostic {
                offset,
                record_type: Some(record_type),
                kind: DiagnosticKind::RecordSizeTooSmall { size },
            });
            break;
        }
        if size as usize > available {
            budget.reserve_one(&mut diagnostics)?;
            diagnostics.push(Diagnostic {
                offset,
                record_type: Some(record_type),
                kind: DiagnosticKind::TruncatedRecord {
                    claimed: size,
                    available,
                },
            });
            break;
        }
        budget.check_record_bytes(size as usize)?;
        budget.charge_record(size as usize)?;
        budget.reserve_one(&mut records)?;
        // size >= 8 here, so every iteration advances the cursor.
        reader.skip(size as usize)?;
        let (data, decoded_len) = decode_record(
            record_type,
            &input[offset + 8..offset + size as usize],
            &mut budget,
        )?;
        if data == RecordData::Raw
            && matches!(
                record_type,
                2..=22 | 24..=47 | 53..=68 | 70 | 85..=92 | 98 | 115 | 120
            )
        {
            budget.reserve_one(&mut diagnostics)?;
            diagnostics.push(Diagnostic {
                offset,
                record_type: Some(record_type),
                kind: DiagnosticKind::InvalidRecordPayload,
            });
        }
        let is_eof = matches!(data, RecordData::Eof(_));
        records.push(RecordSpan {
            offset,
            size,
            record_type,
            data,
            decoded_len,
            edited: false,
        });
        if is_eof {
            break;
        }
    }

    let tail_offset = reader.position();
    Ok(Document {
        source,
        header,
        header_len,
        header_edited: false,
        records,
        diagnostics,
        tail_offset,
    })
}

fn read_header(
    reader: &mut Reader<'_>,
    budget: &mut Budget<'_>,
) -> Result<(EmfHeader, usize), ParseFailure> {
    let record_type = reader.u32()?;
    if record_type != EMR_HEADER {
        return Err(ParseFailure::BadHeaderType { found: record_type });
    }
    let n_size = reader.u32()?;
    // Optional fields exist when nSize exceeds 88 / 100, and must fit inside it.
    let minimum = if n_size > 100 {
        108
    } else if n_size as usize > HEADER_FIXED_BYTES {
        100
    } else {
        HEADER_FIXED_BYTES as u32
    };
    if n_size < minimum {
        return Err(ParseFailure::HeaderSizeTooSmall {
            declared: n_size,
            minimum,
        });
    }
    budget.check_record_bytes(n_size as usize)?;
    budget.charge_record(n_size as usize)?;

    let rect = |r: &mut Reader<'_>| -> Result<Rect, ParseFailure> {
        Ok(Rect {
            left: r.i32()?,
            top: r.i32()?,
            right: r.i32()?,
            bottom: r.i32()?,
        })
    };
    let size = |r: &mut Reader<'_>| -> Result<Size, ParseFailure> {
        Ok(Size {
            cx: r.i32()?,
            cy: r.i32()?,
        })
    };

    let bounds = rect(reader)?;
    let frame = rect(reader)?;
    let signature = reader.u32()?;
    debug_assert_eq!(signature, EMF_MAGIC);
    let version = reader.u32()?;
    let n_bytes = reader.u32()?;
    let n_records = reader.u32()?;
    let n_handles = reader.u16()?;
    let reserved = reader.u16()?;
    let n_description = reader.u32()?;
    let off_description = reader.u32()?;
    let n_pal_entries = reader.u32()?;
    let device = size(reader)?;
    let millimeters = size(reader)?;

    let pixel_format = if n_size > 88 {
        Some(PixelFormatFields {
            cb_pixel_format: reader.u32()?,
            off_pixel_format: reader.u32()?,
            b_open_gl: reader.u32()?,
        })
    } else {
        None
    };
    let micrometers = if n_size > 100 {
        Some(size(reader)?)
    } else {
        None
    };

    // Skip any bytes between the decoded fields and the declared end.
    let header_len = n_size as usize;
    let consumed = reader.position();
    let rest = header_len
        .checked_sub(consumed)
        .ok_or(ParseFailure::ArithmeticOverflow { offset: consumed })?;
    reader.skip(rest)?;

    Ok((
        EmfHeader {
            n_size,
            bounds,
            frame,
            signature,
            version,
            n_bytes,
            n_records,
            n_handles,
            reserved,
            n_description,
            off_description,
            n_pal_entries,
            device,
            millimeters,
            pixel_format,
            micrometers,
        },
        header_len,
    ))
}

fn decode_record(
    kind: u32,
    payload: &[u8],
    budget: &mut Budget<'_>,
) -> Result<(RecordData, usize), ParseFailure> {
    let malformed = || Ok((RecordData::Raw, 0));
    let mut r = Reader::new(payload);
    match kind {
        31 | 32 if payload.len() >= 16 => {
            let scale = ScaleFactors {
                x_num: r.i32()?,
                x_denom: r.i32()?,
                y_num: r.i32()?,
                y_denom: r.i32()?,
            };
            Ok((
                if kind == 31 {
                    RecordData::ScaleViewportExtEx { scale }
                } else {
                    RecordData::ScaleWindowExtEx { scale }
                },
                16,
            ))
        }
        35 | 36 if payload.len() >= if kind == 35 { 24 } else { 28 } => {
            let xform = XForm {
                m11: Float32::from_bits(r.u32()?),
                m12: Float32::from_bits(r.u32()?),
                m21: Float32::from_bits(r.u32()?),
                m22: Float32::from_bits(r.u32()?),
                dx: Float32::from_bits(r.u32()?),
                dy: Float32::from_bits(r.u32()?),
            };
            Ok((
                if kind == 35 {
                    RecordData::SetWorldTransform { xform }
                } else {
                    RecordData::ModifyWorldTransform {
                        xform,
                        modify_mode: r.u32()?,
                    }
                },
                if kind == 35 { 24 } else { 28 },
            ))
        }
        41 if payload.len() >= 20 => Ok((
            RecordData::AngleArc {
                center: Point {
                    x: r.i32()?,
                    y: r.i32()?,
                },
                radius: r.u32()?,
                start_angle: Float32::from_bits(r.u32()?),
                sweep_angle: Float32::from_bits(r.u32()?),
            },
            20,
        )),
        58 if payload.len() >= 4 => Ok((
            RecordData::SetMiterLimit {
                miter_limit: Float32::from_bits(r.u32()?),
            },
            4,
        )),
        9 if payload.len() >= 8 => Ok((
            RecordData::SetWindowExtEx {
                extent: Size {
                    cx: r.i32()?,
                    cy: r.i32()?,
                },
            },
            8,
        )),
        10 if payload.len() >= 8 => Ok((
            RecordData::SetWindowOrgEx {
                origin: Point {
                    x: r.i32()?,
                    y: r.i32()?,
                },
            },
            8,
        )),
        11 if payload.len() >= 8 => Ok((
            RecordData::SetViewportExtEx {
                extent: Size {
                    cx: r.i32()?,
                    cy: r.i32()?,
                },
            },
            8,
        )),
        12 if payload.len() >= 8 => Ok((
            RecordData::SetViewportOrgEx {
                origin: Point {
                    x: r.i32()?,
                    y: r.i32()?,
                },
            },
            8,
        )),
        13 if payload.len() >= 8 => Ok((
            RecordData::SetBrushOrgEx {
                origin: Point {
                    x: r.i32()?,
                    y: r.i32()?,
                },
            },
            8,
        )),
        26 if payload.len() >= 8 => Ok((
            RecordData::OffsetClipRgn {
                offset: Point {
                    x: r.i32()?,
                    y: r.i32()?,
                },
            },
            8,
        )),
        27 if payload.len() >= 8 => Ok((
            RecordData::MoveToEx {
                origin: Point {
                    x: r.i32()?,
                    y: r.i32()?,
                },
            },
            8,
        )),
        14 if payload.len() >= 12 => Ok((
            RecordData::Eof(EofRecord {
                n_pal_entries: r.u32()?,
                off_pal_entries: r.u32()?,
                n_size_last: Reader::new(&payload[payload.len() - 4..]).u32()?,
            }),
            12,
        )),
        17 if payload.len() >= 4 => Ok((RecordData::SetMapMode { map_mode: r.u32()? }, 4)),
        18 if payload.len() >= 4 => Ok((RecordData::SetBkMode { bk_mode: r.u32()? }, 4)),
        19 if payload.len() >= 4 => Ok((
            RecordData::SetPolyFillMode {
                poly_fill_mode: r.u32()?,
            },
            4,
        )),
        20 if payload.len() >= 4 => Ok((RecordData::SetRop2 { rop2: r.u32()? }, 4)),
        21 if payload.len() >= 4 => Ok((
            RecordData::SetStretchBltMode {
                stretch_mode: r.u32()?,
            },
            4,
        )),
        24 | 25 if payload.len() >= 4 => {
            let color = ColorRef {
                red: payload[0],
                green: payload[1],
                blue: payload[2],
                reserved: payload[3],
            };
            let data = if kind == 24 {
                RecordData::SetTextColor { color }
            } else {
                RecordData::SetBkColor { color }
            };
            Ok((data, 4))
        }
        2..=6 if payload.len() >= 20 => {
            let bounds = Rect {
                left: r.i32()?,
                top: r.i32()?,
                right: r.i32()?,
                bottom: r.i32()?,
            };
            let count = r.u32()? as usize;
            let Some(bytes) = count.checked_mul(8) else {
                return malformed();
            };
            if bytes > r.remaining() {
                return malformed();
            }
            budget.charge_alloc(bytes)?;
            budget.charge_work(count as u64)?;
            let mut points = try_vec_with_capacity(count)?;
            for _ in 0..count {
                points.push(Point {
                    x: r.i32()?,
                    y: r.i32()?,
                });
            }
            let data = match kind {
                2 => RecordData::PolyBezier { bounds, points },
                3 => RecordData::Polygon { bounds, points },
                4 => RecordData::Polyline { bounds, points },
                5 => RecordData::PolyBezierTo { bounds, points },
                _ => RecordData::PolylineTo { bounds, points },
            };
            Ok((data, 20 + bytes))
        }
        85..=89 if payload.len() >= 20 => {
            let bounds = Rect {
                left: r.i32()?,
                top: r.i32()?,
                right: r.i32()?,
                bottom: r.i32()?,
            };
            let count = r.u32()? as usize;
            let Some(bytes) = count.checked_mul(4) else {
                return malformed();
            };
            if bytes > r.remaining() {
                return malformed();
            }
            budget.charge_alloc(bytes)?;
            budget.charge_work(count as u64)?;
            let mut points = try_vec_with_capacity(count)?;
            for _ in 0..count {
                points.push(Point16 {
                    x: r.u16()? as i16,
                    y: r.u16()? as i16,
                });
            }
            let data = match kind {
                85 => RecordData::PolyBezier16 { bounds, points },
                86 => RecordData::Polygon16 { bounds, points },
                87 => RecordData::Polyline16 { bounds, points },
                88 => RecordData::PolyBezierTo16 { bounds, points },
                _ => RecordData::PolylineTo16 { bounds, points },
            };
            Ok((data, 20 + bytes))
        }
        7 | 8 | 90 | 91 if payload.len() >= 24 => {
            let bounds = Rect {
                left: r.i32()?,
                top: r.i32()?,
                right: r.i32()?,
                bottom: r.i32()?,
            };
            let poly_count = r.u32()? as usize;
            let point_count = r.u32()? as usize;
            let point_width = if kind < 90 { 8 } else { 4 };
            let Some(bytes) = poly_count
                .checked_mul(4)
                .and_then(|n| n.checked_add(point_count.checked_mul(point_width)?))
            else {
                return malformed();
            };
            if bytes > r.remaining() {
                return malformed();
            }
            budget.charge_alloc(bytes)?;
            budget.charge_work(poly_count as u64 + point_count as u64)?;
            let mut poly_counts = try_vec_with_capacity(poly_count)?;
            for _ in 0..poly_count {
                poly_counts.push(r.u32()?);
            }
            let data = if kind < 90 {
                let mut points = try_vec_with_capacity(point_count)?;
                for _ in 0..point_count {
                    points.push(Point {
                        x: r.i32()?,
                        y: r.i32()?,
                    });
                }
                if kind == 7 {
                    RecordData::PolyPolyline {
                        bounds,
                        poly_counts,
                        points,
                    }
                } else {
                    RecordData::PolyPolygon {
                        bounds,
                        poly_counts,
                        points,
                    }
                }
            } else {
                let mut points = try_vec_with_capacity(point_count)?;
                for _ in 0..point_count {
                    points.push(Point16 {
                        x: r.u16()? as i16,
                        y: r.u16()? as i16,
                    });
                }
                if kind == 90 {
                    RecordData::PolyPolyline16 {
                        bounds,
                        poly_counts,
                        points,
                    }
                } else {
                    RecordData::PolyPolygon16 {
                        bounds,
                        poly_counts,
                        points,
                    }
                }
            };
            Ok((data, 24 + bytes))
        }
        56 | 92 if payload.len() >= 20 => {
            let bounds = Rect {
                left: r.i32()?,
                top: r.i32()?,
                right: r.i32()?,
                bottom: r.i32()?,
            };
            let count = r.u32()? as usize;
            let point_width = if kind == 56 { 8usize } else { 4 };
            let Some(bytes) = count.checked_mul(point_width + 1) else {
                return malformed();
            };
            if bytes > r.remaining() {
                return malformed();
            }
            budget.charge_alloc(bytes)?;
            budget.charge_work(count as u64 * 2)?;
            let data = if kind == 56 {
                let mut points = try_vec_with_capacity(count)?;
                for _ in 0..count {
                    points.push(Point {
                        x: r.i32()?,
                        y: r.i32()?,
                    });
                }
                let mut ab_types = try_vec_with_capacity(count)?;
                ab_types.extend_from_slice(r.take(count)?);
                RecordData::PolyDraw {
                    bounds,
                    points,
                    ab_types,
                }
            } else {
                let mut points = try_vec_with_capacity(count)?;
                for _ in 0..count {
                    points.push(Point16 {
                        x: r.u16()? as i16,
                        y: r.u16()? as i16,
                    });
                }
                let mut ab_types = try_vec_with_capacity(count)?;
                ab_types.extend_from_slice(r.take(count)?);
                RecordData::PolyDraw16 {
                    bounds,
                    points,
                    ab_types,
                }
            };
            Ok((data, 20 + bytes))
        }
        42 if payload.len() >= 16 => Ok((
            RecordData::Ellipse {
                bounds: Rect {
                    left: r.i32()?,
                    top: r.i32()?,
                    right: r.i32()?,
                    bottom: r.i32()?,
                },
            },
            16,
        )),
        43 if payload.len() >= 16 => Ok((
            RecordData::Rectangle {
                bounds: Rect {
                    left: r.i32()?,
                    top: r.i32()?,
                    right: r.i32()?,
                    bottom: r.i32()?,
                },
            },
            16,
        )),
        44 if payload.len() >= 24 => Ok((
            RecordData::RoundRect {
                bounds: Rect {
                    left: r.i32()?,
                    top: r.i32()?,
                    right: r.i32()?,
                    bottom: r.i32()?,
                },
                corner: Size {
                    cx: r.i32()?,
                    cy: r.i32()?,
                },
            },
            24,
        )),
        22 if payload.len() >= 4 => Ok((
            RecordData::SetTextAlign {
                text_align_mode: r.u32()?,
            },
            4,
        )),
        34 if payload.len() >= 4 => Ok((RecordData::RestoreDc { saved_dc: r.i32()? }, 4)),
        37 if payload.len() >= 4 => Ok((
            RecordData::SelectObject {
                ih_object: r.u32()?,
            },
            4,
        )),
        40 if payload.len() >= 4 => Ok((
            RecordData::DeleteObject {
                ih_object: r.u32()?,
            },
            4,
        )),
        57 if payload.len() >= 4 => Ok((
            RecordData::SetArcDirection {
                arc_direction: r.u32()?,
            },
            4,
        )),
        67 if payload.len() >= 4 => Ok((
            RecordData::SelectClipPath {
                region_mode: r.u32()?,
            },
            4,
        )),
        16 if payload.len() >= 4 => Ok((RecordData::SetMapperFlags { flags: r.u32()? }, 4)),
        98 if payload.len() >= 4 => Ok((RecordData::SetIcmMode { mode: r.u32()? }, 4)),
        115 if payload.len() >= 4 => Ok((RecordData::SetLayout { mode: r.u32()? }, 4)),
        28 => Ok((RecordData::SetMetaRgn, 0)),
        65 => Ok((RecordData::FlattenPath, 0)),
        66 => Ok((RecordData::WidenPath, 0)),
        53 | 120 => {
            budget.charge_alloc(payload.len())?;
            budget.charge_work((payload.len() as u64).div_ceil(16))?;
            let mut body = try_vec_with_capacity(payload.len())?;
            body.extend_from_slice(payload);
            let data = if kind == 53 {
                RecordData::ExtFloodFill { body }
            } else {
                RecordData::SetTextJustification { body }
            };
            Ok((data, payload.len()))
        }
        33 => Ok((RecordData::SaveDc, 0)),
        59 => Ok((RecordData::BeginPath, 0)),
        60 => Ok((RecordData::EndPath, 0)),
        61 => Ok((RecordData::CloseFigure, 0)),
        68 => Ok((RecordData::AbortPath, 0)),
        62 if payload.len() >= 16 => Ok((
            RecordData::FillPath {
                bounds: Rect {
                    left: r.i32()?,
                    top: r.i32()?,
                    right: r.i32()?,
                    bottom: r.i32()?,
                },
            },
            16,
        )),
        63 if payload.len() >= 16 => Ok((
            RecordData::StrokeAndFillPath {
                bounds: Rect {
                    left: r.i32()?,
                    top: r.i32()?,
                    right: r.i32()?,
                    bottom: r.i32()?,
                },
            },
            16,
        )),
        64 if payload.len() >= 16 => Ok((
            RecordData::StrokePath {
                bounds: Rect {
                    left: r.i32()?,
                    top: r.i32()?,
                    right: r.i32()?,
                    bottom: r.i32()?,
                },
            },
            16,
        )),
        70 if payload.len() >= 4 => {
            let count = r.u32()? as usize;
            if count > r.remaining() {
                return malformed();
            }
            budget.charge_alloc(count)?;
            budget.charge_work((count as u64).div_ceil(16))?;
            let mut data = try_vec_with_capacity(count)?;
            data.extend_from_slice(r.take(count)?);
            Ok((RecordData::Comment { data }, 4 + count))
        }
        54 if payload.len() >= 8 => Ok((
            RecordData::LineTo {
                origin: Point {
                    x: r.i32()?,
                    y: r.i32()?,
                },
            },
            8,
        )),
        45 if payload.len() >= 32 => Ok((
            RecordData::Arc {
                bounds: Rect {
                    left: r.i32()?,
                    top: r.i32()?,
                    right: r.i32()?,
                    bottom: r.i32()?,
                },
                start: Point {
                    x: r.i32()?,
                    y: r.i32()?,
                },
                end: Point {
                    x: r.i32()?,
                    y: r.i32()?,
                },
            },
            32,
        )),
        55 if payload.len() >= 32 => Ok((
            RecordData::ArcTo {
                bounds: Rect {
                    left: r.i32()?,
                    top: r.i32()?,
                    right: r.i32()?,
                    bottom: r.i32()?,
                },
                start: Point {
                    x: r.i32()?,
                    y: r.i32()?,
                },
                end: Point {
                    x: r.i32()?,
                    y: r.i32()?,
                },
            },
            32,
        )),
        46 if payload.len() >= 32 => Ok((
            RecordData::Chord {
                bounds: Rect {
                    left: r.i32()?,
                    top: r.i32()?,
                    right: r.i32()?,
                    bottom: r.i32()?,
                },
                start: Point {
                    x: r.i32()?,
                    y: r.i32()?,
                },
                end: Point {
                    x: r.i32()?,
                    y: r.i32()?,
                },
            },
            32,
        )),
        47 if payload.len() >= 32 => Ok((
            RecordData::Pie {
                bounds: Rect {
                    left: r.i32()?,
                    top: r.i32()?,
                    right: r.i32()?,
                    bottom: r.i32()?,
                },
                start: Point {
                    x: r.i32()?,
                    y: r.i32()?,
                },
                end: Point {
                    x: r.i32()?,
                    y: r.i32()?,
                },
            },
            32,
        )),
        29 if payload.len() >= 16 => Ok((
            RecordData::ExcludeClipRect {
                clip: Rect {
                    left: r.i32()?,
                    top: r.i32()?,
                    right: r.i32()?,
                    bottom: r.i32()?,
                },
            },
            16,
        )),
        30 if payload.len() >= 16 => Ok((
            RecordData::IntersectClipRect {
                clip: Rect {
                    left: r.i32()?,
                    top: r.i32()?,
                    right: r.i32()?,
                    bottom: r.i32()?,
                },
            },
            16,
        )),
        38 if payload.len() >= 20 => Ok((
            RecordData::CreatePen {
                ih_pen: r.u32()?,
                pen_style: r.u32()?,
                width: Point {
                    x: r.i32()?,
                    y: r.i32()?,
                },
                color: ColorRef {
                    red: r.take(1)?[0],
                    green: r.take(1)?[0],
                    blue: r.take(1)?[0],
                    reserved: r.take(1)?[0],
                },
            },
            20,
        )),
        39 if payload.len() >= 16 => Ok((
            RecordData::CreateBrushIndirect {
                ih_brush: r.u32()?,
                brush_style: r.u32()?,
                color: ColorRef {
                    red: r.take(1)?[0],
                    green: r.take(1)?[0],
                    blue: r.take(1)?[0],
                    reserved: r.take(1)?[0],
                },
                brush_hatch: r.u32()?,
            },
            16,
        )),
        15 if payload.len() >= 12 => Ok((
            RecordData::SetPixelV {
                pixel: Point {
                    x: r.i32()?,
                    y: r.i32()?,
                },
                color: ColorRef {
                    red: r.take(1)?[0],
                    green: r.take(1)?[0],
                    blue: r.take(1)?[0],
                    reserved: r.take(1)?[0],
                },
            },
            12,
        )),
        _ => malformed(),
    }
}
