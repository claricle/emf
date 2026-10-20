# Native record coverage evidence

This records bounded implementation evidence reconciled with [`TODO.plan/11-record-coverage.md`](../TODO.plan/11-record-coverage.md); it does not establish whole-issue completion. The referenced specs are evidence in source, not claims that they were run for this note.

## Typed core and native fields

Palette records are represented as typed Rust variants and decoded by the core parser ([model](../emf-rs/crates/emf-core/src/model.rs), [parser](../emf-rs/crates/emf-core/src/parse.rs)); FFI snapshots and native hydration map the five families to editable Ruby fields ([snapshot](../emf-rs/crates/emf-ffi/src/snapshot.rs), [hydrator](../lib/emf/native/hydrator.rb), [fields](../lib/emf/native/palette_fields.rb)). The exact TODO rows are `RealizePalette` (EMR 52), `SelectPalette` (48), `CreatePalette` (49), `ResizePalette` (51), and `SetPaletteEntries` (50). Focused evidence covers all five records, array edits and malformed counts ([native spec](../spec/emf/native/palette_adapter_spec.rb), [wire spec](../spec/emf/native/palette_wire_spec.rb), [snapshot spec](../emf-rs/crates/emf-ffi/tests/palette_snapshot.rs)). Remaining acceptance is corpus/variant accounting, including zero/one/many entries and malformed spans/counts across the registered record set; no corpus-wide result is asserted here.

`GradientFill` (EMR 118) is a typed Rust `GradientFill` model with rectangle/triangle mesh decoding and validation ([model](../emf-rs/crates/emf-core/src/model.rs), [gradient decoder](../emf-rs/crates/emf-core/src/gradient.rs), [snapshot](../emf-rs/crates/emf-ffi/src/gradient_snapshot.rs)); native family 93 dispatches through [BitmapFields](../lib/emf/native/bitmap_fields.rb) to [GradientFields](../lib/emf/native/gradient_fields.rb). Focused specs cover gradient modes and malformed counts ([native spec](../spec/emf/native/gradient_adapter_spec.rb), [snapshot spec](../emf-rs/crates/emf-ffi/tests/gradient_snapshot.rs)). Remaining work is verifying the registered variants and real corpus, including mesh shapes/index and truncation boundaries.

The ten bitmap TODO rows are `BitBlt` (76), `StretchBlt` (77), `MaskBlt` (78), `PlgBlt` (79), `SetDibitsToDevice` (80), `StretchDIBits` (81), `CreateMonoBrush` (93), `CreateDibPatternBrushPt` (94), `AlphaBlend` (114), and `TransparentBlt` (116). Rust core bitmap parsing and native hydration have typed headers, transfer fields and bounded buffer spans ([model/parser](../emf-rs/crates/emf-core/src/bitmap.rs), [native fields](../lib/emf/native/bitmap_fields.rb), [hydrator](../lib/emf/native/hydrator.rb)); focused native coverage exercises the ten layouts and empty/reversed/absent buffers plus invalid spans ([spec](../spec/emf/native/bitmap_adapter_spec.rb)). Bitmap payloads remain byte buffers: pixel decoding, compression/color interpretation, and complete per-variant corpus evidence remain open. `CreateFontIndirectW` (EMR 82) has typed font variants and parser support ([font model](../emf-rs/crates/emf-core/src/model.rs), [parser](../emf-rs/crates/emf-core/src/parse.rs), [native fields](../lib/emf/native/font_fields.rb)); focused specs cover logical, Panose and extended forms and invalid lengths/axes ([font spec](../spec/emf/native/font_adapter_spec.rb), [font snapshots](../emf-rs/crates/emf-ffi/tests/font_snapshot.rs)). Its row remains unverified against the complete registry/corpus variant set.

## SmallTextOut fixed-prefix support

`SmallTextOut` (EMR 108) exposes the 28-byte fixed payload prefix, a raw 16-byte optional block, and a count/flag-dependent binary `text_bytes` view; same-length edits preserve record layout ([fields](../lib/emf/native/small_text_fields.rb), [hydrator](../lib/emf/native/hydrator.rb)). The focused semantic spec proves Ruby/native parity and that semantic truncation raises, while existing controls preserve raw-body snapshots, suffix bytes, and short-body behavior ([semantic spec](../spec/emf/native/small_text_out_semantics_spec.rb), [adapter spec](../spec/emf/native/small_text_adapter_spec.rb)). Rendering, Unicode conversion, and full variant/corpus proof remain open.

