//! Ownership, lifetime and panic-boundary contract of the C ABI (see include/emf.h).
//!
//! Contract recap: every export clears its output handles on entry; NULL handles
//! are invalid arguments; the three `*_free` functions accept NULL but a live
//! handle must be freed exactly once (double free is forbidden, so it is never
//! exercised here); returned buffers/errors own their bytes independently of the
//! document and of the caller's input. Panics are caught by the private `run`
//! helper (unit-tested in src/lib.rs). An integration test cannot inject a panic,
//! so panic containment is covered by driving every export with hostile
//! arguments: a panic escaping an `extern "C"` fn aborts the test process.
use emf_ffi::*;
use std::{
    collections::BTreeSet,
    fs,
    mem::size_of,
    path::{Path, PathBuf},
    ptr, slice,
};

const DANGLING_BUFFER: *mut EmfBuffer = 8 as *mut EmfBuffer;
const DANGLING_ERROR: *mut EmfError = 8 as *mut EmfError;
const DANGLING_DOC: *mut EmfDocument = 8 as *mut EmfDocument;
const DANGLING_WMF: *mut WmfDocument = 8 as *mut WmfDocument;

fn emf_bytes() -> Vec<u8> {
    let mut bytes = vec![0; 88];
    bytes[..4].copy_from_slice(&1u32.to_le_bytes());
    bytes[4..8].copy_from_slice(&88u32.to_le_bytes());
    bytes[40..44].copy_from_slice(&0x464d4520u32.to_le_bytes());
    // SETMAPMODE then EOF.
    bytes.extend_from_slice(&17u32.to_le_bytes());
    bytes.extend_from_slice(&12u32.to_le_bytes());
    bytes.extend_from_slice(&8u32.to_le_bytes());
    bytes.extend_from_slice(&14u32.to_le_bytes());
    bytes.extend_from_slice(&20u32.to_le_bytes());
    bytes.extend_from_slice(&0u32.to_le_bytes());
    bytes.extend_from_slice(&16u32.to_le_bytes());
    bytes.extend_from_slice(&20u32.to_le_bytes());
    bytes
}

fn wmf_bytes() -> Vec<u8> {
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
    bytes
}

fn info() -> EmfInfo {
    EmfInfo {
        struct_size: size_of::<EmfInfo>() as u32,
        version: EMF_ABI_VERSION,
        ..Default::default()
    }
}

fn error_info() -> EmfErrorInfo {
    EmfErrorInfo {
        struct_size: size_of::<EmfErrorInfo>() as u32,
        version: EMF_ABI_VERSION,
        status: 0,
        category: 0,
        has_offset: 0,
        reserved: 0,
        offset: 0,
        message: ptr::null(),
        message_length: 0,
    }
}

fn plus_options() -> EmfPlusSnapshotOptions {
    EmfPlusSnapshotOptions {
        struct_size: size_of::<EmfPlusSnapshotOptions>() as u32,
        version: 1,
        max_output_bytes: 1 << 20,
    }
}

unsafe fn parse_emf(bytes: &[u8]) -> *mut EmfDocument {
    let mut doc = ptr::null_mut();
    assert_eq!(
        emf_parse(
            bytes.as_ptr(),
            bytes.len() as u64,
            ptr::null(),
            &mut doc,
            ptr::null_mut()
        ),
        EMF_OK
    );
    assert!(!doc.is_null());
    doc
}

unsafe fn parse_wmf(bytes: &[u8]) -> *mut WmfDocument {
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
    assert!(!doc.is_null());
    doc
}

/// Copies a buffer's bytes out and frees it (exactly once).
unsafe fn take(buffer: *mut EmfBuffer) -> Vec<u8> {
    assert!(!buffer.is_null());
    let mut data = ptr::null();
    let mut len = 0;
    assert_eq!(emf_buffer_view(buffer, &mut data, &mut len), EMF_OK);
    let bytes = slice::from_raw_parts(data, len as usize).to_vec();
    emf_buffer_free(buffer);
    bytes
}

/// Reads an error's status and message, then frees it (exactly once).
unsafe fn take_error(error: *mut EmfError) -> (i32, String) {
    assert!(!error.is_null());
    let mut view = error_info();
    assert_eq!(emf_error_view(error, &mut view), EMF_OK);
    let message = if view.message.is_null() {
        String::new()
    } else {
        String::from_utf8(
            slice::from_raw_parts(view.message, view.message_length as usize).to_vec(),
        )
        .expect("error message is UTF-8")
    };
    assert_eq!(view.category, view.status as u32);
    emf_error_free(error);
    (view.status, message)
}

// ---------------------------------------------------------------------------
// Export list parity
// ---------------------------------------------------------------------------

fn rust_files(dir: &Path, out: &mut Vec<PathBuf>) {
    for entry in fs::read_dir(dir).unwrap() {
        let path = entry.unwrap().path();
        if path.is_dir() {
            rust_files(&path, out);
        } else if path.extension().is_some_and(|e| e == "rs") {
            out.push(path);
        }
    }
}

fn exports_in_source() -> BTreeSet<String> {
    let mut files = Vec::new();
    rust_files(
        &Path::new(env!("CARGO_MANIFEST_DIR")).join("src"),
        &mut files,
    );
    let mut names = BTreeSet::new();
    for file in files {
        let text = fs::read_to_string(&file).unwrap();
        assert!(
            !text.contains("export_name") && !text.contains("unsafe(no_mangle)"),
            "{} uses an export form this parity test does not understand",
            file.display()
        );
        let mut lines = text.lines();
        while let Some(line) = lines.next() {
            if line.trim() != "#[no_mangle]" {
                continue;
            }
            // The next line carrying `fn` names the export (attributes/docs may intervene).
            let declaration = lines
                .by_ref()
                .find(|l| l.contains("fn "))
                .expect("#[no_mangle] without a function");
            let after = declaration.split("fn ").nth(1).unwrap();
            let name: String = after
                .chars()
                .take_while(|c| c.is_ascii_alphanumeric() || *c == '_')
                .collect();
            assert!(
                declaration.contains("extern \"C\""),
                "{name} is not extern \"C\""
            );
            assert!(names.insert(name.clone()), "{name} exported twice");
        }
    }
    names
}

