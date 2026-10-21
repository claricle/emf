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
| Comment 0x4003 | Named `RecordData::Comment` private bytes | `emf_plus_comment.rs` | Private application bytes have no standardized interpretation |
| Reserved 0x4005–0x4007; StrokeFillPath 0x4037; unknown IDs | Explicit `RecordData::Opaque` | `emf_plus.rs` | No invented layout for reserved/undocumented data |

SetTSClip C-clear decoding requires DataSize = (Flags & 0x7FFF) * 8 before any
rectangle expansion. The C bit and count must agree with typed data on write;
callers update the enclosing flags after changing rectangle count. Record size and
DataSize derive from data. Signed extremes, zero/maximal count, malformed counts,
truncation, shared allocation/work limits, type/count mismatch, mutable sizes,
unknown neighboring data, padding and split/empty segments have public controls.
Compressed bytes keep their original flags/data without claiming typed acceptance.

Comment private data is named rather than treated as an unknown record. Section
2.3.2.1 requires aligned DataSize and Size = DataSize + 12: unaligned data and
extra record padding are rejected on both parse and write. Ignored nonzero flags
are preserved. Private bytes remain uninterpreted. Dedicated tests cover empty
and nonempty bytes, split segments, unknown neighbors, mutable size derivation,
parse/output limits, rejected edits and atomic enclosing Document repacking.
This changes the earlier permissive malformed-Comment behavior deliberately;
valid Comment bytes retain exact round trips.

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

The continuation-to-Document acceptance in `emf_plus_container.rs` assembles a
logical Object split across three EMR comments, retains exact unchanged bytes and
segment lengths, mutates a decoded SolidBrush and repacks growing/shrinking Region
objects. It checks continuation padding, opaque neighbors, unrelated EMR bytes,
trailing bytes, stale-source rejection and failure atomicity before successful
reuse. `replace_object_bytes` intentionally rejects size changes; explicit fragment
edits update TotalObjectSize before Document repacking. Invalid/incomplete totals
and allocation/work/record limits are rejected without a partial Document edit.
Rich Region decoding remains opt-in: malformed trees/nested paths can be retained
as raw object bytes but fail typed decoding. Region nesting is stored in flat
preorder; the existing 20,000-level test proves nonrecursive parse/write/drop,
while resource budgets bound expansion. This is not recursive rendering support.


Ruby's separate optional `Metafile#emf_plus_stream` API retains the raw `emf_plus`
String and supplies explicit apply/representation handling. Its inventory and tests
are documented separately. Native typed core coverage does not imply every typed
variant has a mapped ABI/Ruby consumer, Model visitor or CLI rendering path.

## Remaining acceptance

Resolve compressed TSClip, establish
independent rendering/conditional-version oracles, and extend the Ruby mapping
beyond native framing (below). Keep licensed embedded corpus, EMF+ Only/dual
mode behavior, fuzz/performance evidence and cross-platform native execution
distinct from synthetic unit acceptance. No full
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

Comment's malformed-layout assertion fails against `aacd19d` (`invalid Comment
layout accepted`). With named private data and strict layout validation, its four
new tests and the same 28 preservation tests pass (32 total). Add
`--test emf_plus_comment` to the command above. Atomic enclosing edits, source
staleness, ignored flags, private-byte edits and failed-limit recovery are included.

The Object/continuation Document checkpoint passes 12 container tests, together
with the unchanged seven base EMF+ and seven Region controls (26 total). The final
changed container file was rerun after adding nested-decode rejection and passes
without compiler warnings. The checks use the same one-job local debug target;
no production repair or new platform/corpus claim accompanies these acceptance
assertions.

## Object-reference validation and Ruby consumer (feature/native-emfplus-references-ruby)

Core `Stream::object_references` resolves, per record, the objects a known
Drawing, Text, image or clip record references against the most recently
completed definition of each of the 64 slots (a definition counts from its last
continuation record). Targets: `Definition`, `SolidColor` (S flag), `EmptySlot`,
`WrongType`, `OutOfRange`. Only invalid chains and resource limits are errors;
unresolved references are data. Tests: `emf_plus_references.rs` (valid, dangling,
type mismatch, redefinition and type change, continuation, solid color, budget).

The EPSN snapshot appends unresolved references as nonfatal diagnostics
(`emf-plus-snapshot-v1.md`, "Reference diagnostics").

`Emf::Native::EmfPlusStream.from_metafile` (lib/emf/native/emf_plus_stream.rb)
builds an `Emf::EmfPlus::Stream` from the snapshot: native framing, object-chain
and reference validation; Ruby `Records` classes decode each frame's validated raw
bytes. Over the 27 EMF+ fixtures, including the three corrupted ones, it equals the
Ruby Stream (segments, records, offsets, gaps, errors, object diagnostics) and the
fallback set is empty.

Ruby requests snapshot **version 2**, which differs from version 1 only by:

- Recovering framing: each comment is framed on its own by the Ruby framer's rules.
  A truncated header, invalid Size/DataSize or a Size past the comment ends that
  comment's framing (the remainder is unframed, kept by Ruby with its collected
  `ParseError`, which Ruby re-derives at the native stop offset and requires to
  match); the next comment starts afresh. A record spanning comments is therefore
  unframed too, as in Ruby, rather than joined. An EMR_COMMENT whose cbData exceeds
  its record is selected, clamped to the bytes it holds. Core exposes this as
  `Document::structured_emf_plus_recovering_with_budget`; its stream cannot be applied
  back (`EmbedError::Edit(RecordLayout)`).
- SetTSClip with C clear is typed (family 0x106: rectangle count u64, then four
  sign-extended i32 words per rectangle). C-set clips stay family 0 with raw bytes.

Version 1 is unchanged. Deliberate tighter behaviour: a correctly framed record
whose typed layout the native decoder rejects (for example a fixed-size record with
the wrong DataSize, or a SetTSClip whose DataSize is not count * 8) fails the whole
snapshot, so `from_metafile` returns nil and the Ruby stream keeps it as a diagnosed
`Unknown`. Regression example: `emf_plus_stream_spec.rb`, "returns nil for a
correctly framed record whose typed layout native rejects". The normalized native
payloads are otherwise not mapped into Ruby values.

MetafileImage and texture metafile images now retain any bytes after
MetafileDataSize in `suffix` (corpus test-109/test-118 carry 24-26); they were
previously rejected, failing the whole snapshot.
