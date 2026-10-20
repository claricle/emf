use emf_core::{
    emf_plus::{self as plus, RecordData},
    ParseLimits,
};
fn words(v: &[u32]) -> Vec<u8> {
    v.iter().flat_map(|v| v.to_le_bytes()).collect()
}
fn record(data: &[u8]) -> Vec<u8> {
    let mut out = vec![0x38, 0x40, 0xba, 0xdc];
    out.extend(((12 + data.len()) as u32).to_le_bytes());
    out.extend((data.len() as u32).to_le_bytes());
    out.extend(data);
    out
}
fn blur() -> Vec<u8> {
    let mut data = vec![
        0xa4, 0x80, 0x3c, 0x63, 0x43, 0x18, 0x2b, 0x48, 0x9e, 0xf2, 0xbe, 0x28, 0x34, 0xc5, 0xfd,
        0xd4,
    ];
    data.extend(words(&[8, 0x7fc12345, u32::MAX]));
    record(&data)
}
#[test]
fn serialized_effect_is_typed_and_exact() {
    let bytes = blur();
    let stream = plus::parse(&bytes, &ParseLimits::default()).unwrap();
    assert!(
        !matches!(stream.records[0].data, RecordData::Opaque(_)),
        "effect remains opaque"
    );
    assert_eq!(plus::serialize(&stream).unwrap(), bytes);
}

