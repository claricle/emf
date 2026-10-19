//! Version 2 owned snapshot encoding. All fields are explicitly little-endian.

use emf_core::{DiagnosticKind, Document, EmfHeader, Point, RecordData, Rect, Size};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum Error {
    SizeOverflow,
    AllocationFailed,
}

pub(crate) fn family(data: &RecordData) -> u32 {
    match data {
        RecordData::Raw => 0,
        RecordData::Eof(_) => 1,
        RecordData::SetMapMode { .. } => 2,
        RecordData::Polyline { .. } => 3,
        RecordData::Comment { .. } => 4,
        RecordData::SetBkMode { .. } => 5,
        RecordData::SetPolyFillMode { .. } => 6,
        RecordData::SetRop2 { .. } => 7,
        RecordData::SetStretchBltMode { .. } => 8,
        RecordData::SetWindowExtEx { .. } => 9,
        RecordData::SetWindowOrgEx { .. } => 10,
        RecordData::SetViewportExtEx { .. } => 11,
        RecordData::SetViewportOrgEx { .. } => 12,
        RecordData::SetBrushOrgEx { .. } => 13,
        RecordData::OffsetClipRgn { .. } => 14,
        RecordData::MoveToEx { .. } => 15,
        RecordData::SetTextColor { .. } => 16,
        RecordData::SetBkColor { .. } => 17,
        RecordData::Ellipse { .. } => 18,
        RecordData::Rectangle { .. } => 19,
        RecordData::RoundRect { .. } => 20,
        RecordData::SetTextAlign { .. } => 21,
        RecordData::SaveDc => 22,
        RecordData::RestoreDc { .. } => 23,
        RecordData::SelectObject { .. } => 24,
        RecordData::DeleteObject { .. } => 25,
        RecordData::SetArcDirection { .. } => 26,
        RecordData::BeginPath => 27,
        RecordData::EndPath => 28,
        RecordData::CloseFigure => 29,
        RecordData::FillPath { .. } => 30,
        RecordData::StrokeAndFillPath { .. } => 31,
        RecordData::StrokePath { .. } => 32,
        RecordData::SelectClipPath { .. } => 33,
        RecordData::AbortPath => 34,
    }
}

fn wire_len(len: usize) -> Result<u64, Error> {
    u64::try_from(len).map_err(|_| Error::SizeOverflow)
}

fn add_len(total: &mut usize, len: usize) -> Result<(), Error> {
    *total = total.checked_add(len).ok_or(Error::SizeOverflow)?;
    Ok(())
}

fn payload_len(data: &RecordData) -> Result<usize, Error> {
    match data {
        RecordData::Raw => Ok(0),
        RecordData::Eof(_) => Ok(12),
        RecordData::SetMapMode { .. }
        | RecordData::SetBkMode { .. }
        | RecordData::SetPolyFillMode { .. }
        | RecordData::SetRop2 { .. }
        | RecordData::SetStretchBltMode { .. }
        | RecordData::SetTextColor { .. }
        | RecordData::SetBkColor { .. } => Ok(4),
        RecordData::Ellipse { .. } | RecordData::Rectangle { .. } => Ok(16),
        RecordData::RoundRect { .. } => Ok(24),
        RecordData::SetTextAlign { .. } => Ok(4),
        RecordData::SaveDc => Ok(0),
        RecordData::RestoreDc { .. } => Ok(4),
        RecordData::SelectObject { .. } => Ok(4),
        RecordData::DeleteObject { .. } => Ok(4),
        RecordData::SetArcDirection { .. } => Ok(4),
        RecordData::BeginPath => Ok(0),
        RecordData::EndPath => Ok(0),
        RecordData::CloseFigure => Ok(0),
        RecordData::FillPath { .. } => Ok(16),
        RecordData::StrokeAndFillPath { .. } => Ok(16),
        RecordData::StrokePath { .. } => Ok(16),
        RecordData::SelectClipPath { .. } => Ok(4),
        RecordData::AbortPath => Ok(0),
        RecordData::SetWindowExtEx { .. }
        | RecordData::SetWindowOrgEx { .. }
        | RecordData::SetViewportExtEx { .. }
        | RecordData::SetViewportOrgEx { .. }
        | RecordData::SetBrushOrgEx { .. }
        | RecordData::OffsetClipRgn { .. }
        | RecordData::MoveToEx { .. } => Ok(8),
        RecordData::Polyline { points, .. } => points
            .len()
            .checked_mul(8)
            .and_then(|len| len.checked_add(24))
            .ok_or(Error::SizeOverflow),
        RecordData::Comment { data } => data.len().checked_add(8).ok_or(Error::SizeOverflow),
    }
}

