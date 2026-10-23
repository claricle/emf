//! Resource budgets for parsing and serialization.
//!
//! Parse units: bytes for `*_bytes`, records for `max_records`, and work units for
//! `max_work_units` (one unit per record framed plus one per 16 bytes of
//! record content examined, plus one per 16 bytes copied into the owned source).
//! A limit is exceeded when the requested total is strictly greater than the limit.

use crate::error::{LimitKind, ParseFailure};

// Portable charge shared with Ruby ResourceBudget. repr(Rust) FontRecord is
// 392 or 400 bytes on supported 64-bit compilers. Admission must not depend on
// that layout choice, and the charge must cover the actual boxed allocation.
pub(crate) const FONT_RECORD_BYTES: usize = 400;
const _: () = assert!(std::mem::size_of::<crate::model::FontRecord>() <= FONT_RECORD_BYTES);

/// Ceilings checked before serialization allocates or copies output.
/// Work counts two units per record (including the header), one per 16 output
/// bytes, and one per point encoded from an edited polyline. Limits are inclusive.
/// Defaults allow 200 MiB of output and 64 Mi work units.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SerializeLimits {
    /// Largest serialized buffer, including opaque suffixes, padding and tail.
    pub max_output_bytes: usize,
    pub max_work_units: u64,
}

impl Default for SerializeLimits {
    fn default() -> Self {
        Self {
            max_output_bytes: 200 * 1024 * 1024,
            max_work_units: 64 * 1024 * 1024,
        }
    }
}

/// Configurable ceilings for one parse or an explicitly shared multi-stage operation.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ParseLimits {
    /// Largest accepted input. Matches the Ruby parser's 200 MiB cap.
    pub max_input_bytes: usize,
    /// Largest accepted single record (`nSize`), including the header record.
    pub max_record_bytes: usize,
    /// Largest number of framed records, header included.
    pub max_records: usize,
    /// Cumulative charged buffer bytes, including each vector growth request.
    /// Font records use a portable conservative charge across compiler layouts.
    /// Excludes allocator metadata and stack storage.
    pub max_allocated_bytes: usize,
    /// Cumulative work units.
    pub max_work_units: u64,
}

impl Default for ParseLimits {
    fn default() -> Self {
        Self {
            max_input_bytes: 200 * 1024 * 1024,
            max_record_bytes: 128 * 1024 * 1024,
            max_records: 4 * 1024 * 1024,
            max_allocated_bytes: 640 * 1024 * 1024,
            max_work_units: 64 * 1024 * 1024,
        }
    }
}

/// Running totals checked against a [`ParseLimits`].
/// Charges are cumulative requests, including temporary buffers and repeated growth;
/// releasing a buffer does not refund its charge. This bounds accounted operations,
/// not allocator metadata, physical RSS, or the process allocation failure behavior.
#[derive(Debug)]
pub struct Budget<'a> {
    limits: &'a ParseLimits,
    records: usize,
    allocated: usize,
    work: u64,
}

impl<'a> Budget<'a> {
    pub fn new(limits: &'a ParseLimits) -> Self {
        Self {
            limits,
            records: 0,
            allocated: 0,
            work: 0,
        }
    }

    pub(crate) fn check_input(&self, len: usize) -> Result<(), ParseFailure> {
        if len > self.limits.max_input_bytes {
            return Err(exceeded(
                LimitKind::InputBytes,
                self.limits.max_input_bytes as u64,
                len as u64,
            ));
        }
        Ok(())
    }

    pub(crate) fn check_record_bytes(&self, size: usize) -> Result<(), ParseFailure> {
        if size > self.limits.max_record_bytes {
            return Err(exceeded(
                LimitKind::RecordBytes,
                self.limits.max_record_bytes as u64,
                size as u64,
            ));
        }
        Ok(())
    }

    /// Count one framed record and charge its work.
    pub(crate) fn charge_record(&mut self, size: usize) -> Result<(), ParseFailure> {
        let records = self
            .records
            .checked_add(1)
            .ok_or(ParseFailure::ArithmeticOverflow {
                offset: self.records,
            })?;
        if records > self.limits.max_records {
            return Err(exceeded(
                LimitKind::RecordCount,
                self.limits.max_records as u64,
                records as u64,
            ));
        }
        self.records = records;
        self.charge_work(1 + (size as u64).div_ceil(16))
    }

