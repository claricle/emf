//! C ABI for owned EMF framing handles. See `include/emf.h` for pointer contracts.
mod emf_plus_snapshot;
mod emf_plus_typed;
mod snapshot;
pub use emf_plus_snapshot::*;
mod types;
mod wmf;
mod wmf_rejection;
mod wmf_snapshot;
mod wmf_view;
pub use types::*;
pub use wmf::*;
pub use wmf_rejection::*;
pub use wmf_snapshot::*;
pub use wmf_view::*;

use emf_core::{Document, Format, ParseFailure, ParseLimits, SerializeFailure};
use std::{
    fmt,
    mem::size_of,
    panic::{catch_unwind, AssertUnwindSafe},
    ptr, slice,
};

const MAX_ERROR_BYTES: usize = 512;

struct Failure {
    status: i32,
    offset: Option<u64>,
    message: Vec<u8>,
    resource: Option<(u32, u64, u64)>,
}

struct Message {
    bytes: [u8; MAX_ERROR_BYTES],
    len: usize,
}

impl fmt::Write for Message {
    fn write_str(&mut self, text: &str) -> fmt::Result {
        let mut len = text.len().min(MAX_ERROR_BYTES - self.len);
        while !text.is_char_boundary(len) {
            len -= 1;
        }
        self.bytes[self.len..self.len + len].copy_from_slice(&text.as_bytes()[..len]);
        self.len += len;
        Ok(())
    }
}

impl Failure {
    fn new(status: i32, offset: Option<u64>, message: impl fmt::Display) -> Self {
        use fmt::Write;
        let mut bounded = Message {
            bytes: [0; MAX_ERROR_BYTES],
            len: 0,
        };
        let _ = write!(&mut bounded, "{message}");
        let mut message = Vec::new();
        if message.try_reserve_exact(bounded.len).is_ok() {
            message.extend_from_slice(&bounded.bytes[..bounded.len]);
        }
        Self {
            status,
            offset,
            message,
            resource: None,
        }
    }

    fn invalid(message: &'static str) -> Self {
        Self::new(EMF_INVALID_ARGUMENT, None, message)
    }
}

impl From<ParseFailure> for Failure {
    fn from(error: ParseFailure) -> Self {
        let status = match &error {
            ParseFailure::LimitExceeded { .. } => EMF_LIMIT_EXCEEDED,
            ParseFailure::AllocationFailed { .. } => EMF_ALLOCATION_FAILED,
            _ => EMF_FORMAT_ERROR,
        };
        let offset = match &error {
            ParseFailure::Truncated { offset, .. }
            | ParseFailure::ArithmeticOverflow { offset } => Some(*offset as u64),
            _ => None,
        };
        let resource = match &error {
            ParseFailure::LimitExceeded {
                kind,
                limit,
                requested,
            } => Some((resource_code(*kind), *limit, *requested)),
            _ => None,
        };
        let mut failure = Self::new(status, offset, error);
        failure.resource = resource;
        failure
    }
}

impl From<SerializeFailure> for Failure {
    fn from(error: SerializeFailure) -> Self {
        let (status, offset) = match &error {
            SerializeFailure::LimitExceeded { .. } => (EMF_LIMIT_EXCEEDED, None),
            SerializeFailure::AllocationFailed { .. } => (EMF_ALLOCATION_FAILED, None),
            SerializeFailure::SizeOverflow => (EMF_SERIALIZE_ERROR, None),
            SerializeFailure::Inconsistent { offset } => {
                (EMF_SERIALIZE_ERROR, Some(*offset as u64))
            }
        };
        let resource = match &error {
            SerializeFailure::LimitExceeded {
                kind,
                limit,
                requested,
            } => Some((resource_code(*kind), *limit, *requested)),
            _ => None,
        };
        let mut failure = Self::new(status, offset, error);
        failure.resource = resource;
        failure
    }
}

// Catch panics before returning through C, including error construction.
unsafe fn run(out_error: *mut *mut EmfError, body: impl FnOnce() -> Result<(), Failure>) -> i32 {
    if !out_error.is_null() {
        out_error.write(ptr::null_mut());
    }
    let result = catch_unwind(AssertUnwindSafe(|| match body() {
        Ok(()) => EMF_OK,
        Err(failure) => {
            if !out_error.is_null() {
                out_error.write(Box::into_raw(Box::new(EmfError {
                    status: failure.status,
                    offset: failure.offset,
                    message: failure.message,
                    resource: failure.resource,
                })));
            }
            failure.status
        }
    }));
    result.unwrap_or(EMF_INTERNAL_ERROR)
}

