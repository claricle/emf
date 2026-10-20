use emf_core::{
    emf_plus::{EmbedError, RecordData as PlusData},
    *,
};

fn plus() -> Vec<u8> {
    let mut b = vec![9, 0x40, 0x34, 0x12]; // Clear with reserved flags
    b.extend_from_slice(&16u32.to_le_bytes());
    b.extend_from_slice(&4u32.to_le_bytes());
    b.extend_from_slice(&0xaabbccddu32.to_le_bytes());
    // Opaque record with nonzero EMF+ padding.
    b.extend_from_slice(&[0x77, 0x77, 0xab, 0xcd, 16, 0, 0, 0, 1, 0, 0, 0, 99, 7, 8, 9]);
    b
}
fn comment(data: &[u8], extra: usize) -> Vec<u8> {
    let mut b = 70u32.to_le_bytes().to_vec();
    let padding = (4 - data.len() % 4) % 4;
    b.extend_from_slice(&((12 + data.len() + padding + extra) as u32).to_le_bytes());
    b.extend_from_slice(&(data.len() as u32).to_le_bytes());
    b.extend_from_slice(data);
    b.resize(b.len() + padding + extra, 0xa5);
    b
}
fn fixture(extra: usize) -> Vec<u8> {
    let mut b = vec![0; 88];
    b[0..4].copy_from_slice(&1u32.to_le_bytes());
    b[4..8].copy_from_slice(&88u32.to_le_bytes());
    b[40..44].copy_from_slice(&0x464d4520u32.to_le_bytes());
    let stream = plus();
    for (i, part) in [&stream[..3], &stream[3..3], &stream[3..]]
        .iter()
        .enumerate()
    {
        let mut data = b"EMF+".to_vec();
        data.extend_from_slice(part);
        b.extend(comment(&data, if i == 2 { extra } else { 0 }));
        b.extend(comment(b"unrelated", 0));
    }
    b.extend_from_slice(&[0x88, 0x88, 0, 0, 12, 0, 0, 0, 4, 3, 2, 1]);
    b.extend_from_slice(&[
        14, 0, 0, 0, 20, 0, 0, 0, 0, 0, 0, 0, 16, 0, 0, 0, 20, 0, 0, 0,
    ]);
    b.extend_from_slice(b"tail");
    let size = b.len() as u32;
    b[48..52].copy_from_slice(&size.to_le_bytes());
    b[52..56].copy_from_slice(&9u32.to_le_bytes());
    b
}
fn doc(extra: usize) -> Document {
    parse(&fixture(extra), &ParseLimits::default()).unwrap()
}

#[test]
fn unchanged_and_typed_edits_preserve_enclosing_comments_unknowns_and_padding() {
    let mut d = doc(0);
    let original = d.clone();
    let mut typed = d.structured_emf_plus(&ParseLimits::default()).unwrap();
    assert_eq!(typed.stream.segment_lengths(), [3, 0, 29]);
    assert_eq!(
        typed.stream.records[0].data,
        PlusData::Clear { argb: 0xaabbccdd }
    );
    d.apply_structured_emf_plus(&typed, &SerializeLimits::default())
        .unwrap();
    assert_eq!(d, original);
    assert_eq!(serialize(&d).unwrap(), fixture(0));
    typed.stream.records[0].data = PlusData::Clear { argb: 0x11223344 };
    d.apply_structured_emf_plus(&typed, &SerializeLimits::default())
        .unwrap();
    let output = serialize(&d).unwrap();
    let reparsed = parse(&output, &ParseLimits::default()).unwrap();
    assert_eq!(
        reparsed
            .structured_emf_plus(&ParseLimits::default())
            .unwrap()
            .stream,
        typed.stream
    );
    for i in [0, 1, 2, 3, 5, 6, 7] {
        assert_eq!(d.records()[i], original.records()[i]);
    }
    let offset = original.records()[4].offset();
    let end = offset + original.records()[4].size() as usize;
    assert_eq!(&output[end - 3..end], &[0xa5; 3]);
    assert_eq!(&output[..offset], &fixture(0)[..offset]);
    assert_eq!(
        &output[offset + original.records()[4].size() as usize..],
        &fixture(0)[offset + original.records()[4].size() as usize..]
    );
    assert_eq!(
        reparsed.emf_plus_chunks().collect::<Vec<_>>().concat()[12..16],
        [0x44, 0x33, 0x22, 0x11]
    );
    assert_eq!(
        d.apply_structured_emf_plus(&typed, &SerializeLimits::default()),
        Err(EmbedError::StaleSource)
    );
}

