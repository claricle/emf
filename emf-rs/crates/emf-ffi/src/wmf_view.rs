//! WMFV v1 / WMFE v1: read-only transports of the typed WMF views (DIB, Bitmap16,
//! pattern-brush target, Escape subtypes, embedded EMF). They are independent of
//! WMFS and never alter a document; callers compare them with another decoder.
use super::*;
use emf_core::wmf::{
    bitmap::BitmapImage,
    brush::BrushRecord,
    dib::{Bitmap16, ColorTable, Dib, DibHeader},
    escape::{CountedEscapePayload, EmbeddedEmfError, EscapePayload, EMBEDDED_EMF_ESCAPE},
    TypedRecord,
};

const MAX_BYTES: usize = 200 * 1024 * 1024;

struct Out(Vec<u8>);
impl Out {
    fn new(magic: &[u8; 4]) -> Result<Self, Failure> {
        let mut out = Self(Vec::new());
        out.raw(magic)?;
        out.u32(1)?;
        Ok(out)
    }
    fn raw(&mut self, bytes: &[u8]) -> Result<(), Failure> {
        if self.0.len().saturating_add(bytes.len()) > MAX_BYTES {
            return Err(Failure::new(
                EMF_LIMIT_EXCEEDED,
                None,
                "WMF view exceeds output limit",
            ));
        }
        self.0
            .try_reserve(bytes.len())
            .map_err(|_| Failure::new(EMF_ALLOCATION_FAILED, None, "WMF view allocation failed"))?;
        self.0.extend_from_slice(bytes);
        Ok(())
    }
    fn u32(&mut self, n: u32) -> Result<(), Failure> {
        self.raw(&n.to_le_bytes())
    }
    fn i32(&mut self, n: i32) -> Result<(), Failure> {
        self.raw(&n.to_le_bytes())
    }
    fn u64(&mut self, n: u64) -> Result<(), Failure> {
        self.raw(&n.to_le_bytes())
    }
    fn bytes(&mut self, bytes: &[u8]) -> Result<(), Failure> {
        self.u64(bytes.len() as u64)?;
        self.raw(bytes)
    }
}

fn bitmap16(out: &mut Out, value: &Bitmap16) -> Result<(), Failure> {
    out.u32(2)?;
    for n in [
        value.bitmap_type,
        value.width,
        value.height,
        value.width_bytes,
    ] {
        out.i32(i32::from(n))?;
    }
    out.u32(u32::from(value.planes))?;
    out.u32(u32::from(value.bits_pixel))?;
    out.bytes(&value.pixels)?;
    out.bytes(&value.trailing)
}

fn dib(out: &mut Out, value: &Dib) -> Result<(), Failure> {
    out.u32(3)?;
    match &value.header {
        DibHeader::Core(h) => {
            out.u32(0)?;
            for n in [h.width, h.height, h.planes, h.bit_count] {
                out.u32(u32::from(n))?;
            }
        }
        DibHeader::Info(h) => {
            out.u32(1)?;
            out.i32(h.width)?;
            out.i32(h.height)?;
            out.u32(u32::from(h.planes))?;
            out.u32(u32::from(h.bit_count))?;
            out.u32(h.compression)?;
            out.u32(h.image_size)?;
            out.i32(h.x_pels_per_meter)?;
            out.i32(h.y_pels_per_meter)?;
            out.u32(h.colors_used)?;
            out.u32(h.colors_important)?;
            out.bytes(&h.extension)?;
        }
    }
    let masks = value.bitfield_masks.unwrap_or([0; 3]);
    out.u32(u32::from(value.bitfield_masks.is_some()))?;
    for mask in masks {
        out.u32(mask)?;
    }
    match &value.colors {
        ColorTable::None => {
            out.u32(0)?;
            out.u64(0)?;
        }
        ColorTable::RgbTriples(rows) => {
            out.u32(1)?;
            out.u64(rows.len() as u64)?;
            for row in rows {
                out.raw(row)?;
            }
        }
        ColorTable::RgbQuads(rows) => {
            out.u32(2)?;
            out.u64(rows.len() as u64)?;
            for row in rows {
                out.raw(row)?;
            }
        }
        ColorTable::PaletteIndices(rows) => {
            out.u32(3)?;
            out.u64(rows.len() as u64)?;
            for row in rows {
                out.raw(&row.to_le_bytes())?;
            }
        }
    }
    out.bytes(&value.pixels)?;
    out.bytes(&value.trailing)
}

