use emf_ffi::*;
use std::{mem::size_of, ptr};

fn header() -> Vec<u8> {
    let mut bytes = vec![0; 88];
    bytes[..4].copy_from_slice(&1u32.to_le_bytes());
    bytes[4..8].copy_from_slice(&88u32.to_le_bytes());
    bytes[40..44].copy_from_slice(&0x464d4520u32.to_le_bytes());
    bytes
}

fn info() -> EmfInfo {
    EmfInfo {
        struct_size: size_of::<EmfInfo>() as u32,
        version: EMF_ABI_VERSION,
        ..Default::default()
    }
}

#[test]
fn limits_cross_the_abi_without_becoming_defaults() {
    let bytes = header();
    let defaults = emf_core::ParseLimits::default();
    let defaults = EmfLimits {
        struct_size: size_of::<EmfLimits>() as u32,
        version: EMF_ABI_VERSION,
        max_input_bytes: defaults.max_input_bytes as u64,
        max_record_bytes: defaults.max_record_bytes as u64,
        max_records: defaults.max_records as u64,
        max_allocated_bytes: defaults.max_allocated_bytes as u64,
        max_work_units: defaults.max_work_units,
    };
    let mut cases = [defaults; 5];
    cases[0].max_input_bytes = 0;
    cases[1].max_record_bytes = 0;
    cases[2].max_records = 0;
    cases[3].max_allocated_bytes = 0;
    cases[4].max_work_units = 0;
    for limits in cases {
        let mut document = ptr::null_mut();
        let mut error = ptr::null_mut();
        unsafe {
            assert_eq!(
                emf_parse(
                    bytes.as_ptr(),
                    bytes.len() as u64,
                    &limits,
                    &mut document,
                    &mut error
                ),
                EMF_LIMIT_EXCEEDED
            );
            assert!(document.is_null());
            assert!(!error.is_null());
            emf_error_free(error);
        }
    }
    let mut document = ptr::null_mut();
    unsafe {
        assert_eq!(
            emf_parse(
                bytes.as_ptr(),
                bytes.len() as u64,
                &defaults,
                &mut document,
                ptr::null_mut()
            ),
            EMF_OK
        );
        emf_document_free(document);
    }
}

#[test]
fn recoverable_tail_is_reported_and_preserved() {
    let mut bytes = header();
    bytes.extend_from_slice(&[0xfe, 0, 0, 0, 7, 0, 0, 0, 0xff]);
    let mut document = ptr::null_mut();
    let mut buffer = ptr::null_mut();
    let mut metadata = info();
    unsafe {
        assert_eq!(
            emf_parse(
                bytes.as_ptr(),
                bytes.len() as u64,
                ptr::null(),
                &mut document,
                ptr::null_mut()
            ),
            EMF_OK
        );
        assert_eq!(emf_document_info(document, &mut metadata), EMF_OK);
        assert_eq!(
            (
                metadata.record_count,
                metadata.diagnostic_count,
                metadata.has_eof
            ),
            (0, 1, 0)
        );
        assert_eq!((metadata.unframed_bytes, metadata.trailing_bytes), (9, 0));
        assert_eq!(
            emf_serialize(document, &mut buffer, ptr::null_mut()),
            EMF_OK
        );
        emf_document_free(document);
        let mut data = ptr::null();
        let mut length = 0;
        assert_eq!(emf_buffer_view(buffer, &mut data, &mut length), EMF_OK);
        assert_eq!(std::slice::from_raw_parts(data, length as usize), bytes);
        emf_buffer_free(buffer);
    }
}

#[test]
fn truncation_error_exposes_an_owned_offset_and_message() {
    let bytes = header()[..44].to_vec();
    let mut document = ptr::null_mut();
    let mut error = ptr::null_mut();
    unsafe {
        assert_eq!(
            emf_parse(
                bytes.as_ptr(),
                bytes.len() as u64,
                ptr::null(),
                &mut document,
                &mut error
            ),
            EMF_FORMAT_ERROR
        );
        drop(bytes);
        let mut details = EmfErrorInfo {
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
        assert_eq!(emf_error_view(error, &mut details), EMF_OK);
        assert_eq!(
            (details.status, details.has_offset, details.offset),
            (EMF_FORMAT_ERROR, 1, 44)
        );
        let message = std::slice::from_raw_parts(details.message, details.message_length as usize);
        assert!(std::str::from_utf8(message).unwrap().contains("44"));
        emf_error_free(error);
    }
}

#[test]
fn rejected_metadata_is_not_overwritten() {
    let bytes = header();
    let mut document = ptr::null_mut();
    let mut error = ptr::null_mut();
    unsafe {
        assert_eq!(
            emf_parse(
                bytes.as_ptr(),
                bytes.len() as u64,
                ptr::null(),
                &mut document,
                ptr::null_mut()
            ),
            EMF_OK
        );
        assert_eq!(
            emf_parse(
                ptr::null(),
                0,
                ptr::null(),
                &mut ptr::null_mut(),
                &mut error
            ),
            EMF_FORMAT_ERROR
        );
        for (size, version) in [(0, EMF_ABI_VERSION), (size_of::<EmfInfo>() as u32, 0)] {
            let mut metadata = EmfInfo {
                struct_size: size,
                version,
                record_count: 123,
                ..Default::default()
            };
            assert_eq!(
                emf_document_info(document, &mut metadata),
                EMF_INVALID_ARGUMENT
            );
            assert_eq!(
                (
                    metadata.struct_size,
                    metadata.version,
                    metadata.record_count
                ),
                (size, version, 123)
            );
        }
        for (size, version) in [(0, EMF_ABI_VERSION), (size_of::<EmfErrorInfo>() as u32, 0)] {
            let mut details = EmfErrorInfo {
                struct_size: size,
                version,
                status: 123,
                category: 0,
                has_offset: 0,
                reserved: 0,
                offset: 0,
                message: ptr::null(),
                message_length: 0,
            };
            assert_eq!(emf_error_view(error, &mut details), EMF_INVALID_ARGUMENT);
            assert_eq!(
                (details.struct_size, details.version, details.status),
                (size, version, 123)
            );
        }
        emf_error_free(error);
        emf_document_free(document);
    }
}
