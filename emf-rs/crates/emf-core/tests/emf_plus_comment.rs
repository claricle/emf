use emf_core::{emf_plus as plus, ParseFailure, ParseLimits, SerializeFailure, SerializeLimits};

fn record(data: &[u8], padding: &[u8]) -> Vec<u8> {
    let mut out = vec![3, 0x40, 0xfe, 0xff];
    out.extend(((12 + data.len() + padding.len()) as u32).to_le_bytes());
    out.extend((data.len() as u32).to_le_bytes());
    out.extend(data);
    out.extend(padding);
    out
}

#[test]
fn private_data_requires_aligned_size_without_record_padding() {
    // MS-EMFPLUS 2.3.2.1 requires aligned DataSize and Size = DataSize + 12.
    for bytes in [record(&[1], &[2, 3, 4]), record(&[1; 4], &[5; 4])] {
        assert!(
            plus::parse(&bytes, &Default::default()).is_err(),
            "invalid Comment layout accepted"
        );
    }
}

#[test]
fn named_private_bytes_preserve_ignored_flags_unknown_neighbors_and_segments() {
    for bytes in [vec![], vec![0, 0xff, 0x80, 0], vec![0x55; 1024]] {
        let wire = record(&bytes, &[]);
        let stream = plus::parse(&wire, &Default::default()).unwrap();
        assert_eq!(stream.records[0].data, plus::RecordData::Comment(bytes));
        assert_eq!(stream.records[0].flags, 0xfffe);
        assert_eq!(plus::serialize(&stream).unwrap(), wire);
    }
    let mut wire = record(&[1, 2, 3, 4], &[]);
    let unknown = [0xff, 0x4f, 0x33, 0x22, 16, 0, 0, 0, 1, 0, 0, 0, 9, 8, 7, 6];
    wire.extend(unknown);
    let mut stream =
        plus::parse_segments(&[&wire[..5], &[], &wire[5..]], &Default::default()).unwrap();
    assert_eq!(
        plus::serialize_segments(&stream, &Default::default()).unwrap(),
        vec![wire[..5].to_vec(), vec![], wire[5..].to_vec()]
    );
    let plus::RecordData::Comment(data) = &mut stream.records[0].data else {
        panic!("expected Comment")
    };
    data[0] = 0xa5;
    let segments = plus::serialize_segments(&stream, &Default::default()).unwrap();
    assert_eq!(
        segments.iter().map(Vec::len).collect::<Vec<_>>(),
        vec![5, 0, wire.len() - 5]
    );
    for count in [16, 0, 4] {
        let plus::RecordData::Comment(data) = &mut stream.records[0].data else {
            unreachable!()
        };
        data.resize(count, 0xaa);
        let output = plus::serialize(&stream).unwrap();
        assert_eq!(
            u32::from_le_bytes(output[8..12].try_into().unwrap()) as usize,
            count
        );
        assert_eq!(&output[output.len() - 16..], &unknown);
        assert_eq!(
            plus::parse(&output, &Default::default()).unwrap().records,
            stream.records
        );
    }
}

