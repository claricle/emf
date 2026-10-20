# Read-only nested EMF+ snapshot, version 1

`emf_document_emf_plus_snapshot_v1` is an additive ABI 1 call returning all
nested frames in one owned `emf_buffer`. It leaves `emf_document_snapshot`
(schema 2), raw comment family 4, document bytes and existing ABI layouts unchanged.
This is partial structured **read** support, with no edit/apply API and no Ruby API.

Pass required `emf_plus_snapshot_options` with exact `struct_size` (16),
`version = EMF_PLUS_SNAPSHOT_VERSION` (1), and an explicit `max_output_bytes`.
The optional ABI 1 `emf_limits` bounds core extraction input, allocations,
record count and work; NULL uses core defaults. Object assembly and each object
decode also use these limits, with independent core budgets; they do not share
one cumulative budget with extraction. Retained object metadata has a separate
`max_allocated_bytes` ceiling. Output allocation is separately bounded by
`max_output_bytes`; peak memory includes the extracted model, retained decoded
objects, assembly temporaries and output. The per-decode ceiling is not an
aggregate ceiling over all retained decoded objects. Exact output size is checked before reserving output.
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
| 0x103 | Effect | normalized subtype, GUID and values below |
| 0x104 | TSGraphics | normalized state and optional palette below |
| 0x105 | Object | fragment bounds and normalized definition below |

Consumers must distinguish typed Empty from opaque families. Unknown object
layouts have a normalized opaque definition. Unknown effect GUIDs have a
normalized opaque effect buffer as below;
unknown/unsupported record types remain family 0. This unpublished version 1 describes the current
read-only increment; it does not claim complete structured EMF+ coverage.

### Shared normalized values

Drawing, Text, Effect, TSGraphics and Object are encoded from the extracted core values, rather than copying
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

### Effect (tag 0x103, record Type 0x4038)

Every effect begins with a subtype u32 followed by the exact GUID bytes[16] in
wire order (no GUID component byte swapping). All currently represented core
Effect variants have normalized payloads. The remaining fields are:

| Subtype | Core variant | Fields after GUID |
| --- | --- | --- |
| 0 | Unknown | buffer byte count u64, exact buffer bytes[count] |
| 1 | Blur | radius f32bits, expand edge u32 |
| 2 | BrightnessContrast | brightness i32, contrast i32 |
| 3 | ColorBalance | cyan/red i32, magenta/green i32, yellow/blue i32 |
| 4 | ColorCurve | adjustment u32, channel u32, intensity i32 |
| 5 | ColorLookupTable | table count u64 (4), tables[count][256] u8 |
| 6 | ColorMatrix | matrix[25] f32bits |
| 7 | HueSaturationLightness | hue i32, saturation i32, lightness i32 |
| 8 | Levels | highlight i32, midtone i32, shadow i32 |
| 9 | RedEyeCorrection | area count u64, areas[count][4] i32 |
| 10 | Sharpen | radius f32bits, amount f32bits |
| 11 | Tint | hue i32, amount i32 |

Lookup tables retain blue, green, red, alpha order. ColorMatrix retains core/wire
order: Matrix[0..5][0], then Matrix[0..5][1], and so on. Each red-eye area is
left, top, right, bottom without expansion or coordinate conversion. Zero-area
and empty unknown buffers retain explicit zero counts. Unknown GUIDs are
supported as subtype 0 without interpreting their buffers. Boolean/enum words
and numeric values are preserved without rendering-range validation; expand
edge is not converted to 0 or 1. Counts describe normalized arrays, independently
of the original wire BufferSize/count fields available in the raw frame.

### TSGraphics (tag 0x104, record Type 0x4039)

There is one layout, with no subtype word. Fields in order are anti-alias mode
u32, text-render hint u32, compositing mode u32, compositing quality u32,
render origin x i32, render origin y i32, text contrast u32, filter type u32,
pixel offset u32, world-to-device transform[6] f32bits, palette present u32.
The original u8/u16 enum and contrast fields are zero-extended; the original i16
render origins are sign-extended. The six transform words retain core/wire order
(m11, m12, m21, m22, dx, dy).

Palette presence is 0 or 1. Only when present, the following fields exist:
style flags u32, entry count u64, entries[count] ARGB u32. A present empty palette
is distinct from an absent palette. Style flags, enum values, float bits and
palette entries are uninterpreted; the original T, V and ignored flags remain
in the enclosing raw/Flags fields. This payload does not imply state application
or rendering support.

### Object (tag 0x105, record Type 0x4008)

Every fragment begins with total-size present u32, total-size u32 (zero when
absent), first frame index u64, last frame index u64 (inclusive), definition
present u32. The indices refer to the nested frame table, not segment indices.
The original C bit and optional total-size word remain explicit even for a final
C-set fragment. The core validates complete chains before producing output.

A definition is present only on its first fragment (including a single-frame
definition). When present, object ID u32, object type u32 and subtype u32 follow,
then the fields below. Continuations have no definition fields and refer back to
the first frame. Reusing an ID creates another definition with its own bounds;
this payload does not resolve drawing references or apply an object table.
Assembly runs once per stream, decode once per definition; sizing and writing
reuse the same decoded value, without repeating work for continuation fragments.
Malformed recognized layouts or incomplete/inconsistent chains fail the entire
snapshot. Unknown supported framing/layout discriminants remain opaque through
the core's existing fallback; normalization does not add rendering validation.

