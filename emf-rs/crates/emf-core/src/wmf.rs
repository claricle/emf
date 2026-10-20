//! Bounded standard/placeable WMF parsing with opaque record preservation.
//!
//! Record sizes are measured in 16-bit words on the wire; offsets and spans use
//! bytes. Unsupported and malformed bounded records remain available verbatim.

pub mod bitmap;
pub mod brush;
pub mod dib;
pub mod escape;
pub mod geometry;
pub mod objects;
pub mod region;
pub mod state;
pub mod text;

/// Typed record families. Original bytes remain authoritative until an edit.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum TypedRecord {
    Bitmap(bitmap::BitmapRecord),
    Brush(brush::BrushRecord),
    Escape(escape::EscapeRecord),
    Geometry(geometry::GeometryRecord),
    Region(region::RegionRecord),
    State(state::StateRecord),
    Text(text::TextRecord),
}

pub(crate) enum DecodeError {
    Malformed,
    Resource(crate::ParseFailure),
}

impl From<crate::ParseFailure> for DecodeError {
    fn from(value: crate::ParseFailure) -> Self {
        Self::Resource(value)
    }
}

use crate::limits::{try_vec_with_capacity, Budget};
use crate::reader::{u16_at, u32_at, Reader};
use crate::{
    EditFailure, Format, LimitKind, ParseFailure, ParseLimits, SerializeFailure, SerializeLimits,
};

pub const PLACEABLE_MAGIC: u32 = 0x9AC6_CDD7;
pub const HEADER_BYTES: usize = 18;
pub const PLACEABLE_HEADER_BYTES: usize = 22;
pub const META_EOF: u16 = 0;
const RECORD_HEADER_BYTES: usize = 6;

/// Standard META_HEADER fields, retained as stored rather than normalized.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Header {
    pub file_type: u16,
    /// Header length in 16-bit words (9 for the supported layout).
    pub header_size: u16,
    pub version: u16,
    /// Declared metafile length in words, excluding the placeable header.
    pub size: u32,
    pub num_objects: u16,
    /// Declared largest record length in words.
    pub max_record: u32,
    pub num_parameters: u16,
}

/// Aldus placeable header. Coordinates retain their signed wire values.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PlaceableHeader {
    pub handle: u16,
    pub left: i16,
    pub top: i16,
    pub right: i16,
    pub bottom: i16,
    pub inch: u16,
    pub reserved: u32,
    pub checksum: u16,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Diagnostic {
    pub offset: usize,
    pub function: Option<u16>,
    pub kind: DiagnosticKind,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum DiagnosticKind {
    PlaceableChecksumMismatch {
        expected: u16,
        found: u16,
    },
    TruncatedRecordHead {
        available: usize,
    },
    RecordSizeTooSmall {
        size_words: u32,
    },
    TruncatedRecord {
        claimed: usize,
        available: usize,
    },
    InvalidEof,
    MissingEof,
    /// Record framing is valid, but the recognized payload is malformed.
    MalformedRecord,
    Object(objects::ObjectIssue),
}

/// Original record span plus an optional replacement payload.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Record {
    offset: usize,
    size_words: u32,
    size: usize,
    function: u16,
    replacement: Option<(u16, Vec<u8>)>,
    typed: Option<TypedRecord>,
    consumed: usize,
    object_index: Option<u16>,
}

impl Record {
    pub fn offset(&self) -> usize {
        self.offset
    }
    pub fn size(&self) -> usize {
        self.size
    }
    pub fn size_words(&self) -> u32 {
        self.size_words
    }
    /// Original wire function; replacement fields are used only by serialization.
    pub fn function(&self) -> u16 {
        self.function
    }
    pub fn is_edited(&self) -> bool {
        self.replacement.is_some()
    }
    pub fn typed(&self) -> Option<&TypedRecord> {
        self.typed.as_ref()
    }
    /// Lowest free object slot allocated by this original creator record.
    pub fn object_index(&self) -> Option<u16> {
        self.object_index
    }
    pub fn is_eof(&self) -> bool {
        self.function == META_EOF && self.size_words == 3
    }

    fn output_size(&self) -> Option<usize> {
        match &self.replacement {
            Some((_, body)) => RECORD_HEADER_BYTES.checked_add(body.len()),
            None => Some(self.size),
        }
    }
}

/// One owned copy of the input, with immutable original header/record spans.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Document {
    source: Vec<u8>,
    header: Header,
    placeable: Option<PlaceableHeader>,
    header_offset: usize,
    header_edited: bool,
    placeable_edited: bool,
    records: Vec<Record>,
    diagnostics: Vec<Diagnostic>,
    tail_offset: usize,
}

