use super::{parser::parse_segments_budget, Error, Stream};
use crate::{
    limits::{try_vec_with_capacity, Budget},
    Document, EditFailure, LimitKind, ParseLimits, RecordData, SerializeFailure, SerializeLimits,
};

/// Detached typed view of the EMF+ comments. Re-extract after a successful edit.
/// Only `stream` is editable; source bytes and comment indices are private.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct EmbeddedStream {
    pub stream: Stream,
    source: Vec<(usize, Vec<u8>)>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum EmbedError {
    /// The selected EMF+ comment set or its data changed since extraction.
    StaleSource,
    Edit(EditFailure),
    Serialize(SerializeFailure),
}
impl From<SerializeFailure> for EmbedError {
    fn from(value: SerializeFailure) -> Self {
        Self::Serialize(value)
    }
}
impl std::fmt::Display for EmbedError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::StaleSource => {
                f.write_str("EMF+ source comments changed; extract a fresh snapshot")
            }
            Self::Edit(e) => e.fmt(f),
            Self::Serialize(e) => e.fmt(f),
        }
    }
}
impl std::error::Error for EmbedError {}

impl EmbeddedStream {
    pub(crate) fn extract(doc: &Document, limits: &ParseLimits) -> Result<Self, Error> {
        let mut budget = Budget::new(limits);
        let mut source = Vec::new();
        let mut input_bytes = 0usize;
        // Account for scanning the enclosing record set, even when no comments match.
        budget.charge_work(doc.records.len() as u64)?;
        for (index, record) in doc.records.iter().enumerate() {
            if let RecordData::Comment { data } = &record.data {
                if data.starts_with(b"EMF+") {
                    input_bytes = input_bytes
                        .checked_add(data.len() - 4)
                        .ok_or(crate::ParseFailure::ArithmeticOverflow { offset: 0 })?;
                    budget.check_input(input_bytes)?;
                    budget.reserve_one(&mut source)?;
                    budget.charge_alloc(data.len())?;
                    budget.charge_work((data.len() as u64).div_ceil(16))?;
                    let mut original = try_vec_with_capacity(data.len())?;
                    original.extend_from_slice(data);
                    source.push((index, original));
                }
            }
        }
        budget.charge_alloc(
            source
                .len()
                .checked_mul(std::mem::size_of::<&[u8]>())
                .ok_or(crate::ParseFailure::ArithmeticOverflow { offset: 0 })?,
        )?;
        let mut segments = try_vec_with_capacity(source.len())?;
        for (_, data) in &source {
            segments.push(&data[4..]);
        }
        let stream = parse_segments_budget(&segments, &mut budget)?;
        Ok(Self { stream, source })
    }

    pub(crate) fn apply(
        &self,
        doc: &mut Document,
        limits: &SerializeLimits,
    ) -> Result<(), EmbedError> {
        // Preflight the logical encoding and all enclosing comparison/staging work
        // before allocating output. The final comment absorbs growth; earlier
        // capacities are retained (or clamped when the logical stream shrinks).
        let (logical_len, logical_work) = super::serializer::plan(&self.stream, limits, false)?;
        if self.source.is_empty() && logical_len != 0 {
            return Err(SerializeFailure::Inconsistent { offset: 0 }.into());
        }
        let total = self
            .source
            .len()
            .checked_mul(4)
            .and_then(|n| n.checked_add(logical_len))
            .ok_or(SerializeFailure::SizeOverflow)?;
        let mut work = doc.records.len() as u64;
        for (_, data) in &self.source {
            work = work
                .checked_add((data.len() as u64).div_ceil(16) + 1)
                .ok_or(SerializeFailure::SizeOverflow)?;
        }
        work = work
            .checked_add((total as u64).div_ceil(16))
            .and_then(|n| n.checked_add(self.source.len() as u64))
            .ok_or(SerializeFailure::SizeOverflow)?;
        let combined_work = work
            .checked_add(logical_work)
            .ok_or(SerializeFailure::SizeOverflow)?;
        for (kind, requested, limit) in [
            (
                LimitKind::OutputBytes,
                total as u64,
                limits.max_output_bytes as u64,
            ),
            (LimitKind::WorkUnits, combined_work, limits.max_work_units),
        ] {
            if requested > limit {
                return Err(SerializeFailure::LimitExceeded {
                    kind,
                    requested,
                    limit,
                }
                .into());
            }
        }
        let mut remaining = logical_len;
        for (position, (_, original)) in self.source.iter().enumerate() {
            let len = if position + 1 == self.source.len() {
                remaining
            } else {
                remaining.min(original.len() - 4)
            };
            // EMR_COMMENT: 8-byte record header, 4-byte count, signature and
            // payload, rounded to DWORD alignment. Reject before reserving.
            let size = len
                .checked_add(16)
                .and_then(|n| n.checked_add((4 - n % 4) % 4))
                .ok_or(SerializeFailure::SizeOverflow)?;
            u32::try_from(size).map_err(|_| SerializeFailure::SizeOverflow)?;
            remaining -= len;
        }
        let mut selected = self.source.iter();
        for (index, record) in doc.records.iter().enumerate() {
            if let RecordData::Comment { data } = &record.data {
                if data.starts_with(b"EMF+")
                    && !selected
                        .next()
                        .is_some_and(|(old_index, old)| *old_index == index && old == data)
                {
                    return Err(EmbedError::StaleSource);
                }
            }
        }
        if selected.next().is_some() {
            return Err(EmbedError::StaleSource);
        }
        let remaining = SerializeLimits {
            max_work_units: limits.max_work_units - work,
            ..limits.clone()
        };
        let bytes = super::serialize_with_limits(&self.stream, &remaining)?;
        let mut replacements = Vec::new();
        replacements
            .try_reserve_exact(self.source.len())
            .map_err(|_| SerializeFailure::AllocationFailed {
                bytes: self
                    .source
                    .len()
                    .saturating_mul(std::mem::size_of::<(usize, RecordData)>()),
            })?;
        let mut offset = 0;
        for (position, (index, original)) in self.source.iter().enumerate() {
            let len = if position + 1 == self.source.len() {
                bytes.len() - offset
            } else {
                (bytes.len() - offset).min(original.len() - 4)
            };
            let segment = &bytes[offset..offset + len];
            offset += len;
            if segment == &original[4..] {
                continue;
            }
            let record = &doc.records[*index];
            let suffix_len = record.size as usize - 8 - record.decoded_len;
            if suffix_len != (4 - record.decoded_len % 4) % 4 {
                return Err(EmbedError::Edit(EditFailure::RecordLayout {
                    index: *index,
                }));
            }
            let mut data = Vec::new();
            data.try_reserve_exact(4 + segment.len()).map_err(|_| {
                SerializeFailure::AllocationFailed {
                    bytes: 4 + segment.len(),
                }
            })?;
            data.extend_from_slice(b"EMF+");
            data.extend_from_slice(segment);
            replacements.push((*index, RecordData::Comment { data }));
        }
        // All validation and fallible allocation precede the first mutation.
        for (index, data) in replacements {
            doc.records[index].data = data;
            doc.records[index].edited = true;
        }
        Ok(())
    }
}
