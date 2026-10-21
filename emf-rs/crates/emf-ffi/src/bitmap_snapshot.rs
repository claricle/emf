//! Semantic bitmap snapshot payloads use EMR field widths, without the EMR header.
//! Fixed fields are encoded from the typed model; offsets are rebuilt from its
//! ordered buffers and retained gaps. Generic trailing bytes stay in the source.
use super::{point, rect, u32_field, Error};
use emf_core::{
    BitmapBufferKind, BitmapMask, BitmapRecord, BitmapSource, BitmapTransfer, ColorRef, DibTransfer,
};

fn fixed(value: &BitmapRecord) -> usize {
    match value.record_type() {
        76 => 100,
        77 | 114 | 116 => 108,
        78 => 128,
        79 => 140,
        80 => 76,
        81 => 80,
        _ => 32,
    }
}
fn index(kind: BitmapBufferKind) -> usize {
    match kind {
        BitmapBufferKind::SourceInfo => 0,
        BitmapBufferKind::SourceBits => 1,
        BitmapBufferKind::MaskInfo => 2,
        BitmapBufferKind::MaskBits => 3,
    }
}
fn layout(value: &BitmapRecord) -> Result<([(u32, u32); 4], usize), Error> {
    let mut positions = [(0, 0); 4];
    let mut end = fixed(value);
    let mut seen = 0u8;
    for kind in value.buffers().order {
        let i = index(kind);
        if seen & (1 << i) != 0 {
            return Err(Error::SizeOverflow);
        }
        seen |= 1 << i;
        if let Some(buffer) = value.buffers().get(kind) {
            end = end
                .checked_add(buffer.padding.len())
                .ok_or(Error::SizeOverflow)?;
            positions[i] = (
                u32::try_from(end).map_err(|_| Error::SizeOverflow)?,
                u32::try_from(buffer.data.len()).map_err(|_| Error::SizeOverflow)?,
            );
            end = end
                .checked_add(buffer.data.len())
                .ok_or(Error::SizeOverflow)?;
        }
    }
    u32::try_from(end).map_err(|_| Error::SizeOverflow)?;
    Ok((positions, end - 8))
}
pub(super) fn len(value: &BitmapRecord) -> Result<usize, Error> {
    Ok(layout(value)?.1)
}
pub(super) fn family(value: &BitmapRecord) -> u32 {
    family_of(value.record_type())
}
pub(super) fn family_of(record_type: u32) -> u32 {
    match record_type {
        76..=81 => 94 + record_type - 76,
        93 => 100,
        94 => 101,
        114 => 102,
        _ => 103,
    }
}
pub(super) fn encode(out: &mut Vec<u8>, value: &BitmapRecord) -> Result<(), Error> {
    let (positions, _) = layout(value)?;
    match value {
        BitmapRecord::BitBlt {
            transfer,
            raster_operation,
        }
        | BitmapRecord::StretchBlt {
            transfer,
            raster_operation,
            ..
        }
        | BitmapRecord::MaskBlt {
            transfer,
            raster_operation,
            ..
        } => append_transfer(out, transfer, *raster_operation, positions),
        BitmapRecord::AlphaBlend {
            transfer, blend, ..
        } => append_transfer(
            out,
            transfer,
            u32::from_le_bytes([
                blend.operation,
                blend.flags,
                blend.source_constant_alpha,
                blend.alpha_format,
            ]),
            positions,
        ),
        BitmapRecord::TransparentBlt {
            transfer,
            transparent_color,
            ..
        } => append_transfer(out, transfer, color_word(*transparent_color), positions),
        BitmapRecord::PlgBlt {
            bounds,
            destination,
            source,
            source_extent,
            mask,
            ..
        } => {
            rect(out, *bounds);
            for p in destination {
                point(out, *p);
            }
            point(out, source.position);
            point(out, *source_extent);
            source_tail(out, source, positions);
            append_mask(out, mask, positions);
        }
        BitmapRecord::SetDibitsToDevice {
            transfer,
            start_scan,
            scan_count,
        } => {
            append_dib(out, transfer, positions);
            u32_field(out, *start_scan);
            u32_field(out, *scan_count);
        }
        BitmapRecord::StretchDibits {
            transfer,
            raster_operation,
            destination_extent,
        } => {
            append_dib(out, transfer, positions);
            u32_field(out, *raster_operation);
            point(out, *destination_extent);
        }
        BitmapRecord::CreateMonoBrush {
            ih_brush, usage, ..
        }
        | BitmapRecord::CreateDibPatternBrushPt {
            ih_brush, usage, ..
        } => {
            u32_field(out, *ih_brush);
            u32_field(out, *usage);
            pair(out, positions[0]);
            pair(out, positions[1]);
        }
    }
    match value {
        BitmapRecord::StretchBlt { source_extent, .. }
        | BitmapRecord::AlphaBlend { source_extent, .. }
        | BitmapRecord::TransparentBlt { source_extent, .. } => point(out, *source_extent),
        BitmapRecord::MaskBlt { mask, .. } => append_mask(out, mask, positions),
        _ => {}
    }
    for kind in value.buffers().order {
        if let Some(buffer) = value.buffers().get(kind) {
            out.extend_from_slice(&buffer.padding);
            out.extend_from_slice(&buffer.data);
        }
    }
    Ok(())
}
fn color_word(c: ColorRef) -> u32 {
    u32::from_le_bytes([c.red, c.green, c.blue, c.reserved])
}
fn pair(out: &mut Vec<u8>, p: (u32, u32)) {
    u32_field(out, p.0);
    u32_field(out, p.1);
}
fn source_tail(out: &mut Vec<u8>, s: &BitmapSource, p: [(u32, u32); 4]) {
    for f in [
        s.transform.m11,
        s.transform.m12,
        s.transform.m21,
        s.transform.m22,
        s.transform.dx,
        s.transform.dy,
    ] {
        u32_field(out, f.to_bits());
    }
    u32_field(out, color_word(s.background_color));
    u32_field(out, s.usage);
    pair(out, p[0]);
    pair(out, p[1]);
}
fn append_transfer(out: &mut Vec<u8>, t: &BitmapTransfer, op: u32, p: [(u32, u32); 4]) {
    rect(out, t.bounds);
    point(out, t.destination);
    point(out, t.destination_extent);
    u32_field(out, op);
    point(out, t.source.position);
    source_tail(out, &t.source, p);
}
fn append_mask(out: &mut Vec<u8>, m: &BitmapMask, p: [(u32, u32); 4]) {
    point(out, m.position);
    u32_field(out, m.usage);
    pair(out, p[2]);
    pair(out, p[3]);
}
fn append_dib(out: &mut Vec<u8>, t: &DibTransfer, p: [(u32, u32); 4]) {
    rect(out, t.bounds);
    point(out, t.destination);
    point(out, t.source);
    point(out, t.source_extent);
    pair(out, p[0]);
    pair(out, p[1]);
    u32_field(out, t.usage);
}

