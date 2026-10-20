#[no_mangle]
pub extern "C" fn emf_probe_abi_version() -> u32 {
    1
}

/// Writes the input bytes reversed into `output` and returns the count
/// written, or `usize::MAX` when a pointer is null or `output_len` is short.
///
/// # Safety
/// `input` must be readable for `input_len` bytes and `output` writable for
/// `output_len` bytes.
#[no_mangle]
pub unsafe extern "C" fn emf_probe_reverse(
    input: *const u8,
    input_len: usize,
    output: *mut u8,
    output_len: usize,
) -> usize {
    if input.is_null() || output.is_null() || output_len < input_len {
        return usize::MAX;
    }
    let source = std::slice::from_raw_parts(input, input_len);
    let target = std::slice::from_raw_parts_mut(output, input_len);
    for (slot, byte) in target.iter_mut().zip(source.iter().rev()) {
        *slot = *byte;
    }
    input_len
}