use emf_core::{LimitKind, SerializeLimits};
use plus::Effect;
fn effect_bytes(guid: &str, payload: &[u8]) -> Vec<u8> {
    let parts: Vec<_> = guid.split('-').collect();
    let mut out = Vec::new();
    out.extend(u32::from_str_radix(parts[0], 16).unwrap().to_le_bytes());
    out.extend(u16::from_str_radix(parts[1], 16).unwrap().to_le_bytes());
    out.extend(u16::from_str_radix(parts[2], 16).unwrap().to_le_bytes());
    let tail = format!("{}{}", parts[3], parts[4]);
    for i in (0..tail.len()).step_by(2) {
        out.push(u8::from_str_radix(&tail[i..i + 2], 16).unwrap());
    }
    out.extend((payload.len() as u32).to_le_bytes());
    out.extend(payload);
    record(&out)
}
fn fixtures() -> Vec<(&'static str, Effect, Vec<u8>)> {
    vec![
        (
            "633C80A4-1843-482B-9EF2-BE2834C5FDD4",
            Effect::Blur {
                radius: 0x7fc12345,
                expand_edge: u32::MAX,
            },
            words(&[0x7fc12345, u32::MAX]),
        ),
        (
            "D3A1DBE1-8EC4-4C17-9F4C-EA97AD1C343D",
            Effect::BrightnessContrast {
                brightness: i32::MIN,
                contrast: -1,
            },
            words(&[0x80000000, u32::MAX]),
        ),
        (
            "537E597D-251E-48DA-9664-29CA496B70F8",
            Effect::ColorBalance {
                cyan_red: -1,
                magenta_green: 2,
                yellow_blue: -3,
            },
            words(&[u32::MAX, 2, (-3i32) as u32]),
        ),
        (
            "DD6A0022-58E4-4A67-9D9B-D48EB881A53D",
            Effect::ColorCurve {
                adjustment: 0xffffffff,
                channel: 2,
                intensity: -3,
            },
            words(&[u32::MAX, 2, (-3i32) as u32]),
        ),
        (
            "A7CE72A9-0F7F-40D7-B3CC-D0C02D5C3212",
            Effect::ColorLookupTable {
                tables: (0..4)
                    .map(|n| std::array::from_fn(|i| (i as u8).wrapping_add(n)))
                    .collect(),
            },
            (0..4)
                .flat_map(|n| (0..256).map(move |i| (i as u8).wrapping_add(n)))
                .collect(),
        ),
        (
            "718F2615-7933-40E3-A511-5F68FE14DD74",
            Effect::ColorMatrix {
                matrix: std::array::from_fn(|i| 0x7fc00000 + i as u32),
            },
            words(&(0..25).map(|i| 0x7fc00000 + i).collect::<Vec<_>>()),
        ),
        (
            "8B2DD6C3-EB07-4D87-A5F0-7108E26A9C5F",
            Effect::HueSaturationLightness {
                hue: -1,
                saturation: 2,
                lightness: -3,
            },
            words(&[u32::MAX, 2, (-3i32) as u32]),
        ),
        (
            "99C354EC-2A31-4F3A-8C34-17A803B33A25",
            Effect::Levels {
                highlight: -1,
                midtone: 2,
                shadow: -3,
            },
            words(&[u32::MAX, 2, (-3i32) as u32]),
        ),
        (
            "74D29D05-69A4-4266-9549-3CC52836B632",
            Effect::RedEyeCorrection {
                areas: vec![[i32::MIN, 2, -3, i32::MAX]],
            },
            words(&[1, 0x80000000, 2, (-3i32) as u32, 0x7fffffff]),
        ),
        (
            "63CBF3EE-C526-402C-8F71-62C540BF5142",
            Effect::Sharpen {
                radius: 0x80000000,
                amount: 0x7fa12345,
            },
            words(&[0x80000000, 0x7fa12345]),
        ),
        (
            "1077AF00-2848-4441-9489-44AD4C2D7A2C",
            Effect::Tint {
                hue: -1,
                amount: i32::MIN,
            },
            words(&[u32::MAX, 0x80000000]),
        ),
    ]
}
fn parse(b: &[u8]) -> plus::Stream {
    plus::parse(b, &ParseLimits::default()).unwrap()
}
#[test]
fn all_effect_guids_decode_exact_fields_and_allow_typed_edits() {
    for (guid, expected, payload) in fixtures() {
        let bytes = effect_bytes(guid, &payload);
        let mut stream = parse(&bytes);
        assert_eq!(
            stream.records[0].data,
            RecordData::Effect(expected.clone()),
            "{guid}"
        );
        assert_eq!(stream.records[0].flags, 0xdcba);
        assert_eq!(plus::serialize(&stream).unwrap(), bytes);
        let mut edited = expected.clone();
        match &mut edited {
            Effect::Blur { radius, .. } | Effect::Sharpen { radius, .. } => *radius ^= 1,
            Effect::BrightnessContrast { brightness, .. } => *brightness += 1,
            Effect::ColorBalance { cyan_red, .. } => *cyan_red += 1,
            Effect::ColorCurve { channel, .. } => *channel += 1,
            Effect::ColorLookupTable { tables } => tables[2][173] ^= 1,
            Effect::ColorMatrix { matrix } => matrix[17] ^= 1,
            Effect::HueSaturationLightness { hue, .. } | Effect::Tint { hue, .. } => *hue += 1,
            Effect::Levels { midtone, .. } => *midtone += 1,
            Effect::RedEyeCorrection { areas } => areas[0][1] += 1,
            _ => unreachable!(),
        }
        stream.records[0].data = RecordData::Effect(edited.clone());
        let out = plus::serialize(&stream).unwrap();
        assert_ne!(out, bytes);
        assert_eq!(parse(&out).records[0].data, RecordData::Effect(edited));
    }
}
#[test]
fn red_eye_grows_shrinks_derives_both_counts_and_preserves_other_records() {
    let (guid, _, payload) = fixtures().remove(8);
    let mut bytes = effect_bytes(guid, &payload);
    let unknown = [
        0xff, 0x4f, 0xab, 0xcd, 16, 0, 0, 0, 1, 0, 0, 0, 0x42, 0x13, 0x37, 0x99,
    ];
    bytes.extend(unknown);
    let mut s =
        plus::parse_segments(&[&bytes[..19], &[], &bytes[19..]], &Default::default()).unwrap();
    for count in [4, 0, 2] {
        let RecordData::Effect(Effect::RedEyeCorrection { areas }) = &mut s.records[0].data else {
            unreachable!()
        };
        areas.resize(count, [-7, 9, 10, 11]);
        let out = plus::serialize(&s).unwrap();
        assert_eq!(&out[out.len() - 16..], &unknown);
        assert_eq!(
            u32::from_le_bytes(out[28..32].try_into().unwrap()) as usize,
            4 + 16 * count
        );
        assert_eq!(
            u32::from_le_bytes(out[32..36].try_into().unwrap()) as usize,
            count
        );
        assert_eq!(parse(&out).records, s.records);
        assert!(plus::serialize_segments(&s, &Default::default()).is_err());
    }
}
#[test]
fn unknown_guid_and_split_record_padding_remain_exact() {
    let bytes = effect_bytes(
        "01020304-0506-0708-0910-111213141516",
        &[0x17, 0x18, 0x19, 0x20],
    );
    let mut s =
        plus::parse_segments(&[&bytes[..7], &[], &bytes[7..]], &Default::default()).unwrap();
    assert!(matches!(
        s.records[0].data,
        RecordData::Effect(Effect::Unknown { .. })
    ));
    assert_eq!(
        plus::serialize_segments(&s, &Default::default()).unwrap(),
        vec![bytes[..7].to_vec(), vec![], bytes[7..].to_vec()]
    );
    s.records[0].padding = vec![0x13, 0x37, 0xba, 0xad];
    let out = plus::serialize(&s).unwrap();
    assert_eq!(&out[..4], &bytes[..4]);
    assert_eq!(&out[8..bytes.len()], &bytes[8..]);
    assert_eq!(&out[bytes.len()..], &[0x13, 0x37, 0xba, 0xad]);
    assert_eq!(parse(&out).records, s.records);
}
#[test]
fn truncated_mismatched_and_negative_counts_fail_without_expansion() {
    for (guid, _, payload) in fixtures() {
        for end in (0..payload.len()).step_by(4) {
            assert!(
                plus::parse(&effect_bytes(guid, &payload[..end]), &Default::default()).is_err(),
                "{guid}:{end}"
            );
        }
        let mut trailing = payload.clone();
        trailing.extend([0; 4]);
        assert!(plus::parse(&effect_bytes(guid, &trailing), &Default::default()).is_err());
        let bytes = effect_bytes(guid, &payload);
        for declared in [0, 1, 4, u32::MAX] {
            let mut malformed = bytes.clone();
            malformed[28..32].copy_from_slice(&declared.to_le_bytes());
            assert!(plus::parse(&malformed, &Default::default()).is_err());
        }
    }
    for count in [2, 0x80000000, u32::MAX] {
        assert!(plus::parse(
            &effect_bytes("74D29D05-69A4-4266-9549-3CC52836B632", &words(&[count])),
            &Default::default()
        )
        .is_err());
    }
    for end in 0..20 {
        let b = record(&[0; 20][..end]);
        assert!(plus::parse(&b, &Default::default()).is_err());
    }
    let b = effect_bytes("01020304-0506-0708-0910-111213141516", &[1, 2, 3]);
    // Make the outer framing aligned; the effect buffer itself is still invalid.
    let mut b = b;
    b.push(0);
    let n = b.len() as u32;
    b[4..8].copy_from_slice(&n.to_le_bytes());
    assert!(plus::parse(&b, &Default::default()).is_err());
}
#[test]
fn invalid_typed_layouts_and_record_variants_fail() {
    let mut s = parse(&blur());
    s.records[0].record_type = 0x4003;
    assert!(plus::serialize(&s).is_err());
    s.records[0].record_type = 0x4038;
    for e in [
        Effect::ColorLookupTable {
            tables: vec![[0; 256]; 3],
        },
        Effect::Unknown {
            guid: [0; 16],
            buffer: vec![1],
        },
        Effect::Unknown {
            guid: fixtures()[0].1.guid(),
            buffer: vec![0; 8],
        },
    ] {
        s.records[0].data = RecordData::Effect(e);
        assert!(plus::serialize(&s).is_err());
    }
    s.records[0].data = RecordData::Opaque(vec![0; 20]);
    assert!(plus::serialize(&s).is_err());
}
#[test]
fn shared_parse_and_serialize_limits_cover_effect_arrays() {
    for index in [4, 8] {
        let (guid, _, payload) = fixtures().remove(index);
        let bytes = effect_bytes(guid, &payload);
        let s = parse(&bytes);
        for limits in [
            ParseLimits {
                max_input_bytes: bytes.len() - 1,
                ..Default::default()
            },
            ParseLimits {
                max_record_bytes: bytes.len() - 1,
                ..Default::default()
            },
            ParseLimits {
                max_records: 0,
                ..Default::default()
            },
            ParseLimits {
                max_work_units: 0,
                ..Default::default()
            },
            ParseLimits {
                max_allocated_bytes: bytes.len(),
                ..Default::default()
            },
        ] {
            assert!(plus::parse(&bytes, &limits).is_err());
        }
        let mut low = 0;
        let mut high = 100_000;
        while low < high {
            let mid = (low + high) / 2;
            if plus::parse(
                &bytes,
                &ParseLimits {
                    max_work_units: mid,
                    ..Default::default()
                },
            )
            .is_ok()
            {
                high = mid
            } else {
                low = mid + 1
            }
        }
        assert!(low >= if index == 4 { 1024 } else { 1 });
        assert!(plus::parse(
            &bytes,
            &ParseLimits {
                max_work_units: low - 1,
                ..Default::default()
            }
        )
        .is_err());
        for limits in [
            SerializeLimits {
                max_output_bytes: bytes.len() - 1,
                ..Default::default()
            },
            SerializeLimits {
                max_work_units: 0,
                ..Default::default()
            },
        ] {
            assert!(matches!(
                plus::serialize_with_limits(&s, &limits),
                Err(emf_core::SerializeFailure::LimitExceeded {
                    kind: LimitKind::OutputBytes | LimitKind::WorkUnits,
                    ..
                })
            ));
        }
    }
}