fn fixed_escape(out: &mut Out, payload: EscapePayload) -> Result<(), Failure> {
    let (code, values): (u16, Vec<i64>) = match payload {
        EscapePayload::Empty(kind) => (kind as u16, vec![]),
        EscapePayload::ClipToPath {
            clip_function,
            reserved1,
        } => (0x1001, vec![clip_function.into(), reserved1.into()]),
        EscapePayload::DrawPatternRect {
            position,
            size,
            style,
            pattern,
        } => (
            0x0019,
            vec![
                position[0].into(),
                position[1].into(),
                size[0].into(),
                size[1].into(),
                style.into(),
                pattern.into(),
            ],
        ),
        EscapePayload::EpsPrinting { set_eps_printing } => (0x0021, vec![set_eps_printing.into()]),
        EscapePayload::GetPsFeatureSetting { feature } => (0x1019, vec![feature.into()]),
        EscapePayload::QueryEscSupport { query } => (0x0008, vec![query.into()]),
        EscapePayload::SetCopyCount { copy_count } => (0x0011, vec![copy_count.into()]),
        EscapePayload::SetLineCap { cap } => (0x0015, vec![cap.into()]),
        EscapePayload::SetLineJoin { join } => (0x0016, vec![join.into()]),
        EscapePayload::SetMiterLimit { miter_limit } => (0x0017, vec![miter_limit.into()]),
    };
    out.u32(4)?;
    out.u32(u32::from(code))?;
    out.u64(values.len() as u64)?;
    for value in values {
        out.raw(&value.to_le_bytes())?;
    }
    Ok(())
}

fn error_code(error: EmbeddedEmfError) -> u32 {
    use EmbeddedEmfError as E;
    match error {
        E::NotEmbeddedEmf => 1,
        E::Transport => 2,
        E::Metadata => 3,
        E::CommentIdentifier => 4,
        E::CommentType => 5,
        E::NonZeroFlags => 6,
        E::ZeroRecordCount => 7,
        E::SegmentTooLarge => 8,
        E::InconsistentSizes => 9,
        E::SequenceMismatch => 10,
        E::RemainingMismatch => 11,
        E::RecordCountMismatch => 12,
        E::Incomplete => 13,
        E::LimitExceeded => 14,
    }
}

/// Typed views of one record as `entries` followed by tagged bodies. A record with
/// no applicable or valid view has zero entries.
fn views(out: &mut Out, typed: Option<&TypedRecord>, limits: &ParseLimits) -> Result<u32, Failure> {
    let mut entries = Out(Vec::new());
    let mut count = 0;
    match typed {
        Some(TypedRecord::Bitmap(record)) => match record.typed_image(limits)? {
            Some(BitmapImage::Absent) => {
                entries.u32(1)?;
                count = 1;
            }
            Some(BitmapImage::Bitmap16(value)) => {
                bitmap16(&mut entries, &value)?;
                count = 1;
            }
            Some(BitmapImage::Dib(value)) => {
                dib(&mut entries, &value)?;
                count = 1;
            }
            None => {}
        },
        Some(TypedRecord::Brush(BrushRecord::DibCreatePatternBrush(brush))) => {
            if let Some(value) = brush.target_dib(limits)? {
                dib(&mut entries, &value)?;
                count = 1;
            }
        }
        Some(TypedRecord::Escape(escape)) => {
            if let Some(payload) = escape.typed_payload() {
                fixed_escape(&mut entries, payload)?;
                count += 1;
            }
            if let Some(counted) = escape.typed_counted_payload() {
                let code = match counted {
                    CountedEscapePayload::Passthrough(_) => 0x0013,
                    CountedEscapePayload::PostScriptData(_) => 0x0025,
                    CountedEscapePayload::PostScriptPassthrough(_) => 0x1013,
                    CountedEscapePayload::StartDoc(_) => 0x000a,
                    CountedEscapePayload::CheckJpegFormat(_) => 0x1017,
                    CountedEscapePayload::CheckPngFormat(_) => 0x1018,
                    CountedEscapePayload::SetColorTable(_) => 0x0004,
                };
                entries.u32(5)?;
                entries.u32(code)?;
                entries.bytes(counted.data())?;
                count += 1;
            }
            if let Some(payload) = escape.typed_special_passthrough2_payload() {
                entries.u32(6)?;
                entries.u32(payload.reserved)?;
                entries.bytes(payload.data)?;
                count += 1;
            }
            if escape.escape_function == EMBEDDED_EMF_ESCAPE {
                match escape.embedded_emf_segment() {
                    Ok(segment) => {
                        entries.u32(7)?;
                        for n in [
                            segment.version,
                            u32::from(segment.checksum),
                            segment.flags,
                            segment.record_count,
                            segment.current_size,
                            segment.remaining_bytes,
                            segment.total_size,
                        ] {
                            entries.u32(n)?;
                        }
                        entries.bytes(segment.data)?;
                    }
                    Err(error) => {
                        entries.u32(8)?;
                        entries.u32(error_code(error))?;
                    }
                }
                count += 1;
            }
        }
        _ => {}
    }
    out.raw(&entries.0)?;
    Ok(count)
}