#[test]
fn raw_mutations_and_new_selected_comments_reject_stale_snapshots_atomically() {
    for (index, data) in [(4, b"EMF+replaced".to_vec()), (1, b"EMF+".to_vec())] {
        let mut d = doc(0);
        let typed = d.structured_emf_plus(&ParseLimits::default()).unwrap();
        d.edit_record(index, RecordData::Comment { data }).unwrap();
        let before = d.clone();
        assert_eq!(
            d.apply_structured_emf_plus(&typed, &SerializeLimits::default()),
            Err(EmbedError::StaleSource)
        );
        assert_eq!(d, before);
    }
}

#[test]
fn invalid_size_layout_and_limits_leave_document_unchanged() {
    for extra in [0, 4] {
        let mut d = doc(extra);
        let before = d.clone();
        let mut typed = d.structured_emf_plus(&ParseLimits::default()).unwrap();
        typed.stream.records[0].data = PlusData::Clear { argb: 123 };
        if extra == 0 {
            typed.stream.records[1].padding.push(0);
        }
        assert!(d
            .apply_structured_emf_plus(&typed, &SerializeLimits::default())
            .is_err());
        assert_eq!(d, before);
    }
    let mut d = doc(0);
    let typed = d.structured_emf_plus(&ParseLimits::default()).unwrap();
    let before = d.clone();
    for limits in [
        SerializeLimits {
            max_output_bytes: 1,
            ..SerializeLimits::default()
        },
        SerializeLimits {
            max_work_units: 1,
            ..SerializeLimits::default()
        },
    ] {
        assert!(matches!(
            d.apply_structured_emf_plus(&typed, &limits),
            Err(EmbedError::Serialize(
                SerializeFailure::LimitExceeded { .. }
            ))
        ));
        assert_eq!(d, before);
    }
    for limits in [
        ParseLimits {
            max_input_bytes: 1,
            ..ParseLimits::default()
        },
        ParseLimits {
            max_allocated_bytes: 1,
            ..ParseLimits::default()
        },
        ParseLimits {
            max_work_units: 1,
            ..ParseLimits::default()
        },
    ] {
        assert!(matches!(
            d.structured_emf_plus(&limits),
            Err(emf_core::emf_plus::Error::Resource(
                ParseFailure::LimitExceeded { .. }
            ))
        ));
    }
}

#[test]
fn late_failure_is_atomic_and_unrelated_raw_edits_can_coexist() {
    let mut d = doc(4);
    let mut typed = d.structured_emf_plus(&ParseLimits::default()).unwrap();
    typed.stream.records[0].flags ^= 1; // Changes first comment.
    typed.stream.records[0].data = PlusData::Clear { argb: 77 }; // Changes last comment.
    let before = d.clone();
    assert_eq!(
        d.apply_structured_emf_plus(&typed, &SerializeLimits::default()),
        Err(EmbedError::Edit(EditFailure::RecordLayout { index: 4 }))
    );
    assert_eq!(d, before);

    let mut d = doc(0);
    let mut typed = d.structured_emf_plus(&ParseLimits::default()).unwrap();
    d.edit_record(
        1,
        RecordData::Comment {
            data: b"another unrelated comment".to_vec(),
        },
    )
    .unwrap();
    let unrelated = d.records()[1].clone();
    typed.stream.records[0].data = PlusData::Clear { argb: 77 };
    d.apply_structured_emf_plus(&typed, &SerializeLimits::default())
        .unwrap();
    assert_eq!(d.records()[1], unrelated);
    let output = serialize(&d).unwrap();
    let parsed = parse(&output, &ParseLimits::default()).unwrap();
    assert_eq!(parsed.records()[1].data(), unrelated.data());
    let fresh = d.structured_emf_plus(&ParseLimits::default()).unwrap();
    let before = d.clone();
    d.apply_structured_emf_plus(&fresh, &SerializeLimits::default())
        .unwrap();
    assert_eq!(d, before);
}

#[test]
fn malformed_embedded_data_is_an_opt_in_error_and_empty_selection_is_exact() {
    let mut d = doc(0);
    for index in [0, 2, 4] {
        d.edit_record(
            index,
            RecordData::Comment {
                data: b"ordinary".to_vec(),
            },
        )
        .unwrap();
    }
    let typed = d.structured_emf_plus(&ParseLimits::default()).unwrap();
    assert!(typed.stream.records.is_empty());
    let before = d.clone();
    d.apply_structured_emf_plus(&typed, &SerializeLimits::default())
        .unwrap();
    assert_eq!(d, before);
    d.edit_record(
        2,
        RecordData::Comment {
            data: b"EMF+bad".to_vec(),
        },
    )
    .unwrap();
    let bytes = serialize(&d).unwrap();
    let parsed = parse(&bytes, &ParseLimits::default()).unwrap();
    assert_eq!(
        parsed.emf_plus_chunks().collect::<Vec<_>>(),
        [b"bad".as_slice()]
    );
    assert!(parsed.structured_emf_plus(&ParseLimits::default()).is_err());
    assert_eq!(serialize(&parsed).unwrap(), bytes);
}

