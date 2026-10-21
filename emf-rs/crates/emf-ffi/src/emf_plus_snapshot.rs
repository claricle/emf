//! Independent read-only EMF+ snapshot schema; see emf-plus-snapshot-v1.md.
use crate::emf_plus_typed::Sink;
use crate::*;
use emf_core::emf_plus::{
    Error, ObjectData, ObjectDefinition, ObjectReference, RecordData, ReferenceTarget,
};

pub const EMF_PLUS_SNAPSHOT_VERSION: u32 = 1;
/// kind u32, role u32, frame index u64, raw ID u32, actual object type u32.
const REFERENCE_DIAGNOSTIC_BYTES: usize = 24;

#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct EmfPlusSnapshotOptions {
    pub struct_size: u32,
    pub version: u32,
    pub max_output_bytes: u64,
}

fn family(data: &RecordData) -> (u32, usize) {
    match data {
        RecordData::Header(_) => (1, 16),
        RecordData::Empty => (2, 0),
        RecordData::Clear { .. } => (3, 4),
        RecordData::RenderingOrigin { .. } => (4, 8),
        RecordData::StackIndex(_) => (5, 4),
        RecordData::BeginContainer { .. } => (6, 36),
        RecordData::Matrix(_) => (7, 24),
        RecordData::Pair(_) => (8, 8),
        RecordData::Scalar(_) => (9, 4),
        RecordData::ClipRect(_) => (10, 16),
        RecordData::Drawing(_) => (0x101, 0),
        RecordData::Text(_) => (0x102, 0),
        RecordData::Effect(_) => (0x103, 0),
        RecordData::TSGraphics(_) => (0x104, 0),
        RecordData::Object(_) => (0x105, 0),
        // These core types have no typed payload in the frozen v1 schema.
        // Their complete source frames remain available through the raw family.
        RecordData::Comment(_) | RecordData::TSClip(_) | RecordData::Opaque(_) => (0, 0),
    }
}

fn typed_len(
    data: &RecordData,
    budget: &mut emf_core::ParseBudget<'_>,
    index: usize,
    object: Option<&(ObjectDefinition, ObjectData)>,
) -> Result<usize, Failure> {
    let mut sink = Sink {
        len: 0,
        out: None,
        budget,
    };
    match data {
        RecordData::Object(fragment) => {
            let (definition, value) = object.ok_or_else(|| {
                Failure::new(EMF_INTERNAL_ERROR, None, "missing object definition")
            })?;
            sink.object_fragment(
                fragment,
                definition,
                (index == definition.first_record).then_some(value),
            )?;
        }
        RecordData::Drawing(value) => sink.drawing(value)?,
        RecordData::Text(value) => sink.text(value)?,
        RecordData::Effect(value) => sink.effect(value)?,
        RecordData::TSGraphics(value) => sink.ts_graphics(value)?,
        _ => {
            sink.budget.charge_work(1)?;
            return Ok(family(data).1);
        }
    }
    Ok(sink.len)
}

fn nested_error(error: Error) -> Failure {
    match error {
        Error::Resource(error) => error.into(),
        Error::InvalidRecord { offset, .. } => {
            Failure::new(EMF_FORMAT_ERROR, Some(offset as u64), error)
        }
        Error::InvalidObject { .. } => Failure::new(EMF_FORMAT_ERROR, None, error),
    }
}

/// Diagnostic kind and the actual object type for a reference that does not
/// resolve; valid and solid-color references produce no diagnostic.
fn reference_diagnostic(reference: &ObjectReference) -> Option<(u32, u32)> {
    match reference.target {
        ReferenceTarget::EmptySlot => Some((1, 0)),
        ReferenceTarget::WrongType { actual_type } => Some((2, actual_type as u32)),
        ReferenceTarget::OutOfRange => Some((3, 0)),
        ReferenceTarget::Definition { .. } | ReferenceTarget::SolidColor => None,
    }
}

pub(super) fn overflow() -> Failure {
    Failure::new(
        EMF_LIMIT_EXCEEDED,
        None,
        "EMF+ snapshot exceeds output limit",
    )
}

fn word(out: &mut Vec<u8>, value: u64) {
    out.extend_from_slice(&value.to_le_bytes());
}

