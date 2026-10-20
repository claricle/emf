use emf_core::{
    wmf::{
        self,
        escape::{EscapeRecord, GetColorTablePayload},
        TypedRecord,
    },
    ParseLimits,
};

fn make_record(data: Vec<u8>) -> EscapeRecord {
    EscapeRecord {
        function: 0xff26,
        escape_function: 0x0005,
        padding: if data.len() % 2 != 0 {
            Some(0xa5)
        } else {
            None
        },
        data,
    }
}

fn payload<'a>(undefined_space: &'a [u8], color_table: &'a [u8]) -> GetColorTablePayload<'a> {
    GetColorTablePayload {
        undefined_space,
        color_table,
    }
}

#[test]
fn view_uses_whole_record_start_and_preserves_arbitrary_gap_and_table_bytes() {
    let mut record = make_record(vec![]);
    let expected = payload(&[0xde, 0xad, 0x00], &[0x01, 0xff, 0x7e, 0x80]);
    record.replace_get_color_table_payload(expected).unwrap();
    assert_eq!(&record.data[..2], &15u16.to_le_bytes());
    assert_eq!(record.typed_get_color_table_payload(), Some(expected));
    let view = record.typed_get_color_table_payload().unwrap();
    assert_eq!(view.undefined_space.as_ptr(), record.data[2..5].as_ptr());
    assert_eq!(view.color_table.as_ptr(), record.data[5..].as_ptr());
    assert_eq!(record.padding, Some(0));
    assert_eq!(record.function, 0xff26);
}

#[test]
fn invalid_offsets_transport_and_subtypes_remain_opaque() {
    for start in [0u16, 11, 16] {
        let mut data = start.to_le_bytes().to_vec();
        data.extend_from_slice(&[1, 2, 3]);
        assert!(make_record(data).typed_get_color_table_payload().is_none());
    }
    let too_short = make_record(vec![12]);
    assert!(too_short.typed_get_color_table_payload().is_none());
    let mut valid = make_record(12u16.to_le_bytes().to_vec());
    valid.padding = Some(0);
    assert!(valid.typed_get_color_table_payload().is_none());
    valid.padding = None;
    valid.escape_function = 4;
    assert!(valid.typed_get_color_table_payload().is_none());
}

#[test]
fn u16_boundaries_are_supported_and_failed_replacements_are_atomic() {
    let mut record = make_record(vec![]);
    record
        .replace_get_color_table_payload(payload(&[], &vec![0x5a; u16::MAX as usize - 2]))
        .unwrap();
    assert_eq!(record.data.len(), u16::MAX as usize);
    assert_eq!(record.padding, Some(0));
    assert_eq!(record.data[..2], 12u16.to_le_bytes());
    assert_eq!(
        record
            .typed_get_color_table_payload()
            .unwrap()
            .color_table
            .len(),
        65533
    );
    let mut start_boundary = make_record(vec![]);
    start_boundary
        .replace_get_color_table_payload(payload(&vec![0x3c; 65523], &[]))
        .unwrap();
    assert_eq!(start_boundary.data[..2], u16::MAX.to_le_bytes());
    assert_eq!(
        start_boundary
            .typed_get_color_table_payload()
            .unwrap()
            .undefined_space
            .len(),
        65523
    );
    let before = record.clone();
    assert!(record
        .replace_get_color_table_payload(payload(&[0], &vec![0; u16::MAX as usize - 2]))
        .is_err());
    assert_eq!(record, before);

    let before = record.clone();
    record.function = 0x1234;
    let invalid_function_before = record.clone();
    assert!(record
        .replace_get_color_table_payload(payload(&[], &[]))
        .is_err());
    assert_eq!(record, invalid_function_before);
    record = before;
    let before_oversize_count = record.clone();
    assert!(record
        .replace_get_color_table_payload(payload(&[], &vec![0; 65534]))
        .is_err());
    assert_eq!(record, before_oversize_count);
    let before_oversize_start = record.clone();
    assert!(record
        .replace_get_color_table_payload(payload(&vec![0; 65524], &[]))
        .is_err());
    assert_eq!(record, before_oversize_start);
}

#[test]
fn document_edit_preserves_record_suffix_and_file_tail() {
    let mut escape_body = 0x0005u16.to_le_bytes().to_vec();
    escape_body.extend_from_slice(&6u16.to_le_bytes());
    escape_body.extend_from_slice(&12u16.to_le_bytes());
    escape_body.extend_from_slice(&[0x11, 0x22, 0x33, 0x44]);
    escape_body.extend_from_slice(&[0xca, 0xfe]);
    let words = ((6 + escape_body.len()) / 2) as u32;
    let mut bytes = vec![1, 0, 9, 0, 0, 3];
    bytes.extend_from_slice(&(12 + words).to_le_bytes());
    bytes.extend_from_slice(&[0, 0]);
    bytes.extend_from_slice(&words.to_le_bytes());
    bytes.extend_from_slice(&[0, 0]);
    bytes.extend_from_slice(&words.to_le_bytes());
    bytes.extend_from_slice(&0xff26u16.to_le_bytes());
    bytes.extend_from_slice(&escape_body);
    bytes.extend_from_slice(&[3, 0, 0, 0, 0, 0, 0xde, 0xad]);

    let mut doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
    assert!(doc.diagnostics().is_empty());
    assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
    let Some(TypedRecord::Escape(escape)) = doc.records()[0].typed() else {
        panic!("escape")
    };
    let mut escape = escape.clone();
    assert_eq!(
        escape.typed_get_color_table_payload(),
        Some(payload(&[], &[0x11, 0x22, 0x33, 0x44]))
    );
    escape
        .replace_get_color_table_payload(payload(&[0x7f, 0x80], &[0x00, 0xff]))
        .unwrap();
    doc.replace_typed(0, TypedRecord::Escape(escape)).unwrap();
    let encoded = wmf::serialize(&doc).unwrap();
    let reparsed = wmf::parse(&encoded, &ParseLimits::default()).unwrap();
    assert!(reparsed
        .record_body(&reparsed.records()[0])
        .unwrap()
        .ends_with(&[0xca, 0xfe]));
    assert_eq!(reparsed.tail(), &[0xde, 0xad]);
    let Some(TypedRecord::Escape(escape)) = reparsed.records()[0].typed() else {
        panic!("escape")
    };
    assert_eq!(
        escape.typed_get_color_table_payload(),
        Some(payload(&[0x7f, 0x80], &[0x00, 0xff]))
    );
}