#[cfg(test)]
mod tests {
    use super::*;
    use emf_core::{parse, ParseLimits, RecordData};

    #[test]
    fn typed_edits_rebuild_offsets_and_leave_retained_bytes_intact() {
        let mut input = vec![0; 88];
        input[..8].copy_from_slice(&[1u32.to_le_bytes(), 88u32.to_le_bytes()].concat());
        input[40..44].copy_from_slice(&0x464d4520u32.to_le_bytes());
        for word in [93u32, 44, 7, 99, 32, 4, 36, 4] {
            input.extend_from_slice(&word.to_le_bytes());
        }
        input.extend_from_slice(b"infobitsTAIL");
        let document = parse(&input, &ParseLimits::default()).unwrap();
        let RecordData::Bitmap(mut bitmap) = document.records()[0].data().clone() else {
            panic!("expected typed bitmap")
        };
        let BitmapRecord::CreateMonoBrush { ih_brush, .. } = &mut bitmap else {
            panic!("expected brush")
        };
        *ih_brush = 0xdeadbeef;
        bitmap
            .buffers_mut()
            .source_info
            .as_mut()
            .unwrap()
            .data
            .extend_from_slice(b"EDIT");
        let mut out = Vec::new();
        encode(&mut out, &bitmap).unwrap();
        assert_eq!(out.len(), len(&bitmap).unwrap());
        assert_eq!(&out[..4], &0xdeadbeefu32.to_le_bytes());
        assert_eq!(&out[4..12], &input[100..108]);
        assert_eq!(&out[12..16], &8u32.to_le_bytes());
        assert_eq!(&out[16..20], &40u32.to_le_bytes());
        assert_eq!(&out[20..], b"\x04\x00\x00\x00infoEDITbits");
        assert!(!out.ends_with(b"TAIL"));
    }
}
