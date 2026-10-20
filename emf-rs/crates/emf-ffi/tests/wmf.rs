use emf_ffi::*;
use std::{mem::size_of, ptr, slice};

fn source() -> Vec<u8> {
    let mut bytes = Vec::new();
    bytes.extend_from_slice(&1u16.to_le_bytes());
    bytes.extend_from_slice(&9u16.to_le_bytes());
    bytes.extend_from_slice(&0x300u16.to_le_bytes());
    bytes.extend_from_slice(&16u32.to_le_bytes());
    bytes.extend_from_slice(&0u16.to_le_bytes());
    bytes.extend_from_slice(&4u32.to_le_bytes());
    bytes.extend_from_slice(&0u16.to_le_bytes());
    bytes.extend_from_slice(&4u32.to_le_bytes());
    bytes.extend_from_slice(&0x103u16.to_le_bytes());
    bytes.extend_from_slice(&8u16.to_le_bytes());
    bytes.extend_from_slice(&3u32.to_le_bytes());
    bytes.extend_from_slice(&0u16.to_le_bytes());
    bytes.extend_from_slice(b"tail");
    bytes
}

unsafe fn serialized(doc: *const WmfDocument) -> Vec<u8> {
    let mut buffer = ptr::null_mut();
    assert_eq!(emf_wmf_serialize(doc, &mut buffer, ptr::null_mut()), EMF_OK);
    let mut data = ptr::null();
    let mut len = 0;
    assert_eq!(emf_buffer_view(buffer, &mut data, &mut len), EMF_OK);
    let bytes = slice::from_raw_parts(data, len as usize).to_vec();
    emf_buffer_free(buffer);
    bytes
}

#[test]
fn wmf_owned_handles_batch_original_bytes_and_edited_round_trip() {
    unsafe {
        let input = source();
        let mut doc = ptr::null_mut();
        assert_eq!(
            emf_wmf_parse(
                input.as_ptr(),
                input.len() as u64,
                ptr::null(),
                &mut doc,
                ptr::null_mut()
            ),
            EMF_OK
        );
        drop(input);
        let mut info = EmfInfo {
            struct_size: size_of::<EmfInfo>() as u32,
            version: EMF_ABI_VERSION,
            ..EmfInfo::default()
        };
        assert_eq!(emf_wmf_document_info(doc, &mut info), EMF_OK);
        assert_eq!(
            (
                info.format,
                info.record_count,
                info.header_bytes,
                info.has_eof,
                info.trailing_bytes,
                info.unframed_bytes
            ),
            (3, 2, 18, 1, 4, 0)
        );
        let mut descriptors = [EmfRecordDescriptor::default(); 2];
        let mut count = 99;
        assert_eq!(
            emf_wmf_record_batch(doc, 0, 2, descriptors.as_mut_ptr(), &mut count),
            EMF_OK
        );
        assert_eq!(count, 2);
        assert_eq!(
            (
                descriptors[0].offset,
                descriptors[0].byte_length,
                descriptors[0].type_id,
                descriptors[1].family
            ),
            (18, 8, 0x103, 1)
        );
        assert_eq!(
            emf_wmf_record_batch(doc, 2, 0, ptr::null_mut(), &mut count),
            EMF_OK
        );
        assert_eq!(count, 0);
        assert_eq!(
            emf_wmf_record_batch(doc, 3, 0, ptr::null_mut(), &mut count),
            EMF_INVALID_ARGUMENT
        );
        assert_eq!(count, 0);
        assert_eq!(serialized(doc), source());
        let replacement = [2u8, 0, 99, 0];
        assert_eq!(
            emf_wmf_replace_record(doc, 0, 0x999, replacement.as_ptr(), 4, ptr::null_mut()),
            EMF_OK
        );
        let edited = serialized(doc);
        assert_eq!(u32::from_le_bytes(edited[6..10].try_into().unwrap()), 17); // The header excludes the opaque tail.
        assert_eq!(&edited[22..28], &[0x99, 9, 2, 0, 99, 0]);
        assert_eq!(&edited[edited.len() - 4..], b"tail");
        let mut raw = ptr::null_mut();
        assert_eq!(
            emf_wmf_record_bytes(doc, 0, &mut raw, ptr::null_mut()),
            EMF_OK
        );
        emf_wmf_document_free(doc);
        let mut data = ptr::null();
        let mut len = 0;
        assert_eq!(emf_buffer_view(raw, &mut data, &mut len), EMF_OK);
        assert_eq!(slice::from_raw_parts(data, len as usize), &source()[18..26]);
        emf_buffer_free(raw);
    }
}

