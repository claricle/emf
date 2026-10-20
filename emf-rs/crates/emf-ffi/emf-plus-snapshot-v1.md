# Read-only nested EMF+ snapshot, version 1

`emf_document_emf_plus_snapshot_v1` is an additive ABI 1 call returning all
nested frames in one owned `emf_buffer`. It leaves `emf_document_snapshot`
(schema 2), raw comment family 4, document bytes and existing ABI layouts unchanged.
This is partial structured **read** support, with no edit/apply API and no Ruby API.

Pass required `emf_plus_snapshot_options` with exact `struct_size` (16),
`version = EMF_PLUS_SNAPSHOT_VERSION` (1), and an explicit `max_output_bytes`.
The optional ABI 1 `emf_limits` bounds core extraction input, allocations,
record count and work; NULL uses core defaults. Output allocation is separately
bounded by `max_output_bytes`; peak memory includes both the bounded extracted
core model and output. Exact output size is checked before reserving output.
All allocations use the existing fallible core/owned-buffer conventions.
The caller releases output with `emf_buffer_free`; output remains valid after
freeing the document. Errors use the existing status/owned-error API.

No EMF+ comments produces a valid empty snapshot. An empty EMF+ segment is retained.
Malformed nested framing/typed layouts return `EMF_FORMAT_ERROR` (logical offset
when available), resource limits retain their status, and output is NULL.
No partial snapshot or recovery is returned. Core currently has no nonfatal nested
conformance-diagnostic channel: diagnostic_count is always zero and must not be
interpreted as proof of conformance. Outer diagnostics remain in schema 2.

All integers are little endian, with no implicit alignment. Offsets below are
relative to the enclosing structure; arrays and variable bodies are concatenated.
Counts and lengths are unsigned. A consumer must reject unrecognized versions,
truncated entries, overflowing lengths and inconsistent total length.

## Header (40 bytes)

| Offset | Type | Meaning |
| --- | --- | --- |
| 0 | bytes[4] | `EPSN` |
| 4 | u32 | independent schema version, 1 |
| 8 | u64 | entire buffer length |
| 16 | u64 | segment count |
| 24 | u64 | nested frame count |
| 32 | u64 | diagnostic count, zero |

## Segment table (32 bytes per segment, follows header)

| Offset | Type | Meaning |
| --- | --- | --- |
| 0 | u64 | source index in `Document::records()` (zero based) |
| 8 | u64 | start in concatenated logical EMF+ bytes |
| 16 | u64 | segment length, excluding `EMF+` signature |
| 24 | u64 | start within EMR_COMMENT data, always 4 |

Segments follow source comment order; zero-length segments are included. Logical
ranges are half open. Enclosing EMR headers and padding are available through the
existing outer APIs. Source comment bytes are never changed.

## Frames (variable length, follow segment table)

| Offset | Type | Meaning |
| --- | --- | --- |
| 0 | u64 | nested frame index |
| 8 | u64 | logical frame offset |
| 16 | u64 | first segment table index touched by frame |
| 24 | u64 | last segment table index touched by frame (inclusive) |
| 32 | u16 | original record Type |
| 34 | u16 | original Flags, including reserved bits |
| 36 | u32 | original Size (header + body + padding) |
| 40 | u32 | original DataSize (body only) |
| 44 | u32 | typed family tag below |
| 48 | u64 | typed payload length |
| 56 | u64 | raw frame length, equals Size |
| 64 | bytes[raw length] | complete original frame, including header and padding |
| next | bytes[typed length] | typed payload |

A frame crossing comments includes both endpoint segments; the segment table
locates each intersection, including a header split across comments. Empty
segments do not own a frame's start/end bytes. Unknown payload and nonzero padding
are retained verbatim in the raw frame. Raw bytes are present for every family.

## Typed payloads

Each listed word is 32 bits. Floating values are IEEE-754 **bits**, preserving
NaNs and negative zero; integer signs are interpreted as specified. Original
record Type/Flags distinguish operations sharing a layout (e.g. Pair).

| Tag | Core family | Typed payload in order |
| --- | --- | --- |
| 0 | Opaque | none; unknown/unsupported core payload in raw frame |
| 1 | Header | version, emf_plus_flags, logical_dpi_x, logical_dpi_y (u32) |
| 2 | Empty | none (typed empty body) |
| 3 | Clear | ARGB u32 |
| 4 | RenderingOrigin | x, y (i32) |
| 5 | StackIndex | stack_index u32 |
| 6 | BeginContainer | destination[4], source[4] (float bits), stack_index u32 |
| 7 | Matrix | matrix[6] (float bits) |
| 8 | Pair | values[2] (float bits) |
| 9 | Scalar | value (float bits) |
| 10 | ClipRect | rectangle[4] (float bits) |
| 0x101 | Drawing | none; core typed, ABI typed encoding pending |
| 0x102 | Text | none; core typed, ABI typed encoding pending |
| 0x103 | Effect | none; core typed, ABI typed encoding pending |
| 0x104 | TSGraphics | none; core typed, ABI typed encoding pending |
| 0x105 | Object | none; core typed, ABI typed encoding pending |

Consumers must keep the distinction between typed Empty and opaque/pending
families. Pending families do not claim typed object/drawing/text parity. A later
schema can add their normalized arrays/objects under a separately negotiated
version; version 1 remains stable.
