//! Shared real fuzz entry points, also executable by the stable corpus driver.
use emf_core::{emf_plus, wmf, ParseLimits};
use emf_ffi::*;
use std::{mem::size_of, ptr, slice};

pub const MAX_INPUT: usize = 8 * 1024 * 1024;
pub fn limits() -> ParseLimits {
    ParseLimits {
        max_input_bytes: MAX_INPUT,
        max_record_bytes: MAX_INPUT,
        max_records: 100_000,
        max_allocated_bytes: 64 * 1024 * 1024,
        max_work_units: 4 * 1024 * 1024,
    }
}

pub fn parse(data: &[u8]) {
    let limits = limits();
    let _ = emf_core::detect_format(data);
    if let Ok(document) = emf_core::parse(data, &limits) {
        // Exercise nested comments and typed object decoders within their budgets.
        let _ = document.structured_emf_plus(&limits);
    }
    let _ = wmf::parse(data, &limits);
    if let Ok(stream) = emf_plus::parse(data, &limits) {
        let _ = stream.object_definitions(&limits);
    }
}

pub fn serialize(data: &[u8]) {
    let limits = limits();
    if let Ok(document) = emf_core::parse(data, &limits) {
        let bytes = emf_core::serialize(&document).expect("unchanged EMF serializes");
        // Native framing retains recovered/unframed/trailing bytes too.
        assert_eq!(bytes, data);
        let reparsed = emf_core::parse(&bytes, &limits).expect("EMF reparses");
        assert_eq!(reparsed, document);
    }
    if let Ok(document) = wmf::parse(data, &limits) {
        let bytes = wmf::serialize(&document).expect("unchanged WMF serializes");
        assert_eq!(bytes, data);
        let reparsed = wmf::parse(&bytes, &limits).expect("WMF reparses");
        assert_eq!(wmf::serialize(&reparsed).unwrap(), bytes);
    }
    if let Ok(stream) = emf_plus::parse(data, &limits) {
        let bytes = emf_plus::serialize(&stream).expect("EMF+ serializes");
        let reparsed = emf_plus::parse(&bytes, &limits).expect("EMF+ reparses");
        // Typed serializers may canonicalize; assert the stable second encoding.
        assert_eq!(emf_plus::serialize(&reparsed).unwrap(), bytes);
    }
}

unsafe fn release_error(error: *mut EmfError, status: i32) {
    assert_ne!(status, EMF_INTERNAL_ERROR);
    if !error.is_null() {
        let mut info: EmfErrorInfo = std::mem::zeroed();
        info.struct_size = size_of::<EmfErrorInfo>() as u32;
        info.version = EMF_ABI_VERSION;
        assert_eq!(emf_error_view(error, &mut info), EMF_OK);
        assert_eq!(info.status, status);
        assert!(info.message_length <= 512);
        emf_error_free(error);
    }
}

unsafe fn buffer_bytes(buffer: *mut EmfBuffer) -> Vec<u8> {
    let mut data = ptr::null();
    let mut length = 0;
    assert_eq!(emf_buffer_view(buffer, &mut data, &mut length), EMF_OK);
    let bytes = if length == 0 {
        Vec::new()
    } else {
        assert!(!data.is_null());
        slice::from_raw_parts(data, length as usize).to_vec()
    };
    emf_buffer_free(buffer);
    bytes
}

