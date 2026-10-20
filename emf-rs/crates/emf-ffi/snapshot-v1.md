# Document snapshot v1

`emf_document_snapshot(document, &buffer, &error)` returns one independently owned
buffer. It follows the header's status, output reset and lifetime rules. Copy
views before freeing the buffer. Raw record bytes remain available through
`emf_record_bytes`; they are not duplicated in the snapshot.

All integers are little-endian, without alignment padding. Lengths and counts
are unsigned 64-bit unless stated otherwise. Coordinates are signed 32-bit.
Decode with explicit bounds checks, validate the schema and total length, and
consume the complete buffer. Schema changes require a new snapshot version.

The sections appear in this order:

| Section | Encoding |
| --- | --- |
| Prefix (56 bytes) | ASCII `EMFS` (4 bytes), schema u32=1, total buffer length u64, raw header length u64, record count u64, diagnostic count u64, trailing length u64, unframed length u64 |
| Decoded header (112 bytes) | Fields below |
| Raw header | Exact original header bytes, including extensions; length from prefix |
| Records | Count from prefix; each entry has a 40-byte prefix and its typed payload |
| Diagnostics | Count from prefix; each entry is 40 bytes |
| Trailing | Exact bytes after EOF; length from prefix |
| Unframed | Exact unframed tail; length from prefix |

Decoded header fields, in order:

| Fields | Encoding |
| --- | --- |
| n_size | u32 |
| bounds left/top/right/bottom; frame left/top/right/bottom | 8 i32 |
| signature, version, n_bytes, n_records | 4 u32 |
| n_handles, reserved | 2 u32 (zero-extended u16) |
| n_description, off_description, n_pal_entries | 3 u32 |
| device cx/cy; millimeters cx/cy | 4 i32 |
| optional_presence | u32: bit0 pixel-format fields, bit1 micrometers |
| cb_pixel_format, off_pixel_format, b_open_gl | 3 u32 |
| micrometers cx/cy | 2 i32 |

Absent optional values are zero. Header values retain their declarations; no
normalization occurs. The opaque header extension starts after byte 88, 100 or 108
of the raw header according to optional presence. Description and pixel blobs
remain in those exact original bytes.

Each record entry starts with index u64, source offset u64, original record
length u64, type ID u32, family u32, typed payload length u64. Payloads:

| Family | Value | Payload |
| --- | --- | --- |
| RAW | 0 | Empty |
| EOF | 1 | n_pal_entries, off_pal_entries, n_size_last: 3 u32 |
| SETMAPMODE | 2 | map_mode u32 |
| POLYLINE | 3 | bounds left/top/right/bottom: 4 i32; point count u64; then count pairs of i32 x/y |
| COMMENT | 4 | data length u64; then that many core-decoded comment data bytes |

Families match descriptor batches. Malformed supported payloads remain RAW and
produce diagnostics. COMMENT contains counted data, including the EMF+ identifier
when present; bytes beyond the counted payload remain available in raw record
bytes. No nested EMF+ decoding occurs. These are the core's validation results;
consumers must not infer support for other record families from RAW classification.

Each diagnostic is kind u32, has_record_type u32 (0 or 1), type ID u32 (zero when
absent), reserved u32=0, source offset u64, detail1 u64, detail2 u64.

| Kind | Value | Details |
| --- | --- | --- |
| Truncated record head | 1 | available bytes, 0 |
| Record size too small | 2 | declared size, 0 |
| Truncated record | 3 | claimed size, available bytes |
| Invalid typed payload | 4 | 0, 0 |

Diagnostics retain core order. Reason codes and numeric details allow consumers
to construct messages without parsing Rust text. Tail retention and typed
validation follow the core, including its EOF stopping rules; consumers choosing
Ruby compatibility policies must account for differences in
comment padding, array ceilings and fixed-record padding normalization.

All size arithmetic and output reservations are checked. A snapshot exceeding
the addressable range returns `EMF_LIMIT_EXCEEDED`; reservation failure returns
`EMF_ALLOCATION_FAILED`. The ABI exposes no document mutation, so original raw
bytes and decoded snapshot values describe the same parse result.
