use super::Error;

/// A logical stream plus original comment payload lengths. Records may cross segments.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Stream {
    pub records: Vec<Record>,
    pub(crate) segment_lengths: Vec<usize>,
}
impl Stream {
    pub fn segment_lengths(&self) -> &[usize] {
        &self.segment_lengths
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Header {
    /// Raw GraphicsVersion bits, including the graphics signature and version.
    pub version: u32,
    pub emf_plus_flags: u32,
    pub logical_dpi_x: u32,
    pub logical_dpi_y: u32,
}

/// Floating values are IEEE-754 *bits*, preserving NaN payloads and signed zero.
/// Record flags (including ignored/reserved bits) are retained separately.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum RecordData {
    Header(Header),
    /// Arbitrary private bytes; ignored flags are retained. Data is four-byte aligned.
    Comment(Vec<u8>),
    Drawing(super::Drawing),
    Text(super::Text),
    Effect(super::Effect),
    TSGraphics(super::TSGraphics),
    TSClip(super::TSClip),
    Empty,
    Clear {
        argb: u32,
    },
    RenderingOrigin {
        x: i32,
        y: i32,
    },
    StackIndex(u32),
    BeginContainer {
        destination: [u32; 4],
        source: [u32; 4],
        stack_index: u32,
    },
    Matrix([u32; 6]),
    Pair([u32; 2]),
    Scalar(u32),
    ClipRect([u32; 4]),
    /// Known unsupported families and unknown records remain visibly opaque.
    Object(super::ObjectFragment),
    Opaque(Vec<u8>),
}
impl RecordData {
    pub(crate) fn element_work(&self) -> u64 {
        match self {
            Self::Drawing(d) => d.element_work(),
            Self::Text(t) => t.element_work(),
            Self::Effect(e) => e.element_work(),
            Self::TSGraphics(g) => g.element_work(),
            Self::TSClip(c) => c.rectangles.len() as u64,
            _ => 0,
        }
    }
    pub(crate) fn len(&self) -> usize {
        match self {
            Self::Drawing(d) => d.len(),
            Self::Text(t) => t.len(),
            Self::Effect(e) => e.len(),
            Self::TSGraphics(g) => g.len(),
            Self::TSClip(c) => c.len(),
            Self::Header(_) | Self::ClipRect(_) => 16,
            Self::Empty => 0,
            Self::Clear { .. } | Self::StackIndex(_) | Self::Scalar(_) => 4,
            Self::RenderingOrigin { .. } | Self::Pair(_) => 8,
            Self::BeginContainer { .. } => 36,
            Self::Matrix(_) => 24,
            Self::Object(v) => v.bytes.len() + if v.total_size.is_some() { 4 } else { 0 },
            Self::Comment(v) | Self::Opaque(v) => v.len(),
        }
    }
    pub(crate) fn write(&self, out: &mut Vec<u8>) {
        fn words(out: &mut Vec<u8>, values: &[u32]) {
            for value in values {
                out.extend_from_slice(&value.to_le_bytes());
            }
        }
        match self {
            Self::Drawing(d) => d.write(out),
            Self::Text(t) => t.write(out),
            Self::Effect(e) => e.write(out),
            Self::TSGraphics(g) => g.write(out),
            Self::TSClip(c) => c.write(out),
            Self::Header(h) => words(
                out,
                &[
                    h.version,
                    h.emf_plus_flags,
                    h.logical_dpi_x,
                    h.logical_dpi_y,
                ],
            ),
            Self::Empty => (),
            Self::Clear { argb } => words(out, &[*argb]),
            Self::RenderingOrigin { x, y } => words(out, &[*x as u32, *y as u32]),
            Self::StackIndex(v) | Self::Scalar(v) => words(out, &[*v]),
            Self::BeginContainer {
                destination,
                source,
                stack_index,
            } => {
                words(out, destination);
                words(out, source);
                words(out, &[*stack_index]);
            }
            Self::Matrix(v) => words(out, v),
            Self::Pair(v) => words(out, v),
            Self::ClipRect(v) => words(out, v),
            Self::Object(v) => {
                if let Some(total) = v.total_size {
                    words(out, &[total]);
                }
                out.extend_from_slice(&v.bytes);
            }
            Self::Comment(v) | Self::Opaque(v) => out.extend_from_slice(v),
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Record {
    pub record_type: u16,
    pub flags: u16,
    pub data: RecordData,
    /// Bytes between DataSize and Size, retained exactly even when nonzero.
    pub padding: Vec<u8>,
}
impl Record {
    pub fn is_dual(&self) -> bool {
        self.record_type == 0x4001 && self.flags & 1 != 0
    }
    pub fn post_multiplied(&self) -> bool {
        self.flags & 0x2000 != 0
    }
    pub(crate) fn validate(&self, offset: usize) -> Result<(), Error> {
        if let RecordData::Comment(bytes) = &self.data {
            return if self.record_type == 0x4003 && bytes.len() % 4 == 0 && self.padding.is_empty()
            {
                Ok(())
            } else {
                Err(Error::InvalidRecord {
                    offset,
                    reason: "invalid Comment type/layout",
                })
            };
        }
        if let RecordData::TSClip(c) = &self.data {
            return if c.valid(self.record_type, self.flags) {
                Ok(())
            } else {
                Err(Error::InvalidRecord {
                    offset,
                    reason: "terminal-server clip type/count mismatch",
                })
            };
        }
        if let RecordData::TSGraphics(g) = &self.data {
            return if g.valid(self.record_type, self.flags) {
                Ok(())
            } else {
                Err(Error::InvalidRecord {
                    offset,
                    reason: "terminal-server graphics type/flags mismatch",
                })
            };
        }
        if let RecordData::Effect(e) = &self.data {
            return if e.valid(self.record_type) {
                Ok(())
            } else {
                Err(Error::InvalidRecord {
                    offset,
                    reason: "effect type/data mismatch",
                })
            };
        }
        if let RecordData::Text(t) = &self.data {
            return if t.valid(self.record_type) {
                Ok(())
            } else {
                Err(Error::InvalidRecord {
                    offset,
                    reason: "text type/data mismatch",
                })
            };
        }
        if let RecordData::Drawing(d) = &self.data {
            return if d.valid(self.record_type, self.flags) {
                Ok(())
            } else {
                Err(Error::InvalidRecord {
                    offset,
                    reason: "drawing type/flags/data mismatch",
                })
            };
        }
        let valid = matches!(
            (self.record_type, &self.data),
            (0x4001, RecordData::Header(_))
                | (0x4008, RecordData::Object(_))
                | (
                    0x4002 | 0x4004 | 0x401e..=0x4024 | 0x402b | 0x4031 | 0x4033 | 0x4034,
                    RecordData::Empty
                )
                | (0x4009, RecordData::Clear { .. })
                | (0x401d, RecordData::RenderingOrigin { .. })
                | (0x4025 | 0x4026 | 0x4028 | 0x4029, RecordData::StackIndex(_))
                | (0x4027, RecordData::BeginContainer { .. })
                | (0x402a | 0x402c, RecordData::Matrix(_))
                | (0x402d | 0x402e | 0x4035, RecordData::Pair(_))
                | (0x402f | 0x4030, RecordData::Scalar(_))
                | (0x4032, RecordData::ClipRect(_))
                | (_, RecordData::Opaque(_))
        ) && !matches!(
            (&self.data, fixed_len(self.record_type)),
            (RecordData::Opaque(_), Some(_))
        ) && !(self.record_type == 0x4008
            && matches!(self.data, RecordData::Opaque(_)));
        let valid = valid
            && !(self.record_type == 0x403a
                && self.flags & 0x8000 == 0
                && matches!(self.data, RecordData::Opaque(_)))
            && !(matches!(self.record_type, 0x4003 | 0x401c | 0x4036 | 0x4038 | 0x4039)
                && matches!(self.data, RecordData::Opaque(_)))
            && !(super::drawing::supported(self.record_type)
                && matches!(self.data, RecordData::Opaque(_)));
        if valid {
            Ok(())
        } else {
            Err(Error::InvalidRecord {
                offset,
                reason: "record type/data mismatch",
            })
        }
    }
}

pub(crate) fn fixed_len(kind: u16) -> Option<usize> {
    Some(match kind {
        0x4001 | 0x4032 => 16,
        0x4002 | 0x4004 | 0x401e..=0x4024 | 0x402b | 0x4031 | 0x4033 | 0x4034 => 0,
        0x4009 | 0x4025 | 0x4026 | 0x4028 | 0x4029 | 0x402f | 0x4030 => 4,
        0x401d | 0x402d | 0x402e | 0x4035 => 8,
        0x4027 => 36,
        0x402a | 0x402c => 24,
        _ => return None,
    })
}

pub(crate) fn decode_fixed(kind: u16, b: &[u8]) -> RecordData {
    let word = |i: usize| u32::from_le_bytes(b[i..i + 4].try_into().unwrap());
    let array = |start: usize| {
        [
            word(start),
            word(start + 4),
            word(start + 8),
            word(start + 12),
        ]
    };
    match kind {
        0x4001 => RecordData::Header(Header {
            version: word(0),
            emf_plus_flags: word(4),
            logical_dpi_x: word(8),
            logical_dpi_y: word(12),
        }),
        0x4009 => RecordData::Clear { argb: word(0) },
        0x401d => RecordData::RenderingOrigin {
            x: word(0) as i32,
            y: word(4) as i32,
        },
        0x4025 | 0x4026 | 0x4028 | 0x4029 => RecordData::StackIndex(word(0)),
        0x4027 => RecordData::BeginContainer {
            destination: array(0),
            source: array(16),
            stack_index: word(32),
        },
        0x402a | 0x402c => {
            RecordData::Matrix([word(0), word(4), word(8), word(12), word(16), word(20)])
        }
        0x402d | 0x402e | 0x4035 => RecordData::Pair([word(0), word(4)]),
        0x402f | 0x4030 => RecordData::Scalar(word(0)),
        0x4032 => RecordData::ClipRect(array(0)),
        _ => RecordData::Empty,
    }
}
