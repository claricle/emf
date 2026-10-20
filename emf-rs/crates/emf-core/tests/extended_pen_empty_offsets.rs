use emf_core::{parse, serialize, ParseLimits, RecordData};

fn document(styles: &[u32]) -> Vec<u8> {
    let fixed = 52 + styles.len() as u32 * 4;
    let mut bytes = vec![0u8; 88];
    bytes[0..4].copy_from_slice(&1u32.to_le_bytes());
    bytes[4..8].copy_from_slice(&88u32.to_le_bytes());
    bytes[40..44].copy_from_slice(&0x464d4520u32.to_le_bytes());
    let fields = [
        95,
        fixed,
        2,
        fixed - 8,
        0,
        fixed - 8,
        0,
        0x12200,
        8,
        0,
        0xffffff,
        0,
        styles.len() as u32,
    ];
    bytes.extend(fields.iter().chain(styles).flat_map(|v| v.to_le_bytes()));
    bytes.extend(
        [999u32, 12, 0xfedcba98, 14, 20, 0, 16, 20]
            .iter()
            .flat_map(|v| v.to_le_bytes()),
    );
    bytes.extend_from_slice(b"tail");
    bytes
}

#[test]
fn zero_length_bitmap_offsets_inside_fixed_fields_preserve_source_and_empty_presence() {
    for styles in [&[][..], &[20, 24, 20, 24][..]] {
        let bytes = document(styles);
        let mut doc = parse(&bytes, &ParseLimits::default()).unwrap();
        let RecordData::ExtCreatePen(pen) = doc.records()[0].data() else {
            panic!(
                "valid empty buffers must decode: {:?}",
                doc.records()[0].data()
            );
        };
        assert_eq!(pen.style_entries, styles);
        assert_eq!(pen.bitmap_info.as_deref(), Some(&[][..]));
        assert_eq!(pen.bitmap_bits.as_deref(), Some(&[][..]));
        assert_eq!(serialize(&doc).unwrap(), bytes);
        let mut edited = pen.clone();
        edited.width = 17;
        doc.edit_record(0, RecordData::ExtCreatePen(edited))
            .unwrap();
        let encoded = serialize(&doc).unwrap();
        let reparsed = parse(&encoded, &ParseLimits::default()).unwrap();
        let RecordData::ExtCreatePen(pen) = reparsed.records()[0].data() else {
            panic!("edited pen must decode")
        };
        assert_eq!(pen.width, 17);
        assert_eq!(pen.bitmap_info.as_deref(), Some(&[][..]));
        assert_eq!(
            &encoded[88 + 52 + styles.len() * 4..],
            &bytes[88 + 52 + styles.len() * 4..]
        );
    }
}

#[test]
fn nonempty_bitmap_offsets_inside_fixed_fields_remain_raw() {
    let mut bytes = document(&[]);
    bytes[88 + 16..88 + 20].copy_from_slice(&4u32.to_le_bytes());
    let doc = parse(&bytes, &ParseLimits::default()).unwrap();
    assert_eq!(doc.records()[0].data(), &RecordData::Raw);
    assert_eq!(serialize(&doc).unwrap(), bytes);
}
