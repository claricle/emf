# WMF snapshot version 1

`emf_wmf_document_snapshot` returns a separately owned `EmfBuffer`, freed with
`emf_buffer_free`. All integers are little-endian. WMFS is independent of the EMF
snapshot versions. No existing EMF ABI function changes. Output, including array
expansion, is limited to 200 MiB and sized before allocation. Edited documents
are serialized and reparsed with default limits before snapshotting; descriptors
therefore describe the current serialized document, unlike original-span getters.

The prefix is magic `WMFS`, u32 version 1, u64 total byte length, then four u64
values: record count, diagnostic count, trailing length, source length. Next are
10 u32 header values: file type, header size, version, size words, object count,
maximum record words, parameter count, has-placeable, has-EOF, reserved zero.
Eight placeable u32 slots always follow: handle, left, top, right, bottom, inch,
reserved, checksum (all zero when absent). Coordinates are sign-extended i32.

Each record has u64 index/offset/byte-length, u32 function/family, u64 payload
length, then payload. The function includes the original high byte. Families:

- 0: opaque, no payload; the caller retains the original source span.
- 1: EOF, no payload.
- 2: fixed geometry fields, i32 in WMF wire order.
- 3: u64 point count/polygon count, u32 polygon sizes, i32 X/Y point pairs.
- 4: pen, brush or object reference fields, u32 in WMF wire order; signed pen
  widths are sign-extended i32 bit patterns.
- 5: i32 X/Y, u32 options/has-rectangle, u64 text/padding/DX/suffix lengths,
  u32 has-DX/reserved-zero, four i32 rectangle coordinates (always present),
  text bytes, padding bytes, i32 DX values, suffix bytes. TextOut has no options,
  rectangle, DX or suffix. Rectangle order is left/top/right/bottom.
- 6: scalar state fields, one u32 per field in WMF wire order. SetBkColor,
  SetMapperFlags and SetTextColor retain their u32 values. SetBkMode, SetMapMode,
  SetPolyFillMode, SetRop2, SetStretchBltMode, SetTextAlign and SetTextCharExtra
  zero-extend their u16 values. SetTextJustification has break-count/break-extra;
  SetLayout has layout/reserved, each zero-extended from u16. The payload contains
  only these fields, with no suffix length or suffix bytes. The complete source
  span includes any suffix; Ruby retains it from the original record body after
  the known wire prefix (two bytes for single u16 fields, four bytes otherwise).
- 7: CreateFontIndirect, exactly 84 bytes: five sign-extended i32 fields in
  height/width/escapement/orientation/weight order, eight zero-extended u32 fields
  in italic/underline/strike-out/char-set/out-precision/clip-precision/quality/
  pitch-and-family order, then exactly 32 raw face-name bytes. All face-name
  bytes survive, including NUL and bytes after it. No suffix length or suffix
  bytes are included; the complete source span retains any bytes after the
  known 50-byte WMF font prefix.
- 8: palette state. CreatePalette (low function byte f7), SetPalEntries (37)
  and AnimatePalette (36) have u32 start/count followed by count entries, each
  four u32 values in red/green/blue/flags wire order (8 + 16 * count bytes).
  Start is the palette version for CreatePalette and the entry offset for updates.
  SelectPalette (34) has one u32 object index; ResizePalette (39) has one u32
  entry count; RealizePalette (35) has an empty payload. All u16 and u8 values
  are zero-extended. No suffix length or suffix bytes are included. The complete
  source span retains bytes after the known WMF prefix: 4 + 4 * count bytes for
  array variants, two bytes for SelectPalette/ResizePalette, zero for RealizePalette.
- 9: region and clipping records. CreateRegion (low function byte ff) has u32
  next-in-chain/object-count, four sign-extended i32 bounds in left/top/right/bottom
  order, then u32 scan-count. Each scan has u32 top/bottom/line-count followed by
  line-count pairs of u32 left/right endpoints. Scan coordinates and endpoints
  zero-extend u16 values. The payload has 28 + sum(12 + 8 * line-count) bytes.
  Wire ObjectType is fixed at 6; RegionSize, ScanCount, maxScan and repeated scan
  point counts are derived from the region. Next-in-chain and object-count
  retain their ignored wire values. FillRegion (28) has u32 region-index/brush-index;
  FrameRegion (29) adds sign-extended i32 height/width. InvertRegion (2a), PaintRegion
  (2b) and SelectClipRegion (2c) each have one u32 object index. OffsetClipRgn (20)
  has sign-extended i32 y/x; ExcludeClipRect (15) and IntersectClipRect (16) have
  sign-extended i32 bottom/right/top/left. All indices zero-extend u16 values.
  No suffix length or suffix bytes are included. The complete source span retains
  bytes following RegionSize for CreateRegion, or the known 4/8/2/4/8-byte wire
  prefix for FillRegion/FrameRegion/index/offset/rectangle variants respectively.

