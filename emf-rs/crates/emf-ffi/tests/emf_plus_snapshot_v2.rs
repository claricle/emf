//! Snapshot version 2: per-comment recovering framing and the typed TSClip family.
use emf_ffi::*;
use std::{mem::size_of, ptr, slice};

fn u32_at(bytes: &[u8], at: usize) -> u32 {
    u32::from_le_bytes(bytes[at..at + 4].try_into().unwrap())
}
fn u64_at(bytes: &[u8], at: usize) -> u64 {
    u64::from_le_bytes(bytes[at..at + 8].try_into().unwrap())
}
fn options(version: u32) -> EmfPlusSnapshotOptions {
    EmfPlusSnapshotOptions {
        struct_size: size_of::<EmfPlusSnapshotOptions>() as u32,
        version,
        max_output_bytes: 1 << 20,
    }
}
fn frame(kind: u16, flags: u16, body: &[u8], padding: &[u8]) -> Vec<u8> {
    let mut bytes = Vec::new();
    bytes.extend_from_slice(&kind.to_le_bytes());
    bytes.extend_from_slice(&flags.to_le_bytes());
    bytes.extend_from_slice(&((12 + body.len() + padding.len()) as u32).to_le_bytes());
    bytes.extend_from_slice(&(body.len() as u32).to_le_bytes());
    bytes.extend_from_slice(body);
    bytes.extend_from_slice(padding);
    bytes
}
/// `cb_data` overrides the declared EMR_COMMENT length of the segment at its index.
fn input(segments: &[&[u8]], cb_data: &[(usize, u32)]) -> Vec<u8> {
    let mut bytes = vec![0; 88];
    bytes[..4].copy_from_slice(&1u32.to_le_bytes());
    bytes[4..8].copy_from_slice(&88u32.to_le_bytes());
    bytes[40..44].copy_from_slice(&0x464d4520u32.to_le_bytes());
    for (index, segment) in segments.iter().enumerate() {
        let len = 16 + segment.len();
        let size = (len + 3) & !3;
        let declared = cb_data
            .iter()
            .find(|(at, _)| *at == index)
            .map_or((4 + segment.len()) as u32, |(_, value)| *value);
        for word in [70, size as u32, declared] {
            bytes.extend_from_slice(&word.to_le_bytes());
        }
        bytes.extend_from_slice(b"EMF+");
        bytes.extend_from_slice(segment);
        bytes.resize(bytes.len() + size - len, 0xa5);
    }
    bytes
}
unsafe fn snapshot(bytes: &[u8], version: u32) -> Result<Vec<u8>, i32> {
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
    let mut buffer = ptr::null_mut();
    let mut error = ptr::null_mut();
    let status = emf_document_emf_plus_snapshot_v1(
        doc,
        &options(version),
        ptr::null(),
        &mut buffer,
        &mut error,
    );
    emf_document_free(doc);
    if status != EMF_OK {
        assert!(buffer.is_null());
        emf_error_free(error);
        return Err(status);
    }
    let (mut data, mut len) = (ptr::null(), 0);
    assert_eq!(emf_buffer_view(buffer, &mut data, &mut len), EMF_OK);
    let out = slice::from_raw_parts(data, len as usize).to_vec();
    emf_buffer_free(buffer);
    Ok(out)
}

struct Frame {
    logical: u64,
    first: u64,
    last: u64,
    kind: u16,
    family: u32,
    raw: Vec<u8>,
    typed: Vec<u8>,
}
/// (segment rows as [index, logical start, length, data start], frames)
fn read(bytes: &[u8]) -> (Vec<[u64; 4]>, Vec<Frame>) {
    let segments = (0..u64_at(bytes, 16) as usize)
        .map(|i| std::array::from_fn(|j| u64_at(bytes, 40 + i * 32 + j * 8)))
        .collect::<Vec<_>>();
    let mut at = 40 + segments.len() * 32;
    let mut frames = Vec::new();
    for _ in 0..u64_at(bytes, 24) {
        let (typed_len, raw_len) = (
            u64_at(bytes, at + 48) as usize,
            u64_at(bytes, at + 56) as usize,
        );
        frames.push(Frame {
            logical: u64_at(bytes, at + 8),
            first: u64_at(bytes, at + 16),
            last: u64_at(bytes, at + 24),
            kind: u16::from_le_bytes([bytes[at + 32], bytes[at + 33]]),
            family: u32_at(bytes, at + 44),
            raw: bytes[at + 64..at + 64 + raw_len].to_vec(),
            typed: bytes[at + 64 + raw_len..at + 64 + raw_len + typed_len].to_vec(),
        });
        at += 64 + raw_len + typed_len;
    }
    (segments, frames)
}

#[test]
fn version_two_header_echoes_the_requested_version_and_unknown_versions_fail() {
    let bytes = input(&[&frame(0x4009, 0, &[0; 4], &[])], &[]);
    unsafe {
        assert_eq!(u32_at(&snapshot(&bytes, 1).unwrap(), 4), 1);
        assert_eq!(u32_at(&snapshot(&bytes, 2).unwrap(), 4), 2);
        assert_eq!(snapshot(&bytes, 3).unwrap_err(), EMF_INVALID_ARGUMENT);
    }
}