fn exports_in_header() -> BTreeSet<String> {
    let text =
        fs::read_to_string(Path::new(env!("CARGO_MANIFEST_DIR")).join("include/emf.h")).unwrap();
    // Drop comments and preprocessor lines, then look at `;`-terminated statements.
    let mut stripped = String::new();
    let mut rest = text.as_str();
    while let Some(start) = rest.find("/*") {
        stripped.push_str(&rest[..start]);
        let end = rest[start..].find("*/").expect("unterminated comment") + start + 2;
        rest = &rest[end..];
    }
    stripped.push_str(rest);
    let code: String = stripped
        .lines()
        .filter(|l| !l.trim_start().starts_with('#'))
        .collect::<Vec<_>>()
        .join("\n");
    let mut names = BTreeSet::new();
    let mut statement = String::new();
    let mut depth = 0i32;
    // Whether each open brace was a transparent `extern "C" {` linkage block.
    let mut linkage = Vec::new();
    for ch in code.chars() {
        match ch {
            '{' if depth == 0 && statement.trim_end().ends_with("extern \"C\"") => {
                statement.clear();
                linkage.push(true);
            }
            '{' => {
                depth += 1;
                linkage.push(false);
            }
            '}' => {
                if linkage.pop() == Some(false) {
                    depth -= 1;
                }
            }
            ';' if depth == 0 => {
                let text = statement.trim().to_string();
                statement.clear();
                if text.starts_with("typedef") {
                    continue;
                }
                let mut words = text.split_whitespace();
                if !matches!(
                    words.next(),
                    Some("int32_t") | Some("uint32_t") | Some("void")
                ) {
                    continue;
                }
                let name = text
                    .split('(')
                    .next()
                    .unwrap()
                    .split_whitespace()
                    .last()
                    .unwrap()
                    .to_string();
                assert!(names.insert(name.clone()), "{name} declared twice");
            }
            _ if depth == 0 => statement.push(ch),
            _ => {}
        }
    }
    names
}

#[test]
fn header_export_list_equals_no_mangle_exports_in_src() {
    let header = exports_in_header();
    let source = exports_in_source();
    assert!(header.len() >= 25, "header parse found only {header:?}");
    assert!(header.contains("emf_buffer_free") && header.contains("emf_wmf_rejection"));
    assert!(header.iter().all(|n| n.starts_with("emf_")), "{header:?}");
    let missing_from_header: Vec<_> = source.difference(&header).collect();
    let missing_from_source: Vec<_> = header.difference(&source).collect();
    assert!(
        missing_from_header.is_empty() && missing_from_source.is_empty(),
        "exported but not in emf.h: {missing_from_header:?}; declared but not exported: {missing_from_source:?}"
    );
}

// ---------------------------------------------------------------------------
// Free functions: emf_document_free / emf_wmf_document_free / emf_buffer_free / emf_error_free
// ---------------------------------------------------------------------------

#[test]
fn free_functions_accept_null() {
    unsafe {
        emf_document_free(ptr::null_mut());
        emf_wmf_document_free(ptr::null_mut());
        emf_buffer_free(ptr::null_mut());
        emf_error_free(ptr::null_mut());
        // Repeated NULL frees are defined too (the only repeated free that is).
        emf_document_free(ptr::null_mut());
        emf_buffer_free(ptr::null_mut());
    }
}

#[test]
fn free_after_failed_calls_is_safe_for_cleared_outputs() {
    // After any failure the output handle slots are NULL, so the caller's
    // unconditional cleanup path (free(NULL)) is the defined way to unwind.
    unsafe {
        let mut doc = DANGLING_DOC;
        let mut error = DANGLING_ERROR;
        assert_eq!(
            emf_parse(ptr::null(), 4, ptr::null(), &mut doc, &mut error),
            EMF_INVALID_ARGUMENT
        );
        assert!(doc.is_null());
        emf_document_free(doc);
        let (status, message) = take_error(error);
        assert_eq!(status, EMF_INVALID_ARGUMENT);
        assert!(message.contains("NULL"));

        let mut wmf = DANGLING_WMF;
        let mut error = DANGLING_ERROR;
        assert_eq!(
            emf_wmf_parse(ptr::null(), 4, ptr::null(), &mut wmf, &mut error),
            EMF_INVALID_ARGUMENT
        );
        assert!(wmf.is_null());
        emf_wmf_document_free(wmf);
        assert_eq!(take_error(error).0, EMF_INVALID_ARGUMENT);
    }
}

// ---------------------------------------------------------------------------
// NULL / invalid handles and output reset
// ---------------------------------------------------------------------------

#[test]
fn emf_abi_version_matches_header() {
    assert_eq!(emf_abi_version(), 1);
    assert_eq!(emf_abi_version(), EMF_ABI_VERSION);
}

