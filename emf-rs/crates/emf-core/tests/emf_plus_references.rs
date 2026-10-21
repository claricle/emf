use emf_core::{
    emf_plus::{self as plus, Error, ObjectReference, ObjectRole, ReferenceTarget},
    LimitKind, ParseFailure, ParseLimits,
};

const FILL_RECTS: u16 = 0x400a;
const DRAW_RECTS: u16 = 0x400b;
const DRAW_STRING: u16 = 0x401c;
const FILL_PATH: u16 = 0x4014;
const DRAW_PATH: u16 = 0x4015;
const DRAW_IMAGE: u16 = 0x401a;
const SET_CLIP_PATH: u16 = 0x4033;
const SET_CLIP_REGION: u16 = 0x4034;
const OBJECT: u16 = 0x4008;
const BRUSH: u16 = 1;
const PEN: u16 = 2;
const PATH: u16 = 3;
const REGION: u16 = 4;
const IMAGE: u16 = 5;
const FONT: u16 = 6;
const FORMAT: u16 = 7;
const ATTRIBUTES: u16 = 8;

fn words(values: &[u32]) -> Vec<u8> {
    values.iter().flat_map(|n| n.to_le_bytes()).collect()
}
fn record(kind: u16, flags: u16, data: &[u8]) -> Vec<u8> {
    let size = (12 + data.len() + 3) & !3;
    let mut bytes = Vec::new();
    bytes.extend_from_slice(&kind.to_le_bytes());
    bytes.extend_from_slice(&flags.to_le_bytes());
    bytes.extend_from_slice(&(size as u32).to_le_bytes());
    bytes.extend_from_slice(&(data.len() as u32).to_le_bytes());
    bytes.extend_from_slice(data);
    bytes.resize(size, 0);
    bytes
}
fn object(kind: u16, id: u16) -> Vec<u8> {
    record(OBJECT, (kind << 8) | id, &[0; 4])
}
/// A one-rectangle integer fill or draw; fills carry a brush word before the count.
fn fill_rects(brush: u32, flags: u16) -> Vec<u8> {
    let mut body = words(&[brush, 1]);
    body.extend([0i16, 0, 1, 1].iter().flat_map(|n| n.to_le_bytes()));
    record(FILL_RECTS, flags | 0x4000, &body)
}
fn draw_rects(pen: u16) -> Vec<u8> {
    let mut body = words(&[1]);
    body.extend([0i16, 0, 1, 1].iter().flat_map(|n| n.to_le_bytes()));
    record(DRAW_RECTS, pen | 0x4000, &body)
}
fn references(records: &[Vec<u8>]) -> Vec<ObjectReference> {
    let stream = plus::parse(&records.concat(), &ParseLimits::default()).unwrap();
    stream.object_references(&ParseLimits::default()).unwrap()
}
fn target(found: &[ObjectReference], record: usize, role: ObjectRole) -> ReferenceTarget {
    found
        .iter()
        .find(|r| r.record_index == record && r.role == role)
        .unwrap_or_else(|| panic!("no {role:?} reference at record {record}"))
        .target
}

#[test]
fn valid_references_resolve_to_their_definitions_in_table_order() {
    let found = references(&[
        object(PEN, 1),
        object(BRUSH, 2),
        draw_rects(1),
        fill_rects(2, 0),
    ]);
    assert_eq!(
        found,
        vec![
            ObjectReference {
                record_index: 2,
                role: ObjectRole::Pen,
                raw_id: 1,
                target: ReferenceTarget::Definition {
                    first_record: 0,
                    last_record: 0
                },
            },
            ObjectReference {
                record_index: 3,
                role: ObjectRole::Brush,
                raw_id: 2,
                target: ReferenceTarget::Definition {
                    first_record: 1,
                    last_record: 1
                },
            },
        ]
    );
}

#[test]
fn every_referencing_family_names_its_required_roles() {
    let mut string = words(&[2, 3, 1]);
    string.extend(words(&[0; 4]));
    string.extend([0x41u8, 0, 0, 0]);
    let mut image = words(&[5, 2]);
    image.extend(words(&[0; 8]));
    let found = references(&[
        object(FONT, 1),
        object(BRUSH, 2),
        object(FORMAT, 3),
        object(IMAGE, 4),
        object(ATTRIBUTES, 5),
        object(PATH, 6),
        object(REGION, 7),
        object(PEN, 8),
        record(DRAW_STRING, 1, &string),
        record(DRAW_IMAGE, 4, &image),
        record(FILL_PATH, 6, &words(&[2])),
        record(DRAW_PATH, 6, &words(&[8])),
        record(SET_CLIP_PATH, 6, &[]),
        record(SET_CLIP_REGION, 7, &[]),
    ]);
    let roles: Vec<_> = found
        .iter()
        .map(|r| (r.record_index, r.role, r.raw_id))
        .collect();
    assert_eq!(
        roles,
        vec![
            (8, ObjectRole::Font, 1),
            (8, ObjectRole::Brush, 2),
            (8, ObjectRole::StringFormat, 3),
            (9, ObjectRole::Image, 4),
            (9, ObjectRole::ImageAttributes, 5),
            (10, ObjectRole::Path, 6),
            (10, ObjectRole::Brush, 2),
            (11, ObjectRole::Path, 6),
            (11, ObjectRole::Pen, 8),
            (12, ObjectRole::Path, 6),
            (13, ObjectRole::Region, 7),
        ]
    );
    assert!(found
        .iter()
        .all(|r| matches!(r.target, ReferenceTarget::Definition { .. })));
}