fn length(value: u64, element_size: usize) -> Result<usize, Failure> {
    let value = usize::try_from(value)
        .map_err(|_| Failure::invalid("length does not fit address space"))?;
    if value > (isize::MAX as usize) / element_size {
        return Err(Failure::invalid("range exceeds address space"));
    }
    Ok(value)
}

unsafe fn input<'a>(data: *const u8, len: u64) -> Result<&'a [u8], Failure> {
    let len = length(len, 1)?;
    if len == 0 {
        return Ok(&[]);
    }
    if data.is_null() {
        return Err(Failure::invalid("input data is NULL"));
    }
    Ok(slice::from_raw_parts(data, len))
}

fn metadata<T>(size: u32, version: u32) -> Result<(), Failure> {
    if size as usize != size_of::<T>() || version != EMF_ABI_VERSION {
        return Err(Failure::invalid(
            "unsupported structure size or ABI version",
        ));
    }
    Ok(())
}

fn ceiling(value: u64) -> Result<usize, Failure> {
    usize::try_from(value).map_err(|_| Failure::invalid("limit does not fit address space"))
}

unsafe fn limits(value: *const EmfLimits) -> Result<ParseLimits, Failure> {
    if value.is_null() {
        return Ok(ParseLimits::default());
    }
    if ptr::addr_of!((*value).struct_size).read() as usize != size_of::<EmfLimits>() {
        return Err(Failure::invalid("unsupported structure size"));
    }
    metadata::<EmfLimits>(
        ptr::addr_of!((*value).struct_size).read(),
        ptr::addr_of!((*value).version).read(),
    )?;
    let value = &*value;
    Ok(ParseLimits {
        max_input_bytes: ceiling(value.max_input_bytes)?,
        max_record_bytes: ceiling(value.max_record_bytes)?,
        max_records: ceiling(value.max_records)?,
        max_allocated_bytes: ceiling(value.max_allocated_bytes)?,
        max_work_units: value.max_work_units,
    })
}

#[no_mangle]
pub extern "C" fn emf_abi_version() -> u32 {
    EMF_ABI_VERSION
}

/// # Safety
/// All non-NULL pointers must be aligned and valid for the declared input or output range.
#[no_mangle]
pub unsafe extern "C" fn emf_detect(
    data: *const u8,
    len: u64,
    out_format: *mut u32,
    out_error: *mut *mut EmfError,
) -> i32 {
    if !out_format.is_null() {
        out_format.write(0);
    }
    run(out_error, || {
        if out_format.is_null() {
            return Err(Failure::invalid("out_format is NULL"));
        }
        let format = emf_core::detect_format(input(data, len)?)?;
        out_format.write(match format {
            Format::Emf => 1,
            Format::WmfApm => 2,
            Format::WmfStandard => 3,
        });
        Ok(())
    })
}

/// # Safety
/// All non-NULL pointers must be aligned and valid for the declared input, limits, or output range.
#[no_mangle]
pub unsafe extern "C" fn emf_parse(
    data: *const u8,
    len: u64,
    parse_limits: *const EmfLimits,
    out_document: *mut *mut EmfDocument,
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
        let document = emf_core::parse(input(data, len)?, &limits)?;
        out_document.write(Box::into_raw(Box::new(EmfDocument { document })));
        Ok(())
    })
}

/// # Safety
/// The document must be a live handle; out_info must reference writable storage for its declared layout.
#[no_mangle]
pub unsafe extern "C" fn emf_document_info(
    document: *const EmfDocument,
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
        out.format = 1;
        out.has_eof = u32::from(document.has_eof());
        out.header_bytes = document.header_bytes().len() as u64;
        out.record_count = document.records().len() as u64;
        out.diagnostic_count = document.diagnostics().len() as u64;
        out.trailing_bytes = document.trailing_bytes().len() as u64;
        out.unframed_bytes = document.unframed_bytes().len() as u64;
        Ok(())
    })
}

/// # Safety
/// The document must be live; outputs must be valid for a count and capacity descriptors respectively.
#[no_mangle]
pub unsafe extern "C" fn emf_record_batch(
    document: *const EmfDocument,
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
                type_id: record.record_type(),
                family: snapshot::family(record.data()),
            });
        }
        out_count.write(count as u64);
        Ok(())
    })
}

