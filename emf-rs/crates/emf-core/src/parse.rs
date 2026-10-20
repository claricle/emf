//! EMF header decoding and record framing.

use crate::detect::{detect_format, Format, EMF_MAGIC};
use crate::error::ParseFailure;
use crate::limits::{try_vec_with_capacity, Budget, ParseLimits};
use crate::model::{
    ColorRef, DesignVector, Diagnostic, DiagnosticKind, Document, EmfHeader, EofRecord,
    ExtCreatePen, ExtTextOut, Float32, Font, FontRecord, LogFont, LogFontEx, LogFontExDv,
    LogFontPanose, PaletteEntry, PixelFormatFields, Point, Point16, RecordData, RecordSpan, Rect,
    RegionData, ScaleFactors, Size, XForm, EMR_HEADER, HEADER_FIXED_BYTES,
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
                2..=22 | 24..=68 | 70..=75 | 82..=92 | 95 | 98 | 115 | 118 | 120
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
        118 => crate::gradient::decode(payload, budget),
        52 => Ok((RecordData::RealizePalette, 0)),
        48 if payload.len() >= 4 => Ok((RecordData::SelectPalette { ih_pal: r.u32()? }, 4)),
        51 if payload.len() >= 8 => Ok((
            RecordData::ResizePalette {
                ih_pal: r.u32()?,
                entry_count: r.u32()?,
            },
            8,
        )),
        49 | 50 => decode_palette(kind, payload, budget),
        82 => decode_font(payload, budget),
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
        53 if payload.len() >= 16 => Ok((
            RecordData::ExtFloodFill {
                start: Point {
                    x: r.i32()?,
                    y: r.i32()?,
                },
                color: ColorRef {
                    red: r.take(1)?[0],
                    green: r.take(1)?[0],
                    blue: r.take(1)?[0],
                    reserved: r.take(1)?[0],
                },
                flood_fill_mode: r.u32()?,
            },
            16,
        )),
        120 if payload.len() >= 8 => Ok((
            RecordData::SetTextJustification {
                break_extra: r.i32()?,
                break_count: r.i32()?,
            },
            8,
        )),
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
        95 => decode_extended_pen(payload, budget),
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

fn decode_extended_pen(
    payload: &[u8],
    budget: &mut Budget<'_>,
) -> Result<(RecordData, usize), ParseFailure> {
    let raw = || Ok((RecordData::Raw, 0));
    if payload.len() < 44 {
        return raw();
    }
    let mut r = Reader::new(payload);
    let ih_pen = r.u32()?;
    let off_info = r.u32()? as usize;
    let cb_info = r.u32()? as usize;
    let off_bits = r.u32()? as usize;
    let cb_bits = r.u32()? as usize;
    let pen_style = r.u32()?;
    let width = r.u32()?;
    let brush_style = r.u32()?;
    let color = ColorRef {
        red: r.take(1)?[0],
        green: r.take(1)?[0],
        blue: r.take(1)?[0],
        reserved: r.take(1)?[0],
    };
    let brush_hatch = r.u32()?;
    let count = r.u32()? as usize;
    let Some(style_bytes) = count.checked_mul(4) else {
        return raw();
    };
    let Some(fixed) = 44usize.checked_add(style_bytes) else {
        return raw();
    };
    if fixed > payload.len() {
        return raw();
    }
    // Wire offsets include the eight-byte record header.
    let span = |offset: usize, len: usize| {
        let start = offset.checked_sub(8)?;
        let end = start.checked_add(len)?;
        (offset % 4 == 0 && start >= fixed && end <= payload.len()).then_some(start..end)
    };
    let info = if off_info == 0 && cb_info == 0 {
        None
    } else {
        let Some(range) = span(off_info, cb_info) else {
            return raw();
        };
        Some(range)
    };
    let bits = if off_bits == 0 && cb_bits == 0 {
        None
    } else {
        let Some(range) = span(off_bits, cb_bits) else {
            return raw();
        };
        Some(range)
    };
    let bits_first = match (&info, &bits) {
        (Some(a), Some(b)) => b.start < a.start || (b.start == a.start && b.is_empty()),
        (None, Some(_)) => true,
        _ => false,
    };
    // Validate every span and its ordering before allocating any decoded data.
    let mut end = fixed;
    for is_bits in [bits_first, !bits_first] {
        if let Some(range) = if is_bits { &bits } else { &info } {
            if range.start < end {
                return raw();
            }
            end = range.end;
        }
    }
    budget.charge_alloc(style_bytes)?;
    budget.charge_work(count as u64)?;
    let mut style_entries = try_vec_with_capacity(count)?;
    for _ in 0..count {
        style_entries.push(r.u32()?);
    }
    let mut bitmap_info = None;
    let mut bitmap_bits = None;
    let mut info_padding = Vec::new();
    let mut bits_padding = Vec::new();
    let mut cursor = fixed;
    for is_bits in [bits_first, !bits_first] {
        if let Some(range) = if is_bits { &bits } else { &info } {
            let padding = copy_pen_bytes(&payload[cursor..range.start], budget)?;
            let data = copy_pen_bytes(&payload[range.clone()], budget)?;
            if is_bits {
                bits_padding = padding;
                bitmap_bits = Some(data);
            } else {
                info_padding = padding;
                bitmap_info = Some(data);
            }
            cursor = range.end;
        }
    }
    Ok((
        RecordData::ExtCreatePen(ExtCreatePen {
            ih_pen,
            pen_style,
            width,
            brush_style,
            color,
            brush_hatch,
            style_entries,
            bitmap_info,
            bitmap_bits,
            info_padding,
            bits_padding,
            bits_first,
        }),
        end,
    ))
}

fn copy_pen_bytes(bytes: &[u8], budget: &mut Budget<'_>) -> Result<Vec<u8>, ParseFailure> {
    budget.charge_alloc(bytes.len())?;
    budget.charge_work((bytes.len() as u64).div_ceil(16))?;
    let mut values = try_vec_with_capacity(bytes.len())?;
    values.extend_from_slice(bytes);
    Ok(values)
}

fn decode_palette(
    kind: u32,
    payload: &[u8],
    budget: &mut Budget<'_>,
) -> Result<(RecordData, usize), ParseFailure> {
    let fixed = if kind == 49 { 8usize } else { 12usize };
    if payload.len() < fixed {
        return Ok((RecordData::Raw, 0));
    }
    let mut r = Reader::new(payload);
    let ih_pal = r.u32()?;
    let (version, start, count) = if kind == 49 {
        (r.u16()?, 0, r.u16()? as usize)
    } else {
        (0, r.u32()?, r.u32()? as usize)
    };
    let Some(bytes) = count.checked_mul(4) else {
        return Ok((RecordData::Raw, 0));
    };
    if bytes > payload.len() - fixed {
        return Ok((RecordData::Raw, 0));
    }
    budget.charge_alloc(bytes)?;
    budget.charge_work(count as u64)?;
    let mut entries = try_vec_with_capacity(count)?;
    for entry in r.take(bytes)?.chunks_exact(4) {
        entries.push(PaletteEntry {
            red: entry[0],
            green: entry[1],
            blue: entry[2],
            flags: entry[3],
        });
    }
    Ok((
        if kind == 49 {
            RecordData::CreatePalette {
                ih_pal,
                version,
                entries,
            }
        } else {
            RecordData::SetPaletteEntries {
                ih_pal,
                start,
                entries,
            }
        },
        fixed + bytes,
    ))
}

fn read_font_units<const N: usize>(r: &mut Reader<'_>) -> Result<[u16; N], ParseFailure> {
    let mut units = [0; N];
    for unit in &mut units {
        *unit = r.u16()?;
    }
    Ok(units)
}
fn read_log_font(r: &mut Reader<'_>) -> Result<LogFont, ParseFailure> {
    Ok(LogFont {
        height: r.i32()?,
        width: r.i32()?,
        escapement: r.i32()?,
        orientation: r.i32()?,
        weight: r.i32()?,
        italic: r.take(1)?[0],
        underline: r.take(1)?[0],
        strike_out: r.take(1)?[0],
        char_set: r.take(1)?[0],
        out_precision: r.take(1)?[0],
        clip_precision: r.take(1)?[0],
        quality: r.take(1)?[0],
        pitch_and_family: r.take(1)?[0],
        face_name: read_font_units(r)?,
    })
}
fn decode_font(
    payload: &[u8],
    budget: &mut Budget<'_>,
) -> Result<(RecordData, usize), ParseFailure> {
    let raw = || Ok((RecordData::Raw, 0));
    if payload.len() < 96 {
        return raw();
    }
    let mut r = Reader::new(payload);
    let ih_object = r.u32()?;
    let size = payload.len() - 4;
    let font = if size == 92 {
        Font::LogFont(read_log_font(&mut r)?)
    } else if size <= 320 {
        // Windows copies short Panose data into a zero-initialized structure.
        let mut padded = [0; 320];
        padded[..size].copy_from_slice(&payload[4..]);
        let mut p = Reader::new(&padded);
        let font = LogFontPanose {
            encoded_size: size,
            log_font: read_log_font(&mut p)?,
            full_name: read_font_units(&mut p)?,
            style: read_font_units(&mut p)?,
            version: p.u32()?,
            style_size: p.u32()?,
            match_value: p.u32()?,
            reserved: p.u32()?,
            vendor_id: p.take(4)?.try_into().unwrap(),
            culture: p.u32()?,
            panose: p.take(10)?.try_into().unwrap(),
            padding: p.take(2)?.try_into().unwrap(),
        };
        r.skip(size)?;
        Font::Panose(font)
    } else {
        if size < 356 {
            return raw();
        }
        let log_font_ex = LogFontEx {
            log_font: read_log_font(&mut r)?,
            full_name: read_font_units(&mut r)?,
            style: read_font_units(&mut r)?,
            script: read_font_units(&mut r)?,
        };
        let signature = r.u32()?;
        let count = r.u32()? as usize;
        if signature != 0x08007664 || count > 16 || count * 4 > r.remaining() {
            return raw();
        }
        budget.charge_alloc(count * 4)?;
        budget.charge_work(count as u64)?;
        let mut values = try_vec_with_capacity(count)?;
        for _ in 0..count {
            values.push(r.i32()?);
        }
        Font::ExDv(LogFontExDv {
            log_font_ex,
            design_vector: DesignVector { signature, values },
        })
    };
    budget.charge_alloc(std::mem::size_of::<FontRecord>())?;
    Ok((
        RecordData::CreateFontIndirectW(Box::new(FontRecord { ih_object, font })),
        r.position(),
    ))
}
