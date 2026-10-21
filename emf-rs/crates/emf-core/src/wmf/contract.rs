//! First rejection under the Ruby WMF contract, with the codec and reason that produced it.
//!
//! `wmf::parse` recovers past malformed records and reports them as diagnostics; the Ruby contract stops at the
//! first failure in a fixed order: placeable, standard header, record framing and per-codec payloads in stream
//! order, the object table, then the largest-record check. This module walks the same phases without building
//! a document and names the first failure. It reports data only (codec, reason, offset, function, one number);
//! the wording belongs to the caller. `None` means the contract accepts the input.

/// Largest input the contract accepts by default.
pub const MAX_INPUT_BYTES: usize = 200 * 1024 * 1024;
/// Most records the contract accepts by default.
pub const MAX_RECORDS: usize = 1_000_000;

/// The contract's two numeric limits. The caller owns them (Ruby's `Wmf::Binary` constants), so they are
/// arguments rather than copies that could drift.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Limits {
    pub max_input_bytes: usize,
    pub max_records: usize,
}

impl Default for Limits {
    fn default() -> Self {
        Self {
            max_input_bytes: MAX_INPUT_BYTES,
            max_records: MAX_RECORDS,
        }
    }
}

const PLACEABLE_BYTES: usize = 22;
const HEADER_BYTES: usize = 18;
const OBJECT_CREATORS: [u8; 7] = [0xFA, 0xFC, 0xFB, 0xF7, 0xF9, 0xFF, 0x42];

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[repr(u32)]
pub enum Codec {
    Input = 1,
    Placeable = 2,
    Header = 3,
    Framing = 4,
    Fixed = 5,
    State = 6,
    Font = 7,
    Object = 8,
    PointArray = 9,
    Text = 10,
    Palette = 11,
    Region = 12,
    Brush = 13,
    Bitmap = 14,
    Geometry = 15,
    DcEscape = 16,
    ObjectTable = 17,
    MaxRecord = 18,
}

/// Stable reason codes: `codec * 100 + n`. Never renumber; append only.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[repr(u32)]
pub enum Reason {
    InputTooLarge = 101,
    PlaceableTruncated = 201,
    PlaceableReserved = 202,
    PlaceableChecksum = 203,
    HeaderTruncated = 301,
    HeaderType = 302,
    HeaderSize = 303,
    HeaderVersion = 304,
    HeaderFileSize = 305,
    HeaderPlaceableHandle = 306,
    RecordLimit = 401,
    TruncatedRecordHeader = 402,
    /// `detail` is the declared length in words.
    InvalidRecordLength = 403,
    DataAfterEof = 404,
    MissingEof = 405,
    InvalidEofLength = 406,
    FixedLength = 501,
    StateLength = 601,
    FontLength = 701,
    ObjectLength = 801,
    PointMissingCount = 901,
    PointTruncatedCounts = 902,
    PointInvalidCount = 903,
    PointLengthMismatch = 904,
    TextTruncated = 1001,
    TextTruncatedRectangle = 1002,
    TextNegativeLength = 1003,
    TextTruncatedString = 1004,
    TextTruncatedSpacing = 1005,
    PaletteTruncatedPrefix = 1101,
    PaletteTruncatedEntries = 1102,
    RegionTruncatedPrefix = 1201,
    RegionTruncatedHeader = 1202,
    RegionInvalidHeader = 1203,
    RegionTruncatedScan = 1204,
    RegionInvalidScan = 1205,
    RegionInvalidScanSize = 1206,
    BrushTruncatedPattern = 1301,
    BrushInvalidPatternExtent = 1302,
    BrushTruncatedDib = 1303,
    BrushInvalidDibUsage = 1304,
    BitmapTruncatedPrefix = 1401,
    BitmapEmptySource = 1402,
    GeometryTruncatedPrefix = 1501,
    GeometryInvalidFloodMode = 1502,
    DcRestoreTruncated = 1601,
    DcEscapeTruncatedPrefix = 1602,
    DcEscapeTruncatedData = 1603,
    ObjectCapacity = 1701,
    /// `detail` is the referenced index.
    ObjectInvalidReference = 1702,
    ObjectNotPalette = 1703,
    ObjectNotRegion = 1704,
    ObjectInvalidRegion = 1705,
    ObjectInvalidBrush = 1706,
    ObjectNotBrush = 1707,
    MaxRecordMismatch = 1801,
}