## Opaque compatibility and status correction

`ForceUfiMapping` (109) and `SetLinkedUfis` (119) now expose Ruby semantic views over preserved body bytes. Force exposes `ufi_checksum`, `ufi_index`, and detached exact-8-byte `ufi_bytes` edits. Linked UFI exposes read-only `u_num_linked_ufi`, indexed checksum/index/UFI byte views and setters, and validates the declared count against the array plus reserved 8-byte suffix. The focused [UFI semantic spec](../spec/emf/native/ufi_semantics_spec.rb) covers strict types and exact lengths, atomic errors, raw-short bodies, suffix/reserved bytes, reassignment and snapshot preservation; native family-0 parity is proven. Rust family-0 snapshots still retain the body as opaque bytes, and full registered-variant/corpus proof remains open.

`PixelFormat` (104) has body-backed `pfd_size`, `pfd_version`, `dw_flags`, and three mask accessors, plus detached `pfd_bytes` for the exact 40-byte pixel-format descriptor. The focused [semantic spec](../spec/emf/native/pixel_format_semantics_spec.rb) covers the required 40-byte prefix, type/range-atomic edits, short bodies, suffixes and Ruby/native snapshot preservation; native family-0 parity is proven. Advisory field values are not enum-validated. Full variant/corpus proof remains open.

`DrawEscape` (105) and `ExtEscape` (106) expose body-backed unsigned `i_escape`, read-only `cj_in`, and detached `data_bytes` with exact-length edits over the required eight-byte prefix. The focused [escape semantic spec](../spec/emf/native/escape_semantics_spec.rb) covers zero-length data, short and oversized spans, invalid type/range atomicity, body reassignment, suffix preservation, and Ruby/native snapshot, input/output, and reparse parity. Native family-0 parity is proven; playback behavior and full variant/corpus proof remain open.

`ColorMatchToTargetW` (121) exposes strict unsigned 32-bit `dw_action`/`dw_flags` accessors, read-only `cb_name`/`cb_data`, and detached exact-length `name_bytes`/`profile_bytes` views after its 16-byte prefix. The focused [semantic spec](../spec/emf/native/color_match_semantics_spec.rb) covers span bounds, zero-length and raw-short bodies, suffixes, body reassignment and native snapshot preservation. Native family-0 parity is proven; playback, encoding interpretation and full variant/corpus proof remain open.

`NamedEscape` (110) exposes strict unsigned 32-bit `i_escape`, read-only `cj_driver`/`cj_in`, and detached exact-length `driver_name_bytes`/`data_bytes` views after its 12-byte prefix. The focused [semantic spec](../spec/emf/native/named_escape_semantics_spec.rb) covers span bounds, odd-byte driver-name payloads, suffixes, body reassignment and native snapshot preservation. Native family-0 parity is proven; Unicode name interpretation, playback and full variant/corpus proof remain open.

Three color-related wire classes expose additive semantic access over preserved `body`: `ColorCorrectPalette` (111) has four unsigned 32-bit accessors (`ih_palette`, `first_entry`, `entry_count`, `reserved`) ([field/body spec](../spec/emf/native/color_correct_palette_spec.rb)); `SetColorspace` (100) and `DeleteColorspace` (101) expose the unsigned 32-bit `ih_cs` object-table index ([accessor spec](../spec/emf/native/colorspace_handles_spec.rb)). Native family-0 body parity is proven for all three; the opaque snapshot preserves body bytes, while these Ruby accessors do not change the snapshot shape. They do not implement playback/rendering semantics or establish complete variant/corpus coverage.

`SetColorAdjustment` (23) has Ruby wire accessors for the twelve ColorAdjustment scalar fields over a preserved `body` ([wire class](../lib/emf/emr/binary/records/set_color_adjustment.rb)); the focused [field/body spec](../spec/emf/native/set_color_adjustment_spec.rb) is the acceptance reference. Native family-0 body parity is proven. Rust typed snapshots, playback/rendering, and complete variant/corpus proof remain open.

`SetIcmProfileA` (112) and `SetIcmProfileW` (113) expose body-backed `dw_flags`, read-only `cb_name`/`cb_data`, and detached raw `name_bytes`/`profile_bytes` spans with exact-length setters. The focused [semantic span spec](../spec/emf/native/icm_profile_semantics_spec.rb) covers both encodings, span bounds, short-body errors, raw short-body preservation, suffixes, siblings and trailing bytes; native family-0 parity is proven. These accessors do not decode names or implement playback/rendering, and full variant/corpus proof remains open.