#[test]
fn emf_detect_clears_outputs_and_rejects_null_arguments() {
    unsafe {
        let bytes = emf_bytes();
        let mut format = 99u32;
        let mut error = DANGLING_ERROR;
        assert_eq!(
            emf_detect(bytes.as_ptr(), bytes.len() as u64, &mut format, &mut error),
            EMF_OK
        );
        assert_eq!((format, error), (1, ptr::null_mut()));

        let mut format = 99u32;
        let mut error = DANGLING_ERROR;
        assert_eq!(
            emf_detect(ptr::null(), 4, &mut format, &mut error),
            EMF_INVALID_ARGUMENT
        );
        assert_eq!(format, 0);
        assert_eq!(take_error(error).0, EMF_INVALID_ARGUMENT);

        let mut error = DANGLING_ERROR;
        assert_eq!(
            emf_detect(bytes.as_ptr(), 4, ptr::null_mut(), &mut error),
            EMF_INVALID_ARGUMENT
        );
        assert_eq!(take_error(error).0, EMF_INVALID_ARGUMENT);

        // out_error is optional.
        assert_eq!(
            emf_detect(ptr::null(), 4, ptr::null_mut(), ptr::null_mut()),
            EMF_INVALID_ARGUMENT
        );
        // Length beyond the address space is an argument error, not a panic.
        let mut format = 0;
        assert_eq!(
            emf_detect(bytes.as_ptr(), u64::MAX, &mut format, ptr::null_mut()),
            EMF_INVALID_ARGUMENT
        );
    }
}

#[test]
fn emf_parse_clears_outputs_and_validates_limits() {
    unsafe {
        let bytes = emf_bytes();
        let mut error = DANGLING_ERROR;
        assert_eq!(
            emf_parse(
                bytes.as_ptr(),
                bytes.len() as u64,
                ptr::null(),
                ptr::null_mut(),
                &mut error
            ),
            EMF_INVALID_ARGUMENT
        );
        assert_eq!(take_error(error).0, EMF_INVALID_ARGUMENT);

        let bad = EmfLimits {
            struct_size: 1,
            version: EMF_ABI_VERSION,
            max_input_bytes: 1,
            max_record_bytes: 1,
            max_records: 1,
            max_allocated_bytes: 1,
            max_work_units: 1,
        };
        let mut doc = DANGLING_DOC;
        let mut error = DANGLING_ERROR;
        assert_eq!(
            emf_parse(
                bytes.as_ptr(),
                bytes.len() as u64,
                &bad,
                &mut doc,
                &mut error
            ),
            EMF_INVALID_ARGUMENT
        );
        assert!(doc.is_null());
        assert_eq!(take_error(error).0, EMF_INVALID_ARGUMENT);

        let wrong_version = EmfLimits {
            struct_size: size_of::<EmfLimits>() as u32,
            version: 2,
            ..bad
        };
        let mut doc = DANGLING_DOC;
        assert_eq!(
            emf_parse(
                bytes.as_ptr(),
                bytes.len() as u64,
                &wrong_version,
                &mut doc,
                ptr::null_mut()
            ),
            EMF_INVALID_ARGUMENT
        );
        assert!(doc.is_null());

        // Zero length accepts NULL data and fails as a format error, not an argument error.
        let mut doc = DANGLING_DOC;
        let mut error = DANGLING_ERROR;
        assert_eq!(
            emf_parse(ptr::null(), 0, ptr::null(), &mut doc, &mut error),
            EMF_FORMAT_ERROR
        );
        assert!(doc.is_null());
        assert_eq!(take_error(error).0, EMF_FORMAT_ERROR);
    }
}

#[test]
fn emf_wmf_parse_clears_outputs_and_rejects_null_arguments() {
    unsafe {
        let bytes = wmf_bytes();
        let mut error = DANGLING_ERROR;
        assert_eq!(
            emf_wmf_parse(
                bytes.as_ptr(),
                bytes.len() as u64,
                ptr::null(),
                ptr::null_mut(),
                &mut error
            ),
            EMF_INVALID_ARGUMENT
        );
        assert_eq!(take_error(error).0, EMF_INVALID_ARGUMENT);
        let mut doc = DANGLING_WMF;
        assert_eq!(
            emf_wmf_parse(ptr::null(), 10, ptr::null(), &mut doc, ptr::null_mut()),
            EMF_INVALID_ARGUMENT
        );
        assert!(doc.is_null());
        // EMF bytes are not WMF: a clean status, outputs still cleared.
        let emf = emf_bytes();
        let mut doc = DANGLING_WMF;
        assert_ne!(
            emf_wmf_parse(
                emf.as_ptr(),
                emf.len() as u64,
                ptr::null(),
                &mut doc,
                ptr::null_mut()
            ),
            EMF_OK
        );
        assert!(doc.is_null());
    }
}

#[test]
fn emf_document_info_and_wmf_document_info_reject_null_and_preserve_layout_fields() {
    unsafe {
        let mut out = info();
        assert_eq!(
            emf_document_info(ptr::null(), &mut out),
            EMF_INVALID_ARGUMENT
        );
        // Metadata fields were validated and survive; payload fields are zeroed.
        assert_eq!(
            (out.struct_size, out.version, out.record_count),
            (size_of::<EmfInfo>() as u32, 1, 0)
        );
        assert_eq!(
            emf_wmf_document_info(ptr::null(), &mut out),
            EMF_INVALID_ARGUMENT
        );
        let doc = parse_emf(&emf_bytes());
        assert_eq!(
            emf_document_info(doc, ptr::null_mut()),
            EMF_INVALID_ARGUMENT
        );
        let mut bad = info();
        bad.struct_size += 1;
        assert_eq!(emf_document_info(doc, &mut bad), EMF_INVALID_ARGUMENT);
        assert_eq!(bad.record_count, 0);
        let mut ok = info();
        assert_eq!(emf_document_info(doc, &mut ok), EMF_OK);
        assert_eq!((ok.format, ok.has_eof, ok.record_count), (1, 1, 2));
        emf_document_free(doc);

        let wmf = parse_wmf(&wmf_bytes());
        assert_eq!(
            emf_wmf_document_info(wmf, ptr::null_mut()),
            EMF_INVALID_ARGUMENT
        );
        let mut bad = info();
        bad.version = 7;
        assert_eq!(emf_wmf_document_info(wmf, &mut bad), EMF_INVALID_ARGUMENT);
        let mut ok = info();
        assert_eq!(emf_wmf_document_info(wmf, &mut ok), EMF_OK);
        assert_eq!(ok.format, 3);
        emf_wmf_document_free(wmf);
    }
}