impl Document {
    pub fn header(&self) -> &Header {
        &self.header
    }
    pub fn placeable_header(&self) -> Option<&PlaceableHeader> {
        self.placeable.as_ref()
    }
    pub fn source(&self) -> &[u8] {
        &self.source
    }
    pub fn records(&self) -> &[Record] {
        &self.records
    }
    pub fn diagnostics(&self) -> &[Diagnostic] {
        &self.diagnostics
    }
    pub fn tail(&self) -> &[u8] {
        &self.source[self.tail_offset..]
    }
    pub fn header_bytes(&self) -> &[u8] {
        &self.source[self.header_offset..self.header_offset + HEADER_BYTES]
    }
    /// Original bytes, including after replacement.
    pub fn record_bytes(&self, record: &Record) -> Option<&[u8]> {
        self.source
            .get(record.offset..record.offset.checked_add(record.size)?)
    }
    pub fn record_body(&self, record: &Record) -> Option<&[u8]> {
        self.record_bytes(record)?.get(RECORD_HEADER_BYTES..)
    }
    /// Whether the original framing reached a valid EOF.
    pub fn has_eof(&self) -> bool {
        self.records.last().is_some_and(Record::is_eof)
    }
    pub fn is_edited(&self) -> bool {
        self.header_edited || self.placeable_edited || self.records.iter().any(Record::is_edited)
    }
    /// Keep the fixed supported header layout; size/max_record refresh on output.
    pub fn set_header(&mut self, header: Header) -> Result<(), EditFailure> {
        if !matches!(header.file_type, 1 | 2) || header.header_size != 9 {
            return Err(EditFailure::HeaderLayout);
        }
        self.header = header;
        self.header_edited = true;
        Ok(())
    }
    /// Replace an existing placeable header; serialization calculates its checksum.
    pub fn set_placeable_header(&mut self, header: PlaceableHeader) -> Result<(), EditFailure> {
        if self.placeable.is_none() {
            return Err(EditFailure::HeaderLayout);
        }
        self.placeable = Some(header);
        self.placeable_edited = true;
        Ok(())
    }
    /// Replace a record without copying its owned body. Reject odd byte lengths
    /// and nonempty EOF payloads; failed edits leave the document unchanged.
    /// This raw edit can change the EOF stopping point when the output is parsed;
    /// original spans and `has_eof` continue to describe the source stream.
    pub fn replace_record(
        &mut self,
        index: usize,
        function: u16,
        body: Vec<u8>,
    ) -> Result<(), EditFailure> {
        let record = self
            .records
            .get_mut(index)
            .ok_or(EditFailure::RecordIndex { index })?;
        if body.len() % 2 != 0 || (function == META_EOF && !body.is_empty()) {
            return Err(EditFailure::RecordLayout { index });
        }
        let size = body
            .len()
            .checked_add(RECORD_HEADER_BYTES)
            .ok_or(EditFailure::SizeOverflow)?;
        u32::try_from(size / 2).map_err(|_| EditFailure::SizeOverflow)?;
        record.replacement = Some((function, body));
        record.typed = None;
        Ok(())
    }

    /// Replace a decoded record of the same wire function, preserving its
    /// original unconsumed suffix. Failed edits leave the document unchanged.
    pub fn replace_typed(&mut self, index: usize, value: TypedRecord) -> Result<(), EditFailure> {
        let record = self
            .records
            .get(index)
            .ok_or(EditFailure::RecordIndex { index })?;
        if record.typed.is_none() {
            return Err(EditFailure::RecordFamily { index });
        }
        let (function, mut body) = match &value {
            TypedRecord::Bitmap(value) => bitmap::encode(value),
            TypedRecord::Brush(value) => brush::encode(value),
            TypedRecord::Escape(value) => escape::encode(value),
            TypedRecord::Geometry(value) => geometry::encode(value),
            TypedRecord::Region(value) => region::encode(value),
            TypedRecord::State(value) => state::encode(value),
            TypedRecord::Text(value) => text::encode(value),
        }
        .map_err(|error| match error {
            EditFailure::RecordLayout { .. } => EditFailure::RecordLayout { index },
            error => error,
        })?;
        if function & 0xff != record.function & 0xff {
            return Err(EditFailure::RecordFamily { index });
        }
        let suffix = self
            .record_body(record)
            .ok_or(EditFailure::RecordLayout { index })?
            .get(record.consumed..)
            .ok_or(EditFailure::RecordLayout { index })?;
        let total = body
            .len()
            .checked_add(suffix.len())
            .ok_or(EditFailure::SizeOverflow)?;
        let bytes = total
            .checked_add(RECORD_HEADER_BYTES)
            .ok_or(EditFailure::SizeOverflow)?;
        if total % 2 != 0 || u32::try_from(bytes / 2).is_err() {
            return Err(EditFailure::SizeOverflow);
        }
        if let TypedRecord::Bitmap(value) = &value {
            if !bitmap::validate_layout(value, record.function, total / 2) {
                return Err(EditFailure::RecordLayout { index });
            }
        }
        body.try_reserve_exact(suffix.len())
            .map_err(|_| EditFailure::SizeOverflow)?;
        body.extend_from_slice(suffix);
        let record = &mut self.records[index];
        record.replacement = Some((record.function, body));
        record.typed = Some(value);
        Ok(())
    }
}

