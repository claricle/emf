use emf_ffi::*;
use std::{mem::size_of, ptr, slice};

fn u32_at(bytes: &[u8], at: usize) -> u32 {
    u32::from_le_bytes(bytes[at..at + 4].try_into().unwrap())
}
fn u64_at(bytes: &[u8], at: usize) -> u64 {
    u64::from_le_bytes(bytes[at..at + 8].try_into().unwrap())
}
fn options(max_output_bytes: u64) -> EmfPlusSnapshotOptions {
    EmfPlusSnapshotOptions {
        struct_size: size_of::<EmfPlusSnapshotOptions>() as u32,
        version: EMF_PLUS_SNAPSHOT_VERSION,
        max_output_bytes,
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
fn input(segments: &[&[u8]]) -> Vec<u8> {
    let mut bytes = vec![0; 88];
    bytes[..4].copy_from_slice(&1u32.to_le_bytes());
    bytes[4..8].copy_from_slice(&88u32.to_le_bytes());
    bytes[40..44].copy_from_slice(&0x464d4520u32.to_le_bytes());
    for segment in segments {
        let len = 16 + segment.len();
        let size = (len + 3) & !3;
        for word in [70, size as u32, (4 + segment.len()) as u32] {
            bytes.extend_from_slice(&word.to_le_bytes());
        }
        bytes.extend_from_slice(b"EMF+");
        bytes.extend_from_slice(segment);
        bytes.resize(bytes.len() + size - len, 0xa5);
    }
    bytes
}
unsafe fn parse(bytes: &[u8]) -> *mut EmfDocument {
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
    doc
}
unsafe fn view(buffer: *mut EmfBuffer) -> Vec<u8> {
    let mut data = ptr::null();
    let mut len = 0;
    assert_eq!(emf_buffer_view(buffer, &mut data, &mut len), EMF_OK);
    let bytes = slice::from_raw_parts(data, len as usize).to_vec();
    emf_buffer_free(buffer);
    bytes
}
unsafe fn snapshot(doc: *mut EmfDocument) -> Vec<u8> {
    let mut buffer = ptr::null_mut();
    assert_eq!(
        emf_document_emf_plus_snapshot_v1(
            doc,
            &options(1 << 20),
            ptr::null(),
            &mut buffer,
            ptr::null_mut()
        ),
        EMF_OK
    );
    view(buffer)
}

// Core typing may grow without changing the frozen snapshot-v1 family schema.
fn assert_raw_fallback(raw: Vec<u8>, expected: fn(&emf_core::emf_plus::RecordData) -> bool) {
    let core = emf_core::emf_plus::parse(&raw, &Default::default()).unwrap();
    assert!(
        expected(&core.records[0].data),
        "fixture must exercise typed core data"
    );
    let clear = frame(0x4009, 0x8000, &0x80ff0033u32.to_le_bytes(), &[]);
    let mut logical = raw.clone();
    logical.extend_from_slice(&clear);
    // Split the new frame's header across outer comments as a source-range control.
    let bytes = input(&[&logical[..7], &logical[7..]]);
    unsafe {
        let doc = parse(&bytes);
        let nested = snapshot(doc);
        assert_eq!(&nested[..4], b"EPSN");
        assert_eq!(u32_at(&nested, 4), 1);
        assert_eq!(u64_at(&nested, 8), nested.len() as u64);
        assert_eq!(u64_at(&nested, 16), 2);
        assert_eq!(u64_at(&nested, 24), 2);
        let first = 40 + 2 * 32;
        assert_eq!(u64_at(&nested, first + 8), 0);
        assert_eq!(u64_at(&nested, first + 16), 0);
        assert_eq!(u64_at(&nested, first + 24), 1);
        assert_eq!(u32_at(&nested, first + 32), u32_at(&raw, 0));
        assert_eq!(u32_at(&nested, first + 36), raw.len() as u32);
        assert_eq!(u32_at(&nested, first + 40), u32_at(&raw, 8));
        assert_eq!(u32_at(&nested, first + 44), 0, "v1 raw family");
        assert_eq!(u64_at(&nested, first + 48), 0, "no invented typed payload");
        assert_eq!(u64_at(&nested, first + 56), raw.len() as u64);
        assert_eq!(&nested[first + 64..first + 64 + raw.len()], raw);
        let next = first + 64 + raw.len();
        assert_eq!(u64_at(&nested, next), 1);
        assert_eq!(u64_at(&nested, next + 8), raw.len() as u64);
        assert_eq!(u32_at(&nested, next + 44), 3, "existing Clear family");
        assert_eq!(u64_at(&nested, next + 48), 4);
        assert_eq!(&nested[next + 64..next + 64 + clear.len()], clear);
        assert_eq!(u32_at(&nested, next + 64 + clear.len()), 0x80ff0033);
        assert_eq!(nested.len(), next + 64 + clear.len() + 4);
        let mut serialized = ptr::null_mut();
        assert_eq!(emf_serialize(doc, &mut serialized, ptr::null_mut()), EMF_OK);
        assert_eq!(
            view(serialized),
            bytes,
            "snapshot preserves source document"
        );
        emf_document_free(doc);
    }
}

#[test]
fn typed_comment_keeps_v1_raw_family_and_private_bytes() {
    assert_raw_fallback(frame(0x4003, 0xfffe, &[0, 0xff, 0x80, 0], &[]), |data| {
        matches!(data, emf_core::emf_plus::RecordData::Comment(_))
    });
}

#[test]
fn typed_tsclip_keeps_v1_raw_family_signed_words_and_padding() {
    let body: Vec<u8> = [i16::MIN, i16::MAX, -1, 0, 1, -2, 3, -4]
        .into_iter()
        .flat_map(i16::to_le_bytes)
        .collect();
    assert_raw_fallback(frame(0x403a, 2, &body, &[0xde, 0xad, 0xbe, 0xef]), |data| {
        matches!(data, emf_core::emf_plus::RecordData::TSClip(_))
    });
}