#[test]
fn emf_record_batch_and_wmf_record_batch_follow_the_start_and_capacity_contract() {
    unsafe {
        let mut count = 99;
        assert_eq!(
            emf_record_batch(ptr::null(), 0, 0, ptr::null_mut(), &mut count),
            EMF_INVALID_ARGUMENT
        );
        assert_eq!(count, 0);
        assert_eq!(
            emf_wmf_record_batch(ptr::null(), 0, 0, ptr::null_mut(), &mut count),
            EMF_INVALID_ARGUMENT
        );

        let doc = parse_emf(&emf_bytes());
        assert_eq!(
            emf_record_batch(doc, 0, 0, ptr::null_mut(), ptr::null_mut()),
            EMF_INVALID_ARGUMENT
        );
        // capacity zero permits NULL descriptors; start == record_count is empty success.
        count = 99;
        assert_eq!(
            emf_record_batch(doc, 2, 0, ptr::null_mut(), &mut count),
            EMF_OK
        );
        assert_eq!(count, 0);
        // start past the end, and non-zero capacity with NULL descriptors, are invalid and clear count.
        count = 99;
        assert_eq!(
            emf_record_batch(doc, 3, 1, ptr::null_mut(), &mut count),
            EMF_INVALID_ARGUMENT
        );
        assert_eq!(count, 0);
        count = 99;
        assert_eq!(
            emf_record_batch(doc, 0, 1, ptr::null_mut(), &mut count),
            EMF_INVALID_ARGUMENT
        );
        assert_eq!(count, 0);
        // Overflowing start/capacity are argument errors.
        assert_eq!(
            emf_record_batch(doc, u64::MAX, 0, ptr::null_mut(), &mut count),
            EMF_INVALID_ARGUMENT
        );
        assert_eq!(
            emf_record_batch(doc, 0, u64::MAX, ptr::null_mut(), &mut count),
            EMF_INVALID_ARGUMENT
        );
        // At most `capacity` descriptors are written; the slot after is untouched.
        let mut slots = [EmfRecordDescriptor::default(); 3];
        count = 99;
        assert_eq!(
            emf_record_batch(doc, 0, 2, slots.as_mut_ptr(), &mut count),
            EMF_OK
        );
        assert_eq!(count, 2);
        assert_eq!(
            (slots[0].index, slots[1].index, slots[2].struct_size),
            (0, 1, 0)
        );
        emf_document_free(doc);

        let wmf = parse_wmf(&wmf_bytes());
        let mut slots = [EmfRecordDescriptor::default(); 4];
        assert_eq!(
            emf_wmf_record_batch(wmf, 0, 4, slots.as_mut_ptr(), &mut count),
            EMF_OK
        );
        assert!((1..4).contains(&count));
        assert_eq!(
            emf_wmf_record_batch(wmf, count + 1, 1, slots.as_mut_ptr(), &mut count),
            EMF_INVALID_ARGUMENT
        );
        assert_eq!(count, 0);
        emf_wmf_document_free(wmf);
    }
}

/// Document-taking exports returning an owned buffer; the first argument is a
/// handle cast to whatever the export expects (NULL here, so the kind is moot).
type Call = Box<dyn Fn(*mut *mut EmfBuffer, *mut *mut EmfError) -> i32>;

fn buffer_exports_with_null_document() -> Vec<(&'static str, Call)> {
    let opts = Box::leak(Box::new(plus_options())) as *const EmfPlusSnapshotOptions;
    vec![
        (
            "emf_document_snapshot",
            Box::new(|b, e| unsafe { emf_document_snapshot(ptr::null(), b, e) }),
        ),
        (
            "emf_record_bytes",
            Box::new(|b, e| unsafe { emf_record_bytes(ptr::null(), 0, b, e) }),
        ),
        (
            "emf_serialize",
            Box::new(|b, e| unsafe { emf_serialize(ptr::null(), b, e) }),
        ),
        (
            "emf_wmf_record_bytes",
            Box::new(|b, e| unsafe { emf_wmf_record_bytes(ptr::null(), 0, b, e) }),
        ),
        (
            "emf_wmf_serialize",
            Box::new(|b, e| unsafe { emf_wmf_serialize(ptr::null(), b, e) }),
        ),
        (
            "emf_wmf_document_snapshot",
            Box::new(|b, e| unsafe { emf_wmf_document_snapshot(ptr::null(), b, e) }),
        ),
        (
            "emf_wmf_record_view",
            Box::new(|b, e| unsafe { emf_wmf_record_view(ptr::null(), 0, ptr::null(), b, e) }),
        ),
        (
            "emf_wmf_embedded_emf",
            Box::new(|b, e| unsafe { emf_wmf_embedded_emf(ptr::null(), ptr::null(), b, e) }),
        ),
        (
            "emf_document_emf_plus_snapshot_v1",
            Box::new(move |b, e| unsafe {
                emf_document_emf_plus_snapshot_v1(ptr::null(), opts, ptr::null(), b, e)
            }),
        ),
    ]
}

