# WMF typed views, WMFV / WMFE version 1

Two read-only exports expose Rust's typed WMF views so another decoder can be
checked against them at run time. They are additive: `EMF_ABI_VERSION` and WMFS
(version 1) are unchanged, and nothing here is needed to hydrate a document.
Raw record fields stay authoritative; the Ruby views are pure functions of those
fields, so native-backed Ruby records already answer them. These exports are the
independent Rust decoder used to prove the two agree.

Both return a separately owned `EmfBuffer` (free with `emf_buffer_free`) and
take an optional `emf_limits` (NULL for defaults). Integers are little-endian.
`bytes` means a u64 length followed by that many raw bytes. Resource-limit
failures are status errors, never an empty view.

## emf_wmf_record_view(document, index, limits, out_buffer, out_error)

`WMFV`, u32 version 1, u32 entry count, then that many entries. Zero entries
means no applicable or valid view (malformed or unsupported interior, other
record types, EOF). An out-of-range index is `EMF_INVALID_ARGUMENT`. Each entry
starts with a u32 tag:

- 1 absent: an optional bitmap source that is not present. No body.
- 2 Bitmap16: i32 type/width/height/width-bytes, u32 planes/bits-pixel,
  `bytes` pixels, `bytes` trailing.
- 3 DIB: u32 header kind (0 core, 1 info). Core: u32 width/height/planes/bit
  count. Info: i32 width/height, u32 planes/bit count/compression/image size,
  i32 x/y pixels per meter, u32 colors used/important, `bytes` extension. Then
  u32 has-masks and three u32 masks (zero when absent), u32 color kind (0 none,
  1 RGB triples, 2 RGB quads, 3 palette indices), u64 count and the rows
  (3, 4 or 2 bytes each), `bytes` pixels, `bytes` trailing.
- 4 fixed or empty Escape: u32 escape subtype, u64 value count, that many i64
  values in declaration order (DrawPatternRect: x, y, width, height, style,
  pattern). Zero values means an empty subtype.
- 5 counted Escape: u32 subtype, `bytes` exact counted data.
- 6 SPCLPASSTHROUGH2: u32 reserved, `bytes` data.
- 7 embedded-EMF segment (Escape 0x000F, valid): u32 version, checksum, flags,
  record count, current size, remaining bytes, total size, `bytes` data.
- 8 embedded-EMF segment error: u32 error code (below).

Applicable records: BitBlt, StretchBlt (Bitmap16), DibBitBlt, DibStretchBlt,
SetDibToDev, StretchDib (DIB, with each record's color usage; the first four use
usage 0), DibCreatePatternBrush (DIB of the target using the effective color
usage) and Escape. An Escape may carry several entries, in the order 4, 5, 6,
then 7 or 8.

## emf_wmf_embedded_emf(document, limits, out_buffer, out_error)

`WMFE`, u32 version 1, u64 sequence count, then per sequence: u64 first record,
u64 segment count, u32 ok flag. When ok: u32 version, u32 checksum, u32
checksum-valid, `bytes` stream. Otherwise: u32 error code.

## Error codes

1 not embedded EMF, 2 transport, 3 metadata, 4 comment identifier, 5 comment
type, 6 non-zero flags, 7 zero record count, 8 segment too large, 9
inconsistent sizes, 10 sequence mismatch, 11 remaining mismatch, 12 record
count mismatch, 13 incomplete, 14 limit exceeded.