#[test]
fn invalid_edits_and_invalid_handles_preserve_outputs_and_source() {
    unsafe {
        let bytes = source();
        let mut doc = ptr::null_mut();
        assert_eq!(
            emf_wmf_parse(
                bytes.as_ptr(),
                bytes.len() as u64,
                ptr::null(),
                &mut doc,
                ptr::null_mut()
            ),
            EMF_OK
        );
        for (index, function, body) in [
            (0, 0x10000, vec![]),
            (2, 1, vec![]),
            (0, 1, vec![1]),
            (0, 0, vec![1, 2]),
        ] {
            assert_eq!(
                emf_wmf_replace_record(
                    doc,
                    index,
                    function,
                    body.as_ptr(),
                    body.len() as u64,
                    ptr::null_mut()
                ),
                EMF_INVALID_ARGUMENT
            );
            assert_eq!(serialized(doc), bytes);
        }
        emf_wmf_document_free(doc);
        emf_wmf_document_free(ptr::null_mut());
        let mut buffer = std::ptr::NonNull::<EmfBuffer>::dangling().as_ptr();
        assert_eq!(
            emf_wmf_serialize(ptr::null(), &mut buffer, ptr::null_mut()),
            EMF_INVALID_ARGUMENT
        );
        assert!(buffer.is_null());
        let mut err = ptr::null_mut();
        let mut invalid = std::ptr::NonNull::<WmfDocument>::dangling().as_ptr();
        assert_eq!(
            emf_wmf_parse(ptr::null(), 1, ptr::null(), &mut invalid, &mut err),
            EMF_INVALID_ARGUMENT
        );
        assert!(invalid.is_null());
        assert!(!err.is_null());
        emf_error_free(err);
    }
}

#[test]
fn wmf_parse_honors_limits_and_distinguishes_unframed_tail() {
    unsafe {
        let mut bytes = source();
        let mut doc = ptr::null_mut();
        let limits = EmfLimits {
            struct_size: size_of::<EmfLimits>() as u32,
            version: EMF_ABI_VERSION,
            max_input_bytes: 1,
            max_record_bytes: 100,
            max_records: 10,
            max_allocated_bytes: 10000,
            max_work_units: 1000,
        };
        assert_eq!(
            emf_wmf_parse(
                bytes.as_ptr(),
                bytes.len() as u64,
                &limits,
                &mut doc,
                ptr::null_mut()
            ),
            EMF_LIMIT_EXCEEDED
        );
        assert!(doc.is_null());
        bytes.truncate(28); // Partial EOF header retained as an unframed suffix.
        assert_eq!(
            emf_wmf_parse(
                bytes.as_ptr(),
                bytes.len() as u64,
                ptr::null(),
                &mut doc,
                ptr::null_mut()
            ),
            EMF_OK
        );
        let mut info = EmfInfo {
            struct_size: size_of::<EmfInfo>() as u32,
            version: EMF_ABI_VERSION,
            ..EmfInfo::default()
        };
        assert_eq!(emf_wmf_document_info(doc, &mut info), EMF_OK);
        assert_eq!(
            (info.has_eof, info.trailing_bytes, info.unframed_bytes),
            (0, 0, 2)
        );
        assert_eq!(serialized(doc), bytes);
        emf_wmf_document_free(doc);
    }
}

#[test]
fn placeable_metadata_and_prefix_survive_record_edits() {
    unsafe {
        let mut bytes = 0x9ac6cdd7u32.to_le_bytes().to_vec();
        bytes.extend_from_slice(&[0; 16]);
        let checksum = bytes.chunks_exact(2).fold(0u16, |sum, pair| {
            sum ^ u16::from_le_bytes([pair[0], pair[1]])
        });
        bytes.extend_from_slice(&checksum.to_le_bytes());
        bytes.extend_from_slice(&source());
        let mut doc = ptr::null_mut();
        assert_eq!(
            emf_wmf_parse(
                bytes.as_ptr(),
                bytes.len() as u64,
                ptr::null(),
                &mut doc,
                ptr::null_mut()
            ),
            EMF_OK
        );
        let mut info = EmfInfo {
            struct_size: size_of::<EmfInfo>() as u32,
            version: EMF_ABI_VERSION,
            ..EmfInfo::default()
        };
        assert_eq!(emf_wmf_document_info(doc, &mut info), EMF_OK);
        assert_eq!(
            (info.format, info.header_bytes, info.record_count),
            (2, 40, 2)
        );
        assert_eq!(serialized(doc), bytes);
        let payload = [5, 0];
        assert_eq!(
            emf_wmf_replace_record(doc, 0, 0x103, payload.as_ptr(), 2, ptr::null_mut()),
            EMF_OK
        );
        let edited = serialized(doc);
        assert_eq!(&edited[..22], &bytes[..22]);
        assert_eq!(&edited[48..], &bytes[48..]);
        assert_eq!(&edited[46..48], &payload);
        emf_wmf_document_free(doc);
    }
}
