# Document snapshot v2

The emitted snapshot schema is 2; the C ABI remains version 1. Snapshot schema
versions are independent of ABI versions and do not change C layouts or functions.
Schema 2 is unreleased; its family table includes the typed cohorts below.
The historical [snapshot v1 contract](snapshot-v1.md) remains unchanged.

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
| Prefix (56 bytes) | ASCII `EMFS` (4 bytes), schema u32=2, total buffer length u64, raw header length u64, record count u64, diagnostic count u64, trailing length u64, unframed length u64 |
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
| SETBKMODE | 5 | bk_mode u32 |
| SETPOLYFILLMODE | 6 | poly_fill_mode u32 |
| SETROP2 | 7 | rop2 u32 |
| SETSTRETCHBLTMODE | 8 | stretch_mode u32 |
| SETWINDOWEXTEX | 9 | extent cx/cy: 2 i32 |
| SETWINDOWORGEX | 10 | origin x/y: 2 i32 |
| SETVIEWPORTEXTEX | 11 | extent cx/cy: 2 i32 |
| SETVIEWPORTORGEX | 12 | origin x/y: 2 i32 |
| SETBRUSHORGEX | 13 | ptl_origin x/y: 2 i32 |
| OFFSETCLIPRGN | 14 | ptl_offset x/y: 2 i32 |
| MOVETOEX | 15 | origin x/y: 2 i32 |
| SETTEXTCOLOR | 16 | red, green, blue, reserved: 4 u8 |
| SETBKCOLOR | 17 | red, green, blue, reserved: 4 u8 |
| ELLIPSE | 18 | box left/top/right/bottom: 4 i32 |
| RECTANGLE | 19 | box left/top/right/bottom: 4 i32 |
| ROUNDRECT | 20 | box left/top/right/bottom: 4 i32; corner cx/cy: 2 i32 |
| SETTEXTALIGN | 21 | text_align_mode: u32 |
| SAVEDC | 22 | empty |
| RESTOREDC | 23 | saved_dc: i32 |
| SELECTOBJECT | 24 | ih_object: u32 |
| DELETEOBJECT | 25 | ih_object: u32 |
| SETARCDIRECTION | 26 | arc_direction: u32 |
| BEGINPATH | 27 | empty |
| ENDPATH | 28 | empty |
| CLOSEFIGURE | 29 | empty |
| FILLPATH | 30 | bounds left/top/right/bottom: 4 i32 |
| STROKEANDFILLPATH | 31 | bounds left/top/right/bottom: 4 i32 |
| STROKEPATH | 32 | bounds left/top/right/bottom: 4 i32 |
| SELECTCLIPPATH | 33 | region_mode: u32 |
| ABORTPATH | 34 | empty |
| SETPIXELV | 35 | i32 pixel x,y; color red/green/blue/reserved: 4 u8 |
| EXCLUDECLIPRECT | 36 | i32 clip left,top,right,bottom |
| INTERSECTCLIPRECT | 37 | i32 clip left,top,right,bottom |
| CREATEPEN | 38 | u32 ih_pen,pen_style; i32 width x,y; color red/green/blue/reserved: 4 u8 |
| CREATEBRUSHINDIRECT | 39 | u32 ih_brush,brush_style; color red/green/blue/reserved: 4 u8; u32 brush_hatch |
| ARC | 40 | i32 bounds left,top,right,bottom; i32 start x,y; i32 end x,y |
| CHORD | 41 | i32 bounds left,top,right,bottom; i32 start x,y; i32 end x,y |
| PIE | 42 | i32 bounds left,top,right,bottom; i32 start x,y; i32 end x,y |
| LINETO | 43 | i32 origin x,y |
| ARCTO | 44 | i32 bounds left,top,right,bottom; i32 start x,y; i32 end x,y |
| POLYBEZIER | 45 | bounds left/top/right/bottom: 4 i32; point count u64; then count pairs of i32 x/y |
| POLYGON | 46 | bounds left/top/right/bottom: 4 i32; point count u64; then count pairs of i32 x/y |
| POLYBEZIERTO | 47 | bounds left/top/right/bottom: 4 i32; point count u64; then count pairs of i32 x/y |
| POLYLINETO | 48 | bounds left/top/right/bottom: 4 i32; point count u64; then count pairs of i32 x/y |
| POLYBEZIER16 | 49 | bounds left/top/right/bottom: 4 i32; point count u64; then count pairs of i16 x/y |
| POLYGON16 | 50 | bounds left/top/right/bottom: 4 i32; point count u64; then count pairs of i16 x/y |
| POLYLINE16 | 51 | bounds left/top/right/bottom: 4 i32; point count u64; then count pairs of i16 x/y |
| POLYBEZIERTO16 | 52 | bounds left/top/right/bottom: 4 i32; point count u64; then count pairs of i16 x/y |
| POLYLINETO16 | 53 | bounds left/top/right/bottom: 4 i32; point count u64; then count pairs of i16 x/y |

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

SELECTCLIPPATH snapshots contain only region_mode; adapters retain its optional opaque suffix from the checked original record span. Unit record payloads are empty. Other fixed-record suffixes remain outside typed snapshots.