    pub fn charge_work(&mut self, units: u64) -> Result<(), ParseFailure> {
        let work = self
            .work
            .checked_add(units)
            .ok_or(ParseFailure::ArithmeticOverflow { offset: 0 })?;
        if work > self.limits.max_work_units {
            return Err(exceeded(
                LimitKind::WorkUnits,
                self.limits.max_work_units,
                work,
            ));
        }
        self.work = work;
        Ok(())
    }

    /// Grow geometrically so framing many small records stays amortized linear.
    /// Charge the full request before allocation, including diagnostic storage.
    pub(crate) fn reserve_one<T>(&mut self, values: &mut Vec<T>) -> Result<(), ParseFailure> {
        if values.len() < values.capacity() {
            return Ok(());
        }
        let capacity = values
            .capacity()
            .checked_mul(2)
            .ok_or(ParseFailure::ArithmeticOverflow {
                offset: values.len(),
            })?
            .max(1);
        let bytes = capacity.checked_mul(std::mem::size_of::<T>()).ok_or(
            ParseFailure::ArithmeticOverflow {
                offset: values.len(),
            },
        )?;
        self.charge_alloc(bytes)?;
        values
            .try_reserve_exact(capacity - values.len())
            .map_err(|_| ParseFailure::AllocationFailed { bytes })
    }

    /// Charge and fallibly reserve one exact buffer before it is populated.
    pub fn vector<T>(&mut self, len: usize) -> Result<Vec<T>, ParseFailure> {
        let bytes = len
            .checked_mul(std::mem::size_of::<T>())
            .ok_or(ParseFailure::ArithmeticOverflow { offset: 0 })?;
        self.charge_alloc(bytes)?;
        try_vec_with_capacity(len)
    }

    pub fn charge_alloc(&mut self, bytes: usize) -> Result<(), ParseFailure> {
        let total = self
            .allocated
            .checked_add(bytes)
            .ok_or(ParseFailure::ArithmeticOverflow { offset: 0 })?;
        if total > self.limits.max_allocated_bytes {
            return Err(exceeded(
                LimitKind::AllocatedBytes,
                self.limits.max_allocated_bytes as u64,
                total as u64,
            ));
        }
        self.allocated = total;
        Ok(())
    }
}

fn exceeded(kind: LimitKind, limit: u64, requested: u64) -> ParseFailure {
    ParseFailure::LimitExceeded {
        kind,
        limit,
        requested,
    }
}

/// Request capacity for `len` elements with a fallible reservation.
pub(crate) fn try_vec_with_capacity<T>(len: usize) -> Result<Vec<T>, ParseFailure> {
    let bytes = len
        .checked_mul(std::mem::size_of::<T>())
        .ok_or(ParseFailure::ArithmeticOverflow { offset: 0 })?;
    let mut v = Vec::new();
    v.try_reserve_exact(len)
        .map_err(|_| ParseFailure::AllocationFailed { bytes })?;
    Ok(v)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cumulative_counters_reject_overflow_even_with_maximum_limits() {
        let limits = ParseLimits {
            max_records: usize::MAX,
            max_allocated_bytes: usize::MAX,
            max_work_units: u64::MAX,
            ..ParseLimits::default()
        };
        let mut budget = Budget::new(&limits);
        budget.charge_alloc(usize::MAX).unwrap();
        assert!(matches!(
            budget.charge_alloc(1),
            Err(ParseFailure::ArithmeticOverflow { .. })
        ));
        budget.charge_work(u64::MAX).unwrap();
        assert!(matches!(
            budget.charge_work(1),
            Err(ParseFailure::ArithmeticOverflow { .. })
        ));
        budget.records = usize::MAX;
        assert!(matches!(
            budget.charge_record(0),
            Err(ParseFailure::ArithmeticOverflow { .. })
        ));
    }

    #[test]
    fn element_byte_multiplication_is_checked_before_reservation() {
        assert!(matches!(
            try_vec_with_capacity::<u64>(usize::MAX),
            Err(ParseFailure::ArithmeticOverflow { .. })
        ));
    }
}
