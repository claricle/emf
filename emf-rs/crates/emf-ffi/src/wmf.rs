//! WMF handles share EMF status, buffer, descriptor and limit layouts.
use super::*;

/// # Safety
/// Handles must be live and of the WMF kind; pointers must be aligned and valid for their declared ranges.
#[no_mangle]
pub unsafe extern "C" fn emf_wmf_parse(
    data: *const u8,
    len: u64,
    parse_limits: *const EmfLimits,
    out_document: *mut *mut WmfDocument,
    out_error: *mut *mut EmfError,
) -> i32 {
    if !out_document.is_null() {
        out_document.write(ptr::null_mut());
    }
    run(out_error, || {
        if out_document.is_null() {
            return Err(Failure::invalid("out_document is NULL"));
        }
        let limits = limits(parse_limits)?;
        let document = emf_core::wmf::parse(input(data, len)?, &limits)?;
        out_document.write(Box::into_raw(Box::new(WmfDocument { document })));
        Ok(())
    })
}

/// # Safety
/// Handles must be live and of the WMF kind; pointers must be aligned and valid for their declared ranges.
#[no_mangle]
pub unsafe extern "C" fn emf_wmf_document_info(
    document: *const WmfDocument,
    out_info: *mut EmfInfo,
) -> i32 {
    run(ptr::null_mut(), || {
        if out_info.is_null() {
            return Err(Failure::invalid("out_info is NULL"));
        }
        let struct_size = ptr::addr_of!((*out_info).struct_size).read();
        if struct_size as usize != size_of::<EmfInfo>() {
            return Err(Failure::invalid("unsupported structure size"));
        }
        let version = ptr::addr_of!((*out_info).version).read();
        metadata::<EmfInfo>(struct_size, version)?;
        let out = &mut *out_info;
        *out = EmfInfo {
            struct_size,
            version,
            ..EmfInfo::default()
        };
        let document = &document
            .as_ref()
            .ok_or_else(|| Failure::invalid("document is NULL"))?
            .document;
        out.format = if document.placeable_header().is_some() {
            2
        } else {
            3
        };
        out.has_eof = u32::from(document.has_eof());
        out.header_bytes = (document.header_bytes().len()
            + if document.placeable_header().is_some() {
                22
            } else {
                0
            }) as u64;
        out.record_count = document.records().len() as u64;
        out.diagnostic_count = document.diagnostics().len() as u64;
        out.trailing_bytes = if document.has_eof() {
            document.tail().len() as u64
        } else {
            0
        };
        out.unframed_bytes = if document.has_eof() {
            0
        } else {
            document.tail().len() as u64
        };
        Ok(())
    })
}

/// # Safety
/// Handles must be live and of the WMF kind; pointers must be aligned and valid for their declared ranges.
#[no_mangle]
pub unsafe extern "C" fn emf_wmf_record_batch(
    document: *const WmfDocument,
    start: u64,
    capacity: u64,
    out_descriptors: *mut EmfRecordDescriptor,
    out_count: *mut u64,
) -> i32 {
    if !out_count.is_null() {
        out_count.write(0);
    }
    run(ptr::null_mut(), || {
        if out_count.is_null() {
            return Err(Failure::invalid("out_count is NULL"));
        }
        let document = &document
            .as_ref()
            .ok_or_else(|| Failure::invalid("document is NULL"))?
            .document;
        let start = length(start, 1)?;
        let capacity = length(capacity, size_of::<EmfRecordDescriptor>())?;
        let records = document
            .records()
            .get(start..)
            .ok_or_else(|| Failure::invalid("record start is out of range"))?;
        if capacity != 0 && out_descriptors.is_null() {
            return Err(Failure::invalid("out_descriptors is NULL"));
        }
        let count = records.len().min(capacity);
        for (position, record) in records.iter().take(count).enumerate() {
            out_descriptors.add(position).write(EmfRecordDescriptor {
                struct_size: size_of::<EmfRecordDescriptor>() as u32,
                version: EMF_ABI_VERSION,
                index: (start + position) as u64,
                offset: record.offset() as u64,
                byte_length: record.size() as u64,
                type_id: u32::from(record.function()),
                family: u32::from(record.is_eof()),
            });
        }
        out_count.write(count as u64);
        Ok(())
    })
}

