use emf_core::{
    emf_plus::{self, ObjectData, ObjectDefinition, StringFormat},
    LimitKind, ParseLimits, SerializeFailure, SerializeLimits,
};
fn words(v: &[u32]) -> Vec<u8> {
    v.iter().flat_map(|n| n.to_le_bytes()).collect()
}
fn definition(kind: u8, bytes: Vec<u8>) -> ObjectDefinition {
    ObjectDefinition {
        id: 3,
        object_type: kind,
        first_record: 0,
        last_record: 0,
        bytes,
    }
}
fn decode(kind: u8, bytes: Vec<u8>) -> ObjectData {
    definition(kind, bytes)
        .decode(&ParseLimits::default())
        .unwrap()
}
fn exact(kind: u8, bytes: Vec<u8>) -> ObjectData {
    let value = decode(kind, bytes.clone());
    assert_eq!(value.object_type(), kind);
    assert_eq!(value.serialize(&SerializeLimits::default()).unwrap(), bytes);
    value
}
#[test]
fn simple_objects_and_raw_font_names_roundtrip_and_edit() {
    let mut solid = exact(1, words(&[0xdbc01002, 0, 0xff010203]));
    let ObjectData::SolidBrush { argb, .. } = &mut solid else {
        panic!()
    };
    *argb = 0x80445566;
    assert_eq!(
        solid.serialize(&SerializeLimits::default()).unwrap(),
        words(&[0xdbc01002, 0, 0x80445566])
    );
    assert!(matches!(
        exact(1, words(&[3, 1, 7, 0xff112233, 0xff445566])),
        ObjectData::HatchBrush { style: 7, .. }
    ));
    assert!(matches!(
        exact(8, words(&[3, 99, 4, 0xff112233, u32::MAX, 77])),
        ObjectData::ImageAttributes {
            reserved1: 99,
            object_clamp: -1,
            reserved2: 77,
            ..
        }
    ));
    let mut bytes = words(&[3, 0x7fc01234, 2, u32::MAX, 88, 3]);
    bytes.extend_from_slice(&[0x00, 0xd8, 0x61, 0x00, 0x00, 0xdc, 0xde, 0xad]);
    let mut font = exact(6, bytes);
    let ObjectData::Font {
        family_name,
        suffix,
        ..
    } = &mut font
    else {
        panic!()
    };
    assert_eq!(family_name, &[0xd800, 0x61, 0xdc00]);
    assert_eq!(suffix, &[0xde, 0xad]);
    family_name[1] = 0x62;
    assert!(
        matches!(decode(6,font.serialize(&SerializeLimits::default()).unwrap()),ObjectData::Font {family_name,..} if family_name[1]==0x62)
    );
}
#[test]
fn string_format_fields_counted_arrays_and_size_changes_are_editable() {
    let mut fields: Vec<u32> = (0..13).collect();
    fields[7] = 0x80000000;
    fields[8] = u32::MAX;
    fields[11] = 0x7fc055aa;
    let mut bytes = words(&fields);
    bytes.extend(words(&[
        2,
        2,
        0x3f800000,
        0x7fc01234,
        1,
        3,
        u32::MAX,
        0x80000000,
    ]));
    let mut data = exact(7, bytes);
    let ObjectData::StringFormat(v) = &mut data else {
        panic!()
    };
    assert_eq!(v.hotkey_prefix, -1);
    assert_eq!(v.tab_stops, &[0x3f800000, 0x7fc01234]);
    assert_eq!(v.character_ranges, [[1, 3], [-1, i32::MIN]]);
    v.tab_stops.push(0x40000000);
    v.character_ranges[0] = [7, 9];
    let ObjectData::StringFormat(v) =
        decode(7, data.serialize(&SerializeLimits::default()).unwrap())
    else {
        panic!()
    };
    assert_eq!(v.tab_stops.len(), 3);
    assert_eq!(v.character_ranges[0], [7, 9]);
    let empty = ObjectData::StringFormat(StringFormat {
        version: 1,
        flags: 0,
        language: 0,
        alignment: 0,
        line_alignment: 0,
        digit_substitution: 0,
        digit_language: 0,
        first_tab_offset: 0,
        hotkey_prefix: 0,
        leading_margin: 0,
        trailing_margin: 0,
        tracking: 0,
        trimming: 0,
        tab_stops: vec![],
        character_ranges: vec![],
    });
    assert_eq!(
        decode(7, empty.serialize(&SerializeLimits::default()).unwrap()),
        empty
    );
}
#[test]
fn image_metadata_and_unexpanded_payloads_preserve_unknown_values() {
    for bitmap_type in [0, 1, 99] {
        let mut bytes = words(&[3, 1, u32::MAX, 2, 0xfffffff8, 0xdeadbeef, bitmap_type]);
        bytes.extend_from_slice(&[0, 0xff, 0x12, 0x34]);
        let mut data = exact(5, bytes);
        let ObjectData::BitmapImage {
            width,
            stride,
            pixel_format,
            data: payload,
            ..
        } = &mut data
        else {
            panic!()
        };
        assert_eq!((*width, *stride, *pixel_format), (-1, -8, 0xdeadbeef));
        assert_eq!(payload, &[0, 0xff, 0x12, 0x34]);
        *width = 13;
        assert!(matches!(
            decode(5, data.serialize(&SerializeLimits::default()).unwrap()),
            ObjectData::BitmapImage { width: 13, .. }
        ));
    }
    let mut bytes = words(&[3, 2, 5, 3]);
    bytes.extend_from_slice(&[9, 8, 7, 0xfe]);
    assert!(
        matches!(exact(5,bytes),ObjectData::MetafileImage {metafile_type:5,data,suffix,..} if data==[9,8,7]&&suffix==[0xfe])
    );
    for (kind, bytes) in [
        (1, words(&[3, 99, 0xdeadbeef])),
        (5, words(&[3, 99, 0x12345678])),
        (77, vec![0, 1, 2]),
    ] {
        assert!(matches!(exact(kind, bytes), ObjectData::Opaque { .. }));
    }
}
#[test]
fn object_counts_and_every_independent_resource_budget_fail() {
    for kind in [1, 5, 6, 7, 8] {
        for size in 0..8 {
            assert!(definition(kind, vec![0; size])
                .decode(&ParseLimits::default())
                .is_err());
        }
    }
    for count in [1, u32::MAX, 0x80000000] {
        let mut b = words(&[0; 13]);
        b.extend(words(&[count, 0]));
        assert!(definition(7, b).decode(&ParseLimits::default()).is_err());
    }
    assert!(definition(5, words(&[3, 2, 5, u32::MAX]))
        .decode(&ParseLimits::default())
        .is_err());
    assert!(definition(6, words(&[3, 1, 2, 3, 4, u32::MAX]))
        .decode(&ParseLimits::default())
        .is_err());
    let bytes = words(&[3, 0, 0xff112233]);
    for kind in [
        LimitKind::InputBytes,
        LimitKind::RecordBytes,
        LimitKind::RecordCount,
        LimitKind::WorkUnits,
    ] {
        let mut limits = ParseLimits::default();
        match kind {
            LimitKind::InputBytes => limits.max_input_bytes = 0,
            LimitKind::RecordBytes => limits.max_record_bytes = 0,
            LimitKind::RecordCount => limits.max_records = 0,
            LimitKind::WorkUnits => limits.max_work_units = 0,
            _ => unreachable!(),
        };
        assert!(
            matches!(definition(1,bytes.clone()).decode(&limits),Err(emf_plus::Error::Resource(emf_core::ParseFailure::LimitExceeded {kind:k,..})) if k==kind)
        );
    }
    let limits = ParseLimits {
        max_allocated_bytes: 0,
        ..ParseLimits::default()
    };
    assert!(definition(99, vec![1]).decode(&limits).is_err());
    let data = decode(1, bytes);
    for limits in [
        SerializeLimits {
            max_output_bytes: 11,
            ..SerializeLimits::default()
        },
        SerializeLimits {
            max_work_units: 0,
            ..SerializeLimits::default()
        },
    ] {
        assert!(matches!(
            data.serialize(&limits),
            Err(SerializeFailure::LimitExceeded { .. })
        ));
    }
}