The notation below has no implicit padding. `blob` is byte count u64 followed by
exact bytes; `words` is element count u64 followed by u32 elements; `pairs` is
pair count u64 followed by interleaved pairs of u32 words. A pair is position
f32bits then ARGB/factor f32bits for a blend, or x/y f32bits for gradient points.
`optional scalar` is presence u32 then value u32 (zero when absent).
`optional T` is presence u32 then T only when present. All presence values are
0 or 1; a present empty array is distinct from absence. Unmarked fields retain
raw u32 words; signed and float interpretations are specified below.

| Subtype | Core variant | Fields after subtype |
| --- | --- | --- |
| 0 | Opaque | object type u32, body blob |
| 1 | SolidBrush | version, ARGB |
| 2 | HatchBrush | version, style, foreground ARGB, background ARGB |
| 3 | TextureBrush | version, texture |
| 4 | PathGradientBrush | version, path gradient |
| 5 | LinearGradientBrush | version, linear gradient |
| 6 | Pen | pen |
| 7 | Path | path |
| 8 | Region | version, node count u64, preorder nodes[count] |
| 9 | Font | version, em size f32bits, size unit, style i32, reserved, UTF-16 unit count u64, units[count] u16, suffix blob |
| 10 | StringFormat | version, flags, language, alignment, line alignment, digit substitution, digit language, first tab offset f32bits, hotkey prefix i32, leading margin f32bits, trailing margin f32bits, tracking f32bits, trimming, tab stops words (f32bits), range count u64, ranges[count][2] i32 |
| 11 | ImageAttributes | version, reserved1, wrap mode, clamp ARGB, object clamp i32, reserved2 |
| 12 | PixelBitmap | pixel bitmap |
| 13 | BitmapImage | bitmap |
| 14 | MetafileImage | metafile |
| 15 | CustomLineCap | custom cap |

Opaque bodies retain the whole assembled definition body, including its version
and any unknown subtype words. UTF-16 units are never decoded or normalized.
StringFormat ranges contain first character index and length. The object type
and ID are zero-extended from the original flag fields.

| Nested value | Fields in order |
| --- | --- |
| path | version, flags, shared points, point-type encoding u32, point types, alignment-padding blob |
| region node | tag u32, followed by fields: 1 Binary: operation u32; 2 Rectangle: rectangle[4] f32bits; 3 Path: path; 4 Empty: none; 5 Infinite: none |
| linear gradient | flags, wrap mode i32, rectangle[4] f32bits, start ARGB, end ARGB, reserved[2], optional transform[6] f32bits, blend count u64, blends[count] pairs |
| path gradient | flags, wrap mode i32, center ARGB, center[2] f32bits, surrounding colors words, boundary tag u32 and boundary, optional transform[6] f32bits, optional blend pairs, optional focus scales[2] f32bits |
| texture | flags, wrap mode i32, optional transform[6] f32bits, optional image |
| pixel bitmap | version, width i32, height i32, stride i32, pixel format, optional palette, pixels blob |
| bitmap | version, width i32, height i32, stride i32, pixel format, bitmap type, data blob |
| metafile | version, metafile type, data blob, suffix blob |
| palette | style flags, entries words (ARGB) |
| custom cap | version, cap subtype u32, cap fields below |

Path point-type encoding 0 has a blob of plain u8 types. Encoding 1 has run count
u64 followed by each run's header u8 and point type u8; runs retain their compressed
headers and are not expanded. Shared points preserve float, sign-extended integer
and width-tagged relative coordinate forms. Region nodes retain the flat preorder
sequence and explicit operation words. Linear blends retain core order (preset
colors, or selected vertical then horizontal factor arrays); positions and values
are interleaved in normalized pairs, unlike their separate wire arrays.
Path-gradient boundary tag 0 contains a path, tag 1 contains points as pairs.
Focus scales contain x then y. A texture image starts with image tag u32:
1 pixel bitmap, 2 bitmap, 3 metafile, followed by that value's fields. Bitmap bytes
remain compressed/uninterpreted where applicable; no image expansion occurs.

Custom cap subtype 0 (Default) contains flags, base cap, base inset f32bits,
stroke start cap, stroke end cap, stroke join, stroke miter limit f32bits,
width scale f32bits, fill hot spot[2] f32bits, stroke hot spot[2] f32bits,
optional fill path, optional line path. Subtype 1 (AdjustableArrow) contains
width f32bits, height f32bits, middle inset f32bits, fill state (raw Boolean u32),
line start cap, line end cap, line join, line miter limit f32bits,
width scale f32bits, fill hot spot[2] f32bits, line hot spot[2] f32bits.

A pen contains version, flags, unit, width f32bits, optional transform[6] f32bits,
then seven optional scalars in order: start cap i32, end cap i32, join i32,
miter limit f32bits, line style i32, dashed line cap i32, dash offset f32bits.
Next are optional dash-pattern words (f32bits), optional alignment scalar i32,
optional compound-line words (f32bits), custom cap count u64, custom caps[count]
in selected start/end order, brush version u32 and brush subtype u32.
The brush fields follow: 0 Solid: ARGB; 1 Hatch: style, foreground ARGB,
background ARGB; 2 Texture: texture; 3 PathGradient: path gradient;
4 LinearGradient: linear gradient. Scalar absence always emits a zero value;
array/transform/path absence emits only the zero presence word.

### Output bounds

A nonallocating checked traversal sizes every normalized field, array element,
UTF-16/glyph unit and retained padding byte before output is reserved. The entire
header, segment table, raw frames and normalized payloads must fit both
`max_output_bytes` and the platform vector-size bound. One fallible reservation
covers that total; the same traversal then emits variable payloads into the
reserved buffer without temporary arrays. A cap one byte below the required
size rejects the entire snapshot with `EMF_LIMIT_EXCEEDED` and NULL output.
