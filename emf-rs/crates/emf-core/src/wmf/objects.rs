//! Bounded object-table lifetime validation (MS-WMF section 3.1.4).

use crate::limits::{try_vec_with_capacity, Budget};
use crate::ParseFailure;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ObjectKind {
    Brush,
    Font,
    Palette,
    Pen,
    Region,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ObjectIssue {
    TableFull,
    InvalidReference {
        index: u16,
    },
    WrongKind {
        index: u16,
        expected: ObjectKind,
        found: ObjectKind,
    },
    InvalidRestoreDc {
        saved_dc: i16,
    },
}

pub(crate) struct ObjectTable {
    capacity: u16,
    slots: Vec<Option<ObjectKind>>,
    next_free: usize,
    saved: usize,
}

impl ObjectTable {
    pub(crate) fn new(capacity: u16) -> Self {
        Self {
            capacity,
            slots: Vec::new(),
            next_free: 0,
            saved: 0,
        }
    }

    pub(crate) fn apply(
        &mut self,
        function: u16,
        body: &[u8],
        budget: &mut Budget<'_>,
    ) -> Result<(Option<u16>, [Option<ObjectIssue>; 2]), ParseFailure> {
        use ObjectKind::*;
        let function = function & 0xff;
        let mut issues = [None, None];
        let kind = match function {
            0xf7 => Some(Palette),
            0xf9 | 0x42 | 0xfc => Some(Brush),
            0xfa => Some(Pen),
            0xfb => Some(Font),
            0xff => Some(Region),
            _ => None,
        };
        if let Some(kind) = kind {
            // Opaque creator payloads still occupy a slot, so later references
            // retain their wire indices even when that payload cannot be decoded.
            let capacity = usize::from(self.capacity);
            if self.slots.is_empty() && capacity != 0 {
                budget.charge_alloc(capacity * std::mem::size_of::<Option<ObjectKind>>())?;
                budget.charge_work(capacity as u64)?;
                self.slots = try_vec_with_capacity(capacity)?;
                self.slots.resize(capacity, None);
            }
            while self.next_free < capacity {
                budget.charge_work(1)?;
                if self.slots[self.next_free].is_none() {
                    break;
                }
                self.next_free += 1;
            }
            if self.next_free == capacity {
                issues[0] = Some(ObjectIssue::TableFull);
                return Ok((None, issues));
            }
            let index = self.next_free;
            self.slots[index] = Some(kind);
            self.next_free += 1;
            return Ok((Some(index as u16), issues));
        }
        if function == 0x1e {
            self.saved = self
                .saved
                .checked_add(1)
                .ok_or(ParseFailure::ArithmeticOverflow { offset: 0 })?;
        } else if function == 0x27 && body.len() >= 2 {
            let saved_dc = i16::from_le_bytes([body[0], body[1]]);
            let depth = if saved_dc < 0 {
                self.saved.checked_sub(usize::from(saved_dc.unsigned_abs()))
            } else if saved_dc > 0 && saved_dc as usize <= self.saved {
                Some(saved_dc as usize - 1)
            } else {
                None
            };
            if let Some(depth) = depth {
                self.saved = depth;
            } else {
                issues[0] = Some(ObjectIssue::InvalidRestoreDc { saved_dc });
            }
        }
        let expected = match function {
            0x34 => Some(Palette),
            0x28..=0x2c => Some(Region),
            _ => None,
        };
        if matches!(
            function,
            0x2d | 0xf0 | 0x34 | 0x2c | 0x2a | 0x2b | 0x28 | 0x29
        ) && body.len() >= 2
        {
            let index = u16::from_le_bytes([body[0], body[1]]);
            // Stock selections are external to the metafile table. Deletion
            // never accepts them.
            if !(function == 0x2d && index & 0x8000 != 0) {
                issues[0] = self.reference(index, expected);
                if function == 0xf0 && issues[0].is_none() {
                    self.slots[usize::from(index)] = None;
                    self.next_free = self.next_free.min(usize::from(index));
                }
            }
            if matches!(function, 0x28 | 0x29) && body.len() >= 4 {
                let brush = u16::from_le_bytes([body[2], body[3]]);
                issues[1] = self.reference(brush, Some(Brush));
            }
        }
        Ok((None, issues))
    }

    fn reference(&self, index: u16, expected: Option<ObjectKind>) -> Option<ObjectIssue> {
        let Some(Some(found)) = self.slots.get(usize::from(index)) else {
            return Some(ObjectIssue::InvalidReference { index });
        };
        if let Some(expected) = expected {
            if expected != *found {
                return Some(ObjectIssue::WrongKind {
                    index,
                    expected,
                    found: *found,
                });
            }
        }
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{LimitKind, ParseLimits};

    #[test]
    fn table_storage_and_free_slot_search_share_parse_budgets() {
        for (allocated, work, expected) in [
            (0, 100, LimitKind::AllocatedBytes),
            (100, 2, LimitKind::WorkUnits),
        ] {
            let limits = ParseLimits {
                max_allocated_bytes: allocated,
                max_work_units: work,
                ..ParseLimits::default()
            };
            let result = ObjectTable::new(2).apply(0x02fa, &[], &mut Budget::new(&limits));
            assert!(
                matches!(result, Err(ParseFailure::LimitExceeded { kind, .. }) if kind == expected)
            );
        }
        let limits = ParseLimits {
            max_allocated_bytes: 2 * std::mem::size_of::<Option<ObjectKind>>(),
            max_work_units: 3,
            ..ParseLimits::default()
        };
        let mut table = ObjectTable::new(2);
        let mut budget = Budget::new(&limits);
        assert_eq!(table.apply(0x02fa, &[], &mut budget).unwrap().0, Some(0));
        assert!(matches!(
            table.apply(0x02fa, &[], &mut budget),
            Err(ParseFailure::LimitExceeded {
                kind: LimitKind::WorkUnits,
                ..
            })
        ));
    }
}