pub(crate) fn encode(document: &Document) -> Result<Vec<u8>, Error> {
    let mut len = 56usize + 112;
    add_len(&mut len, document.header_bytes().len())?;
    for record in document.records() {
        add_len(&mut len, 40)?;
        add_len(&mut len, payload_len(record.data())?)?;
    }
    add_len(
        &mut len,
        document
            .diagnostics()
            .len()
            .checked_mul(40)
            .ok_or(Error::SizeOverflow)?,
    )?;
    add_len(&mut len, document.trailing_bytes().len())?;
    add_len(&mut len, document.unframed_bytes().len())?;
    // Vec allocations cannot exceed isize::MAX bytes, independently of the allocator.
    if len > isize::MAX as usize {
        return Err(Error::SizeOverflow);
    }
    let total = wire_len(len)?;
    let mut out = Vec::new();
    out.try_reserve_exact(len)
        .map_err(|_| Error::AllocationFailed)?;
    out.extend_from_slice(b"EMFS");
    u32_field(&mut out, 2);
    for value in [
        total,
        wire_len(document.header_bytes().len())?,
        wire_len(document.records().len())?,
        wire_len(document.diagnostics().len())?,
        wire_len(document.trailing_bytes().len())?,
        wire_len(document.unframed_bytes().len())?,
    ] {
        u64_field(&mut out, value);
    }
    header(&mut out, document.header());
    out.extend_from_slice(document.header_bytes());
    for (index, record) in document.records().iter().enumerate() {
        u64_field(&mut out, wire_len(index)?);
        u64_field(&mut out, wire_len(record.offset())?);
        u64_field(&mut out, u64::from(record.size()));
        u32_field(&mut out, record.record_type());
        u32_field(&mut out, family(record.data()));
        u64_field(&mut out, wire_len(payload_len(record.data())?)?);
        match record.data() {
            RecordData::Raw => {}
            RecordData::Eof(eof) => {
                u32_field(&mut out, eof.n_pal_entries);
                u32_field(&mut out, eof.off_pal_entries);
                u32_field(&mut out, eof.n_size_last);
            }
            RecordData::SetMapMode { map_mode } => u32_field(&mut out, *map_mode),
            RecordData::SetBkMode { bk_mode } => u32_field(&mut out, *bk_mode),
            RecordData::SetPolyFillMode { poly_fill_mode } => u32_field(&mut out, *poly_fill_mode),
            RecordData::SetRop2 { rop2 } => u32_field(&mut out, *rop2),
            RecordData::SetStretchBltMode { stretch_mode } => u32_field(&mut out, *stretch_mode),
            RecordData::SetWindowExtEx { extent } | RecordData::SetViewportExtEx { extent } => {
                size(&mut out, *extent);
            }
            RecordData::SetWindowOrgEx { origin }
            | RecordData::SetViewportOrgEx { origin }
            | RecordData::SetBrushOrgEx { origin }
            | RecordData::MoveToEx { origin } => point(&mut out, *origin),
            RecordData::OffsetClipRgn { offset } => point(&mut out, *offset),
            RecordData::SetTextColor { color } | RecordData::SetBkColor { color } => {
                out.extend_from_slice(&[color.red, color.green, color.blue, color.reserved]);
            }
            RecordData::Ellipse { bounds } | RecordData::Rectangle { bounds } => {
                rect(&mut out, *bounds)
            }
            RecordData::RoundRect { bounds, corner } => {
                rect(&mut out, *bounds);
                size(&mut out, *corner);
            }
            RecordData::SetTextAlign { text_align_mode } => u32_field(&mut out, *text_align_mode),
            RecordData::SaveDc => {}
            RecordData::RestoreDc { saved_dc } => i32_field(&mut out, *saved_dc),
            RecordData::SelectObject { ih_object } => u32_field(&mut out, *ih_object),
            RecordData::DeleteObject { ih_object } => u32_field(&mut out, *ih_object),
            RecordData::SetArcDirection { arc_direction } => u32_field(&mut out, *arc_direction),
            RecordData::BeginPath => {}
            RecordData::EndPath => {}
            RecordData::CloseFigure => {}
            RecordData::FillPath { bounds } => rect(&mut out, *bounds),
            RecordData::StrokeAndFillPath { bounds } => rect(&mut out, *bounds),
            RecordData::StrokePath { bounds } => rect(&mut out, *bounds),
            RecordData::SelectClipPath { region_mode } => u32_field(&mut out, *region_mode),
            RecordData::AbortPath => {}
            RecordData::Polyline { bounds, points } => {
                rect(&mut out, *bounds);
                u64_field(&mut out, wire_len(points.len())?);
                for point in points {
                    i32_field(&mut out, point.x);
                    i32_field(&mut out, point.y);
                }
            }
            RecordData::Comment { data } => {
                u64_field(&mut out, wire_len(data.len())?);
                out.extend_from_slice(data);
            }
        }
    }
    for diagnostic in document.diagnostics() {
        let (kind, detail1, detail2) = match diagnostic.kind {
            DiagnosticKind::TruncatedRecordHead { available } => (1, wire_len(available)?, 0),
            DiagnosticKind::RecordSizeTooSmall { size } => (2, u64::from(size), 0),
            DiagnosticKind::TruncatedRecord { claimed, available } => {
                (3, u64::from(claimed), wire_len(available)?)
            }
            DiagnosticKind::InvalidRecordPayload => (4, 0, 0),
        };
        u32_field(&mut out, kind);
        u32_field(&mut out, u32::from(diagnostic.record_type.is_some()));
        u32_field(&mut out, diagnostic.record_type.unwrap_or(0));
        u32_field(&mut out, 0);
        u64_field(&mut out, wire_len(diagnostic.offset)?);
        u64_field(&mut out, detail1);
        u64_field(&mut out, detail2);
    }
    out.extend_from_slice(document.trailing_bytes());
    out.extend_from_slice(document.unframed_bytes());
    debug_assert_eq!(out.len(), len);
    Ok(out)
}