#[test]
fn every_buffer_export_rejects_a_null_document_and_resets_outputs() {
    unsafe {
        for (name, call) in buffer_exports_with_null_document() {
            let mut buffer = DANGLING_BUFFER;
            let mut error = DANGLING_ERROR;
            assert_eq!(
                call(&mut buffer, &mut error),
                EMF_INVALID_ARGUMENT,
                "{name}"
            );
            assert!(buffer.is_null(), "{name} left out_buffer set");
            let (status, message) = take_error(error);
            assert_eq!(status, EMF_INVALID_ARGUMENT, "{name}");
            assert!(message.contains("NULL"), "{name}: {message}");
            // out_error is optional.
            let mut buffer = DANGLING_BUFFER;
            assert_eq!(
                call(&mut buffer, ptr::null_mut()),
                EMF_INVALID_ARGUMENT,
                "{name}"
            );
            assert!(buffer.is_null(), "{name}");
            // NULL out_buffer is invalid, and still reports through out_error.
            let mut error = DANGLING_ERROR;
            assert_eq!(
                call(ptr::null_mut(), &mut error),
                EMF_INVALID_ARGUMENT,
                "{name}"
            );
            assert_eq!(take_error(error).0, EMF_INVALID_ARGUMENT, "{name}");
        }
    }
}

#[test]
fn emf_wmf_replace_record_rejects_invalid_arguments_and_preserves_the_document() {
    unsafe {
        let mut error = DANGLING_ERROR;
        assert_eq!(
            emf_wmf_replace_record(ptr::null_mut(), 0, 0x103, ptr::null(), 0, &mut error),
            EMF_INVALID_ARGUMENT
        );
        assert_eq!(take_error(error).0, EMF_INVALID_ARGUMENT);

        let doc = parse_wmf(&wmf_bytes());
        let before = {
            let mut buffer = ptr::null_mut();
            assert_eq!(emf_wmf_serialize(doc, &mut buffer, ptr::null_mut()), EMF_OK);
            take(buffer)
        };
        let payload = [0u8; 2];
        let cases: [(u64, u32, *const u8, u64); 5] = [
            (99, 0x103, payload.as_ptr(), 2),   // index out of range
            (0, 0x1_0000, payload.as_ptr(), 2), // function wider than 16 bits
            (0, 0x103, payload.as_ptr(), 1),    // odd payload
            (0, 0x103, ptr::null(), 2),         // NULL data with length
            (u64::MAX, 0x103, payload.as_ptr(), 2),
        ];
        for (index, function, data, len) in cases {
            let mut error = DANGLING_ERROR;
            let status = emf_wmf_replace_record(doc, index, function, data, len, &mut error);
            assert_eq!(status, EMF_INVALID_ARGUMENT, "{index} {function:#x} {len}");
            assert_eq!(take_error(error).0, EMF_INVALID_ARGUMENT);
        }
        // Oversized edits fail before allocating.
        let mut error = ptr::null_mut();
        assert_eq!(
            emf_wmf_replace_record(doc, 0, 0x103, payload.as_ptr(), u64::MAX, &mut error),
            EMF_LIMIT_EXCEEDED
        );
        assert_eq!(take_error(error).0, EMF_LIMIT_EXCEEDED);
        let mut buffer = ptr::null_mut();
        assert_eq!(emf_wmf_serialize(doc, &mut buffer, ptr::null_mut()), EMF_OK);
        assert_eq!(
            take(buffer),
            before,
            "failed edits must preserve the document"
        );
        emf_wmf_document_free(doc);
    }
}

#[test]
fn emf_wmf_rejection_accepts_null_data_only_with_zero_length() {
    unsafe {
        let mut buffer = DANGLING_BUFFER;
        let mut error = DANGLING_ERROR;
        assert_eq!(
            emf_wmf_rejection(ptr::null(), 5, 1 << 20, 1000, &mut buffer, &mut error),
            EMF_INVALID_ARGUMENT
        );
        assert!(buffer.is_null());
        assert_eq!(take_error(error).0, EMF_INVALID_ARGUMENT);
        let mut buffer = DANGLING_BUFFER;
        assert_eq!(
            emf_wmf_rejection(ptr::null(), 0, 1 << 20, 1000, &mut buffer, ptr::null_mut()),
            EMF_OK
        );
        let bytes = take(buffer);
        assert_eq!((&bytes[..4], bytes.len()), (&b"WMFR"[..], 48));
        // The answer needs no document and is an owned buffer.
        let data = wmf_bytes();
        let mut buffer = ptr::null_mut();
        assert_eq!(
            emf_wmf_rejection(
                data.as_ptr(),
                data.len() as u64,
                u64::MAX,
                u64::MAX,
                &mut buffer,
                ptr::null_mut()
            ),
            EMF_OK
        );
        take(buffer);
        assert_eq!(
            emf_wmf_rejection(data.as_ptr(), u64::MAX, 0, 0, &mut buffer, ptr::null_mut()),
            EMF_INVALID_ARGUMENT
        );
    }
}

#[test]
fn emf_document_emf_plus_snapshot_v1_validates_options_and_clears_output() {
    unsafe {
        let doc = parse_emf(&emf_bytes());
        let opts = plus_options();
        let mut buffer = DANGLING_BUFFER;
        let mut error = DANGLING_ERROR;
        assert_eq!(
            emf_document_emf_plus_snapshot_v1(
                doc,
                ptr::null(),
                ptr::null(),
                &mut buffer,
                &mut error
            ),
            EMF_INVALID_ARGUMENT
        );
        assert!(buffer.is_null());
        assert_eq!(take_error(error).0, EMF_INVALID_ARGUMENT);
        for bad in [
            EmfPlusSnapshotOptions {
                struct_size: 3,
                ..opts
            },
            EmfPlusSnapshotOptions { version: 0, ..opts },
            EmfPlusSnapshotOptions { version: 3, ..opts },
        ] {
            let mut buffer = DANGLING_BUFFER;
            assert_eq!(
                emf_document_emf_plus_snapshot_v1(
                    doc,
                    &bad,
                    ptr::null(),
                    &mut buffer,
                    ptr::null_mut()
                ),
                EMF_INVALID_ARGUMENT
            );
            assert!(buffer.is_null());
        }
        let mut buffer = ptr::null_mut();
        let status = emf_document_emf_plus_snapshot_v1(
            doc,
            &opts,
            ptr::null(),
            &mut buffer,
            ptr::null_mut(),
        );
        assert_eq!(status, EMF_OK);
        assert!(!take(buffer).is_empty());
        emf_document_free(doc);
    }
}

