//! CRC-32 as defined for PNG chunks (the zlib polynomial 0xedb88320),
//! computed over the chunk kind followed by the chunk data.
pub(crate) fn crc32(kind: &[u8; 4], data: &[u8]) -> u32 {
    let mut table = [0u32; 256];
    for (n, slot) in table.iter_mut().enumerate() {
        let mut c = n as u32;
        for _ in 0..8 {
            c = if c & 1 != 0 {
                0xedb8_8320 ^ (c >> 1)
            } else {
                c >> 1
            };
        }
        *slot = c;
    }
    let mut crc = 0xffff_ffffu32;
    for byte in kind.iter().copied().chain(data.iter().copied()) {
        crc = table[((crc ^ u32::from(byte)) & 0xff) as usize] ^ (crc >> 8);
    }
    crc ^ 0xffff_ffff
}

#[cfg(test)]
mod tests {
    use super::crc32;

    #[test]
    fn known_vectors() {
        // IEND (kind only, empty data) and IHDR of a canonical 1x1 PNG.
        assert_eq!(crc32(b"IEND", &[]), 0xae42_6082);
        let ihdr_data = [0u8, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0];
        assert_eq!(crc32(b"IHDR", &ihdr_data), 0x1f15_c489);
    }
}