/// # Safety
/// Handles must be live and of the WMF kind; pointers must be aligned and valid for their declared ranges.
#[no_mangle]
pub unsafe extern "C" fn emf_wmf_record_bytes(
    document: *const WmfDocument,
    index: u64,
    out_buffer: *mut *mut EmfBuffer,
    out_error: *mut *mut EmfError,
) -> i32 {
    if !out_buffer.is_null() {
        out_buffer.write(ptr::null_mut());
    }
    run(out_error, || {
        if out_buffer.is_null() {
            return Err(Failure::invalid("out_buffer is NULL"));
        }
        let document = &document
            .as_ref()
            .ok_or_else(|| Failure::invalid("document is NULL"))?
            .document;
        let index = length(index, 1)?;
        let record = document
            .records()
            .get(index)
            .ok_or_else(|| Failure::invalid("record index is out of range"))?;
        let source = document
            .record_bytes(record)
            .ok_or_else(|| Failure::new(EMF_INTERNAL_ERROR, None, "invalid record span"))?;
        let mut bytes = Vec::new();
        bytes.try_reserve_exact(source.len()).map_err(|_| {
            Failure::new(
                EMF_ALLOCATION_FAILED,
                None,
                "record buffer allocation failed",
            )
        })?;
        bytes.extend_from_slice(source);
        out_buffer.write(Box::into_raw(Box::new(EmfBuffer { bytes })));
        Ok(())
    })
}

/// # Safety
/// Handles must be live and of the WMF kind; pointers must be aligned and valid for their declared ranges.
#[no_mangle]
pub unsafe extern "C" fn emf_wmf_serialize(
    document: *const WmfDocument,
    out_buffer: *mut *mut EmfBuffer,
    out_error: *mut *mut EmfError,
) -> i32 {
    if !out_buffer.is_null() {
        out_buffer.write(ptr::null_mut());
    }
    run(out_error, || {
        if out_buffer.is_null() {
            return Err(Failure::invalid("out_buffer is NULL"));
        }
        let document = &document
            .as_ref()
            .ok_or_else(|| Failure::invalid("document is NULL"))?
            .document;
        let bytes = emf_core::wmf::serialize(document)?;
        out_buffer.write(Box::into_raw(Box::new(EmfBuffer { bytes })));
        Ok(())
    })
}

/// Replace a WMF record payload; source spans remain available until serialization.
/// # Safety
/// The document must be an exclusively borrowed live WMF handle; input and error pointers must be valid.
#[no_mangle]
pub unsafe extern "C" fn emf_wmf_replace_record(
    document: *mut WmfDocument,
    index: u64,
    function: u32,
    data: *const u8,
    len: u64,
    out_error: *mut *mut EmfError,
) -> i32 {
    run(out_error, || {
        let document = &mut document
            .as_mut()
            .ok_or_else(|| Failure::invalid("document is NULL"))?
            .document;
        let index = length(index, 1)?;
        let function = u16::try_from(function)
            .map_err(|_| Failure::invalid("WMF function exceeds 16 bits"))?;
        if index >= document.records().len() {
            return Err(Failure::invalid("record index is out of range"));
        }
        // Bound the owned edit before allocation, using the default record ceiling.
        if len > ParseLimits::default().max_record_bytes.saturating_sub(6) as u64 {
            return Err(Failure::new(
                EMF_LIMIT_EXCEEDED,
                None,
                "WMF edit exceeds record limit",
            ));
        }
        let source = input(data, len)?;
        if source.len() % 2 != 0 || (function == 0 && !source.is_empty()) {
            return Err(Failure::invalid("invalid WMF record payload"));
        }
        let mut bytes = Vec::new();
        bytes
            .try_reserve_exact(source.len())
            .map_err(|_| Failure::new(EMF_ALLOCATION_FAILED, None, "WMF edit allocation failed"))?;
        bytes.extend_from_slice(source);
        document
            .replace_record(index, function, bytes)
            .map_err(|error| Failure::new(EMF_SERIALIZE_ERROR, None, error))?;
        Ok(())
    })
}

/// # Safety
/// A non-NULL document must be a live WMF handle, freed exactly once with no concurrent users.
#[no_mangle]
pub unsafe extern "C" fn emf_wmf_document_free(document: *mut WmfDocument) {
    if !document.is_null() {
        drop(Box::from_raw(document));
    }
}
