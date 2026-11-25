//! zlib codec calls through libz-sys. The deflate side is configured with
//! libpng 1.6's default write parameters (see `encode`) so the emitted IDAT
//! bytes match the Ruby ground-truth chain (libpng + zlib) exactly; inflate
//! is used for pixel-surface decoding.

use crate::Error;
use std::os::raw::{c_char, c_int};

type ZStream = libz_sys::z_stream;

const Z_NO_FLUSH: c_int = 0;
const Z_FINISH: c_int = 4;
const Z_OK: c_int = 0;
const Z_STREAM_END: c_int = 1;
const Z_DEFLATED: c_int = 8;
const Z_FILTERED: c_int = 1;
const Z_BUF_ERROR: c_int = -5;

unsafe fn z_version() -> *const c_char {
    libz_sys::zlibVersion()
}

unsafe fn init_deflate(strm: *mut ZStream, level: i32, window_bits: i32) -> Result<(), Error> {
    let ret = libz_sys::deflateInit2_(
        strm,
        level,
        Z_DEFLATED,
        window_bits,
        8, // memLevel: libpng default
        Z_FILTERED,
        z_version(),
        std::mem::size_of::<ZStream>() as c_int,
    );
    if ret == Z_OK {
        Ok(())
    } else {
        Err(Error::Zlib("deflateInit2 failed"))
    }
}

unsafe fn init_inflate(strm: *mut ZStream) -> Result<(), Error> {
    let ret = libz_sys::inflateInit2_(
        strm,
        15, // accept any standard zlib stream
        z_version(),
        std::mem::size_of::<ZStream>() as c_int,
    );
    if ret == Z_OK {
        Ok(())
    } else {
        Err(Error::Zlib("inflateInit2 failed"))
    }
}

/// Compress `input` into a zlib stream with the given level and window bits.
///
/// Mirrors libpng's `png_compress_IDAT`: a continuous deflate over the whole
/// input (Z_NO_FLUSH per feed, Z_FINISH at the end), so output is identical
/// to feeding row-by-row as libpng does.
pub(crate) fn zlib_compress(input: &[u8], level: i32, window_bits: i32) -> Result<Vec<u8>, Error> {
    unsafe {
        let mut uninit = std::mem::MaybeUninit::<ZStream>::zeroed();
        init_deflate(uninit.as_mut_ptr(), level, window_bits)?;
        let strm = uninit.assume_init_mut();
        let mut out = Vec::with_capacity(input.len() / 2 + 64);
        let mut cursor = 0usize;
        loop {
            let avail_in = (input.len() - cursor).min(u32::MAX as usize);
            strm.next_in = input[cursor..].as_ptr().cast_mut().cast();
            strm.avail_in = avail_in as libz_sys::uInt;
            let flush = if cursor + avail_in == input.len() {
                Z_FINISH
            } else {
                Z_NO_FLUSH
            };
            loop {
                let before = out.len();
                strm.next_out = out.spare_capacity_mut().as_mut_ptr().cast();
                strm.avail_out = out.capacity().saturating_sub(before) as libz_sys::uInt;
                if strm.avail_out == 0 {
                    out.reserve(4096);
                    continue;
                }
                let ret = libz_sys::deflate(strm, flush);
                let written = out.capacity().saturating_sub(before) - strm.avail_out as usize;
                out.set_len(before + written);
                if ret == Z_STREAM_END {
                    libz_sys::deflateEnd(strm);
                    return Ok(out);
                }
                if ret != Z_OK {
                    libz_sys::deflateEnd(strm);
                    return Err(Error::Zlib("deflate failed"));
                }
                if strm.avail_out == 0 {
                    out.reserve(4096);
                    continue;
                }
                if flush == Z_FINISH {
                    libz_sys::deflateEnd(strm);
                    return Err(Error::Zlib("deflate unfinished"));
                }
                break;
            }
            cursor += avail_in;
        }
    }
}

/// Inflate a zlib stream, returning the decompressed bytes.
pub(crate) fn zlib_decompress(input: &[u8]) -> Result<Vec<u8>, Error> {
    unsafe {
        let mut uninit = std::mem::MaybeUninit::<ZStream>::zeroed();
        init_inflate(uninit.as_mut_ptr())?;
        let strm = uninit.assume_init_mut();
        let mut out: Vec<u8> = Vec::new();
        let mut chunk = [0u8; 65536];
        let mut cursor = 0usize;
        loop {
            let avail_in = (input.len() - cursor).min(u32::MAX as usize);
            strm.next_in = input[cursor..].as_ptr().cast_mut().cast();
            strm.avail_in = avail_in as libz_sys::uInt;
            strm.next_out = chunk.as_mut_ptr().cast();
            strm.avail_out = chunk.len() as libz_sys::uInt;
            let ret = libz_sys::inflate(strm, Z_NO_FLUSH);
            let produced = chunk.len() - strm.avail_out as usize;
            out.extend_from_slice(&chunk[..produced]);
            cursor = input.len() - strm.avail_in as usize;
            if ret == Z_STREAM_END {
                libz_sys::inflateEnd(strm);
                return Ok(out);
            }
            if ret == Z_OK {
                if produced == 0 && cursor == input.len() {
                    libz_sys::inflateEnd(strm);
                    return Err(Error::Zlib("truncated zlib stream"));
                }
                continue;
            }
            if ret == Z_BUF_ERROR {
                libz_sys::inflateEnd(strm);
                return Err(Error::Zlib("truncated zlib stream"));
            }
            libz_sys::inflateEnd(strm);
            return Err(Error::Zlib("inflate failed"));
        }
    }
}