fn u32_field(out: &mut Vec<u8>, value: u32) {
    out.extend_from_slice(&value.to_le_bytes());
}
fn i32_field(out: &mut Vec<u8>, value: i32) {
    out.extend_from_slice(&value.to_le_bytes());
}
fn u64_field(out: &mut Vec<u8>, value: u64) {
    out.extend_from_slice(&value.to_le_bytes());
}
fn rect(out: &mut Vec<u8>, value: Rect) {
    for coordinate in [value.left, value.top, value.right, value.bottom] {
        i32_field(out, coordinate);
    }
}
fn point(out: &mut Vec<u8>, value: Point) {
    i32_field(out, value.x);
    i32_field(out, value.y);
}
fn size(out: &mut Vec<u8>, value: Size) {
    i32_field(out, value.cx);
    i32_field(out, value.cy);
}
fn header(out: &mut Vec<u8>, value: &EmfHeader) {
    u32_field(out, value.n_size);
    rect(out, value.bounds);
    rect(out, value.frame);
    for field in [
        value.signature,
        value.version,
        value.n_bytes,
        value.n_records,
        u32::from(value.n_handles),
        u32::from(value.reserved),
        value.n_description,
        value.off_description,
        value.n_pal_entries,
    ] {
        u32_field(out, field);
    }
    size(out, value.device);
    size(out, value.millimeters);
    u32_field(
        out,
        u32::from(value.pixel_format.is_some()) | (u32::from(value.micrometers.is_some()) << 1),
    );
    let pixel = value.pixel_format;
    u32_field(out, pixel.map_or(0, |p| p.cb_pixel_format));
    u32_field(out, pixel.map_or(0, |p| p.off_pixel_format));
    u32_field(out, pixel.map_or(0, |p| p.b_open_gl));
    size(out, value.micrometers.unwrap_or(Size { cx: 0, cy: 0 }));
}

#[cfg(test)]
mod tests {
    use super::*;
    use emf_core::{parse, ParseLimits};

    fn fixture_header(len: usize) -> Vec<u8> {
        let mut bytes = vec![0; len];
        let fields = [
            (0, 1),
            (4, len as u32),
            (8, (-10i32) as u32),
            (12, 20),
            (16, 30),
            (20, 40),
            (24, 50),
            (28, 60),
            (32, 70),
            (36, 80),
            (40, 0x464d4520),
            (44, 0x10000),
            (48, 1234),
            (52, 99),
            (56, 0x43211234),
            (60, 3),
            (64, 84),
            (68, 5),
            (72, 640),
            (76, 480),
            (80, 210),
            (84, 297),
        ];
        for (offset, value) in fields {
            bytes[offset..offset + 4].copy_from_slice(&value.to_le_bytes());
        }
        if len >= 100 {
            bytes[88..100].copy_from_slice(&[7u32, 88, 1].map(u32::to_le_bytes).concat());
        }
        if len >= 108 {
            bytes[100..108].copy_from_slice(&[210000i32, -297000].map(i32::to_le_bytes).concat());
        }
        if len > 108 {
            bytes[108..].fill(0xa5);
        }
        bytes
    }