#[test]
fn effects_repack_through_document_atomically_and_reject_stale_edits() {
    fn comment(data: &[u8]) -> Vec<u8> {
        let size = (12 + data.len() + 3) & !3;
        let mut b = 70u32.to_le_bytes().to_vec();
        b.extend((size as u32).to_le_bytes());
        b.extend((data.len() as u32).to_le_bytes());
        b.extend(data);
        b.resize(size, 0xa5);
        b
    }
    let (guid, _, payload) = fixtures().remove(8);
    let logical = effect_bytes(guid, &payload);
    let mut wire = vec![0; 88];
    wire[..4].copy_from_slice(&1u32.to_le_bytes());
    wire[4..8].copy_from_slice(&88u32.to_le_bytes());
    wire[40..44].copy_from_slice(&0x464d4520u32.to_le_bytes());
    for part in [&logical[..7], &logical[7..7], &logical[7..]] {
        let mut data = b"EMF+".to_vec();
        data.extend(part);
        wire.extend(comment(&data));
        wire.extend(comment(b"unrelated"));
    }
    wire.extend([
        14, 0, 0, 0, 20, 0, 0, 0, 0, 0, 0, 0, 16, 0, 0, 0, 20, 0, 0, 0,
    ]);
    let size = wire.len() as u32;
    wire[48..52].copy_from_slice(&size.to_le_bytes());
    wire[52..56].copy_from_slice(&8u32.to_le_bytes());
    let mut d = emf_core::parse(&wire, &Default::default()).unwrap();
    let original = d.clone();
    let snapshot = d.structured_emf_plus(&Default::default()).unwrap();
    d.apply_structured_emf_plus(&snapshot, &Default::default())
        .unwrap();
    assert_eq!(emf_core::serialize(&d).unwrap(), wire);
    for count in [6, 0] {
        let mut snapshot = d.structured_emf_plus(&Default::default()).unwrap();
        let RecordData::Effect(Effect::RedEyeCorrection { areas }) =
            &mut snapshot.stream.records[0].data
        else {
            unreachable!()
        };
        areas.resize(count, [-7, 8, 9, 10]);
        let before = d.clone();
        assert!(d
            .apply_structured_emf_plus(
                &snapshot,
                &SerializeLimits {
                    max_output_bytes: 0,
                    ..Default::default()
                }
            )
            .is_err());
        assert_eq!(d, before);
        d.apply_structured_emf_plus(&snapshot, &Default::default())
            .unwrap();
        let reparsed =
            emf_core::parse(&emf_core::serialize(&d).unwrap(), &Default::default()).unwrap();
        assert_eq!(
            reparsed
                .structured_emf_plus(&Default::default())
                .unwrap()
                .stream
                .records,
            snapshot.stream.records
        );
        for i in [1, 3, 5, 6] {
            assert_eq!(d.records()[i], original.records()[i]);
        }
        let edited = d.clone();
        assert_eq!(
            d.apply_structured_emf_plus(&snapshot, &Default::default()),
            Err(plus::EmbedError::StaleSource)
        );
        assert_eq!(d, edited);
    }
}
