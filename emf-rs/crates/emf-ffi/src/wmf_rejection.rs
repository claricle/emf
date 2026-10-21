//! WMFR v1: the first rejection under the Ruby WMF contract, as data. Independent of any document handle:
//! it works on the raw input, so it also answers when `emf_wmf_parse` itself failed.
use super::*;
use emf_core::wmf::contract::{self, Limits};

/// # Safety
/// The limits are the contract's input-size and record-count ceilings; the caller owns them.
/// `data` must be valid for `len` bytes (or NULL when `len` is zero); output pointers must be writable.
#[no_mangle]
pub unsafe extern "C" fn emf_wmf_rejection(
    data: *const u8,
    len: u64,
    max_input_bytes: u64,
    max_records: u64,
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
        let limits = Limits {
            max_input_bytes: usize::try_from(max_input_bytes).unwrap_or(usize::MAX),
            max_records: usize::try_from(max_records).unwrap_or(usize::MAX),
        };
        let rejection = contract::first_rejection(input(data, len)?, &limits);
        out_buffer.write(Box::into_raw(Box::new(EmfBuffer {
            bytes: encode(rejection.as_ref()),
        })));
        Ok(())
    })
}

/// `WMFR`, then u32 version, present, codec, reason, has-offset, has-function, function, then u64 offset and
/// detail. Absent fields and a missing rejection (present 0) are zero.
fn encode(rejection: Option<&contract::Rejection>) -> Vec<u8> {
    let mut bytes = Vec::with_capacity(48);
    bytes.extend_from_slice(b"WMFR");
    let words = match rejection {
        None => [1, 0, 0, 0, 0, 0, 0],
        Some(found) => [
            1,
            1,
            found.codec() as u32,
            found.reason as u32,
            u32::from(found.offset.is_some()),
            u32::from(found.function.is_some()),
            u32::from(found.function.unwrap_or(0)),
        ],
    };
    for word in words {
        bytes.extend_from_slice(&word.to_le_bytes());
    }
    let offset = rejection.and_then(|found| found.offset).unwrap_or(0) as u64;
    bytes.extend_from_slice(&offset.to_le_bytes());
    bytes.extend_from_slice(&rejection.map_or(0, |found| found.detail).to_le_bytes());
    bytes
}