/// # Safety
/// The document must be live; non-NULL output pointers must reference writable handle slots.
#[no_mangle]
pub unsafe extern "C" fn emf_document_snapshot(
    document: *const EmfDocument,
    out_buffer: *mut *mut EmfBuffer,
    out_error: *mut *mut EmfError,
) -> i32 {
    document_snapshot(document, out_buffer, out_error, snapshot::encode)
}

/// Schema 3 snapshot (snapshot-v3.md); same status, output and lifetime rules.
///
/// # Safety
/// The document must be live; non-NULL output pointers must reference writable handle slots.
#[no_mangle]
pub unsafe extern "C" fn emf_document_snapshot_v3(
    document: *const EmfDocument,
    out_buffer: *mut *mut EmfBuffer,
    out_error: *mut *mut EmfError,
) -> i32 {
    document_snapshot(document, out_buffer, out_error, snapshot::encode_v3)
}

unsafe fn document_snapshot(
    document: *const EmfDocument,
    out_buffer: *mut *mut EmfBuffer,
    out_error: *mut *mut EmfError,
    encode: fn(&Document) -> Result<Vec<u8>, snapshot::Error>,
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
        let bytes = encode(document).map_err(|error| match error {
            snapshot::Error::SizeOverflow => Failure::new(
                EMF_LIMIT_EXCEEDED,
                None,
                "snapshot size exceeds address space",
            ),
            snapshot::Error::AllocationFailed => {
                Failure::new(EMF_ALLOCATION_FAILED, None, "snapshot allocation failed")
            }
        })?;
        out_buffer.write(Box::into_raw(Box::new(EmfBuffer { bytes })));
        Ok(())
    })
}

/// # Safety
/// The document must be live; non-NULL output pointers must reference writable handle slots.
#[no_mangle]
pub unsafe extern "C" fn emf_record_bytes(
    document: *const EmfDocument,
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
/// The document must be live; non-NULL output pointers must reference writable handle slots.
#[no_mangle]
pub unsafe extern "C" fn emf_serialize(
    document: *const EmfDocument,
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
        let bytes = emf_core::serialize(document)?;
        out_buffer.write(Box::into_raw(Box::new(EmfBuffer { bytes })));
        Ok(())
    })
}

/// # Safety
/// The buffer must be live; non-NULL outputs must reference writable pointer and length slots.
#[no_mangle]
pub unsafe extern "C" fn emf_buffer_view(
    buffer: *const EmfBuffer,
    out_data: *mut *const u8,
    out_length: *mut u64,
) -> i32 {
    if !out_data.is_null() {
        out_data.write(ptr::null());
    }
    if !out_length.is_null() {
        out_length.write(0);
    }
    run(ptr::null_mut(), || {
        if out_data.is_null() || out_length.is_null() {
            return Err(Failure::invalid("buffer view output is NULL"));
        }
        let buffer = buffer
            .as_ref()
            .ok_or_else(|| Failure::invalid("buffer is NULL"))?;
        if !buffer.bytes.is_empty() {
            out_data.write(buffer.bytes.as_ptr());
        }
        out_length.write(buffer.bytes.len() as u64);
        Ok(())
    })
}

/// # Safety
/// The error must be live; out_info must reference writable storage for its declared layout.
#[no_mangle]
pub unsafe extern "C" fn emf_error_view(
    error: *const EmfError,
    out_info: *mut EmfErrorInfo,
) -> i32 {
    run(ptr::null_mut(), || {
        if out_info.is_null() {
            return Err(Failure::invalid("out_info is NULL"));
        }
        let struct_size = ptr::addr_of!((*out_info).struct_size).read();
        if struct_size as usize != size_of::<EmfErrorInfo>() {
            return Err(Failure::invalid("unsupported structure size"));
        }
        let version = ptr::addr_of!((*out_info).version).read();
        metadata::<EmfErrorInfo>(struct_size, version)?;
        let out = &mut *out_info;
        *out = EmfErrorInfo {
            struct_size,
            version,
            status: 0,
            category: 0,
            has_offset: 0,
            reserved: 0,
            offset: 0,
            message: ptr::null(),
            message_length: 0,
        };
        let error = error
            .as_ref()
            .ok_or_else(|| Failure::invalid("error is NULL"))?;
        out.status = error.status;
        out.category = error.status as u32;
        out.has_offset = u32::from(error.offset.is_some());
        out.offset = error.offset.unwrap_or(0);
        if !error.message.is_empty() {
            out.message = error.message.as_ptr();
        }
        out.message_length = error.message.len() as u64;
        Ok(())
    })
}