fn decode_typed(
    function: u16,
    body: &[u8],
    budget: &mut Budget<'_>,
) -> Result<Option<(TypedRecord, usize)>, DecodeError> {
    if let Some((value, consumed)) = state::decode(function, body, budget)? {
        return Ok(Some((TypedRecord::State(value), consumed)));
    }
    if let Some((value, consumed)) = geometry::decode(function, body, budget)? {
        return Ok(Some((TypedRecord::Geometry(value), consumed)));
    }
    if let Some((value, consumed)) = text::decode(function, body, budget)? {
        return Ok(Some((TypedRecord::Text(value), consumed)));
    }
    if let Some((value, consumed)) = region::decode(function, body, budget)? {
        return Ok(Some((TypedRecord::Region(value), consumed)));
    }
    if let Some((value, consumed)) = bitmap::decode(function, body, budget)? {
        return Ok(Some((TypedRecord::Bitmap(value), consumed)));
    }
    if let Some((value, consumed)) = escape::decode(function, body, budget)? {
        return Ok(Some((TypedRecord::Escape(value), consumed)));
    }
    Ok(brush::decode(function, body, budget)?
        .map(|(value, consumed)| (TypedRecord::Brush(value), consumed)))
}

/// Decode supported headers and frame records. Bad record framing stops at the
/// offending byte; no resynchronization is attempted. All input is retained.
pub fn parse(input: &[u8], limits: &ParseLimits) -> Result<Document, ParseFailure> {
    let mut budget = Budget::new(limits);
    budget.check_input(input.len())?;
    let mut reader = Reader::new(input);
    let mut diagnostics = Vec::new();
    let placeable = if u32_at(input, 0) == Some(PLACEABLE_MAGIC) {
        budget.check_record_bytes(PLACEABLE_HEADER_BYTES)?;
        budget.charge_record(PLACEABLE_HEADER_BYTES)?;
        reader.u32()?;
        let header = PlaceableHeader {
            handle: reader.u16()?,
            left: reader.u16()? as i16,
            top: reader.u16()? as i16,
            right: reader.u16()? as i16,
            bottom: reader.u16()? as i16,
            inch: reader.u16()?,
            reserved: reader.u32()?,
            checksum: reader.u16()?,
        };
        let expected = checksum(&input[..20]);
        if expected != header.checksum {
            push_diagnostic(
                &mut budget,
                &mut diagnostics,
                0,
                None,
                DiagnosticKind::PlaceableChecksumMismatch {
                    expected,
                    found: header.checksum,
                },
            )?;
        }
        Some(header)
    } else {
        match crate::detect_format(input)? {
            Format::WmfStandard => {}
            other => return Err(ParseFailure::UnsupportedFormat(other)),
        }
        None
    };
    let header_offset = reader.position();
    budget.check_record_bytes(HEADER_BYTES)?;
    budget.charge_record(HEADER_BYTES)?;
    let header = Header {
        file_type: reader.u16()?,
        header_size: reader.u16()?,
        version: reader.u16()?,
        size: reader.u32()?,
        num_objects: reader.u16()?,
        max_record: reader.u32()?,
        num_parameters: reader.u16()?,
    };
    if !matches!(header.file_type, 1 | 2) {
        return Err(ParseFailure::BadHeaderType {
            found: u32::from(header.file_type),
        });
    }
    if header.header_size != 9 {
        return Err(ParseFailure::HeaderSizeTooSmall {
            declared: u32::from(header.header_size) * 2,
            minimum: HEADER_BYTES as u32,
        });
    }
    budget.charge_work((input.len() as u64).div_ceil(16))?;
    budget.charge_alloc(input.len())?;
    let mut source = try_vec_with_capacity(input.len())?;
    source.extend_from_slice(input);
    let mut records = Vec::new();
    let mut found_eof = false;
    let mut objects = objects::ObjectTable::new(header.num_objects);
    while !reader.is_empty() {
        let offset = reader.position();
        let available = reader.remaining();
        if available < RECORD_HEADER_BYTES {
            push_diagnostic(
                &mut budget,
                &mut diagnostics,
                offset,
                None,
                DiagnosticKind::TruncatedRecordHead { available },
            )?;
            break;
        }
        let size_words = u32_at(input, offset).expect("bounded record header");
        let function = u16_at(input, offset + 4).expect("bounded record header");
        if size_words < 3 {
            push_diagnostic(
                &mut budget,
                &mut diagnostics,
                offset,
                Some(function),
                DiagnosticKind::RecordSizeTooSmall { size_words },
            )?;
            break;
        }
        let size = usize::try_from(size_words)
            .ok()
            .and_then(|n| n.checked_mul(2))
            .ok_or(ParseFailure::ArithmeticOverflow { offset })?;
        if size > available {
            push_diagnostic(
                &mut budget,
                &mut diagnostics,
                offset,
                Some(function),
                DiagnosticKind::TruncatedRecord {
                    claimed: size,
                    available,
                },
            )?;
            break;
        }
        budget.check_record_bytes(size)?;
        budget.charge_record(size)?;
        budget.reserve_one(&mut records)?;
        let decoded = match decode_typed(
            function,
            &input[offset + RECORD_HEADER_BYTES..offset + size],
            &mut budget,
        ) {
            Ok(decoded) => decoded,
            Err(DecodeError::Malformed) => {
                push_diagnostic(
                    &mut budget,
                    &mut diagnostics,
                    offset,
                    Some(function),
                    DiagnosticKind::MalformedRecord,
                )?;
                None
            }
            Err(DecodeError::Resource(error)) => return Err(error),
        };
        let (typed, consumed) = match decoded {
            Some((value, consumed)) => (Some(value), consumed),
            None => (None, 0),
        };
        let (object_index, issues) = objects.apply(
            function,
            &input[offset + RECORD_HEADER_BYTES..offset + size],
            &mut budget,
        )?;
        for issue in issues.into_iter().flatten() {
            push_diagnostic(
                &mut budget,
                &mut diagnostics,
                offset,
                Some(function),
                DiagnosticKind::Object(issue),
            )?;
        }
        reader.skip(size)?;
        records.push(Record {
            offset,
            size_words,
            size,
            function,
            replacement: None,
            typed,
            consumed,
            object_index,
        });
        if function == META_EOF {
            if size_words == 3 {
                found_eof = true;
                break;
            }
            push_diagnostic(
                &mut budget,
                &mut diagnostics,
                offset,
                Some(function),
                DiagnosticKind::InvalidEof,
            )?;
        }
    }
    let tail_offset = reader.position();
    if !found_eof {
        push_diagnostic(
            &mut budget,
            &mut diagnostics,
            tail_offset,
            None,
            DiagnosticKind::MissingEof,
        )?;
    }
    Ok(Document {
        source,
        header,
        placeable,
        header_offset,
        header_edited: false,
        placeable_edited: false,
        records,
        diagnostics,
        tail_offset,
    })
}