/// # Safety
/// The document must be live. Options and optional limits must reference their declared
/// layouts; non-NULL output pointers must reference writable handle slots.
#[no_mangle]
pub unsafe extern "C" fn emf_document_emf_plus_snapshot_v1(
    document: *const EmfDocument,
    options: *const EmfPlusSnapshotOptions,
    parse_limits: *const EmfLimits,
    out_buffer: *mut *mut EmfBuffer,
    out_error: *mut *mut EmfError,
) -> i32 {
    if !out_buffer.is_null() {
        out_buffer.write(ptr::null_mut());
    }
    run(out_error, || {
        if out_buffer.is_null() || options.is_null() {
            return Err(Failure::invalid("snapshot options or output is NULL"));
        }
        if ptr::addr_of!((*options).struct_size).read() as usize
            != size_of::<EmfPlusSnapshotOptions>()
        {
            return Err(Failure::invalid("unsupported EMF+ options size"));
        }
        let options = &*options;
        if options.version != EMF_PLUS_SNAPSHOT_VERSION {
            return Err(Failure::invalid("unsupported EMF+ snapshot version"));
        }
        let document = &document
            .as_ref()
            .ok_or_else(|| Failure::invalid("document is NULL"))?
            .document;
        // Extraction uses the existing bounded core parser, including comment scans,
        // source copies and work/record/allocation ceilings.
        let parse_limits = limits(parse_limits)?;
        let mut budget = emf_core::ParseBudget::new(&parse_limits);
        let embedded = document
            .structured_emf_plus_with_budget(&mut budget)
            .map_err(nested_error)?;
        let stream = &embedded.stream;
        // Assemble and decode once per definition, including continuation chains.
        // Reuse these values for both checked sizing and output writing.
        let definitions = stream
            .object_definitions_with_budget(&mut budget)
            .map_err(nested_error)?;
        let mut objects = budget.vector::<(ObjectDefinition, ObjectData)>(definitions.len())?;
        for mut definition in definitions {
            let value = definition
                .decode_with_budget(&mut budget)
                .map_err(nested_error)?;
            // Only identity and bounds are needed after decoding; release the
            // assembled wire body rather than retaining a duplicate copy.
            definition.bytes = Vec::new();
            objects.push((definition, value));
        }
        // Unresolved references are nonfatal diagnostics appended after the frames.
        let references = stream
            .object_references_with_budget(&mut budget)
            .map_err(nested_error)?;
        let mut diagnostics = budget.vector::<(ObjectReference, (u32, u32))>(references.len())?;
        diagnostics.extend(
            references
                .into_iter()
                .filter_map(|r| reference_diagnostic(&r).map(|d| (r, d))),
        );
        let lengths = stream.segment_lengths();
        let raw_len = lengths
            .iter()
            .try_fold(0usize, |n, len| n.checked_add(*len).ok_or_else(overflow))?;
        let mut object_index = 0;
        let typed_total =
            stream
                .records
                .iter()
                .enumerate()
                .try_fold(0usize, |n, (index, record)| {
                    let object = objects.get(object_index);
                    let len = typed_len(&record.data, &mut budget, index, object)?;
                    if object.is_some_and(|(definition, _)| definition.last_record == index) {
                        object_index += 1;
                    }
                    n.checked_add(len).ok_or_else(overflow)
                })?;
        let total = lengths
            .len()
            .checked_mul(32)
            .and_then(|n| {
                stream
                    .records
                    .len()
                    .checked_mul(64)
                    .and_then(|r| n.checked_add(r))
            })
            .and_then(|n| n.checked_add(40))
            .and_then(|n| n.checked_add(raw_len))
            .and_then(|n| n.checked_add(typed_total))
            .and_then(|n| n.checked_add(diagnostics.len().checked_mul(REFERENCE_DIAGNOSTIC_BYTES)?))
            .filter(|n| *n as u64 <= options.max_output_bytes && *n <= isize::MAX as usize)
            .ok_or_else(overflow)?;
        // Charge raw copying, table/record scans and both enclosing source scans.
        // Normalized sizing/writing charges each Sink emission before examining it.
        let scan_work = (document.records().len() as u64)
            .checked_mul(2)
            .and_then(|n| {
                (stream.records.len() as u64)
                    .checked_mul(2)
                    .and_then(|r| n.checked_add(r))
            })
            .and_then(|n| {
                (lengths.len() as u64)
                    .checked_mul(3)
                    .and_then(|r| n.checked_add(r))
            })
            .and_then(|n| n.checked_add((total as u64).div_ceil(16)))
            .ok_or_else(overflow)?;
        budget.charge_work(scan_work)?;
        let mut bytes = budget.vector::<u8>(total)?;
        bytes.extend_from_slice(b"EPSN");
        bytes.extend_from_slice(&EMF_PLUS_SNAPSHOT_VERSION.to_le_bytes());
        for value in [
            total as u64,
            lengths.len() as u64,
            stream.records.len() as u64,
            diagnostics.len() as u64,
        ] {
            word(&mut bytes, value);
        }
        let segments = || {
            document
                .records()
                .iter()
                .enumerate()
                .filter_map(|(index, record)| match record.data() {
                    emf_core::RecordData::Comment { data } if data.starts_with(b"EMF+") => {
                        Some((index, &data[4..]))
                    }
                    _ => None,
                })
        };
        let mut logical_offset = 0;
        for (index, segment) in segments() {
            for value in [index as u64, logical_offset as u64, segment.len() as u64, 4] {
                word(&mut bytes, value);
            }
            logical_offset += segment.len();
        }
        let mut source = segments().flat_map(|(_, segment)| segment.iter().copied());
        let mut offset = 0usize;
        let mut first_segment = 0usize;
        let mut segment_end = lengths.first().copied().unwrap_or(0);
        let mut object_index = 0;
        for (index, record) in stream.records.iter().enumerate() {
            let mut header = [0u8; 12];
            for byte in &mut header {
                *byte = source
                    .next()
                    .ok_or_else(|| Failure::new(EMF_INTERNAL_ERROR, None, "invalid core frame"))?;
            }
            let size = u32::from_le_bytes(header[4..8].try_into().unwrap()) as usize;
            let data_size = u32::from_le_bytes(header[8..12].try_into().unwrap()) as usize;
            while offset >= segment_end {
                first_segment += 1;
                segment_end += lengths[first_segment];
            }
            let mut last_segment = first_segment;
            let mut last_end = segment_end;
            while offset + size > last_end {
                last_segment += 1;
                last_end += lengths[last_segment];
            }
            for value in [
                index as u64,
                offset as u64,
                first_segment as u64,
                last_segment as u64,
            ] {
                word(&mut bytes, value);
            }
            bytes.extend_from_slice(&header[..8]);
            bytes.extend_from_slice(&(data_size as u32).to_le_bytes());
            let (tag, _) = family(&record.data);
            let object = objects.get(object_index);
            let typed_len = typed_len(&record.data, &mut budget, index, object)?;
            bytes.extend_from_slice(&tag.to_le_bytes());
            word(&mut bytes, typed_len as u64);
            word(&mut bytes, size as u64);
            let raw_start = bytes.len();
            bytes.extend_from_slice(&header);
            bytes.extend(source.by_ref().take(size - 12));
            // Variable families use normalized core values. The remaining supported
            // families have fixed word layouts identical to their validated wire bodies.
            match &record.data {
                RecordData::Object(fragment) => {
                    let (definition, value) = object.ok_or_else(|| {
                        Failure::new(EMF_INTERNAL_ERROR, None, "missing object definition")
                    })?;
                    Sink {
                        len: 0,
                        out: Some(&mut bytes),
                        budget: &mut budget,
                    }
                    .object_fragment(
                        fragment,
                        definition,
                        (index == definition.first_record).then_some(value),
                    )?;
                }
                RecordData::Drawing(value) => Sink {
                    len: 0,
                    out: Some(&mut bytes),
                    budget: &mut budget,
                }
                .drawing(value)?,
                RecordData::Text(value) => Sink {
                    len: 0,
                    out: Some(&mut bytes),
                    budget: &mut budget,
                }
                .text(value)?,
                RecordData::Effect(value) => Sink {
                    len: 0,
                    out: Some(&mut bytes),
                    budget: &mut budget,
                }
                .effect(value)?,
                RecordData::TSGraphics(value) => Sink {
                    len: 0,
                    out: Some(&mut bytes),
                    budget: &mut budget,
                }
                .ts_graphics(value)?,
                _ => bytes.extend_from_within(raw_start + 12..raw_start + 12 + typed_len),
            }
            if object.is_some_and(|(definition, _)| definition.last_record == index) {
                object_index += 1;
            }
            offset += size;
        }
        for (reference, (kind, actual_type)) in &diagnostics {
            let role = reference.role.object_type() as u32;
            bytes.extend_from_slice(&kind.to_le_bytes());
            bytes.extend_from_slice(&role.to_le_bytes());
            word(&mut bytes, reference.record_index as u64);
            bytes.extend_from_slice(&reference.raw_id.to_le_bytes());
            bytes.extend_from_slice(&actual_type.to_le_bytes());
        }
        debug_assert_eq!(bytes.len(), total);
        out_buffer.write(Box::into_raw(Box::new(EmfBuffer { bytes })));
        Ok(())
    })
}
