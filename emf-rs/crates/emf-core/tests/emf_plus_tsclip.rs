use emf_core::{
    emf_plus as plus, LimitKind, ParseFailure, ParseLimits, SerializeFailure, SerializeLimits,
};

fn record(flags: u16, data: &[u8]) -> Vec<u8> {
    let mut out = 0x403au16.to_le_bytes().to_vec();
    out.extend(flags.to_le_bytes());
    out.extend(((12 + data.len()) as u32).to_le_bytes());
    out.extend((data.len() as u32).to_le_bytes());
    out.extend(data);
    out
}

#[test]
fn uncompressed_clipping_is_typed() {
    let bytes = record(1, &[0; 8]);
    let stream = plus::parse(&bytes, &ParseLimits::default()).unwrap();
    assert!(
        !matches!(stream.records[0].data, plus::RecordData::Opaque(_)),
        "uncompressed SetTSClip remains opaque"
    );
    assert_eq!(plus::serialize(&stream).unwrap(), bytes);
}

fn payload(rectangles: &[[i16; 4]]) -> Vec<u8> {
    rectangles
        .iter()
        .flatten()
        .flat_map(|v| v.to_le_bytes())
        .collect()
}
fn parse(bytes: &[u8]) -> plus::Stream {
    plus::parse(bytes, &Default::default()).unwrap()
}
#[test]
fn signed_words_empty_and_maximum_count_are_exact() {
    for rectangles in [
        vec![],
        vec![[i16::MIN, i16::MAX, -1, 0], [1, -2, 3, -4]],
        vec![[0; 4]; 0x7fff],
    ] {
        let bytes = record(rectangles.len() as u16, &payload(&rectangles));
        let stream = parse(&bytes);
        assert_eq!(
            stream.records[0].data,
            plus::RecordData::TSClip(plus::TSClip { rectangles })
        );
        assert_eq!(plus::serialize(&stream).unwrap(), bytes);
    }
}
#[test]
fn edits_preserve_segments_unknowns_and_padding() {
    let mut bytes = record(2, &payload(&[[1, 2, 3, 4], [-1, -2, -3, -4]]));
    let unknown = [
        0xff, 0x4f, 0x13, 0x37, 16, 0, 0, 0, 1, 0, 0, 0, 0xaa, 0xbb, 0xcc, 0xdd,
    ];
    bytes.extend(unknown);
    let mut stream =
        plus::parse_segments(&[&bytes[..7], &[], &bytes[7..]], &Default::default()).unwrap();
    assert_eq!(
        plus::serialize_segments(&stream, &Default::default()).unwrap(),
        vec![bytes[..7].to_vec(), vec![], bytes[7..].to_vec()]
    );
    let plus::RecordData::TSClip(clip) = &mut stream.records[0].data else {
        panic!("expected typed clip")
    };
    clip.rectangles[1][3] = i16::MIN;
    let same_size = plus::serialize_segments(&stream, &Default::default()).unwrap();
    assert_eq!(
        same_size.iter().map(Vec::len).collect::<Vec<_>>(),
        vec![7, 0, bytes.len() - 7]
    );
    assert_eq!(&same_size.concat()[bytes.len() - unknown.len()..], &unknown);
    stream.records[0].padding = vec![0xde, 0xad, 0xbe, 0xef];
    for count in [5, 0, 1] {
        let plus::RecordData::TSClip(clip) = &mut stream.records[0].data else {
            unreachable!()
        };
        clip.rectangles.resize(count, [5, -6, 7, -8]);
        stream.records[0].flags = count as u16;
        let out = plus::serialize(&stream).unwrap();
        assert_eq!(
            u32::from_le_bytes(out[8..12].try_into().unwrap()) as usize,
            count * 8
        );
        assert_eq!(
            &out[out.len() - 20..out.len() - 16],
            &[0xde, 0xad, 0xbe, 0xef]
        );
        assert_eq!(&out[out.len() - 16..], &unknown);
        assert_eq!(parse(&out).records, stream.records);
    }
}
#[test]
fn compressed_form_stays_explicitly_opaque_and_exact() {
    // No guessed interpretation or rejection based on the contradictory C-set layout.
    for data in [vec![], vec![0x80, 0xff, 0x7f, 0x00], vec![0x12; 12]] {
        let bytes = record(0x8003, &data);
        let stream = parse(&bytes);
        assert_eq!(stream.records[0].data, plus::RecordData::Opaque(data));
        assert_eq!(plus::serialize(&stream).unwrap(), bytes);
    }
}
#[test]
fn invalid_counts_truncation_and_inconsistent_edits_fail() {
    for count in [0, 1, 3, 0x7fff] {
        assert!(matches!(
            plus::parse(&record(count, &[0; 16]), &Default::default()),
            Err(plus::Error::InvalidRecord { .. })
        ));
    }
    for length in [0, 4, 12, 20] {
        assert!(plus::parse(&record(2, &vec![0; length]), &Default::default()).is_err());
    }
    let mut bytes = record(1, &[0; 8]);
    bytes.pop();
    assert!(matches!(
        plus::parse(&bytes, &Default::default()),
        Err(plus::Error::Resource(ParseFailure::Truncated { .. }))
    ));
    for (kind, flags) in [(0x403a, 0), (0x403a, 0x8001), (0x4039, 1)] {
        let mut stream = parse(&record(1, &[0; 8]));
        stream.records[0].record_type = kind;
        stream.records[0].flags = flags;
        assert!(matches!(
            plus::serialize(&stream),
            Err(SerializeFailure::Inconsistent { .. })
        ));
    }
    let mut stream = parse(&record(1, &[0; 8]));
    stream.records[0].data = plus::RecordData::Opaque(vec![0; 8]);
    assert!(plus::serialize(&stream).is_err());
}
#[test]
fn rectangle_expansion_and_serialization_use_shared_limits() {
    let bytes = record(2, &[0; 16]);
    for allocation in [false, true] {
        let check = |n: u64| {
            let limits = if allocation {
                ParseLimits {
                    max_allocated_bytes: n as usize,
                    ..Default::default()
                }
            } else {
                ParseLimits {
                    max_work_units: n,
                    ..Default::default()
                }
            };
            plus::parse(&bytes, &limits)
        };
        let (mut low, mut high) = (0, 100_000);
        while low < high {
            let mid = (low + high) / 2;
            if check(mid).is_ok() {
                high = mid;
            } else {
                low = mid + 1;
            }
        }
        assert!(low > 0);
        assert!(
            matches!(check(low - 1), Err(plus::Error::Resource(ParseFailure::LimitExceeded { kind, .. }))
            if kind == if allocation { LimitKind::AllocatedBytes } else { LimitKind::WorkUnits })
        );
        assert_eq!(check(low).unwrap().records, parse(&bytes).records);
    }
    let stream = parse(&bytes);
    for limits in [
        SerializeLimits {
            max_output_bytes: bytes.len() - 1,
            ..Default::default()
        },
        SerializeLimits {
            max_work_units: 5,
            ..Default::default()
        },
    ] {
        assert!(matches!(
            plus::serialize_with_limits(&stream, &limits),
            Err(SerializeFailure::LimitExceeded { .. })
        ));
    }
    assert_eq!(plus::serialize(&stream).unwrap(), bytes);
}
