use emf_core::{
    wmf::{
        self,
        objects::{ObjectIssue, ObjectKind},
        DiagnosticKind,
    },
    ParseLimits,
};

fn record(function: u16, body: &[u8]) -> Vec<u8> {
    let mut bytes = ((body.len() as u32 + 6) / 2).to_le_bytes().to_vec();
    bytes.extend_from_slice(&function.to_le_bytes());
    bytes.extend_from_slice(body);
    bytes
}

fn document(capacity: u16, records: &[Vec<u8>]) -> Vec<u8> {
    let mut bytes: Vec<u8> = [1u16, 9, 0x300]
        .into_iter()
        .flat_map(u16::to_le_bytes)
        .collect();
    let size = 18 + records.iter().map(Vec::len).sum::<usize>() + 6;
    bytes.extend_from_slice(&(size as u32 / 2).to_le_bytes());
    bytes.extend_from_slice(&capacity.to_le_bytes());
    bytes.extend_from_slice(
        &(records.iter().map(Vec::len).max().unwrap_or(6) as u32 / 2).to_le_bytes(),
    );
    bytes.extend_from_slice(&0u16.to_le_bytes());
    for item in records {
        bytes.extend_from_slice(item);
    }
    bytes.extend_from_slice(&record(0, &[]));
    bytes.extend_from_slice(&[0xde, 0xad, 0xbe]);
    bytes
}

fn pen() -> Vec<u8> {
    record(0x02fa, &[0; 10])
}
fn brush() -> Vec<u8> {
    record(0x02fc, &[0; 8])
}
fn index(function: u16, value: u16) -> Vec<u8> {
    record(function, &value.to_le_bytes())
}
fn issues(doc: &wmf::Document) -> Vec<ObjectIssue> {
    doc.diagnostics()
        .iter()
        .filter_map(|d| match d.kind {
            DiagnosticKind::Object(issue) => Some(issue),
            _ => None,
        })
        .collect()
}

#[test]
fn creation_uses_lowest_free_index_and_deletion_reuses_slot() {
    let bytes = document(
        2,
        &[
            pen(),
            brush(),
            index(0x012d, 0),
            index(0x01f0, 0),
            pen(),
            pen(),
            index(0x01f0, 1),
            index(0x012d, 1),
        ],
    );
    let doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
    assert_eq!(
        doc.records()
            .iter()
            .map(|r| r.object_index())
            .collect::<Vec<_>>(),
        [
            Some(0),
            Some(1),
            None,
            None,
            Some(0),
            None,
            None,
            None,
            None
        ]
    );
    assert_eq!(
        issues(&doc),
        [
            ObjectIssue::TableFull,
            ObjectIssue::InvalidReference { index: 1 }
        ]
    );
    assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
    assert_eq!(doc.tail(), [0xde, 0xad, 0xbe]);
}

#[test]
fn references_validate_kind_and_region_zero_is_a_table_index() {
    let bytes = document(
        1,
        &[
            pen(),
            index(0x0234, 0),
            index(0x012c, 0),
            index(0x012d, 4),
            index(0x012d, 0x8007),
            index(0x01f0, 0x8007),
        ],
    );
    let doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
    assert_eq!(
        issues(&doc),
        [
            ObjectIssue::WrongKind {
                index: 0,
                expected: ObjectKind::Palette,
                found: ObjectKind::Pen
            },
            ObjectIssue::WrongKind {
                index: 0,
                expected: ObjectKind::Region,
                found: ObjectKind::Pen
            },
            ObjectIssue::InvalidReference { index: 4 },
            ObjectIssue::InvalidReference { index: 0x8007 },
        ]
    );
    assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
}

#[test]
fn saved_dc_indices_are_signed_and_restore_discards_newer_states() {
    let save = || record(0x001e, &[]);
    let restore = |value: i16| record(0x0127, &value.to_le_bytes());
    let bytes = document(
        0,
        &[
            restore(-1),
            save(),
            save(),
            save(),
            restore(2),
            restore(-1),
            restore(-1),
            save(),
            restore(i16::MIN),
            restore(0),
            restore(1),
        ],
    );
    let doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
    assert_eq!(
        issues(&doc),
        [
            ObjectIssue::InvalidRestoreDc { saved_dc: -1 },
            ObjectIssue::InvalidRestoreDc { saved_dc: -1 },
            ObjectIssue::InvalidRestoreDc { saved_dc: i16::MIN },
            ObjectIssue::InvalidRestoreDc { saved_dc: 0 },
        ]
    );
    assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
}

#[test]
fn zero_capacity_reports_full_and_does_not_index_an_empty_table() {
    let bytes = document(0, &[pen(), index(0x012d, 0), index(0x01f0, 0)]);
    let doc = wmf::parse(&bytes, &ParseLimits::default()).unwrap();
    assert_eq!(
        issues(&doc),
        [
            ObjectIssue::TableFull,
            ObjectIssue::InvalidReference { index: 0 },
            ObjectIssue::InvalidReference { index: 0 }
        ]
    );
    assert_eq!(wmf::serialize(&doc).unwrap(), bytes);
}
