//! EMF header decoding and record framing.

use crate::detect::{detect_format, Format, EMF_MAGIC};
use crate::error::ParseFailure;
use crate::limits::{try_vec_with_capacity, Budget, ParseLimits};
use crate::model::{
    Diagnostic, DiagnosticKind, Document, EmfHeader, PixelFormatFields, RecordSpan, Rect, Size,
    EMR_EOF, EMR_HEADER, HEADER_FIXED_BYTES,
};
use crate::reader::{u32_at, Reader};

const RECORD_HEAD_BYTES: usize = 8;

/// Parse an EMF file into an owned [`Document`].
///
/// Only a damaged or oversize header, an unsupported container or an exceeded
/// budget is fatal. A bad record ends framing with a [`Diagnostic`] and keeps
/// the remaining bytes so serialization stays exact.
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
        records.push(RecordSpan {
            offset,
            size,
            record_type,
        });
        if record_type == EMR_EOF {
            break;
        }
    }

    let tail_offset = reader.position();
    Ok(Document {
        source,
        header,
        header_len,
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