pub fn ffi(data: &[u8]) {
    if data.len() > MAX_INPUT {
        return;
    }
    // Only valid owned allocations and null pointers. Fuzz bytes never become addresses.
    unsafe {
        let l = limits();
        let limits = EmfLimits {
            struct_size: size_of::<EmfLimits>() as u32,
            version: EMF_ABI_VERSION,
            max_input_bytes: l.max_input_bytes as u64,
            max_record_bytes: l.max_record_bytes as u64,
            max_records: l.max_records as u64,
            max_allocated_bytes: l.max_allocated_bytes as u64,
            max_work_units: l.max_work_units,
        };
        for length in [0, 1, u64::MAX] {
            let mut error = ptr::null_mut();
            let mut document = ptr::null_mut();
            let status = emf_parse(ptr::null(), length, &limits, &mut document, &mut error);
            assert_ne!(status, EMF_OK);
            assert!(document.is_null());
            release_error(error, status);
        }
        let mut error = ptr::null_mut();
        let status = emf_parse(
            data.as_ptr(),
            data.len() as u64,
            &limits,
            ptr::null_mut(),
            &mut error,
        );
        assert_eq!(status, EMF_INVALID_ARGUMENT);
        release_error(error, status);
        // Exercise the fuzz payload after the invalid-argument calls.
        let mut document = ptr::null_mut();
        let mut error = ptr::null_mut();
        let status = emf_parse(
            data.as_ptr(),
            data.len() as u64,
            &limits,
            &mut document,
            &mut error,
        );
        release_error(error, status);
        if status == EMF_OK {
            assert!(!document.is_null());
            let mut info = EmfInfo {
                struct_size: size_of::<EmfInfo>() as u32,
                version: EMF_ABI_VERSION,
                ..Default::default()
            };
            assert_eq!(emf_document_info(document, &mut info), EMF_OK);
            let mut count = 9;
            assert_eq!(
                emf_record_batch(document, 0, 0, ptr::null_mut(), &mut count),
                EMF_OK
            );
            assert_eq!(count, 0);
            let mut descriptor = EmfRecordDescriptor::default();
            let start = data.first().copied().unwrap_or(0) as u64;
            let status = emf_record_batch(document, start, 1, &mut descriptor, &mut count);
            assert_ne!(status, EMF_INTERNAL_ERROR);
            let mut buffer = ptr::null_mut();
            let mut error = ptr::null_mut();
            let status = emf_serialize(document, &mut buffer, &mut error);
            release_error(error, status);
            assert_eq!(status, EMF_OK);
            // Buffers own their memory after the document is freed.
            emf_document_free(document);
            assert_eq!(buffer_bytes(buffer), data);
        } else {
            assert!(document.is_null());
        }
        let mut wmf = ptr::null_mut();
        let mut error = ptr::null_mut();
        let status = emf_wmf_parse(
            data.as_ptr(),
            data.len() as u64,
            &limits,
            &mut wmf,
            &mut error,
        );
        release_error(error, status);
        if status == EMF_OK {
            let mut buffer = ptr::null_mut();
            let mut error = ptr::null_mut();
            let status = emf_wmf_serialize(wmf, &mut buffer, &mut error);
            release_error(error, status);
            assert_eq!(status, EMF_OK);
            emf_wmf_document_free(wmf);
            assert_eq!(buffer_bytes(buffer), data);
        } else {
            assert!(wmf.is_null());
        }
        // Every input, including rejected bytes, must leave the ABI usable.
        let mut control = [0u8; 108];
        for (offset, value) in [
            (0, 1u32),
            (4, 88),
            (40, 0x464d4520),
            (48, 108),
            (52, 2),
            (88, 14),
            (92, 20),
            (104, 20),
        ] {
            control[offset..offset + 4].copy_from_slice(&value.to_le_bytes());
        }
        let mut document = ptr::null_mut();
        let mut error = ptr::null_mut();
        let status = emf_parse(
            control.as_ptr(),
            control.len() as u64,
            &limits,
            &mut document,
            &mut error,
        );
        release_error(error, status);
        assert_eq!(status, EMF_OK, "valid control after fuzz payload");
        let mut buffer = ptr::null_mut();
        let mut error = ptr::null_mut();
        let status = emf_serialize(document, &mut buffer, &mut error);
        release_error(error, status);
        assert_eq!(status, EMF_OK);
        emf_document_free(document);
        assert_eq!(buffer_bytes(buffer), control);
        emf_document_free(ptr::null_mut());
        emf_wmf_document_free(ptr::null_mut());
        emf_buffer_free(ptr::null_mut());
        emf_error_free(ptr::null_mut());
    }
}