#[test]
fn typed_object_edit_preserves_continuation_padding_and_comment_segments() {
    fn record(flags: u16, data: &[u8], padding: &[u8]) -> Vec<u8> {
        let mut out = Vec::new();
        out.extend_from_slice(&0x4008u16.to_le_bytes());
        out.extend_from_slice(&flags.to_le_bytes());
        out.extend(words(&[
            (12 + data.len() + padding.len()) as u32,
            data.len() as u32,
        ]));
        out.extend_from_slice(data);
        out.extend_from_slice(padding);
        out
    }
    let body = words(&[0xdbc01002, 0, 0xff112233]);
    let mut first = words(&[12]);
    first.extend_from_slice(&body[..5]);
    let mut bytes = record(0x8103, &first, &[0xab, 0xcd, 0xef]);
    bytes.extend(record(0x0103, &body[5..], &[0xfa]));
    let limits = ParseLimits::default();
    let mut stream = emf_plus::parse_segments(&[&bytes[..7], &[], &bytes[7..]], &limits).unwrap();
    let def = stream.object_definitions(&limits).unwrap().remove(0);
    let mut data = def.decode(&limits).unwrap();
    let ObjectData::SolidBrush { argb, .. } = &mut data else {
        panic!()
    };
    *argb = 0xff445566;
    stream
        .replace_object_bytes(
            def.first_record,
            &data.serialize(&SerializeLimits::default()).unwrap(),
            &limits,
        )
        .unwrap();
    let segments = emf_plus::serialize_segments(&stream, &SerializeLimits::default()).unwrap();
    assert_eq!(
        segments.iter().map(Vec::len).collect::<Vec<_>>(),
        vec![7, 0, bytes.len() - 7]
    );
    assert_eq!(stream.records[0].padding, [0xab, 0xcd, 0xef]);
    assert_eq!(stream.records[1].padding, [0xfa]);
    let edited = stream.object_definitions(&limits).unwrap().remove(0);
    assert_eq!(edited.decode(&limits).unwrap(), data);
}