impl Reason {
    pub fn codec(self) -> Codec {
        match self as u32 / 100 {
            1 => Codec::Input,
            2 => Codec::Placeable,
            3 => Codec::Header,
            4 => Codec::Framing,
            5 => Codec::Fixed,
            6 => Codec::State,
            7 => Codec::Font,
            8 => Codec::Object,
            9 => Codec::PointArray,
            10 => Codec::Text,
            11 => Codec::Palette,
            12 => Codec::Region,
            13 => Codec::Brush,
            14 => Codec::Bitmap,
            15 => Codec::Geometry,
            16 => Codec::DcEscape,
            17 => Codec::ObjectTable,
            _ => Codec::MaxRecord,
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Rejection {
    pub reason: Reason,
    /// Byte offset the contract reports; absent for whole-input failures.
    pub offset: Option<usize>,
    /// Record function the contract reports; absent when no record is involved.
    pub function: Option<u16>,
    pub detail: u64,
}

impl Rejection {
    pub fn codec(&self) -> Codec {
        self.reason.codec()
    }

    fn whole(reason: Reason) -> Self {
        Self {
            reason,
            offset: None,
            function: None,
            detail: 0,
        }
    }

    fn at(reason: Reason, offset: usize, function: Option<u16>) -> Self {
        Self {
            reason,
            offset: Some(offset),
            function,
            detail: 0,
        }
    }

    fn with_detail(mut self, detail: u64) -> Self {
        self.detail = detail;
        self
    }
}

fn le16(bytes: &[u8], at: usize) -> u16 {
    u16::from_le_bytes([bytes[at], bytes[at + 1]])
}

fn le32(bytes: &[u8], at: usize) -> u32 {
    u32::from_le_bytes([bytes[at], bytes[at + 1], bytes[at + 2], bytes[at + 3]])
}

/// The contract's first rejection of `input`, or `None` when the contract accepts it.
pub fn first_rejection(input: &[u8], limits: &Limits) -> Option<Rejection> {
    check(input, limits).err()
}

struct Header {
    size_words: u32,
    objects: u16,
    max_record: u32,
}

/// A record the object-table phase must revisit.
struct Tracked {
    offset: usize,
    function: u16,
    first: u16,
    second: u16,
}

fn check(input: &[u8], limits: &Limits) -> Result<(), Rejection> {
    if input.len() > limits.max_input_bytes {
        return Err(Rejection::whole(Reason::InputTooLarge));
    }
    let (placeable, start) = placeable(input)?;
    let header = header(input, start, placeable)?;
    let limit = start + header.size_words as usize * 2;
    let (tracked, largest) = records(input, start + HEADER_BYTES, limit, limits.max_records)?;
    object_table(&tracked, usize::from(header.objects))?;
    if header.max_record as usize != largest {
        return Err(Rejection::whole(Reason::MaxRecordMismatch));
    }
    Ok(())
}

/// Returns the placeable handle (when present) and the standard header's offset.
fn placeable(input: &[u8]) -> Result<(Option<u16>, usize), Rejection> {
    if input.len() < 4 || le32(input, 0) != super::PLACEABLE_MAGIC {
        return Ok((None, 0));
    }
    if input.len() < PLACEABLE_BYTES {
        return Err(Rejection::whole(Reason::PlaceableTruncated));
    }
    if le32(input, 16) != 0 {
        return Err(Rejection::whole(Reason::PlaceableReserved));
    }
    let sum = (0..10).fold(0u16, |sum, word| sum ^ le16(input, word * 2));
    if le16(input, 20) != sum {
        return Err(Rejection::whole(Reason::PlaceableChecksum));
    }
    Ok((Some(le16(input, 4)), PLACEABLE_BYTES))
}

fn header(input: &[u8], start: usize, placeable: Option<u16>) -> Result<Header, Rejection> {
    if input.len() - start < HEADER_BYTES {
        return Err(Rejection::whole(Reason::HeaderTruncated));
    }
    let kind = le16(input, start);
    let size = le32(input, start + 6);
    if !matches!(kind, 1 | 2) {
        return Err(Rejection::whole(Reason::HeaderType));
    }
    if le16(input, start + 2) != 9 {
        return Err(Rejection::whole(Reason::HeaderSize));
    }
    if !matches!(le16(input, start + 4), 0x100 | 0x300) {
        return Err(Rejection::whole(Reason::HeaderVersion));
    }
    if size < 9 || size as usize > (input.len() - start) / 2 {
        return Err(Rejection::whole(Reason::HeaderFileSize));
    }
    if kind == 2 && placeable.is_some_and(|handle| handle != 0) {
        return Err(Rejection::whole(Reason::HeaderPlaceableHandle));
    }
    Ok(Header {
        size_words: size,
        objects: le16(input, start + 10),
        max_record: le32(input, start + 12),
    })
}

fn records(
    input: &[u8],
    mut offset: usize,
    limit: usize,
    max_records: usize,
) -> Result<(Vec<Tracked>, usize), Rejection> {
    let mut tracked = Vec::new();
    let mut count = 0usize;
    let mut largest = 0usize;
    while offset < limit {
        if count >= max_records {
            return Err(Rejection::at(Reason::RecordLimit, offset, None));
        }
        if limit - offset < 6 {
            return Err(Rejection::at(Reason::TruncatedRecordHeader, offset, None));
        }
        let words = le32(input, offset) as usize;
        let function = le16(input, offset + 4);
        if words < 3 || words > (limit - offset) / 2 {
            return Err(
                Rejection::at(Reason::InvalidRecordLength, offset, Some(function))
                    .with_detail(words as u64),
            );
        }
        let raw = &input[offset..offset + words * 2];
        decode(raw, function, offset)?;
        let low = function as u8;
        if OBJECT_CREATORS.contains(&low)
            || matches!(low, 0x28 | 0x29 | 0x2A | 0x2B | 0x2C | 0x2D | 0xF0 | 0x34)
        {
            tracked.push(Tracked {
                offset,
                function,
                first: if raw.len() >= 8 { le16(raw, 6) } else { 0 },
                second: if raw.len() >= 10 { le16(raw, 8) } else { 0 },
            });
        }
        count += 1;
        largest = largest.max(words);
        offset += raw.len();
        if function == 0 {
            if offset != limit {
                return Err(Rejection::at(Reason::DataAfterEof, offset, Some(function)));
            }
            return Ok((tracked, largest));
        }
    }
    Err(Rejection::at(Reason::MissingEof, offset, None))
}

fn decode(raw: &[u8], function: u16, offset: usize) -> Result<(), Rejection> {
    let fail = |reason| Err(Rejection::at(reason, offset, Some(function)));
    if function == 0 {
        return if raw.len() == 6 {
            Ok(())
        } else {
            fail(Reason::InvalidEofLength)
        };
    }
    let low = function as u8;
    match low {
        0xFB => {
            if raw.len() < 6 + 50 {
                return fail(Reason::FontLength);
            }
        }
        0x01 | 0x31 | 0x09 | 0x0A | 0x49 | 0x02 | 0x03 | 0x06 | 0x04 | 0x07 | 0x2E | 0x08 => {
            let payload = if matches!(low, 0x01 | 0x31 | 0x09 | 0x0A | 0x49) {
                4
            } else {
                2
            };
            if raw.len() < 6 + payload {
                return fail(Reason::StateLength);
            }
        }
        0xF7 | 0x37 | 0x36 | 0x34 | 0x39 | 0x35 => return palette(raw, low, offset, function),
        0xFF | 0x28 | 0x29 | 0x2A | 0x2B | 0x2C | 0x20 | 0x15 | 0x16 => {
            return region(raw, low, offset, function)
        }
        0xF9 | 0x42 => return brush(raw, low, offset, function),
        0x22 | 0x40 | 0x23 | 0x41 | 0x33 | 0x43 => return bitmap(raw, function, offset),
        0x10 | 0x12 | 0x19 | 0x1F | 0x48 | 0x1D => return geometry(raw, low, offset, function),
        0x1E | 0x27 | 0x05 | 0x26 => return dc_escape(raw, low, offset, function),
        0xFA | 0xFC | 0x2D | 0xF0 => {
            let payload = match low {
                0xFA => 10,
                0xFC => 8,
                _ => 2,
            };
            if raw.len() != 6 + payload {
                return fail(Reason::ObjectLength);
            }
        }
        0x21 | 0x32 => return text(raw, low == 0x32, offset, function),
        0x24 | 0x25 | 0x38 => return point_array(raw, low, offset, function),
        0x14 | 0x13 | 0x0B | 0x0C | 0x0D | 0x0E | 0x0F | 0x11 | 0x17 | 0x18 | 0x1A | 0x1B
        | 0x1C | 0x30 => {
            let words = match low {
                0x17 | 0x1A | 0x30 => 8,
                0x1C => 6,
                0x18 | 0x1B => 4,
                _ => 2,
            };
            if raw.len() != 6 + words * 2 {
                return fail(Reason::FixedLength);
            }
        }
        _ => {}
    }
    Ok(())
}

fn point_array(raw: &[u8], low: u8, offset: usize, function: u16) -> Result<(), Rejection> {
    let fail = |reason| Err(Rejection::at(reason, offset, Some(function)));
    if raw.len() < 8 {
        return fail(Reason::PointMissingCount);
    }
    let (points_start, point_count) = if low == 0x38 {
        let polygons = usize::from(le16(raw, 6));
        let start = 8 + polygons * 2;
        if raw.len() < start {
            return fail(Reason::PointTruncatedCounts);
        }
        let total: u64 = (0..polygons).map(|n| u64::from(le16(raw, 8 + n * 2))).sum();
        (start, total as i64)
    } else {
        let count = i64::from(le16(raw, 6) as i16);
        let minimum = if low == 0x24 { 2 } else { 0 };
        if count < minimum {
            return fail(Reason::PointInvalidCount);
        }
        (8, count)
    };
    if raw.len() as i64 != points_start as i64 + point_count * 4 {
        return fail(Reason::PointLengthMismatch);
    }
    Ok(())
}

fn text(raw: &[u8], extended: bool, offset: usize, function: u16) -> Result<(), Rejection> {
    let fail = |reason| Err(Rejection::at(reason, offset, Some(function)));
    if raw.len() < if extended { 14 } else { 12 } {
        return fail(Reason::TextTruncated);
    }
    let (count, mut start) = if extended {
        (i64::from(le16(raw, 10) as i16), 14usize)
    } else {
        (i64::from(le16(raw, 6) as i16), 8usize)
    };
    if extended && le16(raw, 12) & 6 != 0 {
        if raw.len() < start + 8 {
            return fail(Reason::TextTruncatedRectangle);
        }
        start += 8;
    }
    if count < 0 {
        return fail(Reason::TextNegativeLength);
    }
    let count = count as usize;
    let finish = start + count + count % 2;
    if raw.len() < finish + if extended { 0 } else { 4 } {
        return fail(Reason::TextTruncatedString);
    }
    if extended {
        let remaining = raw.len() - finish;
        if remaining > 0 && count > 0 && remaining < count * 2 {
            return fail(Reason::TextTruncatedSpacing);
        }
    }
    Ok(())
}

fn palette(raw: &[u8], low: u8, offset: usize, function: u16) -> Result<(), Rejection> {
    let fail = |reason| Err(Rejection::at(reason, offset, Some(function)));
    match low {
        0xF7 | 0x37 | 0x36 => {
            if raw.len() < 10 {
                return fail(Reason::PaletteTruncatedPrefix);
            }
            if raw.len() < 10 + usize::from(le16(raw, 8)) * 4 {
                return fail(Reason::PaletteTruncatedEntries);
            }
        }
        0x34 | 0x39 if raw.len() < 8 => return fail(Reason::PaletteTruncatedPrefix),
        _ => {}
    }
    Ok(())
}

fn region(raw: &[u8], low: u8, offset: usize, function: u16) -> Result<(), Rejection> {
    let fail = |reason| Err(Rejection::at(reason, offset, Some(function)));
    let size = match low {
        0xFF => return region_body(&raw[6..], offset, function),
        0x28 | 0x20 => 4,
        0x29 | 0x15 | 0x16 => 8,
        _ => 2,
    };
    if raw.len() < 6 + size {
        return fail(Reason::RegionTruncatedPrefix);
    }
    Ok(())
}

fn region_body(body: &[u8], offset: usize, function: u16) -> Result<(), Rejection> {
    let fail = |reason| Err(Rejection::at(reason, offset, Some(function)));
    if body.len() < 22 {
        return fail(Reason::RegionTruncatedHeader);
    }
    let kind = le16(body, 2);
    let size = i64::from(le16(body, 8) as i16);
    let count = i64::from(le16(body, 10) as i16);
    let max_scan = i64::from(le16(body, 12) as i16);
    if kind != 6
        || size < 22
        || size > body.len() as i64
        || count < 0
        || max_scan < 0
        || count > (size - 22) / 8
    {
        return fail(Reason::RegionInvalidHeader);
    }
    let size = size as usize;
    let (mut cursor, mut observed) = (22usize, 0usize);
    for _ in 0..count {
        if size - cursor < 8 {
            return fail(Reason::RegionTruncatedScan);
        }
        let points = usize::from(le16(body, cursor));
        let scan = 8 + points * 2;
        if points % 2 == 1
            || scan > size - cursor
            || usize::from(le16(body, cursor + scan - 2)) != points
        {
            return fail(Reason::RegionInvalidScan);
        }
        observed = observed.max(points);
        cursor += scan;
    }
    if cursor != size || observed as i64 != max_scan {
        return fail(Reason::RegionInvalidScanSize);
    }
    Ok(())
}

fn brush(raw: &[u8], low: u8, offset: usize, function: u16) -> Result<(), Rejection> {
    let fail = |reason| Err(Rejection::at(reason, offset, Some(function)));
    if low == 0xF9 {
        if raw.len() < 38 {
            return fail(Reason::BrushTruncatedPattern);
        }
        let width = i64::from(le16(raw, 8) as i16);
        let height = i64::from(le16(raw, 10) as i16);
        let (planes, bits) = (i64::from(raw[14]), i64::from(raw[15]));
        let length = (width > 0 && height > 0 && planes == 1 && bits > 0)
            .then(|| ((width * bits + 15) / 16) * 2 * height);
        if !length.is_some_and(|length| length <= raw.len() as i64 - 38) {
            return fail(Reason::BrushInvalidPatternExtent);
        }
    } else {
        if raw.len() < 12 {
            return fail(Reason::BrushTruncatedDib);
        }
        if le16(raw, 6) != 3 && le16(raw, 8) > 2 {
            return fail(Reason::BrushInvalidDibUsage);
        }
    }
    Ok(())
}

fn bitmap(raw: &[u8], function: u16, offset: usize) -> Result<(), Rejection> {
    let fail = |reason| Err(Rejection::at(reason, offset, Some(function)));
    let kind = function as u8;
    let optional = matches!(kind, 0x22 | 0x40 | 0x23 | 0x41);
    let absent = optional && (raw.len() - 6) / 2 == usize::from(function >> 8);
    // Field widths in bytes, with the reserved word counted only when it is on the wire.
    let length = match kind {
        0x22 | 0x40 if absent => 18,
        0x22 | 0x40 => 16,
        0x23 | 0x41 if absent => 22,
        0x23 | 0x41 => 20,
        0x33 => 18,
        _ => 22,
    };
    if raw.len() < 6 + length {
        return fail(Reason::BitmapTruncatedPrefix);
    }
    if !absent && raw.len() <= 6 + length {
        return fail(Reason::BitmapEmptySource);
    }
    Ok(())
}

fn geometry(raw: &[u8], low: u8, offset: usize, function: u16) -> Result<(), Rejection> {
    let fail = |reason| Err(Rejection::at(reason, offset, Some(function)));
    let payload = match low {
        0x10 | 0x12 | 0x19 | 0x1F => 8,
        0x48 => 10,
        _ => 12,
    };
    if raw.len() < 6 + payload {
        return fail(Reason::GeometryTruncatedPrefix);
    }
    if low == 0x48 && le16(raw, 6) > 1 {
        return fail(Reason::GeometryInvalidFloodMode);
    }
    Ok(())
}

fn dc_escape(raw: &[u8], low: u8, offset: usize, function: u16) -> Result<(), Rejection> {
    let fail = |reason| Err(Rejection::at(reason, offset, Some(function)));
    match low {
        0x27 if raw.len() < 8 => fail(Reason::DcRestoreTruncated),
        0x26 if raw.len() < 10 => fail(Reason::DcEscapeTruncatedPrefix),
        0x26 => {
            let count = usize::from(le16(raw, 8));
            if raw.len() < 10 + count + count % 2 {
                return fail(Reason::DcEscapeTruncatedData);
            }
            Ok(())
        }
        _ => Ok(()),
    }
}

/// Mirrors the contract's object-table walk: creators take the lowest free slot, references must name a live
/// slot of the right kind, deletes free their slot.
fn object_table(records: &[Tracked], capacity: usize) -> Result<(), Rejection> {
    let mut slots: Vec<Option<u8>> = vec![None; capacity];
    let mut lowest_free = 0usize;
    for record in records {
        let low = record.function as u8;
        let fail = |reason, detail: u64| {
            Err(Rejection::at(reason, record.offset, Some(record.function)).with_detail(detail))
        };
        if OBJECT_CREATORS.contains(&low) {
            let Some(index) = (lowest_free..capacity).find(|&index| slots[index].is_none()) else {
                return fail(Reason::ObjectCapacity, 0);
            };
            slots[index] = Some(low);
            lowest_free = index + 1;
        } else if matches!(low, 0x28 | 0x29) {
            let (region, brush) = (usize::from(record.first), usize::from(record.second));
            if region >= capacity || slots[region].is_none() {
                return fail(Reason::ObjectInvalidRegion, region as u64);
            }
            if slots[region] != Some(0xFF) {
                return fail(Reason::ObjectNotRegion, region as u64);
            }
            if brush >= capacity || slots[brush].is_none() {
                return fail(Reason::ObjectInvalidBrush, brush as u64);
            }
            if !matches!(slots[brush], Some(0xFC | 0xF9 | 0x42)) {
                return fail(Reason::ObjectNotBrush, brush as u64);
            }
        } else if matches!(low, 0x2A | 0x2B | 0x2C | 0x2D | 0xF0 | 0x34) {
            let index = usize::from(record.first);
            // High-bit stock selectors are preserved without interpretation.
            if low == 0x2D && index & 0x8000 != 0 {
                continue;
            }
            if index >= capacity || slots[index].is_none() {
                return fail(Reason::ObjectInvalidReference, index as u64);
            }
            if low == 0x34 && slots[index] != Some(0xF7) {
                return fail(Reason::ObjectNotPalette, index as u64);
            }
            if matches!(low, 0x2A..=0x2C) && slots[index] != Some(0xFF) {
                return fail(Reason::ObjectNotRegion, index as u64);
            }
            if low == 0xF0 {
                slots[index] = None;
                lowest_free = lowest_free.min(index);
            }
        }
    }
    Ok(())
}