/// Return an owned WMFV v1 buffer with the typed views of one record: magic,
/// u32 version 1, u32 entry count, then tagged little-endian entries (see
/// `wmf-views-v1.md`). Resource-limit failures are errors, not empty views.
/// # Safety
/// The handle must be a live WMF handle; output pointers must be writable.
#[no_mangle]
pub unsafe extern "C" fn emf_wmf_record_view(
    document: *const WmfDocument,
    index: u64,
    parse_limits: *const EmfLimits,
    out_buffer: *mut *mut EmfBuffer,
    out_error: *mut *mut EmfError,
) -> i32 {
    if !out_buffer.is_null() {
        out_buffer.write(ptr::null_mut());
    }
    run(out_error, || {
        if out_buffer.is_null() {
            return Err(Failure::invalid("out_buffer is NULL"));
        }
        let limits = limits(parse_limits)?;
        let document = &document
            .as_ref()
            .ok_or_else(|| Failure::invalid("document is NULL"))?
            .document;
        let record = document
            .records()
            .get(length(index, 1)?)
            .ok_or_else(|| Failure::invalid("record index is out of range"))?;
        let mut body = Out(Vec::new());
        let count = views(&mut body, record.typed(), &limits)?;
        let mut out = Out::new(b"WMFV")?;
        out.u32(count)?;
        out.raw(&body.0)?;
        out_buffer.write(Box::into_raw(Box::new(EmfBuffer { bytes: out.0 })));
        Ok(())
    })
}

/// Return an owned WMFE v1 buffer with every embedded-EMF escape sequence:
/// magic, u32 version 1, u64 count, then per sequence u64 first record, u64
/// segment count, u32 ok flag, and either (u32 version, u32 checksum, u32
/// checksum-valid, u64 length, bytes) or a u32 error code.
/// # Safety
/// The handle must be a live WMF handle; output pointers must be writable.
#[no_mangle]
pub unsafe extern "C" fn emf_wmf_embedded_emf(
    document: *const WmfDocument,
    parse_limits: *const EmfLimits,
    out_buffer: *mut *mut EmfBuffer,
    out_error: *mut *mut EmfError,
) -> i32 {
    if !out_buffer.is_null() {
        out_buffer.write(ptr::null_mut());
    }
    run(out_error, || {
        if out_buffer.is_null() {
            return Err(Failure::invalid("out_buffer is NULL"));
        }
        let limits = limits(parse_limits)?;
        let document = &document
            .as_ref()
            .ok_or_else(|| Failure::invalid("document is NULL"))?
            .document;
        let sequences = document.embedded_emf_sequences(&limits);
        let mut out = Out::new(b"WMFE")?;
        out.u64(sequences.len() as u64)?;
        for sequence in &sequences {
            out.u64(sequence.first_record as u64)?;
            out.u64(sequence.segment_count as u64)?;
            match &sequence.emf {
                Ok(emf) => {
                    out.u32(1)?;
                    out.u32(emf.version)?;
                    out.u32(u32::from(emf.checksum))?;
                    out.u32(u32::from(emf.checksum_valid))?;
                    out.bytes(&emf.bytes)?;
                }
                Err(error) => {
                    out.u32(0)?;
                    out.u32(error_code(*error))?;
                }
            }
        }
        out_buffer.write(Box::into_raw(Box::new(EmfBuffer { bytes: out.0 })));
        Ok(())
    })
}