#[test]
fn emf_buffer_view_and_emf_error_view_reject_null_and_clear_outputs() {
    unsafe {
        let mut data = 8 as *const u8;
        let mut len = 7;
        assert_eq!(
            emf_buffer_view(ptr::null(), &mut data, &mut len),
            EMF_INVALID_ARGUMENT
        );
        assert_eq!((data, len), (ptr::null(), 0));
        let doc = parse_emf(&emf_bytes());
        let mut buffer = ptr::null_mut();
        assert_eq!(emf_serialize(doc, &mut buffer, ptr::null_mut()), EMF_OK);
        assert_eq!(
            emf_buffer_view(buffer, ptr::null_mut(), &mut len),
            EMF_INVALID_ARGUMENT
        );
        assert_eq!(
            emf_buffer_view(buffer, &mut data, ptr::null_mut()),
            EMF_INVALID_ARGUMENT
        );
        emf_buffer_free(buffer);
        emf_document_free(doc);

        let mut view = error_info();
        assert_eq!(emf_error_view(ptr::null(), &mut view), EMF_INVALID_ARGUMENT);
        assert_eq!((view.status, view.message), (0, ptr::null()));
        assert_eq!(
            emf_error_view(ptr::null(), ptr::null_mut()),
            EMF_INVALID_ARGUMENT
        );
        // A real error rejects wrong struct size / version and leaves the view unset.
        let mut error = ptr::null_mut();
        emf_parse(
            ptr::null(),
            0,
            ptr::null(),
            &mut ptr::null_mut(),
            &mut error,
        );
        assert!(!error.is_null());
        let mut bad = error_info();
        bad.struct_size = 1;
        assert_eq!(emf_error_view(error, &mut bad), EMF_INVALID_ARGUMENT);
        let mut bad = error_info();
        bad.version = 9;
        assert_eq!(emf_error_view(error, &mut bad), EMF_INVALID_ARGUMENT);
        assert!(bad.message.is_null());
        emf_error_free(error);
    }
}

// ---------------------------------------------------------------------------
// Buffer / error ownership
// ---------------------------------------------------------------------------

#[test]
fn emf_serialize_returns_independent_buffers_each_freed_once() {
    unsafe {
        let source = emf_bytes();
        let doc = parse_emf(&source);
        let (mut a, mut b) = (ptr::null_mut(), ptr::null_mut());
        assert_eq!(emf_serialize(doc, &mut a, ptr::null_mut()), EMF_OK);
        assert_eq!(emf_serialize(doc, &mut b, ptr::null_mut()), EMF_OK);
        assert_ne!(a, b);
        let (mut pa, mut pb) = (ptr::null(), ptr::null());
        let (mut la, mut lb) = (0, 0);
        assert_eq!(emf_buffer_view(a, &mut pa, &mut la), EMF_OK);
        assert_eq!(emf_buffer_view(b, &mut pb, &mut lb), EMF_OK);
        assert_ne!(pa, pb, "buffers must not alias");
        // A view is stable across repeated calls until the buffer is freed.
        let (mut pa2, mut la2) = (ptr::null(), 0);
        assert_eq!(emf_buffer_view(a, &mut pa2, &mut la2), EMF_OK);
        assert_eq!((pa, la), (pa2, la2));
        // Freeing one leaves the other intact.
        emf_buffer_free(a);
        assert_eq!(slice::from_raw_parts(pb, lb as usize), &source[..]);
        emf_buffer_free(b);
        emf_document_free(doc);
    }
}

#[test]
fn emf_record_bytes_copies_the_record_and_rejects_out_of_range_indices() {
    unsafe {
        let source = emf_bytes();
        let doc = parse_emf(&source);
        let mut buffer = ptr::null_mut();
        assert_eq!(
            emf_record_bytes(doc, 0, &mut buffer, ptr::null_mut()),
            EMF_OK
        );
        assert_eq!(take(buffer), &source[88..100]);
        for index in [2u64, u64::MAX] {
            let mut buffer = DANGLING_BUFFER;
            let mut error = ptr::null_mut();
            assert_eq!(
                emf_record_bytes(doc, index, &mut buffer, &mut error),
                EMF_INVALID_ARGUMENT
            );
            assert!(buffer.is_null());
            assert_eq!(take_error(error).0, EMF_INVALID_ARGUMENT);
        }
        emf_document_free(doc);
    }
}

#[test]
fn emf_error_view_message_stays_valid_until_emf_error_free_and_is_bounded() {
    unsafe {
        // Truncated header: format error with an offset and a message.
        let bytes = emf_bytes();
        let mut doc = ptr::null_mut();
        let mut error = ptr::null_mut();
        assert_eq!(
            emf_parse(bytes.as_ptr(), 44, ptr::null(), &mut doc, &mut error),
            EMF_FORMAT_ERROR
        );
        assert!(doc.is_null());
        let mut first = error_info();
        let mut second = error_info();
        assert_eq!(emf_error_view(error, &mut first), EMF_OK);
        assert_eq!(emf_error_view(error, &mut second), EMF_OK);
        assert_eq!(first.message, second.message, "view is stable");
        assert!(first.message_length > 0 && first.message_length <= 512);
        assert_eq!(first.has_offset, 1);
        assert_eq!(first.reserved, 0);
        let copy = slice::from_raw_parts(first.message, first.message_length as usize).to_vec();
        assert!(std::str::from_utf8(&copy).is_ok());
        emf_error_free(error);

        // The error is independent of the input buffer it described.
        let mut input = emf_bytes();
        let mut error = ptr::null_mut();
        assert_eq!(
            emf_parse(input.as_ptr(), 44, ptr::null(), &mut doc, &mut error),
            EMF_FORMAT_ERROR
        );
        input.iter_mut().for_each(|b| *b = 0xAA);
        drop(input);
        let (status, message) = take_error(error);
        assert_eq!(status, EMF_FORMAT_ERROR);
        assert_eq!(message.as_bytes(), &copy[..]);
    }
}

