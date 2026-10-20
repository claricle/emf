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
| 0x101 | Drawing | normalized subtype and values below |
| 0x102 | Text | normalized subtype and values below |
| 0x103 | Effect | none; core typed, ABI typed encoding pending |
| 0x104 | TSGraphics | none; core typed, ABI typed encoding pending |
| 0x105 | Object | none; core typed, ABI typed encoding pending |

Consumers must distinguish typed Empty from opaque/pending families. Effect,
TSGraphics and Object remain explicitly unsupported typed families, with their
complete raw frames preserved. This unpublished version 1 describes the current
read-only increment; it does not claim complete structured EMF+ coverage.

### Shared normalized values

Drawing and Text are encoded from the extracted core values, rather than copying
their wire bodies. Every field below is concatenated without alignment. `u32`
means an unsigned 32-bit word; `i32` is its two's-complement signed interpretation.
`f32bits` is a u32 containing the original IEEE-754 bits, without floating-point
conversion (including NaNs and negative zero). Counts are u64, including counts
of UTF-16 units, glyphs, points and padding bytes. Arrays have no terminator.
Original Type and Flags retain operation identity, pen/object IDs held in flags,
brush ID versus literal ARGB interpretation, and other operation-specific flags.

| Value | Fields, in order |
| --- | --- |
| optional brush | present u32 (0 or 1), value u32 (zero when absent) |
| rectangle | encoding u32 (0 float, 1 integer), x, y, width, height |
| points | encoding u32 (0 float, 1 integer, 2 relative), count u64, points[count] |
| source | image attributes ID u32, unit i32, rectangle[4] f32bits |
| padding | byte count u64, exact bytes[count] |

A rectangle's four coordinates are f32bits for encoding 0 and sign-extended i32
for encoding 1. Each float/integer point has x and y in that same representation
(8 bytes per point). A relative point has x-width u32, x-delta i32, y-width u32,
y-delta i32 (16 bytes per point). Width is 7 or 15, preserving the core coordinate
variant; signed deltas are not accumulated into absolute coordinates. The
coordinate encodings describe the extracted values explicitly, independently of
wire compression flags. Source rectangles always contain float bits.

Padding here means core `data_padding`, including any bytes retained inside
DataSize after the variable values. Any separate frame padding beyond DataSize
remains only in the complete raw frame. Both are preserved verbatim.

### Drawing (tag 0x101)

The first u32 is a subtype. All currently represented core Drawing variants have
normalized payloads. The remaining fields are:

| Subtype | Core variant (record Types) | Fields after subtype |
| --- | --- | --- |
| 1 | Rectangles (0x400A, 0x400B) | optional brush, rectangle count u64, rectangles[count] |
| 2 | Ellipse (0x400E, 0x400F) | optional brush, rectangle |
| 3 | Arc (0x4010–0x4012) | optional brush, start angle f32bits, sweep angle f32bits, rectangle |
| 4 | Points (0x400C, 0x400D, 0x4019) | optional brush, points, padding |
| 5 | Curve (0x4016–0x4018) | optional brush, tension f32bits, range present u32, offset u32, segments u32, points, padding |
| 6 | ImageRect (0x401A) | source, destination rectangle |
| 7 | ImagePoints (0x401B) | source, points, padding |
| 8 | ObjectReference (0x4013–0x4015) | value u32 |

Curve range presence is 0 or 1; offset and segments are both zero when absent.
Presence applies to DrawCurve's offset/segment pair, not its point count. Optional
brushes are present for Fill operations represented with a brush/color word.
ObjectReference's value is the preserved brush/color or pen ID word; original
Type/Flags specify its meaning. No object-table resolution or effect linking is
implied by these values.

### Text (tag 0x102)

The first u32 is a subtype. All currently represented core Text variants have
normalized payloads. The remaining fields are:

| Subtype | Core variant (record Type) | Fields after subtype |
| --- | --- | --- |
| 1 | String (0x401C) | brush u32, format ID u32, layout[4] f32bits, UTF-16 count u64, units[count] u16, padding |
| 2 | Driver (0x4036) | brush u32, options u32, glyph count u64, glyphs[count] u16, position count u64, positions[count][2] f32bits, matrix present u32, optional matrix[6] f32bits, padding |

UTF-16 units and glyphs are little-endian u16 values with no Unicode decoding,
validation, replacement or normalization. Unpaired surrogates remain unchanged.
Glyph values remain explicit even when options select glyph indices. A String's
layout is x, y, width, height. A Driver position is x, y. The position count is
explicit: with options bit 0x4 and nonempty glyphs core represents one position;
otherwise it represents one position per glyph (zero for empty glyphs). Matrix
presence is 0 or 1; its six words exist only when present, in core/wire order
(m11, m12, m21, m22, dx, dy). A present matrix is retained even for zero glyphs.

### Output bounds

A nonallocating checked traversal sizes every normalized field, array element,
UTF-16/glyph unit and retained padding byte before output is reserved. The entire
header, segment table, raw frames and normalized payloads must fit both
`max_output_bytes` and the platform vector-size bound. One fallible reservation
covers that total; the same traversal then emits variable payloads into the
reserved buffer without temporary arrays. A cap one byte below the required
size rejects the entire snapshot with `EMF_LIMIT_EXCEEDED` and NULL output.