fn push_diagnostic(
    budget: &mut Budget<'_>,
    diagnostics: &mut Vec<Diagnostic>,
    offset: usize,
    function: Option<u16>,
    kind: DiagnosticKind,
) -> Result<(), ParseFailure> {
    budget.reserve_one(diagnostics)?;
    diagnostics.push(Diagnostic {
        offset,
        function,
        kind,
    });
    Ok(())
}

pub fn serialize(document: &Document) -> Result<Vec<u8>, SerializeFailure> {
    serialize_with_limits(document, &SerializeLimits::default())
}

/// Bound output/work before reserving or copying. Any edit refreshes the standard
/// header's size and largest-record words, excluding placeable and tail bytes.
/// Only a placeable edit refreshes its checksum; untouched damage stays exact.
pub fn serialize_with_limits(
    document: &Document,
    limits: &SerializeLimits,
) -> Result<Vec<u8>, SerializeFailure> {
    let mut total = document
        .header_offset
        .checked_add(HEADER_BYTES)
        .ok_or(SerializeFailure::SizeOverflow)?;
    let mut next = total;
    let mut max_record = 0;
    let mut work = if document.placeable.is_some() {
        4u64
    } else {
        2u64
    };
    check_limit(LimitKind::WorkUnits, limits.max_work_units, work)?;
    for record in &document.records {
        work = work.checked_add(2).ok_or(SerializeFailure::SizeOverflow)?;
        check_limit(LimitKind::WorkUnits, limits.max_work_units, work)?;
        if record.offset != next || document.record_bytes(record).is_none() {
            return Err(SerializeFailure::Inconsistent { offset: next });
        }
        next = next
            .checked_add(record.size)
            .ok_or(SerializeFailure::SizeOverflow)?;
        let size = record.output_size().ok_or(SerializeFailure::SizeOverflow)?;
        let words = u32::try_from(size / 2).map_err(|_| SerializeFailure::SizeOverflow)?;
        max_record = max_record.max(words);
        total = total
            .checked_add(size)
            .ok_or(SerializeFailure::SizeOverflow)?;
    }
    if next != document.tail_offset {
        return Err(SerializeFailure::Inconsistent { offset: next });
    }
    let edited = document.is_edited();
    let size_words = if edited {
        u32::try_from((total - document.header_offset) / 2)
            .map_err(|_| SerializeFailure::SizeOverflow)?
    } else {
        document.header.size
    };
    total = total
        .checked_add(document.tail().len())
        .ok_or(SerializeFailure::SizeOverflow)?;
    check_limit(
        LimitKind::OutputBytes,
        limits.max_output_bytes as u64,
        total as u64,
    )?;
    work = work
        .checked_add((total as u64).div_ceil(16))
        .ok_or(SerializeFailure::SizeOverflow)?;
    check_limit(LimitKind::WorkUnits, limits.max_work_units, work)?;
    let mut out = Vec::new();
    out.try_reserve_exact(total)
        .map_err(|_| SerializeFailure::AllocationFailed { bytes: total })?;
    out.extend_from_slice(&document.source[..document.header_offset + HEADER_BYTES]);
    if document.placeable_edited {
        write_placeable(
            &mut out[..PLACEABLE_HEADER_BYTES],
            document
                .placeable
                .as_ref()
                .expect("existing placeable header"),
        );
    }
    if document.header_edited {
        write_header(&mut out[document.header_offset..], &document.header);
    }
    if edited {
        let offset = document.header_offset;
        out[offset + 6..offset + 10].copy_from_slice(&size_words.to_le_bytes());
        out[offset + 12..offset + 16].copy_from_slice(&max_record.to_le_bytes());
    }
    for record in &document.records {
        if let Some((function, body)) = &record.replacement {
            let size = record.output_size().ok_or(SerializeFailure::SizeOverflow)?;
            let words = u32::try_from(size / 2).map_err(|_| SerializeFailure::SizeOverflow)?;
            out.extend_from_slice(&words.to_le_bytes());
            out.extend_from_slice(&function.to_le_bytes());
            out.extend_from_slice(body);
        } else {
            out.extend_from_slice(document.record_bytes(record).ok_or(
                SerializeFailure::Inconsistent {
                    offset: record.offset,
                },
            )?);
        }
    }
    out.extend_from_slice(document.tail());
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

fn write_header(out: &mut [u8], header: &Header) {
    out[0..2].copy_from_slice(&header.file_type.to_le_bytes());
    out[2..4].copy_from_slice(&header.header_size.to_le_bytes());
    out[4..6].copy_from_slice(&header.version.to_le_bytes());
    out[6..10].copy_from_slice(&header.size.to_le_bytes());
    out[10..12].copy_from_slice(&header.num_objects.to_le_bytes());
    out[12..16].copy_from_slice(&header.max_record.to_le_bytes());
    out[16..18].copy_from_slice(&header.num_parameters.to_le_bytes());
}

fn write_placeable(out: &mut [u8], header: &PlaceableHeader) {
    out[..4].copy_from_slice(&PLACEABLE_MAGIC.to_le_bytes());
    for (offset, value) in [
        (4, header.handle),
        (6, header.left as u16),
        (8, header.top as u16),
        (10, header.right as u16),
        (12, header.bottom as u16),
        (14, header.inch),
    ] {
        out[offset..offset + 2].copy_from_slice(&value.to_le_bytes());
    }
    out[16..20].copy_from_slice(&header.reserved.to_le_bytes());
    let checksum = checksum(&out[..20]);
    out[20..22].copy_from_slice(&checksum.to_le_bytes());
}

fn checksum(bytes: &[u8]) -> u16 {
    bytes
        .chunks_exact(2)
        .fold(0, |sum, word| sum ^ u16::from_le_bytes([word[0], word[1]]))
}