#[test]
fn malformed_headers_end_their_own_comment_and_the_next_comment_frames_afresh() {
    let clear = frame(0x4009, 0, &[1, 2, 3, 4], &[]);
    let malformed = [
        (
            "size below header",
            frame(0x4009, 0, &[], &[])
                .iter()
                .enumerate()
                .map(|(i, b)| {
                    if (4..8).contains(&i) {
                        [8u8, 0, 0, 0][i - 4]
                    } else {
                        *b
                    }
                })
                .collect::<Vec<u8>>(),
        ),
        ("zero size", vec![9, 0x40, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
        (
            "unaligned size",
            vec![9, 0x40, 0, 0, 13, 0, 0, 0, 0, 0, 0, 0, 0],
        ),
        (
            "data size beyond size",
            vec![
                9, 0x40, 0, 0, 16, 0, 0, 0, 0xff, 0xff, 0xff, 0xff, 0, 0, 0, 0,
            ],
        ),
        (
            "size beyond the comment",
            vec![9, 0x40, 0, 0, 0xfc, 0xff, 0xff, 0xff, 0, 0, 0, 0],
        ),
        ("truncated header", vec![9, 0x40, 0, 0, 12, 0]),
    ];
    for (name, bad) in malformed {
        let first = [clear.clone(), bad.clone(), clear.clone()].concat();
        let bytes = input(&[&first, &clear], &[]);
        unsafe {
            // Version 1 rejects the whole snapshot (format error, or a limit for a huge Size).
            assert!(snapshot(&bytes, 1).is_err(), "{name}");
            let (segments, frames) = read(&snapshot(&bytes, 2).unwrap());
            assert_eq!(segments[0][2], first.len() as u64, "{name}");
            assert_eq!(
                segments[1],
                [1, first.len() as u64, clear.len() as u64, 4],
                "{name}"
            );
            // The first comment keeps only the frame before the bad header.
            assert_eq!(frames.len(), 2, "{name}");
            assert_eq!(
                (frames[0].logical, frames[0].first, frames[0].last),
                (0, 0, 0),
                "{name}"
            );
            assert_eq!(
                (frames[1].logical, frames[1].first, frames[1].last),
                (first.len() as u64, 1, 1),
                "{name}"
            );
            assert_eq!(frames[1].raw, clear, "{name}");
        }
    }
}

#[test]
fn a_comment_with_nothing_framable_is_kept_as_an_empty_frame_segment() {
    let clear = frame(0x4009, 0, &[1, 2, 3, 4], &[]);
    let bytes = input(&[&[0, 9, 9], &clear], &[]);
    unsafe {
        let (segments, frames) = read(&snapshot(&bytes, 2).unwrap());
        assert_eq!(segments.len(), 2);
        assert_eq!((segments[0][2], segments[1][1]), (3, 3));
        assert_eq!(
            (frames.len(), frames[0].logical, frames[0].first),
            (1, 3, 1)
        );
    }
}

#[test]
fn a_record_split_across_comments_is_not_joined_in_version_two() {
    let clear = frame(0x4009, 0, &[1, 2, 3, 4], &[]);
    let bytes = input(&[&clear[..7], &clear[7..]], &[]);
    unsafe {
        assert_eq!(read(&snapshot(&bytes, 1).unwrap()).1.len(), 1);
        assert!(read(&snapshot(&bytes, 2).unwrap()).1.is_empty());
    }
}

#[test]
fn an_overrunning_cb_data_selects_the_comment_clamped_to_the_bytes_it_holds() {
    let clear = frame(0x4009, 0, &[1, 2, 3, 4], &[]);
    let bytes = input(&[&clear, &clear], &[(0, 0xffff_ff00)]);
    unsafe {
        let (v1_segments, v1_frames) = read(&snapshot(&bytes, 1).unwrap());
        assert_eq!((v1_segments.len(), v1_frames.len()), (1, 1));
        let (segments, frames) = read(&snapshot(&bytes, 2).unwrap());
        assert_eq!(segments.len(), 2);
        assert_eq!(segments[0][0], 0);
        // The record holds the payload plus its alignment padding.
        assert_eq!(segments[0][2], clear.len() as u64);
        assert_eq!(frames.len(), 2);
        // A declared length below the signature selects nothing.
        let none = input(&[&clear], &[(0, 3)]);
        assert_eq!(read(&snapshot(&none, 2).unwrap()).0.len(), 0);
    }
}

#[test]
fn tsclip_is_typed_in_version_two_only_and_compressed_clips_stay_opaque() {
    let rectangles: Vec<u8> = [i16::MIN, i16::MAX, -1, 0, 1, -2, 3, -4]
        .into_iter()
        .flat_map(i16::to_le_bytes)
        .collect();
    let uncompressed = frame(0x403a, 2, &rectangles, &[]);
    let empty = frame(0x403a, 0, &[], &[]);
    let compressed = frame(0x403a, 0x8001, &[5, 6, 7, 8], &[]);
    let bytes = input(
        &[&[uncompressed.clone(), empty, compressed.clone()].concat()],
        &[],
    );
    unsafe {
        let (_, v1) = read(&snapshot(&bytes, 1).unwrap());
        assert!(v1.iter().all(|f| f.family == 0 && f.typed.is_empty()));
        let (_, v2) = read(&snapshot(&bytes, 2).unwrap());
        let words: Vec<i32> = (0..8)
            .map(|i| u32_at(&v2[0].typed, 8 + i * 4) as i32)
            .collect();
        assert_eq!(v2[0].family, 0x106);
        assert_eq!(u64_at(&v2[0].typed, 0), 2);
        assert_eq!(words, [-32768, 32767, -1, 0, 1, -2, 3, -4]);
        assert_eq!(v2[0].typed.len(), 8 + 32);
        assert_eq!(v2[0].raw, uncompressed);
        assert_eq!(
            (v2[1].family, v2[1].typed.clone()),
            (0x106, 0u64.to_le_bytes().to_vec())
        );
        assert_eq!(
            (v2[2].family, v2[2].kind, v2[2].typed.len()),
            (0, 0x403a, 0)
        );
        assert_eq!(v2[2].raw, compressed);
    }
}