`PolyTextOutA` (96) and `PolyTextOutW` (97) preserve the raw body while exposing indexed `text_bytes`, `dx_bytes` and `entry_bounds` views with exact-span setters; `c_strings` is read-only. The focused [semantic span spec](../spec/emf/native/poly_text_out_semantics_spec.rb) covers the variable-length 24-byte A / 40-byte W descriptors, record-relative spans, A/W character widths, `PDY` doubled `dx` width, optional bounds, and truncation/offset guards. Native family-0 parity, raw short-body preservation and suffix preservation are covered. These are byte views, not Unicode conversion or rendering support; full variant/corpus proof remains open.

`CreateColorspace` (99) and `CreateColorspaceW` (122) expose the logical color-space structure as body-backed scalars: `ih_cs`, `lcs_signature`, `lcs_version`, `lcs_size`, `color_space_type`, `intent`, three raw unsigned 32-bit gamma values, 36 raw endpoint bytes, and fixed-width `filename_bytes` (260 bytes A / 520 bytes W). W also exposes `dw_flags`, read-only `cb_data`, and the declared `profile_bytes` span after the 592-byte LCS prefix. The focused [semantic span spec](../spec/emf/native/create_colorspace_semantics_spec.rb) exercises the 332-byte A / 592-byte W LCS bodies, exact-length atomic span edits, short-body behavior and suffix preservation; native family-0 parity is proven. `SetColorspace` (100) and `DeleteColorspace` (101) expose unsigned 32-bit `ih_cs` with a four-byte minimum semantic span ([handle spec](../spec/emf/native/colorspace_handles_spec.rb)). No enum or filename/profile encoding validation is claimed; full variant/corpus proof remains open.

`GlsRecord` (102) and `GlsBoundedRecord` (103) retain their opaque bodies while exposing read-only `cb_data` and detached `data_bytes` with exact-length edits; the bounded form also exposes the raw 16-byte `bounds` prefix with a setter. The focused [GLS semantic spec](../spec/emf/native/gls_semantics_spec.rb) covers four-/20-byte prefixes, span validation, zero/short/oversized payloads, suffixes and Ruby/native snapshot/reparse preservation. Native family-0 parity is proven; full variant/corpus proof remains open.

`ExtFloodFill` (53) and `SetTextJustification` (120) have typed scalar fields in
Rust `RecordData` and parse arms ([model](../emf-rs/crates/emf-core/src/model.rs),
[parser](../emf-rs/crates/emf-core/src/parse.rs)), with snapshot families 91/92 and
native hydration ([fields](../lib/emf/native/fields.rb),
[hydrator](../lib/emf/native/hydrator.rb)). Focused [semantic state controls](../spec/emf/native/semantic_state_spec.rb)
cover signed fields, edits and suffix preservation. They are not members of
`OPAQUE_BODY_TYPES`; their plan rows now reflect this support. Corpus/variant proof
remains open. No group above claims completion.

## Inventory check

The current registry has 119 autoloads: 118 numeric record types plus `Raw`.
`SETCOLORADJUSTMENT` maps to `SetColorAdjustment` in the registry. `HEADER` is not a
record registry entry; header parsing has separate acceptance criteria. The focused
[extended-header spec](../spec/emf/native/header_extension_spec.rb) exercises
Ruby/native preservation for 88-, 100-, 108- and 124-byte layouts, explicit
description/pixel-format offsets, opaque gaps and suffix bytes, and a following-record
mutation. This proves only those bounded layouts and preservation behavior; complete
header-variant and corpus parity remain open. Run
`ruby script/record_coverage` using a supported project Ruby to check inventory
identity against the plan; this is not semantic or corpus proof.
The guard detects missing/extra/duplicate classes, numeric collisions, mismatched
constants, registration/autoload differences and wire-source link drift. It reads
the current literal Ruby declarations without loading native code or parsing a
fixture. A future dynamic registry requires updating this extractor.

Passing inventory checks does not prove semantic dispatch or corpus coverage.
Opaque-body records retain semantic gaps; SmallTextOut exposes a binary text view
but does not implement rendering or Unicode conversion. These controls likewise do
not prove complete registered variants or corpus coverage. P11 remains incomplete
pending full variant/corpus evidence.