#[test]
fn invalid_edits_truncation_and_resource_failures_leave_source_usable() {
    let wire = record(&[0x80; 32], &[]);
    let baseline = plus::parse(&wire, &Default::default()).unwrap();
    for mutation in 0..4 {
        let mut stream = baseline.clone();
        match mutation {
            0 => stream.records[0].record_type = 0x4004,
            1 => stream.records[0].padding = vec![0; 4],
            2 => stream.records[0].data = plus::RecordData::Comment(vec![0; 3]),
            _ => stream.records[0].data = plus::RecordData::Opaque(vec![0; 32]),
        }
        assert!(matches!(
            plus::serialize(&stream),
            Err(SerializeFailure::Inconsistent { .. })
        ));
    }
    for length in [1, 11, wire.len() - 1] {
        assert!(matches!(
            plus::parse(&wire[..length], &Default::default()),
            Err(plus::Error::Resource(ParseFailure::Truncated { .. }))
        ));
    }
    for limits in [
        ParseLimits {
            max_allocated_bytes: 31,
            ..Default::default()
        },
        ParseLimits {
            max_record_bytes: wire.len() - 1,
            ..Default::default()
        },
        ParseLimits {
            max_work_units: 0,
            ..Default::default()
        },
    ] {
        assert!(matches!(
            plus::parse(&wire, &limits),
            Err(plus::Error::Resource(ParseFailure::LimitExceeded { .. }))
        ));
    }
    assert!(matches!(
        plus::serialize_with_limits(
            &baseline,
            &SerializeLimits {
                max_output_bytes: wire.len() - 1,
                ..Default::default()
            }
        ),
        Err(SerializeFailure::LimitExceeded { .. })
    ));
    assert_eq!(plus::serialize(&baseline).unwrap(), wire);
}

#[test]
fn private_data_grows_and_shrinks_through_atomic_document_repacking() {
    fn outer(data: &[u8]) -> Vec<u8> {
        let size = (12 + data.len() + 3) & !3;
        let mut bytes = 70u32.to_le_bytes().to_vec();
        bytes.extend((size as u32).to_le_bytes());
        bytes.extend((data.len() as u32).to_le_bytes());
        bytes.extend(data);
        bytes.resize(size, 0xa5);
        bytes
    }
    let logical = record(&[0x11; 4], &[]);
    let mut wire = vec![0; 88];
    wire[..4].copy_from_slice(&1u32.to_le_bytes());
    wire[4..8].copy_from_slice(&88u32.to_le_bytes());
    wire[40..44].copy_from_slice(&0x464d4520u32.to_le_bytes());
    for part in [&logical[..7], &[], &logical[7..]] {
        let mut data = b"EMF+".to_vec();
        data.extend(part);
        wire.extend(outer(&data));
        wire.extend(outer(b"unrelated"));
    }
    wire.extend([
        14, 0, 0, 0, 20, 0, 0, 0, 0, 0, 0, 0, 16, 0, 0, 0, 20, 0, 0, 0,
    ]);
    let len = wire.len() as u32;
    wire[48..52].copy_from_slice(&len.to_le_bytes());
    wire[52..56].copy_from_slice(&8u32.to_le_bytes());
    let mut document = emf_core::parse(&wire, &Default::default()).unwrap();
    let original = document.clone();
    let snapshot = document.structured_emf_plus(&Default::default()).unwrap();
    document
        .apply_structured_emf_plus(&snapshot, &Default::default())
        .unwrap();
    assert_eq!(emf_core::serialize(&document).unwrap(), wire);
    for count in [20, 0] {
        let mut edit = document.structured_emf_plus(&Default::default()).unwrap();
        edit.stream.records[0].data = plus::RecordData::Comment(vec![0x99; count]);
        let before = document.clone();
        assert!(document
            .apply_structured_emf_plus(
                &edit,
                &SerializeLimits {
                    max_output_bytes: 0,
                    ..Default::default()
                }
            )
            .is_err());
        assert_eq!(document, before);
        document
            .apply_structured_emf_plus(&edit, &Default::default())
            .unwrap();
        let output = emf_core::serialize(&document).unwrap();
        let parsed = emf_core::parse(&output, &Default::default()).unwrap();
        assert_eq!(
            parsed
                .structured_emf_plus(&Default::default())
                .unwrap()
                .stream
                .records,
            edit.stream.records
        );
        for index in [1, 3, 5, 6] {
            assert_eq!(document.records()[index], original.records()[index]);
        }
        let before = document.clone();
        assert!(matches!(
            document.apply_structured_emf_plus(&snapshot, &Default::default()),
            Err(plus::EmbedError::StaleSource)
        ));
        assert_eq!(document, before);
    }
}
