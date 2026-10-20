use emf_core::{
    wmf::{
        self,
        escape::{EncapsulatedPostScriptPayload, EscapeRecord},
    },
    ParseLimits,
};

fn record(data: Vec<u8>) -> EscapeRecord {
    EscapeRecord {
        function: 0xff26,
        escape_function: 0x1014,
        padding: if data.len() % 2 != 0 {
            Some(0xa5)
        } else {
            None
        },
        data,
    }
}

fn payload<'a>(data: &'a [u8], extra: &'a [u8]) -> EncapsulatedPostScriptPayload<'a> {
    EncapsulatedPostScriptPayload {
        version: 0xffff_ffff,
        points: [[i32::MIN, i32::MAX], [-1, 0], [16, -16]],
        data,
        extra,
    }
}

#[test]
fn postscript_view_preserves_signed_coordinates_and_both_count_domains() {
    let mut r = record(vec![]);
    let p = payload(&[0xff, 0, 0xc0], &[0xab, 0xcd]);
    r.replace_encapsulated_postscript_payload(p).unwrap();
    assert_eq!(r.typed_encapsulated_postscript_payload(), Some(p));
    assert_eq!(u32::from_le_bytes(r.data[..4].try_into().unwrap()), 35);
    assert_eq!(r.data.len(), 37);
    assert_eq!(r.padding, Some(0));
    let v = r.typed_encapsulated_postscript_payload().unwrap();
    assert_eq!(v.data.as_ptr(), r.data[32..].as_ptr());
    assert_eq!(v.extra.as_ptr(), r.data[35..].as_ptr());

    let mut body = 0x1014u16.to_le_bytes().to_vec();
    body.extend_from_slice(&(r.data.len() as u16).to_le_bytes());
    body.extend_from_slice(&r.data);
    body.extend_from_slice(&[0xa5, 0xca, 0xfe]);
    let words = (6 + body.len()) as u32 / 2;
    let mut bytes = vec![1, 0, 9, 0, 0, 3];
    bytes.extend_from_slice(&(12 + words).to_le_bytes());
    bytes.extend_from_slice(&[0, 0]);
    bytes.extend_from_slice(&words.to_le_bytes());
    bytes.extend_from_slice(&[0, 0]);
    bytes.extend_from_slice(&words.to_le_bytes());
    bytes.extend_from_slice(&0xff26u16.to_le_bytes());
    bytes.extend_from_slice(&body);
    bytes.extend_from_slice(&[3, 0, 0, 0, 0, 0, 0xde, 0xad]);
    let mut doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
    assert!(doc.diagnostics().is_empty());
    assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
    let Some(wmf::TypedRecord::Escape(parsed)) = doc.records()[0].typed() else {
        panic!("escape")
    };
    assert_eq!(parsed.typed_encapsulated_postscript_payload(), Some(p));
    let mut changed = parsed.clone();
    changed
        .replace_encapsulated_postscript_payload(payload(&[0x80, 0], &[9, 8]))
        .unwrap();
    doc.replace_typed(0, wmf::TypedRecord::Escape(changed))
        .unwrap();
    let encoded = wmf::serialize(&doc).unwrap();
    let parsed = wmf::parse(&encoded, &ParseLimits::default()).unwrap();
    assert!(parsed
        .record_body(&parsed.records()[0])
        .unwrap()
        .ends_with(&[0xca, 0xfe]));
    assert_eq!(parsed.tail(), &[0xde, 0xad]);
    let Some(wmf::TypedRecord::Escape(r)) = parsed.records()[0].typed() else {
        panic!("escape")
    };
    assert_eq!(
        r.typed_encapsulated_postscript_payload(),
        Some(payload(&[0x80, 0], &[9, 8]))
    );
    assert_eq!(r.function, 0xff26);
    assert_eq!(r.padding, None);
}

#[test]
fn invalid_inner_sizes_stay_opaque_and_failed_edits_are_atomic() {
    for len in 0..32 {
        assert!(record(vec![0; len])
            .typed_encapsulated_postscript_payload()
            .is_none());
    }
    for size in [0u32, 31, 33, u32::MAX] {
        let mut bytes = vec![0; 32];
        bytes[..4].copy_from_slice(&size.to_le_bytes());
        assert!(record(bytes)
            .typed_encapsulated_postscript_payload()
            .is_none());
    }
    let mut r = record(vec![]);
    let max = vec![0xff; u16::MAX as usize - 32];
    r.replace_encapsulated_postscript_payload(payload(&max, &[]))
        .unwrap();
    assert_eq!(r.data.len(), u16::MAX as usize);
    assert_eq!(
        r.typed_encapsulated_postscript_payload(),
        Some(payload(&max, &[]))
    );
    let before = r.clone();
    assert!(r
        .replace_encapsulated_postscript_payload(payload(&max, &[0]))
        .is_err());
    assert_eq!(r, before);
    r.escape_function = 0x1013;
    assert!(r.typed_encapsulated_postscript_payload().is_none());
    r.escape_function = 0x1014;
    r.padding = None;
    assert!(r.typed_encapsulated_postscript_payload().is_none());
    r.function = 0x1234;
    let before = r.clone();
    assert!(r
        .replace_encapsulated_postscript_payload(payload(&[], &[]))
        .is_err());
    assert_eq!(r, before);
}
