# Document snapshot v3

Schema 3 is the [schema 2 layout](snapshot-v2.md) with the record entries moved
into one fixed-stride table. `emf_document_snapshot_v3(document, &buffer, &error)`
emits it; `emf_document_snapshot` still emits schema 2. The C ABI remains version 1.
Status, output reset and lifetime rules are those of `emf_document_snapshot`.

Family tables, typed payload encodings, the decoded header, the raw header,
diagnostics, trailing and unframed sections are defined by snapshot v2 and are
unchanged here. This document lists only what differs. A schema 3 buffer for a
document has the same total length as its schema 2 buffer, and the same bytes
outside the records section, apart from the schema field.

## Differences from schema 2

- Prefix: the schema u32 at bytes 4–8 is 3. Every other prefix field is unchanged.
- Decoded header (112 bytes) and raw header: unchanged, byte for byte.
- Records section: two runs, in this order.
  1. Record table: one 40-byte entry per record, back to back, in record order.
     Each entry has the schema 2 fields (index, source offset, original record
     length, type ID, family, typed payload length). The stride is always 40 bytes.
  2. Typed payloads: the payload bytes of each record, concatenated in record
     order. Each payload is encoded as schema 2 specifies for its family, and its
     length is the typed payload length in its table entry.
- Diagnostics, trailing and unframed: unchanged, following the payloads.

The schema 2 section order therefore becomes: prefix, decoded header, raw header,
record table, record payloads, diagnostics, trailing, unframed.

## Decoding

After the raw header, read `count` 40-byte entries from the prefix's record count,
with checked multiplication. Sum the typed payload lengths from those entries with
checked addition. The payload run begins at the end of the table and ends after
that sum. Diagnostics begin there, followed by trailing and unframed as the prefix
lengths give them. The sum must end exactly where the diagnostics begin, and
the complete buffer must be consumed. Validate the schema (3) and total length
before reading entries.