/// # Safety
/// A non-NULL document must be a live handle returned by emf_parse and must be freed exactly once.
#[no_mangle]
pub unsafe extern "C" fn emf_document_free(document: *mut EmfDocument) {
    if !document.is_null() {
        drop(Box::from_raw(document));
    }
}
/// # Safety
/// A non-NULL buffer must be a live returned buffer handle and must be freed exactly once.
#[no_mangle]
pub unsafe extern "C" fn emf_buffer_free(buffer: *mut EmfBuffer) {
    if !buffer.is_null() {
        drop(Box::from_raw(buffer));
    }
}
/// # Safety
/// A non-NULL error must be a live returned error handle and must be freed exactly once.
#[no_mangle]
pub unsafe extern "C" fn emf_error_free(error: *mut EmfError) {
    if !error.is_null() {
        drop(Box::from_raw(error));
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn resource_accessor_preserves_each_parse_limit_and_ignores_unrelated_failures() {
        use emf_core::LimitKind;
        let kinds = [
            LimitKind::InputBytes,
            LimitKind::RecordBytes,
            LimitKind::RecordCount,
            LimitKind::AllocatedBytes,
            LimitKind::WorkUnits,
            LimitKind::OutputBytes,
        ];
        for (index, kind) in kinds.into_iter().enumerate() {
            let failure = ParseFailure::LimitExceeded {
                kind,
                limit: 17,
                requested: 23,
            };
            let mut error = ptr::null_mut();
            unsafe {
                assert_eq!(run(&mut error, || Err(failure.into())), EMF_LIMIT_EXCEEDED);
                let mut info = EmfResourceInfo {
                    struct_size: size_of::<EmfResourceInfo>() as u32,
                    version: EMF_ABI_VERSION,
                    ..Default::default()
                };
                assert_eq!(emf_error_resource_view(error, &mut info), EMF_OK);
                assert_eq!((info.resource, info.limit, info.actual), (index as u32 + 1, 17, 23));
                emf_error_free(error);
            }
        }
        let mut error = ptr::null_mut();
        unsafe {
            assert_eq!(run(&mut error, || Err(Failure::invalid("work_units limit exceeded"))), EMF_INVALID_ARGUMENT);
            let mut info = EmfResourceInfo {
                struct_size: size_of::<EmfResourceInfo>() as u32,
                version: EMF_ABI_VERSION,
                ..Default::default()
            };
            assert_eq!(emf_error_resource_view(error, &mut info), EMF_OK);
            assert_eq!((info.resource, info.limit, info.actual), (0, 0, 0));
            assert_eq!(emf_error_resource_view(ptr::null(), &mut info), EMF_INVALID_ARGUMENT);
            assert_eq!(emf_error_resource_view(error, ptr::null_mut()), EMF_INVALID_ARGUMENT);
            info.struct_size = 8;
            assert_eq!(emf_error_resource_view(error, &mut info), EMF_INVALID_ARGUMENT);
            emf_error_free(error);
        }
    }

    #[test]
    fn serialization_limits_keep_their_status_and_detail_in_owned_errors() {
        let mut bytes = vec![0; 88];
        bytes[..4].copy_from_slice(&1u32.to_le_bytes());
        bytes[4..8].copy_from_slice(&88u32.to_le_bytes());
        bytes[40..44].copy_from_slice(&0x464d4520u32.to_le_bytes());
        let document = emf_core::parse(&bytes, &ParseLimits::default()).unwrap();
        assert_eq!(emf_core::serialize(&document).unwrap(), bytes);
        for (kind, requested, limits) in [
            (
                emf_core::LimitKind::OutputBytes,
                88,
                emf_core::SerializeLimits {
                    max_output_bytes: 0,
                    ..Default::default()
                },
            ),
            (
                emf_core::LimitKind::WorkUnits,
                2,
                emf_core::SerializeLimits {
                    max_work_units: 0,
                    ..Default::default()
                },
            ),
        ] {
            let failure = emf_core::serialize_with_limits(&document, &limits).unwrap_err();
            assert_eq!(
                failure,
                SerializeFailure::LimitExceeded {
                    kind,
                    limit: 0,
                    requested
                }
            );
            let expected = failure.to_string();
            let mut error = ptr::null_mut();
            unsafe {
                let status = run(&mut error, || Err(failure.into()));
                assert_eq!(status, EMF_LIMIT_EXCEEDED);
                assert!(!error.is_null());
                let mut info = EmfErrorInfo {
                    struct_size: size_of::<EmfErrorInfo>() as u32,
                    version: EMF_ABI_VERSION,
                    status: 0,
                    category: 0,
                    has_offset: 0,
                    reserved: 0,
                    offset: 0,
                    message: ptr::null(),
                    message_length: 0,
                };
                assert_eq!(emf_error_view(error, &mut info), EMF_OK);
                assert_eq!(info.status, EMF_LIMIT_EXCEEDED);
                assert_eq!(info.category, EMF_LIMIT_EXCEEDED as u32);
                assert_eq!(info.has_offset, 0);
                let message =
                    std::slice::from_raw_parts(info.message, info.message_length as usize);
                assert_eq!(message, expected.as_bytes());
                emf_error_free(error);
            }
        }
    }

    #[test]
    fn limit_ceilings_accept_full_usize_range_without_forming_memory_ranges() {
        let maximum = usize::MAX as u64;
        let supplied = EmfLimits {
            struct_size: size_of::<EmfLimits>() as u32,
            version: EMF_ABI_VERSION,
            max_input_bytes: maximum,
            max_record_bytes: maximum,
            max_records: maximum,
            max_allocated_bytes: maximum,
            max_work_units: u64::MAX,
        };
        let converted = unsafe { limits(&supplied) }
            .ok()
            .expect("usize ceilings are valid");
        assert_eq!(converted.max_input_bytes, usize::MAX);
        assert_eq!(converted.max_record_bytes, usize::MAX);
        assert_eq!(converted.max_records, usize::MAX);
        assert_eq!(converted.max_allocated_bytes, usize::MAX);
        assert_eq!(converted.max_work_units, u64::MAX);
        assert!(length(maximum, 1).is_err());
    }

    #[test]
    fn panic_is_contained_and_optional_error_is_reset() {
        let mut error = std::ptr::NonNull::<EmfError>::dangling().as_ptr();
        let status = unsafe { run(&mut error, || panic!("boundary regression")) };
        assert_eq!(status, EMF_INTERNAL_ERROR);
        assert!(error.is_null());
        assert_eq!(
            unsafe { run(ptr::null_mut(), || panic!("optional error")) },
            EMF_INTERNAL_ERROR
        );
        assert_eq!(unsafe { run(ptr::null_mut(), || Ok(())) }, EMF_OK);
    }
}

fn resource_code(kind: emf_core::LimitKind) -> u32 {
    match kind {
        emf_core::LimitKind::InputBytes => 1,
        emf_core::LimitKind::RecordBytes => 2,
        emf_core::LimitKind::RecordCount => 3,
        emf_core::LimitKind::AllocatedBytes => 4,
        emf_core::LimitKind::WorkUnits => 5,
        emf_core::LimitKind::OutputBytes => 6,
    }
}

/// # Safety
/// The error must be live; out_info must reference writable storage for its declared layout.
#[no_mangle]
pub unsafe extern "C" fn emf_error_resource_view(
    error: *const EmfError,
    out_info: *mut EmfResourceInfo,
) -> i32 {
    run(ptr::null_mut(), || {
        if out_info.is_null() {
            return Err(Failure::invalid("out_info is NULL"));
        }
        let struct_size = ptr::addr_of!((*out_info).struct_size).read();
        if struct_size as usize != size_of::<EmfResourceInfo>() {
            return Err(Failure::invalid("unsupported structure size"));
        }
        let version = ptr::addr_of!((*out_info).version).read();
        metadata::<EmfResourceInfo>(struct_size, version)?;
        let error = error
            .as_ref()
            .ok_or_else(|| Failure::invalid("error is NULL"))?;
        let (resource, limit, actual) = error.resource.unwrap_or((0, 0, 0));
        out_info.write(EmfResourceInfo {
            struct_size,
            version,
            resource,
            reserved: 0,
            limit,
            actual,
        });
        Ok(())
    })
}