- 10: pattern brushes. CreatePatternBrush (low function byte f9) has four
  sign-extended i32 values in bitmap-type/width/height/width-bytes order, then
  u32 planes/bits-pixel, exactly four raw ignored pointer bytes and 18 raw
  reserved bytes, u32 pattern length, and the raw pattern (50 + length bytes).
  Width-bytes is retained independently and can be zero or negative. Pattern
  length is derived from positive width/height, one plane and nonzero bits-pixel:
  ceil(width * bits-pixel / 16) * 2 * height. No suffix bytes or suffix length
  appear in the payload; the complete source span retains bytes after the
  32-byte wire header and pattern. DibCreatePatternBrush (42) has u32 style,
  stored color-usage and target length, then raw target (12 + length bytes).
  Style and color-usage zero-extend u16 values. Style 3 ignores color-usage when
  interpreting a DIB, but the stored value survives unchanged; other styles
  require color-usage at most 2. The target is the entire nonempty, even-length
  wire remainder, including malformed or unsupported DIB data. No DIB decoding
  is performed for this payload. Function high bytes and complete source spans
  are retained for both variants. CreateBrushIndirect remains family 4.

- 11: bitmap transfers. Every payload ends with u32 bitmap presence (0 or 1),
  u32 byte length, and that many raw bitmap bytes. BitBlt (22) and DibBitBlt
  (40) begin with u32 raster-operation, sign-extended i32 source-y/source-x/
  height/width/destination-y/destination-x, and u32 reserved (40 + length bytes
  total). StretchBlt (23) and DibStretchBlt (41) begin with u32 raster-operation,
  sign-extended i32 source-height/source-width/source-y/source-x/destination-height/
  destination-width/destination-y/destination-x, and u32 reserved (48 + length).
  For these four variants, bitmap absence is determined by the complete wire
  body word count equaling the function high byte. An absent bitmap has presence
  and length zero; reserved zero-extends the stored u16. The complete source span
  retains suffix bytes after the absent 18-byte Blt or 22-byte StretchBlt header,
  without duplicating them in the payload. Present bitmaps have reserved zero and
  contain the entire nonempty, even-length remainder after the 16-byte Blt or
  20-byte StretchBlt header.
  SetDibToDev (33) begins with nine u32 values: color-usage, scan-count, start-scan,
  source-y, source-x, height, width, destination-y, destination-x, all zero-extended
  from u16 (44 + length bytes total). StretchDib (43) begins with u32
  raster-operation/color-usage, then the eight sign-extended StretchBlt geometry
  values in the same order (48 + length). These two variants always have presence
  1 and retain the entire nonempty, even-length remainder after their 18-byte or
  22-byte wire headers respectively. Color-usage retains the complete u16 range.
  Bitmap interiors remain opaque, including malformed or unsupported DIB data.
  All six variants retain complete function words and source spans.

Families 2–11 cover the existing Ruby WMF models only. Rust-only typed records
remain opaque. For Ruby compatibility, ExtTextOut DX consumes one i16 per
character even with ETO_PDY set; the original flag and remaining bytes survive
as suffix. The compatibility view uses the Rust typed decoder with only that
flag masked, leaving source metadata and returned option values unchanged.
It can fail under default parse resource limits.

Each diagnostic is u32 kind/has-function/function/detail-kind, u64 offset/detail1/
detail2. Kinds: 1 version, 2 declared size, 3 maximum record, 4 checksum,
5 truncated header, 6 record too small, 7 truncated record, 8 invalid EOF,
9 missing EOF, 10 malformed payload, 11 object issue, 12 DIB unsupported by WMF
version. Kind 12 stores the WMF version in detail1, with detail-kind and detail2
zero; the function and offset identify the DIB record. Numeric pairs retain the
core variant's field order. Object detail kinds are 1 table full, 2 invalid
reference, 3 wrong kind, 4 invalid RestoreDC. Detail1 is the index or sign-extended
saved DC; wrong-kind detail2 packs expected in the low u32 and found in the high
u32. Object kinds are brush1/font2/palette3/pen4/region5. These are core diagnostics;
the Ruby bridge independently enforces its existing stricter parsing policy.

Trailing bytes follow the diagnostics. Record source bytes are not duplicated in
the snapshot; Ruby hydration uses the input for opaque records, state suffixes
and span checks.
EOF, malformed fixed sizes, headers/checksums, object lifetimes, and count limits
remain subject to Ruby compatibility checks. The snapshot API itself is lossless
and diagnostic, and does not apply all those strict Ruby rejection policies.