#[test]
fn continued_object_edits_reach_enclosing_comments() {
    use emf_core::emf_plus::ObjectData;
    fn object_record(flags: u16, data: &[u8], padding: &[u8]) -> Vec<u8> {
        let mut b = 0x4008u16.to_le_bytes().to_vec();
        b.extend_from_slice(&flags.to_le_bytes());
        b.extend_from_slice(&((12 + data.len() + padding.len()) as u32).to_le_bytes());
        b.extend_from_slice(&(data.len() as u32).to_le_bytes());
        b.extend_from_slice(data);
        b.extend_from_slice(padding);
        b
    }
    let body: Vec<u8> = [0xdbc01002u32, 0, 0xff112233]
        .iter()
        .flat_map(|v| v.to_le_bytes())
        .collect();
    let mut first = 12u32.to_le_bytes().to_vec();
    first.extend_from_slice(&body[..5]);
    let mut bytes = object_record(0x8103, &first, &[0xab, 0xcd, 0xef]);
    bytes.extend(object_record(0x0103, &body[5..], &[0xfa]));
    let mut d = doc(0);
    for (index, part) in [(0, &bytes[..7]), (2, &bytes[7..7]), (4, &bytes[7..])] {
        let mut data = b"EMF+".to_vec();
        data.extend_from_slice(part);
        d.edit_record(index, RecordData::Comment { data }).unwrap();
    }
    let serialized = serialize(&d).unwrap();
    let mut d = parse(&serialized, &ParseLimits::default()).unwrap();
    let mut typed = d.structured_emf_plus(&ParseLimits::default()).unwrap();
    let definition = typed
        .stream
        .object_definitions(&ParseLimits::default())
        .unwrap()
        .remove(0);
    let mut value = definition.decode(&ParseLimits::default()).unwrap();
    let ObjectData::SolidBrush { argb, .. } = &mut value else {
        panic!()
    };
    *argb = 0xff445566;
    typed
        .stream
        .replace_object_bytes(
            definition.first_record,
            &value.serialize(&SerializeLimits::default()).unwrap(),
            &ParseLimits::default(),
        )
        .unwrap();
    d.apply_structured_emf_plus(&typed, &SerializeLimits::default())
        .unwrap();
    let output = serialize(&d).unwrap();
    let reparsed = parse(&output, &ParseLimits::default()).unwrap();
    let stream = reparsed
        .structured_emf_plus(&ParseLimits::default())
        .unwrap()
        .stream;
    assert_eq!(stream, typed.stream);
    assert_eq!(
        stream.object_definitions(&ParseLimits::default()).unwrap()[0]
            .decode(&ParseLimits::default())
            .unwrap(),
        value
    );
}

fn split_document() -> Document {
    let bytes = plus();
    let mut d = doc(0);
    for (index, part) in [(0, &bytes[..7]), (2, &bytes[7..19]), (4, &bytes[19..])] {
        let mut data = b"EMF+".to_vec();
        data.extend_from_slice(part);
        d.edit_record(index, RecordData::Comment { data }).unwrap();
    }
    parse(&serialize(&d).unwrap(), &ParseLimits::default()).unwrap()
}

