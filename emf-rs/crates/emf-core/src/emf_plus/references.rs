//! Time-indexed object references (MS-EMFPLUS 2.3.4 and 2.3.5.1).
use super::{objects, Drawing, Error, Record, RecordData, Stream, Text};
use crate::{limits::Budget, ParseLimits};

/// The required object type, rather than the meaning of the record's flags.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ObjectRole {
    Brush,
    Pen,
    Path,
    Region,
    Image,
    Font,
    StringFormat,
    ImageAttributes,
}
impl ObjectRole {
    pub fn object_type(self) -> u8 {
        match self {
            Self::Brush => 1,
            Self::Pen => 2,
            Self::Path => 3,
            Self::Region => 4,
            Self::Image => 5,
            Self::Font => 6,
            Self::StringFormat => 7,
            Self::ImageAttributes => 8,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ReferenceTarget {
    /// A completed definition, including all its continuation records.
    Definition {
        first_record: usize,
        last_record: usize,
    },
    /// The S flag makes the raw brush word an ARGB color, not a table index.
    SolidColor,
    EmptySlot,
    WrongType {
        actual_type: u8,
    },
    OutOfRange,
}

/// Resolution is observational: invalid references do not change wire data.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ObjectReference {
    pub record_index: usize,
    pub role: ObjectRole,
    pub raw_id: u32,
    pub target: ReferenceTarget,
}

impl Stream {
    /// Resolve references in known drawing, text, image and clip records against
    /// the most recent completed definition before each record. Unknown records
    /// are not guessed. Invalid object chains/resource limits return an error;
    /// missing, mistyped or out-of-range references are returned as diagnostics.
    /// Object bodies are neither copied nor decoded by this operation.
    pub fn object_references(&self, limits: &ParseLimits) -> Result<Vec<ObjectReference>, Error> {
        let mut budget = Budget::new(limits);
        objects::check_stream(self, &mut budget, true)?;
        self.resolve_references(&mut budget)
    }

    /// Share an extraction/parse budget without counting framed records twice.
    pub fn object_references_with_budget(
        &self,
        budget: &mut Budget<'_>,
    ) -> Result<Vec<ObjectReference>, Error> {
        objects::check_stream(self, budget, false)?;
        self.resolve_references(budget)
    }

    fn resolve_references(&self, budget: &mut Budget<'_>) -> Result<Vec<ObjectReference>, Error> {
        let mut definitions = Vec::new();
        objects::visit_chains(self, budget, |first, last, _, budget| {
            budget.reserve_one(&mut definitions)?;
            definitions.push((first, last));
            Ok(())
        })?;
        let mut slots = [None; 64];
        let mut next = definitions.iter().peekable();
        let mut output = Vec::new();
        for (index, record) in self.records.iter().enumerate() {
            budget.charge_work(1)?;
            record.validate(index)?;
            while next.peek().is_some_and(|(_, last)| *last < index) {
                let &(first, last) = next.next().unwrap();
                let flags = self.records[first].flags;
                slots[(flags & 0xff) as usize] = Some((((flags >> 8) & 0x7f) as u8, first, last));
            }
            references(record, |role, raw_id, solid| {
                budget.charge_work(1)?;
                let target = if solid {
                    ReferenceTarget::SolidColor
                } else if raw_id >= 64 {
                    ReferenceTarget::OutOfRange
                } else {
                    match slots[raw_id as usize] {
                        None => ReferenceTarget::EmptySlot,
                        Some((actual_type, _, _)) if actual_type != role.object_type() => {
                            ReferenceTarget::WrongType { actual_type }
                        }
                        Some((_, first_record, last_record)) => ReferenceTarget::Definition {
                            first_record,
                            last_record,
                        },
                    }
                };
                budget.reserve_one(&mut output)?;
                output.push(ObjectReference {
                    record_index: index,
                    role,
                    raw_id,
                    target,
                });
                Ok(())
            })?;
        }
        Ok(output)
    }
}

fn references(
    record: &Record,
    mut add: impl FnMut(ObjectRole, u32, bool) -> Result<(), Error>,
) -> Result<(), Error> {
    use ObjectRole::*;
    let id = (record.flags & 0xff) as u32;
    let solid = record.flags & 0x8000 != 0;
    match &record.data {
        RecordData::Drawing(drawing) => match drawing {
            Drawing::Rectangles { brush, .. }
            | Drawing::Ellipse { brush, .. }
            | Drawing::Arc { brush, .. }
            | Drawing::Points { brush, .. }
            | Drawing::Curve { brush, .. } => {
                if let Some(brush) = brush {
                    add(Brush, *brush, solid)?;
                } else {
                    add(Pen, id, false)?;
                }
            }
            Drawing::ImageRect { source, .. } | Drawing::ImagePoints { source, .. } => {
                add(Image, id, false)?;
                add(ImageAttributes, source.attributes_id, false)?;
            }
            Drawing::ObjectReference { value } => {
                add(
                    if record.record_type == 0x4013 {
                        Region
                    } else {
                        Path
                    },
                    id,
                    false,
                )?;
                add(
                    if record.record_type == 0x4015 {
                        Pen
                    } else {
                        Brush
                    },
                    *value,
                    record.record_type != 0x4015 && solid,
                )?;
            }
        },
        RecordData::Text(text) => {
            add(Font, id, false)?;
            match text {
                Text::String {
                    brush, format_id, ..
                } => {
                    add(Brush, *brush, solid)?;
                    add(StringFormat, *format_id, false)?;
                }
                Text::Driver { brush, .. } => add(Brush, *brush, solid)?,
            }
        }
        RecordData::Empty if matches!(record.record_type, 0x4033 | 0x4034) => {
            add(
                if record.record_type == 0x4033 {
                    Path
                } else {
                    Region
                },
                id,
                false,
            )?;
        }
        _ => (),
    }
    Ok(())
}