// ---------------------------------------------------------------------------
// No use after document free / input free
// ---------------------------------------------------------------------------

#[test]
fn emf_buffers_stay_valid_after_document_and_input_are_freed() {
    unsafe {
        let mut input = emf_bytes();
        let original = input.clone();
        let doc = parse_emf(&input);
        // Parse must not borrow from the caller's input.
        input.iter_mut().for_each(|b| *b = 0xEE);
        drop(input);

        let (mut serialized, mut snapshot, mut record, mut plus) = (
            ptr::null_mut(),
            ptr::null_mut(),
            ptr::null_mut(),
            ptr::null_mut(),
        );
        assert_eq!(emf_serialize(doc, &mut serialized, ptr::null_mut()), EMF_OK);
        assert_eq!(
            emf_document_snapshot(doc, &mut snapshot, ptr::null_mut()),
            EMF_OK
        );
        assert_eq!(
            emf_record_bytes(doc, 1, &mut record, ptr::null_mut()),
            EMF_OK
        );
        let opts = plus_options();
        assert_eq!(
            emf_document_emf_plus_snapshot_v1(doc, &opts, ptr::null(), &mut plus, ptr::null_mut()),
            EMF_OK
        );
        let mut views = Vec::new();
        for buffer in [serialized, snapshot, record, plus] {
            let (mut data, mut len) = (ptr::null(), 0);
            assert_eq!(emf_buffer_view(buffer, &mut data, &mut len), EMF_OK);
            views.push((
                data,
                len,
                slice::from_raw_parts(data, len as usize).to_vec(),
            ));
        }
        emf_document_free(doc);
        // Free the document, then read the buffers through their pre-free views.
        for (data, len, copy) in &views {
            assert_eq!(slice::from_raw_parts(*data, *len as usize), &copy[..]);
        }
        assert_eq!(views[0].2, original);
        assert_eq!(views[2].2, &original[100..120]);
        for buffer in [serialized, snapshot, record, plus] {
            emf_buffer_free(buffer);
        }
    }
}

#[test]
fn emf_wmf_buffers_stay_valid_after_document_and_input_are_freed() {
    unsafe {
        let mut input = wmf_bytes();
        let original = input.clone();
        let doc = parse_wmf(&input);
        input.iter_mut().for_each(|b| *b = 0xEE);
        drop(input);
        let mut buffers = [ptr::null_mut::<EmfBuffer>(); 5];
        assert_eq!(
            emf_wmf_serialize(doc, &mut buffers[0], ptr::null_mut()),
            EMF_OK
        );
        assert_eq!(
            emf_wmf_document_snapshot(doc, &mut buffers[1], ptr::null_mut()),
            EMF_OK
        );
        assert_eq!(
            emf_wmf_record_bytes(doc, 0, &mut buffers[2], ptr::null_mut()),
            EMF_OK
        );
        assert_eq!(
            emf_wmf_record_view(doc, 0, ptr::null(), &mut buffers[3], ptr::null_mut()),
            EMF_OK
        );
        assert_eq!(
            emf_wmf_embedded_emf(doc, ptr::null(), &mut buffers[4], ptr::null_mut()),
            EMF_OK
        );
        let views: Vec<_> = buffers
            .iter()
            .map(|&buffer| {
                let (mut data, mut len) = (ptr::null(), 0);
                assert_eq!(emf_buffer_view(buffer, &mut data, &mut len), EMF_OK);
                (
                    data,
                    len,
                    slice::from_raw_parts(data, len as usize).to_vec(),
                )
            })
            .collect();
        emf_wmf_document_free(doc);
        for (data, len, copy) in &views {
            if *len > 0 {
                assert_eq!(slice::from_raw_parts(*data, *len as usize), &copy[..]);
            }
        }
        assert_eq!(views[0].2, original);
        assert_eq!(&views[3].2[..4], b"WMFV");
        assert_eq!(&views[4].2[..4], b"WMFE");
        for buffer in buffers {
            emf_buffer_free(buffer);
        }
    }
}

#[test]
fn emf_wmf_replace_record_edit_survives_into_buffers_taken_before_and_after() {
    unsafe {
        let doc = parse_wmf(&wmf_bytes());
        let mut before = ptr::null_mut();
        assert_eq!(emf_wmf_serialize(doc, &mut before, ptr::null_mut()), EMF_OK);
        let payload = [3u8, 0];
        assert_eq!(
            emf_wmf_replace_record(doc, 0, 0x103, payload.as_ptr(), 2, ptr::null_mut()),
            EMF_OK
        );
        let mut after = ptr::null_mut();
        assert_eq!(emf_wmf_serialize(doc, &mut after, ptr::null_mut()), EMF_OK);
        emf_wmf_document_free(doc);
        let (before, after) = (take(before), take(after));
        assert_ne!(before, after);
        assert!(after.windows(2).any(|w| w == [3, 0]));
    }
}

// ---------------------------------------------------------------------------
// Panic containment: hostile arguments against every export
// ---------------------------------------------------------------------------