#[test]
fn dangling_and_out_of_range_references_are_diagnostics_not_errors() {
    let found = references(&[object(PEN, 1), draw_rects(2), draw_rects(200)]);
    assert_eq!(
        target(&found, 1, ObjectRole::Pen),
        ReferenceTarget::EmptySlot
    );
    assert_eq!(
        target(&found, 2, ObjectRole::Pen),
        ReferenceTarget::OutOfRange
    );
}

#[test]
fn a_reference_before_its_definition_is_dangling() {
    let found = references(&[draw_rects(1), object(PEN, 1), draw_rects(1)]);
    assert_eq!(
        target(&found, 0, ObjectRole::Pen),
        ReferenceTarget::EmptySlot
    );
    assert_eq!(
        target(&found, 2, ObjectRole::Pen),
        ReferenceTarget::Definition {
            first_record: 1,
            last_record: 1
        }
    );
}

#[test]
fn type_mismatch_reports_the_actual_object_type() {
    let found = references(&[object(BRUSH, 1), draw_rects(1), fill_rects(1, 0)]);
    assert_eq!(
        target(&found, 1, ObjectRole::Pen),
        ReferenceTarget::WrongType { actual_type: 1 }
    );
    assert!(matches!(
        target(&found, 2, ObjectRole::Brush),
        ReferenceTarget::Definition { .. }
    ));
}

#[test]
fn solid_color_brush_words_are_not_table_lookups() {
    let found = references(&[fill_rects(0xff00ff00, 0x8000)]);
    assert_eq!(found[0].target, ReferenceTarget::SolidColor);
    assert_eq!(found[0].raw_id, 0xff00ff00);
    let found = references(&[fill_rects(70, 0)]);
    assert_eq!(found[0].target, ReferenceTarget::OutOfRange);
}

#[test]
fn redefinition_is_time_indexed_and_may_change_the_object_type() {
    let found = references(&[
        object(PEN, 1),
        draw_rects(1),
        object(PEN, 1),
        draw_rects(1),
        object(BRUSH, 1),
        draw_rects(1),
    ]);
    let definition = |first_record| ReferenceTarget::Definition {
        first_record,
        last_record: first_record,
    };
    assert_eq!(target(&found, 1, ObjectRole::Pen), definition(0));
    assert_eq!(target(&found, 3, ObjectRole::Pen), definition(2));
    assert_eq!(
        target(&found, 5, ObjectRole::Pen),
        ReferenceTarget::WrongType { actual_type: 1 }
    );
}

#[test]
fn continuation_objects_resolve_only_once_complete_and_report_their_span() {
    let chunk = |flags: u16, total: Option<u32>, bytes: &[u8]| {
        let mut body = total.map(|n| n.to_le_bytes().to_vec()).unwrap_or_default();
        body.extend_from_slice(bytes);
        record(OBJECT, flags, &body)
    };
    let chain = |id: u16| {
        let flags = (PEN << 8) | id;
        vec![
            chunk(flags | 0x8000, Some(8), &[1, 2, 3, 4]),
            chunk(flags | 0x8000, Some(8), &[5, 6, 7, 8]),
        ]
    };
    let mut records = chain(4);
    records.push(draw_rects(4));
    records.extend(chain(4));
    records.push(draw_rects(4));
    let found = references(&records);
    assert_eq!(
        target(&found, 2, ObjectRole::Pen),
        ReferenceTarget::Definition {
            first_record: 0,
            last_record: 1
        }
    );
    assert_eq!(
        target(&found, 5, ObjectRole::Pen),
        ReferenceTarget::Definition {
            first_record: 3,
            last_record: 4
        }
    );
    // A chain interrupted by another record is rejected before any resolution.
    let broken = [chain(4).remove(0), draw_rects(4)].concat();
    assert!(matches!(
        plus::parse(&broken, &ParseLimits::default()),
        Err(Error::InvalidObject { .. })
    ));
}

#[test]
fn records_without_references_and_unknown_records_yield_none() {
    let found = references(&[record(0x4031, 0, &[]), record(0x7fff, 0, &[1, 2, 3, 4])]);
    assert!(found.is_empty());
}

#[test]
fn reference_resolution_is_bounded_by_the_work_budget() {
    let mut records = vec![object(PEN, 1)];
    records.extend((0..64).map(|_| draw_rects(1)));
    let stream = plus::parse(&records.concat(), &ParseLimits::default()).unwrap();
    let limits = ParseLimits {
        max_work_units: 40,
        ..ParseLimits::default()
    };
    assert!(matches!(
        stream.object_references(&limits),
        Err(Error::Resource(ParseFailure::LimitExceeded {
            kind: LimitKind::WorkUnits,
            ..
        }))
    ));
}
