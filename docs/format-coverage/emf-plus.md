# EMF+ acceptance inventory

This inventory distinguishes native typed interpretation, explicit opaque retention,
and public integration. It supplements [native implementation details](native-emf-plus.md)
and the [Ruby inventory](../../TODO.plan/09-emf-plus-coverage.md). The normative
source is local `reference-docs/ms-emfplus/ch02-structures.md` (MS-EMFPLUS 240423).
Whole-format acceptance remains partial; byte preservation alone does not establish
rendering semantics or complete specification conformance.

## Native record families

The specification enumerates 58 record types (0x4001–0x403A): 54 have record
sections, three are reserved and StrokeFillPath has no normative record section.
The native opt-in module is `emf-rs/crates/emf-core/src/emf_plus/`.

| Family / identifiers | Typed implementation | Public regression files under `emf-core/tests/` | Remaining boundary |
| --- | --- | --- | --- |
| Header, EOF, GetDC; state, save/restore/container, transform and clipping records | `records.rs`, `parser.rs`, `serializer.rs` | `emf_plus.rs` | Playback ordering, rendering enum domains and object-reference validity are not validated |
| Drawing 0x4009–0x401B and curve/image layouts | `drawing.rs` and fixed Clear | `emf_plus_drawing.rs` | Raw float bits and coordinate widths are retained; rendering equivalence is unproven |
| DrawString 0x401C, DrawDriverString 0x4036 | `text.rs` | `emf_plus_text.rs` | Raw UTF-16/glyphs; no text shaping or font rendering |
| Object 0x4008 | `objects.rs`, `object_data.rs`, `object_data/` | `emf_plus.rs`, `emf_plus_objects.rs` and family tests below | Explicit bounded assembly/edit; no implicit resegmentation |
| SerializableObject 0x4038 | `effects.rs`, all eleven standard GUID layouts | `emf_plus_effects.rs` | Unknown GUID buffers remain uninterpreted |
| SetTSGraphics 0x4039 | `tsgraphics.rs`, fixed state and optional palette | `emf_plus_tsgraphics.rs` | Raw rendering fields; no terminal-server playback |
| SetTSClip 0x403A, C clear | `tsclip.rs`, counted signed four-word rectangles | `emf_plus_tsclip.rs` | Wire-order words only; no guessed delta/geometry interpretation |
| SetTSClip 0x403A, C set | Explicit `RecordData::Opaque` | `emf_plus_tsclip.rs` | Section 2.3.8.1 fixes four bytes per rectangle but describes variable one/two-byte deltas. Resolve against an independent oracle before typed compressed decoding |
| Comment 0x4003 | Explicit `RecordData::Opaque` | Generic unknown/padding retention in `emf_plus.rs` | Dedicated private-data variant/acceptance remains open |
| Reserved 0x4005–0x4007; StrokeFillPath 0x4037; unknown IDs | Explicit `RecordData::Opaque` | `emf_plus.rs` | No invented layout for reserved/undocumented data |

SetTSClip C-clear decoding requires DataSize = (Flags & 0x7FFF) * 8 before any
rectangle expansion. The C bit and count must agree with typed data on write;
callers update the enclosing flags after changing rectangle count. Record size and
DataSize derive from data. Signed extremes, zero/maximal count, malformed counts,
truncation, shared allocation/work limits, type/count mismatch, mutable sizes,
unknown neighboring data, padding and split/empty segments have public controls.
Compressed bytes keep their original flags/data without claiming typed acceptance.

## Native objects

| Type | Typed extent | Regression files |
| --- | --- | --- |
| Brush | Solid, Hatch, LinearGradient, PathGradient, Texture; optional transforms/blends/boundaries | `emf_plus_objects.rs`, `emf_plus_linear_brush.rs`, `emf_plus_path_brush.rs`, `emf_plus_texture.rs` |
| Pen | Flag-selected fields, arrays, nested brushes and custom caps | `emf_plus_pen.rs` |
| Path | Float, integer, relative coordinate width, point types and compressed runs | `emf_plus_path.rs` |
| Region | Flat preorder binary tree, rectangle/path/empty/infinite nodes | `emf_plus_region.rs` |
| Image | Bitmap/metafile metadata, 14 known pixel formats and palettes | `emf_plus_bitmap.rs`, `emf_plus_texture.rs`, `emf_plus_objects.rs` |
| Font | Raw float bits, style/unit, UTF-16 family and suffix | `emf_plus_objects.rs` |
| StringFormat | All fixed words, counted tab stops and character ranges | `emf_plus_objects.rs` |
| ImageAttributes | Fixed reserved/wrap/clamp fields | `emf_plus_objects.rs` |
| CustomLineCap | Default and adjustable arrow, optional fill/outline paths | `emf_plus_linecap.rs` |

Unknown object/brush/image/node variants retain opaque bytes. Bitmap pixels are
not decompressed, nested metafiles are not recursively interpreted, and rendering
numeric ranges are not validated. Each family has exact/mutable and malformed/limit
controls; these are generated protocol regressions, not licensed rendering goldens.

## Representation and integration

Native `parse`/`parse_segments` accept logical bytes after EMF+ signatures, including
empty/headerless extraction streams. `serialize_segments` retains exact original
boundaries and rejects size-changing edits. `Document::structured_emf_plus` and
`apply_structured_emf_plus` supply optional extraction, stale-source checking and
atomic comment repacking; see `emf_plus_container.rs`. Raw chunks stay available.
This is an editing API, not a full standalone playback-document validator.

Ruby's separate optional `Metafile#emf_plus_stream` API retains the raw `emf_plus`
String and supplies explicit apply/representation handling. Its inventory and tests
are documented separately. Native typed core coverage does not imply every typed
variant has a mapped ABI/Ruby consumer, Model visitor or CLI rendering path.

## Remaining acceptance

Resolve compressed TSClip, supply dedicated native Comment acceptance, establish
independent rendering/conditional-version oracles, and measure the advertised
ABI/Ruby mapping for every family. Keep licensed embedded corpus, EMF+ Only/dual
mode behavior, full ordering/reference validation, fuzz/performance evidence and
cross-platform native execution distinct from synthetic unit acceptance. No full
format completion, Windows/Linux execution, full corpus rerun or rendering oracle
is claimed by this checkpoint.

## Checked checkpoint (2026-10-20)

The public C-clear typed assertion fails on base `70e141d` because the record is
opaque. With `tsclip.rs`, all six focused tests pass, together with 22 existing
EMF+, container and terminal-server graphics preservation tests (28 total).
Commands: `cargo test --manifest-path emf-rs/Cargo.toml -p emf-core --test
emf_plus_tsclip --test emf_plus_tsgraphics --test emf_plus --test
emf_plus_container`, using the existing local target and one build job. These
are macOS arm64 debug checks, not release/platform or full-corpus acceptance.