/// Calls every EMF export with `bytes` and frees everything it returns. Reaching
/// the end means no export unwound (a panic escaping `extern "C"` aborts).
unsafe fn exercise_emf(bytes: &[u8], limits: *const EmfLimits) {
    let mut format = 0;
    let _ = emf_detect(
        bytes.as_ptr(),
        bytes.len() as u64,
        &mut format,
        ptr::null_mut(),
    );
    let mut doc = ptr::null_mut();
    let mut error = ptr::null_mut();
    let status = emf_parse(
        bytes.as_ptr(),
        bytes.len() as u64,
        limits,
        &mut doc,
        &mut error,
    );
    assert_eq!(doc.is_null(), status != EMF_OK);
    assert_eq!(error.is_null(), status == EMF_OK);
    emf_error_free(error);
    if doc.is_null() {
        return;
    }
    let mut meta = info();
    let _ = emf_document_info(doc, &mut meta);
    let mut slots = vec![EmfRecordDescriptor::default(); meta.record_count as usize + 1];
    let mut count = 0;
    let _ = emf_record_batch(doc, 0, slots.len() as u64, slots.as_mut_ptr(), &mut count);
    let opts = plus_options();
    for index in 0..=meta.record_count + 1 {
        let mut buffer = ptr::null_mut();
        let _ = emf_record_bytes(doc, index, &mut buffer, ptr::null_mut());
        emf_buffer_free(buffer);
    }
    for call in 0..3 {
        let mut buffer = ptr::null_mut();
        let mut error = ptr::null_mut();
        let _ = match call {
            0 => emf_document_snapshot(doc, &mut buffer, &mut error),
            1 => emf_serialize(doc, &mut buffer, &mut error),
            _ => emf_document_emf_plus_snapshot_v1(doc, &opts, limits, &mut buffer, &mut error),
        };
        emf_buffer_free(buffer);
        emf_error_free(error);
    }
    emf_document_free(doc);
}

unsafe fn exercise_wmf(bytes: &[u8], limits: *const EmfLimits) {
    let mut buffer = ptr::null_mut();
    let _ = emf_wmf_rejection(
        bytes.as_ptr(),
        bytes.len() as u64,
        1 << 20,
        1000,
        &mut buffer,
        ptr::null_mut(),
    );
    emf_buffer_free(buffer);
    let mut doc = ptr::null_mut();
    let mut error = ptr::null_mut();
    let status = emf_wmf_parse(
        bytes.as_ptr(),
        bytes.len() as u64,
        limits,
        &mut doc,
        &mut error,
    );
    assert_eq!(doc.is_null(), status != EMF_OK);
    emf_error_free(error);
    if doc.is_null() {
        return;
    }
    let mut meta = info();
    let _ = emf_wmf_document_info(doc, &mut meta);
    let mut slots = vec![EmfRecordDescriptor::default(); meta.record_count as usize + 1];
    let mut count = 0;
    let _ = emf_wmf_record_batch(doc, 0, slots.len() as u64, slots.as_mut_ptr(), &mut count);
    for index in 0..=meta.record_count + 1 {
        for call in 0..2 {
            let mut buffer = ptr::null_mut();
            let _ = if call == 0 {
                emf_wmf_record_bytes(doc, index, &mut buffer, ptr::null_mut())
            } else {
                emf_wmf_record_view(doc, index, limits, &mut buffer, ptr::null_mut())
            };
            emf_buffer_free(buffer);
        }
    }
    for call in 0..3 {
        let mut buffer = ptr::null_mut();
        let _ = match call {
            0 => emf_wmf_serialize(doc, &mut buffer, ptr::null_mut()),
            1 => emf_wmf_document_snapshot(doc, &mut buffer, ptr::null_mut()),
            _ => emf_wmf_embedded_emf(doc, limits, &mut buffer, ptr::null_mut()),
        };
        emf_buffer_free(buffer);
    }
    let _ = emf_wmf_replace_record(doc, 0, 0, ptr::null(), 0, ptr::null_mut());
    emf_wmf_document_free(doc);
}

#[test]
fn every_export_returns_a_status_for_every_truncation_and_bit_flip() {
    // Covers emf_detect, emf_parse, emf_document_info, emf_record_batch,
    // emf_record_bytes, emf_document_snapshot, emf_serialize,
    // emf_document_emf_plus_snapshot_v1 and the WMF counterparts. A panic
    // escaping any of them would abort this test; `run` (src/lib.rs) converts a
    // caught panic into EMF_INTERNAL_ERROR, asserted by its own unit test.
    unsafe {
        let emf = emf_bytes();
        let wmf = wmf_bytes();
        for len in 0..=emf.len() {
            exercise_emf(&emf[..len], ptr::null());
        }
        for len in 0..=wmf.len() {
            exercise_wmf(&wmf[..len], ptr::null());
        }
        for (source, wmf_kind) in [(&emf, false), (&wmf, true)] {
            for position in 0..source.len() {
                for mask in [0xffu8, 0x80, 0x01] {
                    let mut mutated = source.clone();
                    mutated[position] ^= mask;
                    if wmf_kind {
                        exercise_wmf(&mutated, ptr::null());
                    } else {
                        exercise_emf(&mutated, ptr::null());
                    }
                }
            }
        }
    }
}

#[test]
fn every_export_accepts_zero_ceiling_limits_without_unwinding() {
    unsafe {
        let zero = EmfLimits {
            struct_size: size_of::<EmfLimits>() as u32,
            version: EMF_ABI_VERSION,
            max_input_bytes: 0,
            max_record_bytes: 0,
            max_records: 0,
            max_allocated_bytes: 0,
            max_work_units: 0,
        };
        let tiny = EmfLimits {
            max_input_bytes: 1,
            max_record_bytes: 1,
            max_records: 1,
            max_allocated_bytes: 1,
            max_work_units: 1,
            ..zero
        };
        for limits in [&zero, &tiny] {
            exercise_emf(&emf_bytes(), limits);
            exercise_wmf(&wmf_bytes(), limits);
        }
    }
}