    fn record(input: &mut Vec<u8>, kind: u32, payload: &[u8]) {
        input.extend_from_slice(&kind.to_le_bytes());
        input.extend_from_slice(&(8 + payload.len() as u32).to_le_bytes());
        input.extend_from_slice(payload);
    }

    struct Cursor<'a> {
        bytes: &'a [u8],
        position: usize,
    }
    impl<'a> Cursor<'a> {
        fn take(&mut self, count: usize) -> &'a [u8] {
            let bytes = &self.bytes[self.position..self.position + count];
            self.position += count;
            bytes
        }
        fn u32(&mut self) -> u32 {
            u32::from_le_bytes(self.take(4).try_into().unwrap())
        }
        fn u64(&mut self) -> u64 {
            u64::from_le_bytes(self.take(8).try_into().unwrap())
        }
        fn words(&mut self, expected: &[u32]) {
            for value in expected {
                assert_eq!(self.u32(), *value);
            }
        }
    }

    fn prefix(bytes: &[u8], counts: [u64; 5]) -> Cursor<'_> {
        let mut cursor = Cursor { bytes, position: 0 };
        assert_eq!(cursor.take(4), b"EMFS");
        assert_eq!(cursor.u32(), 2);
        assert_eq!(cursor.u64(), bytes.len() as u64);
        for count in counts {
            assert_eq!(cursor.u64(), count);
        }
        cursor
    }

    #[test]
    fn scalar_state_families_encode_unsigned_values_without_opaque_suffixes() {
        for (kind, expected_family) in [(18, 5), (19, 6), (20, 7), (21, 8)] {
            for value in [0u32, 0x80000000, u32::MAX] {
                let mut input = fixture_header(88);
                let mut payload = value.to_le_bytes().to_vec();
                payload.extend_from_slice(b"tail");
                record(&mut input, kind, &payload);
                let document = parse(&input, &ParseLimits::default()).unwrap();
                assert_eq!(family(document.records()[0].data()), expected_family);
                let encoded = encode(&document).unwrap();
                let mut cursor = prefix(&encoded, [88, 1, 0, 0, 0]);
                cursor.take(112 + 88);
                assert_eq!(cursor.u64(), 0);
                assert_eq!(cursor.u64(), 88);
                assert_eq!(cursor.u64(), 16);
                assert_eq!(cursor.u32(), kind);
                assert_eq!(cursor.u32(), expected_family);
                assert_eq!(cursor.u64(), 4);
                assert_eq!(cursor.u32(), value);
                assert_eq!(cursor.position, encoded.len());
            }
        }
    }

    #[test]
    fn color_and_shape_snapshots_preserve_typed_bytes_without_suffixes() {
        for (kind, expected_family, words) in [
            (24, 16, vec![0xdbff8000u32]),
            (25, 17, vec![0xff7f00ff]),
            (42, 18, vec![0x80000000, 0x7fffffff, 0xffffffff, 0]),
            (43, 19, vec![0x7fffffff, 0x80000000, 0, 0xffffffff]),
            (
                44,
                20,
                vec![
                    0xffffffff, 0, 0x80000000, 0x7fffffff, 0x80000000, 0x7fffffff,
                ],
            ),
        ] {
            let mut input = fixture_header(88);
            let mut payload = words
                .iter()
                .flat_map(|value| value.to_le_bytes())
                .collect::<Vec<_>>();
            payload.extend_from_slice(b"tail");
            record(&mut input, kind, &payload);
            let document = parse(&input, &ParseLimits::default()).unwrap();
            assert_eq!(family(document.records()[0].data()), expected_family);
            let encoded = encode(&document).unwrap();
            let mut cursor = prefix(&encoded, [88, 1, 0, 0, 0]);
            cursor.take(112 + 88);
            assert_eq!(cursor.u64(), 0);
            assert_eq!(cursor.u64(), 88);
            assert_eq!(cursor.u64(), (payload.len() + 8) as u64);
            assert_eq!(cursor.u32(), kind);
            assert_eq!(cursor.u32(), expected_family);
            assert_eq!(cursor.u64(), (words.len() * 4) as u64);
            cursor.words(&words);
            assert_eq!(cursor.position, encoded.len());
        }
    }

    #[test]
    fn fixed_state_snapshots_encode_units_signed_bounds_and_scalars_without_suffixes() {
        for (index, (kind, count)) in [
            (22, 1),
            (33, 0),
            (34, 1),
            (37, 1),
            (40, 1),
            (57, 1),
            (59, 0),
            (60, 0),
            (61, 0),
            (62, 4),
            (63, 4),
            (64, 4),
            (67, 1),
            (68, 0),
        ]
        .into_iter()
        .enumerate()
        {
            let words = &[0x80000000u32, 0x7fffffff, 0xffffffff, 0][..count];
            let mut payload = words
                .iter()
                .flat_map(|value| value.to_le_bytes())
                .collect::<Vec<_>>();
            payload.extend_from_slice(b"opaque");
            let mut input = fixture_header(88);
            record(&mut input, kind, &payload);
            let document = parse(&input, &ParseLimits::default()).unwrap();
            let encoded = encode(&document).unwrap();
            let mut cursor = prefix(&encoded, [88, 1, 0, 0, 0]);
            cursor.take(112 + 88);
            assert_eq!(cursor.u64(), 0);
            assert_eq!(cursor.u64(), 88);
            assert_eq!(cursor.u64(), (payload.len() + 8) as u64);
            assert_eq!(cursor.u32(), kind);
            assert_eq!(cursor.u32(), 21 + index as u32);
            assert_eq!(cursor.u64(), (count * 4) as u64);
            cursor.words(words);
            assert_eq!(cursor.position, encoded.len());
        }
    }

    #[test]
    fn coordinate_families_encode_signed_pairs_without_opaque_suffixes() {
        for (kind, expected_family) in [
            (9, 9),
            (10, 10),
            (11, 11),
            (12, 12),
            (13, 13),
            (26, 14),
            (27, 15),
        ] {
            for values in [[0i32, -1], [i32::MIN, i32::MAX], [i32::MAX, i32::MIN]] {
                let mut input = fixture_header(88);
                let mut payload = values.map(i32::to_le_bytes).concat();
                payload.extend_from_slice(b"tail");
                record(&mut input, kind, &payload);
                let document = parse(&input, &ParseLimits::default()).unwrap();
                assert_eq!(family(document.records()[0].data()), expected_family);
                let encoded = encode(&document).unwrap();
                let mut cursor = prefix(&encoded, [88, 1, 0, 0, 0]);
                cursor.take(112 + 88);
                assert_eq!(cursor.u64(), 0);
                assert_eq!(cursor.u64(), 88);
                assert_eq!(cursor.u64(), 20);
                assert_eq!(cursor.u32(), kind);
                assert_eq!(cursor.u32(), expected_family);
                assert_eq!(cursor.u64(), 8);
                cursor.words(&values.map(|value| value as u32));
                assert_eq!(cursor.position, encoded.len());
            }
        }
    }

    #[test]
    fn encodes_each_family_and_owned_header_and_tail_without_record_padding() {
        let raw_header = fixture_header(88);
        let mut input = raw_header.clone();
        record(&mut input, 0x12345678, &[0xaa, 0xbb, 0xcc, 0xdd]);
        record(&mut input, 17, &[8, 0, 0, 0, 0xee, 0xee, 0xee, 0xee]);
        let polyline = [-1i32, -2, 3, 4, 2, -5, 6, 7, -8]
            .map(i32::to_le_bytes)
            .concat();
        record(&mut input, 4, &polyline);
        record(
            &mut input,
            70,
            &[5, 0, 0, 0, b'E', b'M', b'F', b'+', 0x99, 0xaa, 0xbb, 0xcc],
        );
        record(&mut input, 14, &[0, 0, 0, 0, 16, 0, 0, 0, 20, 0, 0, 0]);
        input.extend_from_slice(b"tail");
        let document = parse(&input, &ParseLimits::default()).unwrap();
        let encoded = encode(&document).unwrap();
        drop(document);
        let mut cursor = prefix(&encoded, [88, 5, 0, 4, 0]);
        cursor.words(&[
            88,
            (-10i32) as u32,
            20,
            30,
            40,
            50,
            60,
            70,
            80,
            0x464d4520,
            0x10000,
            1234,
            99,
            0x1234,
            0x4321,
            3,
            84,
            5,
            640,
            480,
            210,
            297,
            0,
            0,
            0,
            0,
            0,
            0,
        ]);
        assert_eq!(cursor.take(88), raw_header);
        for (index, offset, original_len, kind, family, payload_len) in [
            (0, 88, 12, 0x12345678, 0, 0),
            (1, 100, 16, 17, 2, 4),
            (2, 116, 44, 4, 3, 40),
            (3, 160, 20, 70, 4, 13),
            (4, 180, 20, 14, 1, 12),
        ] {
            assert_eq!(cursor.u64(), index);
            assert_eq!(cursor.u64(), offset);
            assert_eq!(cursor.u64(), original_len);
            cursor.words(&[kind, family]);
            assert_eq!(cursor.u64(), payload_len);
            match family {
                0 => {}
                1 => cursor.words(&[0, 16, 20]),
                2 => cursor.words(&[8]),
                3 => {
                    cursor.words(&[u32::MAX, u32::MAX - 1, 3, 4]);
                    assert_eq!(cursor.u64(), 2);
                    cursor.words(&[(-5i32) as u32, 6, 7, (-8i32) as u32]);
                }
                4 => {
                    assert_eq!(cursor.u64(), 5);
                    assert_eq!(cursor.take(5), b"EMF+\x99");
                }
                _ => unreachable!(),
            }
        }
        assert_eq!(cursor.take(4), b"tail");
        assert_eq!(cursor.position, encoded.len());
    }

    #[test]
    fn optional_header_presence_and_opaque_extensions_are_exact() {
        for (len, presence, optional) in [
            (88, 0, [0, 0, 0, 0, 0]),
            (100, 1, [7, 88, 1, 0, 0]),
            (112, 3, [7, 88, 1, 210000, (-297000i32) as u32]),
        ] {
            let input = fixture_header(len);
            let document = parse(&input, &ParseLimits::default()).unwrap();
            let encoded = encode(&document).unwrap();
            let mut cursor = prefix(&encoded, [len as u64, 0, 0, 0, 0]);
            assert_eq!(cursor.u32(), len as u32);
            cursor.take(84);
            assert_eq!(cursor.u32(), presence);
            cursor.words(&optional);
            assert_eq!(cursor.take(len), input);
            assert_eq!(cursor.position, encoded.len());
        }
    }

    #[test]
    fn malformed_typed_records_stay_raw_and_diagnostic_reasons_preserve_tails() {
        for (tail, kind, has_type, record_type, detail1, detail2) in [
            (vec![1, 2, 3], 1, 0, 0, 3, 0),
            ([99u32, 4].map(u32::to_le_bytes).concat(), 2, 1, 99, 4, 0),
            ([99u32, 24].map(u32::to_le_bytes).concat(), 3, 1, 99, 24, 8),
        ] {
            let mut input = fixture_header(88);
            record(&mut input, 17, &[]);
            input.extend_from_slice(&tail);
            let document = parse(&input, &ParseLimits::default()).unwrap();
            assert_eq!(family(document.records()[0].data()), 0);
            let encoded = encode(&document).unwrap();
            let mut cursor = prefix(&encoded, [88, 1, 2, 0, tail.len() as u64]);
            cursor.take(112 + 88);
            assert_eq!(cursor.u64(), 0);
            assert_eq!(cursor.u64(), 88);
            assert_eq!(cursor.u64(), 8);
            cursor.words(&[17, 0]);
            assert_eq!(cursor.u64(), 0);
            cursor.words(&[4, 1, 17, 0]);
            assert_eq!(cursor.u64(), 88);
            assert_eq!(cursor.u64(), 0);
            assert_eq!(cursor.u64(), 0);
            cursor.words(&[kind, has_type, record_type, 0]);
            assert_eq!(cursor.u64(), 96);
            assert_eq!(cursor.u64(), detail1);
            assert_eq!(cursor.u64(), detail2);
            assert_eq!(cursor.take(tail.len()), tail);
            assert_eq!(cursor.position, encoded.len());
        }
    }

    #[test]
    fn checked_length_addition_reports_overflow() {
        let mut len = usize::MAX;
        assert_eq!(add_len(&mut len, 1), Err(Error::SizeOverflow));
    }
}
