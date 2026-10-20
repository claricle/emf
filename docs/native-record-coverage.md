# Native record coverage evidence

This records bounded implementation evidence reconciled with [`TODO.plan/11-record-coverage.md`](../TODO.plan/11-record-coverage.md); it does not establish whole-issue completion. The referenced specs are evidence in source, not claims that they were run for this note.

## Typed core and native fields

Palette records are represented as typed Rust variants and decoded by the core parser ([model](../emf-rs/crates/emf-core/src/model.rs), [parser](../emf-rs/crates/emf-core/src/parse.rs)); FFI snapshots and native hydration map the five families to editable Ruby fields ([snapshot](../emf-rs/crates/emf-ffi/src/snapshot.rs), [hydrator](../lib/emf/native/hydrator.rb), [fields](../lib/emf/native/palette_fields.rb)). The exact TODO rows are `RealizePalette` (EMR 52), `SelectPalette` (48), `CreatePalette` (49), `ResizePalette` (51), and `SetPaletteEntries` (50). Focused evidence covers all five records, array edits and malformed counts ([native spec](../spec/emf/native/palette_adapter_spec.rb), [wire spec](../spec/emf/native/palette_wire_spec.rb), [snapshot spec](../emf-rs/crates/emf-ffi/tests/palette_snapshot.rs)). Remaining acceptance is registry reconciliation and corpus/variant accounting, including zero/one/many entries and malformed spans/counts across the registered record set; no corpus-wide result is asserted here.

`GradientFill` (EMR 118) is a typed Rust `GradientFill` model with rectangle/triangle mesh decoding and validation ([model](../emf-rs/crates/emf-core/src/model.rs), [gradient decoder](../emf-rs/crates/emf-core/src/gradient.rs), [snapshot](../emf-rs/crates/emf-ffi/src/gradient_snapshot.rs)); native family 93 dispatches through [BitmapFields](../lib/emf/native/bitmap_fields.rb) to [GradientFields](../lib/emf/native/gradient_fields.rb). Focused specs cover gradient modes and malformed counts ([native spec](../spec/emf/native/gradient_adapter_spec.rb), [snapshot spec](../emf-rs/crates/emf-ffi/tests/gradient_snapshot.rs)). Remaining work is verifying the registered variants and real corpus, including mesh shapes/index and truncation boundaries.

The ten bitmap TODO rows are `BitBlt` (76), `StretchBlt` (77), `MaskBlt` (78), `PlgBlt` (79), `SetDibitsToDevice` (80), `StretchDIBits` (81), `CreateMonoBrush` (93), `CreateDibPatternBrushPt` (94), `AlphaBlend` (114), and `TransparentBlt` (116). Rust core bitmap parsing and native hydration have typed headers, transfer fields and bounded buffer spans ([model/parser](../emf-rs/crates/emf-core/src/bitmap.rs), [native fields](../lib/emf/native/bitmap_fields.rb), [hydrator](../lib/emf/native/hydrator.rb)); focused native coverage exercises the ten layouts and empty/reversed/absent buffers plus invalid spans ([spec](../spec/emf/native/bitmap_adapter_spec.rb)). Bitmap payloads remain byte buffers: pixel decoding, compression/color interpretation, and complete per-variant corpus evidence remain open. `CreateFontIndirectW` (EMR 82) has typed font variants and parser support ([font model](../emf-rs/crates/emf-core/src/model.rs), [parser](../emf-rs/crates/emf-core/src/parse.rs), [native fields](../lib/emf/native/font_fields.rb)); focused specs cover logical, Panose and extended forms and invalid lengths/axes ([font spec](../spec/emf/native/font_adapter_spec.rb), [font snapshots](../emf-rs/crates/emf-ffi/tests/font_snapshot.rs)). Its row remains unverified against the complete registry/corpus variant set.

## SmallTextOut fixed-prefix support

`SmallTextOut` (EMR 108) is not wholly opaque: native hydration decodes its 28-byte fixed payload prefix (36 bytes including header) and preserves the remaining text/options-dependent bytes as `body` ([fields](../lib/emf/native/small_text_fields.rb), [hydrator](../lib/emf/native/hydrator.rb)). The focused spec covers prefix edits, body preservation, short-record raw fallback and following-record continuity ([spec](../spec/emf/native/small_text_adapter_spec.rb)). Its TODO row records this partial typed-prefix support; text interpretation based on `cChars`/`fuOptions`, option variants, and corpus/truncation coverage remain unproven.

## Opaque compatibility and status correction

These adapter types are intentionally carried as editable opaque `body` bytes, not typed record semantics: `PolyTextOutA` 96, `PolyTextOutW` 97, `CreateColorspace` 99, `SetColorspace` 100, `DeleteColorspace` 101, `GlsRecord` 102, `GlsBoundedRecord` 103, `PixelFormat` 104, `DrawEscape` 105, `ExtEscape` 106, `ForceUfiMapping` 109, `NamedEscape` 110, `ColorCorrectPalette` 111, `SetIcmProfileA` 112, `SetIcmProfileW` 113, `SetLinkedUfis` 119, `ColorMatchToTargetW` 121, and `CreateColorspaceW` 122. `OPAQUE_BODY_TYPES` establishes the dispatch list and [adapter spec](../spec/emf/native/adapter_spec.rb) checks empty/nonempty bodies, Ruby parity, edits and unknown-record preservation ([hydrator](../lib/emf/native/hydrator.rb)). For these TODO rows, use “In progress: native opaque-body compatibility and edit parity; semantic decoding and registry/corpus variant proof remain open”; this does not imply typed parsing.

`ExtFloodFill` (53) and `SetTextJustification` (120) have typed scalar fields in
Rust `RecordData` and parse arms ([model](../emf-rs/crates/emf-core/src/model.rs),
[parser](../emf-rs/crates/emf-core/src/parse.rs)), with snapshot families 91/92 and
native hydration ([fields](../lib/emf/native/fields.rb),
[hydrator](../lib/emf/native/hydrator.rb)). Focused [semantic state controls](../spec/emf/native/semantic_state_spec.rb)
cover signed fields, edits and suffix preservation. They are not members of
`OPAQUE_BODY_TYPES`; their plan rows now reflect this support. Corpus/variant proof
remains open. No group above claims completion.

## Inventory check

Run `ruby script/record_coverage` using a supported project Ruby to compare all 118
autoloads (117 registered numeric types plus the `Raw` fallback) with the plan.
`HEADER` and `SETCOLORADJUSTMENT` constants are not registry entries and are not
silently added as record rows. Header parsing has separate acceptance criteria.
The guard detects missing/extra/duplicate classes, numeric collisions, mismatched
constants, registration/autoload differences and wire-source link drift. It reads
the current literal Ruby declarations without loading native code or parsing a
fixture. A future dynamic registry requires updating this extractor.

Passing inventory checks does not prove semantic dispatch or corpus coverage. The
18 opaque compatibility types above and SmallTextOut's variable text body remain
the exact semantic gaps in this registry accounting; typed records still require
variant and corpus reconciliation before P11 can be marked complete.
