//! Version 1 WMFS transport. Integers are little-endian; coordinates are i32.
//! Only Ruby's public WMF model families receive payloads. Other records retain
//! their source spans and remain opaque, even when the native core knows more.
use super::*;
use emf_core::wmf::{
    bitmap::BitmapRecord as M, brush::BrushRecord as B, geometry::GeometryRecord as G,
    objects::ObjectIssue, objects::ObjectKind, region::RegionRecord as R, state::StateRecord as S,
    text::TextRecord as T, DiagnosticKind as D, Document, Record, TypedRecord,
};

const MAX_BYTES: usize = 200 * 1024 * 1024;

struct Writer {
    bytes: Option<Vec<u8>>,
    length: usize,
    limit: usize,
}
impl Writer {
    fn raw(&mut self, bytes: &[u8]) -> Result<(), Failure> {
        self.length = self
            .length
            .checked_add(bytes.len())
            .filter(|n| *n <= self.limit)
            .ok_or_else(|| {
                Failure::new(
                    EMF_LIMIT_EXCEEDED,
                    None,
                    "WMF snapshot exceeds output limit",
                )
            })?;
        if let Some(out) = &mut self.bytes {
            out.extend_from_slice(bytes);
        }
        Ok(())
    }
    fn u32(&mut self, n: u32) -> Result<(), Failure> {
        self.raw(&n.to_le_bytes())
    }
    fn i32(&mut self, n: i16) -> Result<(), Failure> {
        self.u32(n as i32 as u32)
    }
    fn u64(&mut self, n: u64) -> Result<(), Failure> {
        self.raw(&n.to_le_bytes())
    }
}