#[test]
fn growth_and_shrink_repack_across_comments_and_preserve_unrelated_wire() {
    for change in [1, -1, -2] {
        let mut d = split_document();
        let original = d.clone();
        let mut typed = d.structured_emf_plus(&ParseLimits::default()).unwrap();
        if change > 0 {
            // Insert a complete opaque record before a record already split
            // across comments, moving the old records across those boundaries.
            let added = typed.stream.records[1].clone();
            typed.stream.records.insert(0, added);
        } else if change == -1 {
            typed.stream.records.remove(0);
        } else {
            typed.stream.records.clear();
        }
        let expected = emf_core::emf_plus::serialize(&typed.stream).unwrap();
        let lengths = match change {
            1 => vec![7, 12, 29],
            -1 => vec![7, 9, 0],
            _ => vec![0, 0, 0],
        };
        d.apply_structured_emf_plus(&typed, &SerializeLimits::default())
            .unwrap();
        assert_eq!(
            d.emf_plus_chunks().map(<[u8]>::len).collect::<Vec<_>>(),
            lengths
        );
        let output = serialize(&d).unwrap();
        let parsed = parse(&output, &ParseLimits::default()).unwrap();
        assert_eq!(
            parsed.emf_plus_chunks().collect::<Vec<_>>().concat(),
            expected
        );
        assert_eq!(
            parsed
                .structured_emf_plus(&ParseLimits::default())
                .unwrap()
                .stream
                .records,
            typed.stream.records
        );
        for index in [1, 3, 5, 6, 7] {
            assert_eq!(d.records()[index], original.records()[index]);
            assert_eq!(
                parsed.record_bytes(&parsed.records()[index]),
                original.record_bytes(&original.records()[index])
            );
        }
        // Existing outer padding prefixes survive a shrink; newly needed
        // padding is zeroed according to the ordinary EMR_COMMENT contract.
        for index in [0, 2, 4] {
            let old = original.record_bytes(&original.records()[index]).unwrap();
            let new = parsed.record_bytes(&parsed.records()[index]).unwrap();
            let old_payload = match original.records()[index].data() {
                RecordData::Comment { data } => data.len(),
                _ => unreachable!(),
            };
            let new_payload = match parsed.records()[index].data() {
                RecordData::Comment { data } => data.len(),
                _ => unreachable!(),
            };
            let old_padding = &old[12 + old_payload..];
            let new_padding = &new[12 + new_payload..];
            let preserved = old_padding.len().min(new_padding.len());
            assert_eq!(&new_padding[..preserved], &old_padding[..preserved]);
            assert!(new_padding[preserved..].iter().all(|b| *b == 0));
        }
        assert!(output.ends_with(b"tail"));
        assert_eq!(
            d.apply_structured_emf_plus(&typed, &SerializeLimits::default()),
            Err(EmbedError::StaleSource)
        );
        let fresh = d.structured_emf_plus(&ParseLimits::default()).unwrap();
        let before = d.clone();
        d.apply_structured_emf_plus(&fresh, &SerializeLimits::default())
            .unwrap();
        assert_eq!(d, before);
        assert_eq!(serialize(&d).unwrap(), output);
    }
}

#[test]
fn repacking_output_limits_and_late_layout_failure_are_atomic() {
    let mut d = split_document();
    let mut typed = d.structured_emf_plus(&ParseLimits::default()).unwrap();
    let added = typed.stream.records[1].clone();
    typed.stream.records.insert(0, added);
    let before = d.clone();
    for limits in [
        SerializeLimits {
            max_output_bytes: 59,
            ..SerializeLimits::default()
        },
        SerializeLimits {
            max_work_units: 1,
            ..SerializeLimits::default()
        },
    ] {
        assert!(matches!(
            d.apply_structured_emf_plus(&typed, &limits),
            Err(EmbedError::Serialize(
                SerializeFailure::LimitExceeded { .. }
            ))
        ));
        assert_eq!(d, before);
    }
    d.apply_structured_emf_plus(
        &typed,
        &SerializeLimits {
            max_output_bytes: 60,
            ..SerializeLimits::default()
        },
    )
    .unwrap();
    let mut d = doc(4);
    let mut typed = d.structured_emf_plus(&ParseLimits::default()).unwrap();
    let added = typed.stream.records[1].clone();
    typed.stream.records.insert(0, added);
    let before = d.clone();
    assert_eq!(
        d.apply_structured_emf_plus(&typed, &SerializeLimits::default()),
        Err(EmbedError::Edit(EditFailure::RecordLayout { index: 4 }))
    );
    assert_eq!(d, before);
}

#[test]
fn repacking_rejects_stale_growth_and_has_no_implicit_comment_insertion() {
    let mut d = split_document();
    let mut typed = d.structured_emf_plus(&ParseLimits::default()).unwrap();
    let added = typed.stream.records[1].clone();
    typed.stream.records.push(added);
    d.edit_record(
        0,
        RecordData::Comment {
            data: b"EMF+changed".to_vec(),
        },
    )
    .unwrap();
    let before = d.clone();
    assert_eq!(
        d.apply_structured_emf_plus(&typed, &SerializeLimits::default()),
        Err(EmbedError::StaleSource)
    );
    assert_eq!(d, before);

    let stream = typed.stream;
    let mut d = split_document();
    for index in [0, 2, 4] {
        d.edit_record(
            index,
            RecordData::Comment {
                data: b"ordinary".to_vec(),
            },
        )
        .unwrap();
    }
    let mut typed = d.structured_emf_plus(&ParseLimits::default()).unwrap();
    typed.stream = stream;
    let before = d.clone();
    assert!(matches!(
        d.apply_structured_emf_plus(&typed, &SerializeLimits::default()),
        Err(EmbedError::Serialize(SerializeFailure::Inconsistent { .. }))
    ));
    assert_eq!(d, before);
}
