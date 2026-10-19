//! EMF header decoding and record framing.

use crate::detect::{detect_format, Format, EMF_MAGIC};
use crate::error::ParseFailure;
use crate::limits::{try_vec_with_capacity, Budget, ParseLimits};
use crate::model::{
    ColorRef, Diagnostic, DiagnosticKind, Document, EmfHeader, EofRecord, ExtTextOut, Float32,
    PixelFormatFields, Point, Point16, RecordData, RecordSpan, Rect, RegionData, ScaleFactors,
    Size, XForm, EMR_HEADER, HEADER_FIXED_BYTES,
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
                2..=22 | 24..=47 | 53..=68 | 70..=75 | 83..=92 | 98 | 115 | 120
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
        83 => decode_text::<u8>(payload, budget),
        84 => decode_text::<u16>(payload, budget),
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
        71..=75 => {
            let fixed = match kind {
                71 => 24,
                72 => 32,
                73 | 74 => 20,
                _ => 8,
            };
            if payload.len() < fixed {
                return malformed();
            }
            let bounds = if kind != 75 {
                Some(read_rect(&mut r)?)
            } else {
                None
            };
            let count = r.u32()? as usize;
            let ih_brush = if kind == 71 || kind == 72 {
                r.u32()?
            } else {
                0
            };
            let stroke = if kind == 72 {
                Size {
                    cx: r.i32()?,
                    cy: r.i32()?,
                }
            } else {
                Size { cx: 0, cy: 0 }
            };
            let region_mode = if kind == 75 { r.u32()? } else { 0 };
            if count > r.remaining() {
                return malformed();
            }
            if count == 0 && kind == 75 && region_mode == 5 {
                return Ok((
                    RecordData::ExtSelectClipRgn {
                        region_mode,
                        region: None,
                    },
                    fixed,
                ));
            }
            let Some(region) = read_region(r.take(count)?, budget)? else {
                return malformed();
            };
            let data = match kind {
                71 => RecordData::FillRgn {
                    bounds: bounds.unwrap(),
                    ih_brush,
                    region,
                },
                72 => RecordData::FrameRgn {
                    bounds: bounds.unwrap(),
                    ih_brush,
                    stroke,
                    region,
                },
                73 => RecordData::InvertRgn {
                    bounds: bounds.unwrap(),
                    region,
                },
                74 => RecordData::PaintRgn {
                    bounds: bounds.unwrap(),
                    region,
                },
                _ => RecordData::ExtSelectClipRgn {
                    region_mode,
                    region: Some(region),
                },
            };
            Ok((data, fixed + count))
        }
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

trait TextUnit: Sized {
    fn read(r: &mut Reader<'_>) -> Result<Self, ParseFailure>;
    fn record(text: ExtTextOut<Self>) -> RecordData;
}
impl TextUnit for u8 {
    fn read(r: &mut Reader<'_>) -> Result<Self, ParseFailure> {
        Ok(r.take(1)?[0])
    }
    fn record(text: ExtTextOut<Self>) -> RecordData {
        RecordData::ExtTextOutA(text)
    }
}
impl TextUnit for u16 {
    fn read(r: &mut Reader<'_>) -> Result<Self, ParseFailure> {
        r.u16()
    }
    fn record(text: ExtTextOut<Self>) -> RecordData {
        RecordData::ExtTextOutW(text)
    }
}

fn decode_text<T: TextUnit>(
    payload: &[u8],
    budget: &mut Budget<'_>,
) -> Result<(RecordData, usize), ParseFailure> {
    let raw = || Ok((RecordData::Raw, 0));
    if payload.len() < 52 {
        return raw();
    }
    let mut r = Reader::new(payload);
    let read_rect = |r: &mut Reader<'_>| -> Result<Rect, ParseFailure> {
        Ok(Rect {
            left: r.i32()?,
            top: r.i32()?,
            right: r.i32()?,
            bottom: r.i32()?,
        })
    };
    let bounds = read_rect(&mut r)?;
    let graphics_mode = r.u32()?;
    let ex_scale = Float32::from_bits(r.u32()?);
    let ey_scale = Float32::from_bits(r.u32()?);
    let reference = Point {
        x: r.i32()?,
        y: r.i32()?,
    };
    let count = r.u32()? as usize;
    let off_string = r.u32()? as usize;
    let options = r.u32()?;
    let rectangle = if options & 0x100 == 0 {
        if r.remaining() < 20 {
            return raw();
        }
        Some(read_rect(&mut r)?)
    } else {
        None
    };
    let off_dx = r.u32()? as usize;
    let fixed = r.position();
    let width = std::mem::size_of::<T>();
    let Some(string_len) = count.checked_mul(width) else {
        return raw();
    };
    let Some(dx_count) = count.checked_mul(if options & 0x2000 != 0 { 2 } else { 1 }) else {
        return raw();
    };
    let Some(dx_len) = dx_count.checked_mul(4) else {
        return raw();
    };
    // Offsets include the eight-byte record header, while payload slices do not.
    let span = |offset: usize, len: usize, alignment: usize| {
        let start = offset.checked_sub(8)?;
        let end = start.checked_add(len)?;
        (start >= fixed && offset % alignment == 0 && end <= payload.len()).then_some(start..end)
    };
    let string = if off_string == 0 && count == 0 {
        None
    } else {
        let Some(range) = span(off_string, string_len, width) else {
            return raw();
        };
        Some(range)
    };
    let dx = if off_dx == 0 {
        None
    } else {
        let Some(range) = span(off_dx, dx_len, 4) else {
            return raw();
        };
        Some(range)
    };
    if let (Some(a), Some(b)) = (&string, &dx) {
        if a.start < b.end && b.start < a.end {
            return raw();
        }
    }
    let dx_first = match (&string, &dx) {
        (Some(a), Some(b)) => b.start < a.start,
        (None, Some(_)) => true,
        _ => false,
    };
    let mut end = fixed;
    let mut string_padding = Vec::new();
    let mut dx_padding = Vec::new();
    for is_dx in [dx_first, !dx_first] {
        if let Some(range) = if is_dx { &dx } else { &string } {
            if range.start < end {
                return raw();
            }
            let bytes = &payload[end..range.start];
            budget.charge_work((bytes.len() as u64).div_ceil(16))?;
            budget.charge_alloc(bytes.len())?;
            let mut padding = try_vec_with_capacity(bytes.len())?;
            padding.extend_from_slice(bytes);
            if is_dx {
                dx_padding = padding;
            } else {
                string_padding = padding;
            }
            end = range.end;
        }
    }
    budget.charge_work(count as u64)?;
    budget.charge_alloc(string_len)?;
    let mut text = try_vec_with_capacity(count)?;
    if let Some(range) = &string {
        let mut r = Reader::new(&payload[range.clone()]);
        for _ in 0..count {
            text.push(T::read(&mut r)?);
        }
    }
    let dx = if let Some(range) = dx {
        budget.charge_work(dx_count as u64)?;
        budget.charge_alloc(dx_len)?;
        let mut values = try_vec_with_capacity(dx_count)?;
        let mut r = Reader::new(&payload[range]);
        for _ in 0..dx_count {
            values.push(r.u32()?);
        }
        Some(values)
    } else {
        None
    };
    Ok((
        T::record(ExtTextOut {
            bounds,
            graphics_mode,
            ex_scale,
            ey_scale,
            reference,
            options,
            rectangle,
            text,
            dx,
            string_padding,
            dx_padding,
            dx_first,
            string_present: string.is_some(),
        }),
        end,
    ))
}

fn read_rect(r: &mut Reader<'_>) -> Result<Rect, ParseFailure> {
    Ok(Rect {
        left: r.i32()?,
        top: r.i32()?,
        right: r.i32()?,
        bottom: r.i32()?,
    })
}

fn read_region(bytes: &[u8], budget: &mut Budget<'_>) -> Result<Option<RegionData>, ParseFailure> {
    if bytes.len() < 32 {
        return Ok(None);
    }
    let mut r = Reader::new(bytes);
    if r.u32()? != 32 {
        return Ok(None);
    }
    let region_type = r.u32()?;
    let count = r.u32()? as usize;
    let buffer_size = r.u32()? as usize;
    let bounds = read_rect(&mut r)?;
    let Some(rect_bytes) = count.checked_mul(16) else {
        return Ok(None);
    };
    if rect_bytes != buffer_size || rect_bytes > r.remaining() {
        return Ok(None);
    }
    let extra = r.remaining() - rect_bytes;
    budget.charge_alloc(rect_bytes)?;
    budget.charge_alloc(extra)?;
    budget.charge_work(count as u64)?;
    budget.charge_work((extra as u64).div_ceil(16))?;
    let mut rectangles = try_vec_with_capacity(count)?;
    for _ in 0..count {
        rectangles.push(read_rect(&mut r)?);
    }
    let mut trailing_bytes = try_vec_with_capacity(extra)?;
    trailing_bytes.extend_from_slice(r.take(extra)?);
    Ok(Some(RegionData {
        region_type,
        bounds,
        rectangles,
        trailing_bytes,
    }))
}