// A stack array avoids allocating temporary payloads in either encoding pass.
fn fixed(value: &G) -> Option<([i16; 8], usize)> {
    macro_rules! fields { ($($n:expr),*) => {{ let values = [$($n),*]; let mut out = [0; 8]; out[..values.len()].copy_from_slice(&values); Some((out, values.len())) }}; }
    match *value {
        G::MoveTo { y, x }
        | G::LineTo { y, x }
        | G::SetWindowOrg { y, x }
        | G::SetWindowExt { y, x }
        | G::SetViewportOrg { y, x }
        | G::SetViewportExt { y, x }
        | G::OffsetWindowOrg { y, x }
        | G::OffsetViewportOrg { y, x } => fields![y, x],
        G::Ellipse {
            bottom,
            right,
            top,
            left,
        }
        | G::Rectangle {
            bottom,
            right,
            top,
            left,
        } => fields![bottom, right, top, left],
        G::RoundRect {
            ellipse_height,
            ellipse_width,
            bottom,
            right,
            top,
            left,
        } => fields![ellipse_height, ellipse_width, bottom, right, top, left],
        G::Arc {
            y_end,
            x_end,
            y_start,
            x_start,
            bottom,
            right,
            top,
            left,
        }
        | G::Pie {
            y_end,
            x_end,
            y_start,
            x_start,
            bottom,
            right,
            top,
            left,
        }
        | G::Chord {
            y_end,
            x_end,
            y_start,
            x_start,
            bottom,
            right,
            top,
            left,
        } => fields![y_end, x_end, y_start, x_start, bottom, right, top, left],
        _ => None,
    }
}
fn scalar_state(value: &S) -> Option<([u32; 2], usize)> {
    match *value {
        S::SetBkColor(n) | S::SetMapperFlags(n) | S::SetTextColor(n) => Some(([n, 0], 1)),
        S::SetBkMode(n)
        | S::SetMapMode(n)
        | S::SetPolyFillMode(n)
        | S::SetRop2(n)
        | S::SetStretchBltMode(n)
        | S::SetTextAlign(n)
        | S::SetTextCharExtra(n) => Some(([u32::from(n), 0], 1)),
        S::SetTextJustification {
            break_count,
            break_extra,
        } => Some(([u32::from(break_count), u32::from(break_extra)], 2)),
        S::SetLayout { layout, reserved } => Some(([u32::from(layout), u32::from(reserved)], 2)),
        _ => None,
    }
}
fn family(record: &Record) -> u32 {
    if record.is_eof() {
        return 1;
    }
    match record.typed() {
        Some(TypedRecord::Geometry(g)) if fixed(g).is_some() => 2,
        Some(TypedRecord::Geometry(
            G::Polygon { .. } | G::Polyline { .. } | G::PolyPolygon { .. },
        )) => 3,
        Some(TypedRecord::State(
            S::CreatePenIndirect(_)
            | S::CreateBrushIndirect(_)
            | S::SelectObject(_)
            | S::DeleteObject(_),
        )) => 4,
        Some(TypedRecord::Text(_)) => 5,
        Some(TypedRecord::State(s)) if scalar_state(s).is_some() => 6,
        Some(TypedRecord::State(S::CreateFontIndirect(_))) => 7,
        Some(TypedRecord::State(
            S::CreatePalette(_)
            | S::SetPalEntries(_)
            | S::AnimatePalette(_)
            | S::SelectPalette(_)
            | S::RealizePalette
            | S::ResizePalette(_),
        )) => 8,
        Some(TypedRecord::Region(_))
        | Some(TypedRecord::State(S::SelectClipRegion(_)))
        | Some(TypedRecord::Geometry(
            G::OffsetClipRgn { .. } | G::ExcludeClipRect { .. } | G::IntersectClipRect { .. },
        )) => 9,
        Some(TypedRecord::Brush(_)) => 10,
        Some(TypedRecord::Bitmap(_)) => 11,
        _ => 0,
    }
}
fn payload(
    out: &mut Writer,
    doc: &Document,
    record: &Record,
    original: &[u8],
) -> Result<(), Failure> {
    match (family(record), record.typed()) {
        (2, Some(TypedRecord::Geometry(g))) => {
            let (values, len) = fixed(g).expect("fixed geometry family");
            for value in &values[..len] {
                out.i32(*value)?;
            }
        }
        (3, Some(TypedRecord::Geometry(g))) => {
            let (points, counts): (_, &[u16]) = match g {
                G::Polygon { points } | G::Polyline { points } => (points, &[]),
                G::PolyPolygon {
                    points,
                    poly_counts,
                } => (points, poly_counts),
                _ => unreachable!(),
            };
            out.u64(points.len() as u64)?;
            out.u64(counts.len() as u64)?;
            for count in counts {
                out.u32(u32::from(*count))?;
            }
            for point in points {
                out.i32(point.x)?;
                out.i32(point.y)?;
            }
        }
        (4, Some(TypedRecord::State(s))) => match s {
            S::CreatePenIndirect(p) => {
                out.u32(u32::from(p.style))?;
                out.i32(p.width_x)?;
                out.i32(p.width_y)?;
                out.u32(p.color)?;
            }
            S::CreateBrushIndirect(b) => {
                out.u32(u32::from(b.style))?;
                out.u32(b.color)?;
                out.u32(u32::from(b.hatch))?;
            }
            S::SelectObject(i) | S::DeleteObject(i) => out.u32(u32::from(*i))?,
            _ => unreachable!(),
        },
        (6, Some(TypedRecord::State(s))) => {
            let (values, len) = scalar_state(s).expect("scalar state family");
            for value in &values[..len] {
                out.u32(*value)?;
            }
        }
        (7, Some(TypedRecord::State(S::CreateFontIndirect(font)))) => {
            for value in [
                font.height,
                font.width,
                font.escapement,
                font.orientation,
                font.weight,
            ] {
                out.i32(value)?;
            }
            for value in [
                font.italic,
                font.underline,
                font.strike_out,
                font.char_set,
                font.out_precision,
                font.clip_precision,
                font.quality,
                font.pitch_and_family,
            ] {
                out.u32(u32::from(value))?;
            }
            out.raw(&font.face_name)?;
        }
        (8, Some(TypedRecord::State(s))) => match s {
            S::CreatePalette(p) | S::SetPalEntries(p) | S::AnimatePalette(p) => {
                out.u32(u32::from(p.start))?;
                out.u32(p.entries.len() as u32)?;
                for entry in &p.entries {
                    for value in [entry.red, entry.green, entry.blue, entry.flags] {
                        out.u32(u32::from(value))?;
                    }
                }
            }
            S::SelectPalette(index) | S::ResizePalette(index) => out.u32(u32::from(*index))?,
            S::RealizePalette => (),
            _ => unreachable!(),
        },
        (9, Some(TypedRecord::Region(r))) => match r {
            R::CreateRegion(region) => {
                out.u32(u32::from(region.next_in_chain))?;
                out.u32(region.object_count)?;
                for value in [
                    region.bounds.left,
                    region.bounds.top,
                    region.bounds.right,
                    region.bounds.bottom,
                ] {
                    out.i32(value)?;
                }
                out.u32(region.scans.len() as u32)?;
                for scan in &region.scans {
                    out.u32(u32::from(scan.top))?;
                    out.u32(u32::from(scan.bottom))?;
                    out.u32(scan.lines.len() as u32)?;
                    for line in &scan.lines {
                        out.u32(u32::from(line.left))?;
                        out.u32(u32::from(line.right))?;
                    }
                }
            }
            R::FillRegion { region, brush } => {
                out.u32(u32::from(*region))?;
                out.u32(u32::from(*brush))?;
            }
            R::FrameRegion {
                region,
                brush,
                height,
                width,
            } => {
                out.u32(u32::from(*region))?;
                out.u32(u32::from(*brush))?;
                out.i32(*height)?;
                out.i32(*width)?;
            }
            R::InvertRegion(index) | R::PaintRegion(index) => out.u32(u32::from(*index))?,
        },
        (9, Some(TypedRecord::State(S::SelectClipRegion(index)))) => out.u32(u32::from(*index))?,
        (9, Some(TypedRecord::Geometry(g))) => match g {
            G::OffsetClipRgn { y, x } => {
                out.i32(*y)?;
                out.i32(*x)?;
            }
            G::ExcludeClipRect {
                bottom,
                right,
                top,
                left,
            }
            | G::IntersectClipRect {
                bottom,
                right,
                top,
                left,
            } => {
                for value in [bottom, right, top, left] {
                    out.i32(*value)?;
                }
            }
            _ => unreachable!(),
        },
        (10, Some(TypedRecord::Brush(b))) => match b {
            B::CreatePatternBrush(b) => {
                for value in [b.bitmap_type, b.width, b.height, b.width_bytes] {
                    out.i32(value)?;
                }
                out.u32(u32::from(b.planes))?;
                out.u32(u32::from(b.bits_pixel))?;
                out.raw(&b.bits)?;
                out.raw(&b.reserved)?;
                out.u32(b.pattern.len() as u32)?;
                out.raw(&b.pattern)?;
            }
            B::DibCreatePatternBrush(b) => {
                out.u32(u32::from(b.style))?;
                out.u32(u32::from(b.color_usage))?;
                out.u32(b.target.len() as u32)?;
                out.raw(&b.target)?;
            }
        },
        (11, Some(TypedRecord::Bitmap(bitmap))) => {
            let image = match bitmap {
                M::BitBlt(b) | M::DibBitBlt(b) => {
                    out.u32(b.raster_operation)?;
                    for value in [
                        b.source_y,
                        b.source_x,
                        b.height,
                        b.width,
                        b.destination_y,
                        b.destination_x,
                    ] {
                        out.i32(value)?;
                    }
                    out.u32(u32::from(b.reserved))?;
                    b.bitmap.as_deref()
                }
                M::StretchBlt(b) | M::DibStretchBlt(b) => {
                    out.u32(b.raster_operation)?;
                    for value in [
                        b.source_height,
                        b.source_width,
                        b.source_y,
                        b.source_x,
                        b.destination_height,
                        b.destination_width,
                        b.destination_y,
                        b.destination_x,
                    ] {
                        out.i32(value)?;
                    }
                    out.u32(u32::from(b.reserved))?;
                    b.bitmap.as_deref()
                }
                M::SetDibToDev(b) => {
                    for value in [
                        b.color_usage,
                        b.scan_count,
                        b.start_scan,
                        b.source_y,
                        b.source_x,
                        b.height,
                        b.width,
                        b.destination_y,
                        b.destination_x,
                    ] {
                        out.u32(u32::from(value))?;
                    }
                    Some(b.bitmap.as_slice())
                }
                M::StretchDib(b) => {
                    out.u32(b.raster_operation)?;
                    out.u32(u32::from(b.color_usage))?;
                    for value in [
                        b.source_height,
                        b.source_width,
                        b.source_y,
                        b.source_x,
                        b.destination_height,
                        b.destination_width,
                        b.destination_y,
                        b.destination_x,
                    ] {
                        out.i32(value)?;
                    }
                    Some(b.bitmap.as_slice())
                }
            };
            out.u32(u32::from(image.is_some()))?;
            out.u32(image.map_or(0, |bytes| bytes.len() as u32))?;
            if let Some(bytes) = image {
                out.raw(bytes)?;
            }
        }
        (5, Some(TypedRecord::Text(t))) => {
            let (x, y, text, padding, options, rectangle, dx, suffix) = match t {
                T::TextOut {
                    x,
                    y,
                    text,
                    padding,
                    ..
                } => (*x, *y, text, padding, 0, None, None, &[][..]),
                T::ExtTextOut {
                    x,
                    y,
                    text,
                    padding,
                    options,
                    rectangle,
                    dx,
                    ..
                } => {
                    let used = 8
                        + usize::from(rectangle.is_some()) * 8
                        + text.len()
                        + padding.len()
                        + dx.as_ref().map_or(0, |v| v.len() * 2);
                    let suffix = doc
                        .record_body(record)
                        .and_then(|b| b.get(used..))
                        .ok_or_else(|| {
                            Failure::new(EMF_INTERNAL_ERROR, None, "invalid WMF text span")
                        })?;
                    (
                        *x,
                        *y,
                        text,
                        padding,
                        original
                            .get(record.offset() + 12..record.offset() + 14)
                            .map(|b| u16::from_le_bytes([b[0], b[1]]))
                            .unwrap_or(*options),
                        rectangle.as_ref(),
                        dx.as_ref(),
                        suffix,
                    )
                }
            };
            out.i32(x)?;
            out.i32(y)?;
            out.u32(u32::from(options))?;
            out.u32(u32::from(rectangle.is_some()))?;
            out.u64(text.len() as u64)?;
            out.u64(padding.len() as u64)?;
            out.u64(dx.map_or(0, Vec::len) as u64)?;
            out.u64(suffix.len() as u64)?;
            out.u32(u32::from(dx.is_some()))?;
            out.u32(0)?;
            if let Some(r) = rectangle {
                for n in [r.left, r.top, r.right, r.bottom] {
                    out.i32(n)?;
                }
            } else {
                for _ in 0..4 {
                    out.u32(0)?;
                }
            }
            out.raw(text)?;
            out.raw(padding)?;
            if let Some(dx) = dx {
                for n in dx {
                    out.i32(*n)?;
                }
            }
            out.raw(suffix)?;
        }
        _ => (),
    }
    Ok(())
}
fn object_kind(kind: ObjectKind) -> u64 {
    match kind {
        ObjectKind::Brush => 1,
        ObjectKind::Font => 2,
        ObjectKind::Palette => 3,
        ObjectKind::Pen => 4,
        ObjectKind::Region => 5,
    }
}
fn diagnostic(kind: &D) -> (u32, u32, u64, u64) {
    match *kind {
        D::UnsupportedVersion { version } => (1, 0, version.into(), 0),
        D::DibUnsupportedByVersion { version } => (12, 0, version.into(), 0),
        D::HeaderSizeMismatch {
            declared_words,
            actual_words,
        } => (2, 0, declared_words.into(), actual_words),
        D::MaxRecordMismatch {
            declared_words,
            actual_words,
        } => (3, 0, declared_words.into(), actual_words.into()),
        D::PlaceableChecksumMismatch { expected, found } => (4, 0, expected.into(), found.into()),
        D::TruncatedRecordHead { available } => (5, 0, available as u64, 0),
        D::RecordSizeTooSmall { size_words } => (6, 0, size_words.into(), 0),
        D::TruncatedRecord { claimed, available } => (7, 0, claimed as u64, available as u64),
        D::InvalidEof => (8, 0, 0, 0),
        D::MissingEof => (9, 0, 0, 0),
        D::MalformedRecord => (10, 0, 0, 0),
        D::Object(issue) => match issue {
            ObjectIssue::TableFull => (11, 1, 0, 0),
            ObjectIssue::InvalidReference { index } => (11, 2, index.into(), 0),
            ObjectIssue::WrongKind {
                index,
                expected,
                found,
            } => (
                11,
                3,
                index.into(),
                object_kind(expected) | (object_kind(found) << 32),
            ),
            ObjectIssue::InvalidRestoreDc { saved_dc } => (11, 4, saved_dc as i64 as u64, 0),
        },
    }
}
fn write(out: &mut Writer, doc: &Document, total: u64, original: &[u8]) -> Result<(), Failure> {
    out.raw(b"WMFS")?;
    out.u32(1)?;
    out.u64(total)?;
    for n in [
        doc.records().len(),
        doc.diagnostics().len(),
        doc.tail().len(),
        doc.source().len(),
    ] {
        out.u64(n as u64)?;
    }
    let h = doc.header();
    for n in [
        u32::from(h.file_type),
        u32::from(h.header_size),
        u32::from(h.version),
        h.size,
        u32::from(h.num_objects),
        h.max_record,
        u32::from(h.num_parameters),
        u32::from(doc.placeable_header().is_some()),
        u32::from(doc.has_eof()),
        0,
    ] {
        out.u32(n)?;
    }
    if let Some(p) = doc.placeable_header() {
        out.u32(u32::from(p.handle))?;
        for n in [p.left, p.top, p.right, p.bottom] {
            out.i32(n)?;
        }
        for n in [u32::from(p.inch), p.reserved, u32::from(p.checksum)] {
            out.u32(n)?;
        }
    } else {
        for _ in 0..8 {
            out.u32(0)?;
        }
    }
    for (index, record) in doc.records().iter().enumerate() {
        let mut count = Writer {
            bytes: None,
            length: 0,
            limit: out.limit,
        };
        payload(&mut count, doc, record, original)?;
        out.u64(index as u64)?;
        out.u64(record.offset() as u64)?;
        out.u64(record.size() as u64)?;
        out.u32(u32::from(record.function()))?;
        out.u32(family(record))?;
        out.u64(count.length as u64)?;
        payload(out, doc, record, original)?;
    }
    for d in doc.diagnostics() {
        let (kind, detail_kind, first, second) = diagnostic(&d.kind);
        for n in [
            kind,
            u32::from(d.function.is_some()),
            u32::from(d.function.unwrap_or(0)),
            detail_kind,
        ] {
            out.u32(n)?;
        }
        for n in [d.offset as u64, first, second] {
            out.u64(n)?;
        }
    }
    out.raw(doc.tail())
}
fn encode(doc: &Document, limit: usize, original: &[u8]) -> Result<Vec<u8>, Failure> {
    let mut out = Writer {
        bytes: None,
        length: 0,
        limit,
    };
    write(&mut out, doc, 0, original)?;
    let length = out.length;
    let mut bytes = Vec::new();
    bytes.try_reserve_exact(length).map_err(|_| {
        Failure::new(
            EMF_ALLOCATION_FAILED,
            None,
            "WMF snapshot allocation failed",
        )
    })?;
    out.bytes = Some(bytes);
    out.length = 0;
    write(&mut out, doc, length as u64, original)?;
    Ok(out.bytes.expect("allocated snapshot"))
}

