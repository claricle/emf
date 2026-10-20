use emf_core::{emf_plus as plus, ParseLimits, SerializeLimits};
fn record(flags: u16, data: &[u8]) -> Vec<u8> {
    let mut out = 0x4039u16.to_le_bytes().to_vec();
    out.extend(flags.to_le_bytes());
    out.extend(((12 + data.len()) as u32).to_le_bytes());
    out.extend((data.len() as u32).to_le_bytes());
    out.extend(data);
    out
}
#[test]
fn graphics_state_is_typed_and_exact() {
    let bytes = record(0xfffe, &[0; 36]);
    let s = plus::parse(&bytes, &ParseLimits::default()).unwrap();
    assert!(
        !matches!(s.records[0].data, plus::RecordData::Opaque(_)),
        "TSGraphics remains opaque"
    );
    assert_eq!(plus::serialize(&s).unwrap(), bytes);
}
use plus::{Palette, RecordData, TSGraphics};
fn payload(palette: bool) -> Vec<u8> {
    let mut p = vec![
        0xfe, 0xfd, 0xfc, 0xfb, 0x00, 0x80, 0xff, 0x7f, 0xff, 0xff, 0xfa, 0xf9,
    ];
    for w in [
        0x7fc12345u32,
        0x80000000,
        0x7fa00001,
        0xffffffff,
        0,
        0x3f800000,
    ] {
        p.extend(w.to_le_bytes());
    }
    if palette {
        p.extend(0xfedcba98u32.to_le_bytes());
        p.extend(2u32.to_le_bytes());
        p.extend(0x11223344u32.to_le_bytes());
        p.extend(0x99aabbccu32.to_le_bytes());
    }
    p
}
fn parse(b: &[u8]) -> plus::Stream {
    plus::parse(b, &Default::default()).unwrap()
}
#[test]
fn exact_fields_palette_flags_and_float_bits_roundtrip() {
    for flags in [0, 2, 0xfffc, 0xfffe, 1, 3, 0xfffd, 0xffff] {
        let has = flags & 1 != 0;
        let b = record(flags, &payload(has));
        let s = parse(&b);
        assert_eq!(
            s.records[0].data,
            RecordData::TSGraphics(TSGraphics {
                anti_alias_mode: 0xfe,
                text_render_hint: 0xfd,
                compositing_mode: 0xfc,
                compositing_quality: 0xfb,
                render_origin: [i16::MIN, i16::MAX],
                text_contrast: u16::MAX,
                filter_type: 0xfa,
                pixel_offset: 0xf9,
                world_to_device: [0x7fc12345, 0x80000000, 0x7fa00001, 0xffffffff, 0, 0x3f800000],
                palette: has.then(|| Palette {
                    style_flags: 0xfedcba98,
                    entries: vec![0x11223344, 0x99aabbcc]
                }),
            })
        );
        assert_eq!(s.records[0].flags, flags);
        assert_eq!(plus::serialize(&s).unwrap(), b);
    }
}
#[test]
fn typed_edits_derive_palette_count_and_preserve_unknowns_padding_and_segments() {
    let mut b = record(0xffff, &payload(true));
    let unknown = [
        0xff, 0x4f, 0x13, 0x37, 16, 0, 0, 0, 1, 0, 0, 0, 0xaa, 0xbb, 0xcc, 0xdd,
    ];
    b.extend(unknown);
    let mut s = plus::parse_segments(&[&b[..5], &[], &b[5..]], &Default::default()).unwrap();
    assert_eq!(
        plus::serialize_segments(&s, &Default::default()).unwrap(),
        vec![b[..5].to_vec(), vec![], b[5..].to_vec()]
    );
    s.records[0].padding = vec![0xba, 0xad, 0xf0, 0x0d];
    for count in [6, 0, 3] {
        let RecordData::TSGraphics(g) = &mut s.records[0].data else {
            unreachable!()
        };
        g.render_origin[0] = -17;
        g.world_to_device[5] ^= 1;
        let palette = g.palette.as_mut().unwrap();
        palette.style_flags ^= 1;
        palette.entries.resize(count, 0x77abcdef);
        let out = plus::serialize(&s).unwrap();
        assert_eq!(
            u32::from_le_bytes(out[52..56].try_into().unwrap()) as usize,
            count
        );
        assert_eq!(&out[out.len() - 16..], &unknown);
        assert_eq!(
            &out[out.len() - 20..out.len() - 16],
            &[0xba, 0xad, 0xf0, 0x0d]
        );
        assert_eq!(parse(&out).records, s.records);
    }
    let RecordData::TSGraphics(g) = &mut s.records[0].data else {
        unreachable!()
    };
    g.palette = None;
    s.records[0].flags &= !1;
    let out = plus::serialize(&s).unwrap();
    assert_eq!(parse(&out).records, s.records);
    assert_eq!(out.len(), 68);
}
#[test]
fn malformed_layouts_and_inconsistent_typed_flags_fail() {
    for has in [false, true] {
        let p = payload(has);
        for end in 0..p.len() {
            let mut b = record(u16::from(has), &p[..end]);
            let n = (b.len() + 3) & !3;
            b.resize(n, 0);
            b[4..8].copy_from_slice(&(n as u32).to_le_bytes());
            assert!(plus::parse(&b, &Default::default()).is_err(), "{has}:{end}");
        }
        let mut p = p;
        p.extend([0; 4]);
        assert!(plus::parse(&record(u16::from(has), &p), &Default::default()).is_err());
    }
    for count in [0, 1, 3, u32::MAX] {
        let mut p = payload(true);
        p[40..44].copy_from_slice(&count.to_le_bytes());
        assert!(plus::parse(&record(1, &p), &Default::default()).is_err());
    }
    for has in [false, true] {
        let mut s = parse(&record(u16::from(has), &payload(has)));
        s.records[0].flags ^= 1;
        assert!(plus::serialize(&s).is_err());
        s.records[0].flags ^= 1;
        s.records[0].record_type = 0x4003;
        assert!(plus::serialize(&s).is_err());
    }
    let mut s = parse(&record(0, &payload(false)));
    s.records[0].data = RecordData::Opaque(vec![0; 36]);
    assert!(plus::serialize(&s).is_err());
}
#[test]
fn palette_and_fixed_state_share_parse_and_serialize_limits() {
    use emf_core::{LimitKind, SerializeFailure};
    let b = record(1, &payload(true));
    let s = parse(&b);
    for limits in [
        ParseLimits {
            max_input_bytes: b.len() - 1,
            ..Default::default()
        },
        ParseLimits {
            max_record_bytes: b.len() - 1,
            ..Default::default()
        },
        ParseLimits {
            max_records: 0,
            ..Default::default()
        },
    ] {
        assert!(plus::parse(&b, &limits).is_err());
    }
    for allocation in [false, true] {
        let mut low = 0u64;
        let mut high = 100_000;
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
            plus::parse(&b, &limits)
        };
        while low < high {
            let mid = (low + high) / 2;
            if check(mid).is_ok() {
                high = mid
            } else {
                low = mid + 1
            }
        }
        assert!(low > 0);
        assert!(check(low).is_ok());
        assert!(check(low - 1).is_err());
    }
    for limits in [
        SerializeLimits {
            max_output_bytes: b.len() - 1,
            ..Default::default()
        },
        SerializeLimits {
            max_work_units: 0,
            ..Default::default()
        },
    ] {
        assert!(matches!(
            plus::serialize_with_limits(&s, &limits),
            Err(SerializeFailure::LimitExceeded {
                kind: LimitKind::OutputBytes | LimitKind::WorkUnits,
                ..
            })
        ));
    }
}

#[test]
fn graphics_repack_through_document_atomically_and_reject_stale_edits() {
    fn comment(data: &[u8]) -> Vec<u8> {
        let size = (12 + data.len() + 3) & !3;
        let mut b = 70u32.to_le_bytes().to_vec();
        b.extend((size as u32).to_le_bytes());
        b.extend((data.len() as u32).to_le_bytes());
        b.extend(data);
        b.resize(size, 0xa5);
        b
    }
    let logical = record(0xffff, &payload(true));
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
        let RecordData::TSGraphics(TSGraphics {
            palette: Some(Palette { entries: areas, .. }),
            ..
        }) = &mut snapshot.stream.records[0].data
        else {
            unreachable!()
        };
        areas.resize(count, 0x77abcdef);
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