fn ruby_text_view(doc: &Document) -> Result<Option<Document>, Failure> {
    let needs_view = |record: &Record| {
        record.function() & 0xff == 0x32
            && doc
                .record_body(record)
                .and_then(|b| b.get(6..8))
                .is_some_and(|b| u16::from_le_bytes([b[0], b[1]]) & 0x2000 != 0)
    };
    if !doc.records().iter().any(needs_view) {
        return Ok(None);
    }
    let mut bytes = Vec::new();
    bytes.try_reserve_exact(doc.source().len()).map_err(|_| {
        Failure::new(
            EMF_ALLOCATION_FAILED,
            None,
            "WMF text view allocation failed",
        )
    })?;
    bytes.extend_from_slice(doc.source());
    for record in doc.records().iter().filter(|r| needs_view(r)) {
        bytes[record.offset() + 13] &= !0x20;
    }
    Ok(Some(emf_core::wmf::parse(
        &bytes,
        &emf_core::ParseLimits::default(),
    )?))
}

/// Return an owned WMFS v1 snapshot of the current WMF document. Output is
/// limited to 200 MiB, including transport expansion of coordinates and arrays.
/// Edited handles are serialized and reparsed under default resource limits.
/// # Safety
/// The handle must be a live WMF handle; output pointers must be writable.
#[no_mangle]
pub unsafe extern "C" fn emf_wmf_document_snapshot(
    document: *const WmfDocument,
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
        let doc = &document
            .as_ref()
            .ok_or_else(|| Failure::invalid("document is NULL"))?
            .document;
        let current;
        let doc = if doc.is_edited() {
            let bytes = emf_core::wmf::serialize(doc)?;
            current = emf_core::wmf::parse(&bytes, &emf_core::ParseLimits::default())?;
            &current
        } else {
            doc
        };
        // Ruby's existing ExtTextOut model interprets DX as one signed word per
        // character, including when the otherwise opaque ETO_PDY bit is set.
        // Decode that compatibility view natively and retain the original flag
        // and remaining spacing bytes as the model's opaque suffix.
        let compatible = ruby_text_view(doc)?;
        let bytes = encode(compatible.as_ref().unwrap_or(doc), MAX_BYTES, doc.source())?;
        out_buffer.write(Box::into_raw(Box::new(EmfBuffer { bytes })));
        Ok(())
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn checks_brush_data_output_budget_before_allocating() {
        let source = [
            1, 0, 9, 0, 0, 3, 18, 0, 0, 0, 1, 0, 6, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0x42, 1, 3, 0, 0xff,
            0xff, 0x80, 0, 3, 0, 0, 0, 0, 0,
        ];
        let doc = emf_core::wmf::parse(&source, &emf_core::ParseLimits::default()).unwrap();
        let bytes = encode(&doc, 214, doc.source()).unwrap_or_else(|e| panic!("{:?}", e.message));
        assert_eq!(bytes.len(), 214);
        assert_eq!(
            encode(&doc, 213, doc.source()).unwrap_err().status,
            EMF_LIMIT_EXCEEDED
        );
    }
    #[test]
    fn checks_bitmap_data_output_budget_before_allocating() {
        let mut source = vec![
            1, 0, 9, 0, 0, 3, 25, 0, 0, 0, 0, 0, 13, 0, 0, 0, 0, 0, 13, 0, 0, 0, 0x33, 0x0d,
        ];
        source.extend_from_slice(&[0; 18]);
        source.extend_from_slice(&[0x80, 0xff, 3, 0, 0, 0, 0, 0]);
        let doc = emf_core::wmf::parse(&source, &emf_core::ParseLimits::default()).unwrap();
        let bytes = encode(&doc, 246, doc.source()).unwrap_or_else(|e| panic!("{:?}", e.message));
        assert_eq!(bytes.len(), 246);
        assert_eq!(
            encode(&doc, 245, doc.source()).unwrap_err().status,
            EMF_LIMIT_EXCEEDED
        );
    }
    #[test]
    fn checks_exact_output_budget_before_allocating() {
        let source = [
            1, 0, 9, 0, 0, 3, 12, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0,
        ];
        let doc = emf_core::wmf::parse(&source, &emf_core::ParseLimits::default()).unwrap();
        let bytes = encode(&doc, 160, doc.source()).unwrap_or_else(|e| panic!("{:?}", e.message));
        assert_eq!(bytes.len(), 160);
        assert_eq!(
            encode(&doc, 159, doc.source()).unwrap_err().status,
            EMF_LIMIT_EXCEEDED
        );
    }
}
