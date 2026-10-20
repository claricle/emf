# WMF coverage and remaining acceptance

Status: partial format coverage. Typed record transport does not establish typed
coverage of every nested bitmap or Escape payload. Issue 15 and plan 09 remain
open until the residuals below have implementation and acceptance evidence.

This inventory describes the implementation at `704d77a`. The normative local
reference is [MS-WMF structures](../../reference-docs/ms-wmf/ch02-structures.md).
The scope is standard and Aldus placeable WMF, independently of EMF/EMF+.

## Headers, framing and edits

| Contract | Implementation | Evidence |
| --- | --- | --- |
| Standard types 1/2 and versions 0x0100/0x0300 | Ruby `lib/emf/wmf/parser.rb`; Rust `emf-rs/crates/emf-core/src/wmf.rs` | `spec/emf/wmf/parser_spec.rb`; Rust `tests/wmf.rs` |
| Placeable signed bounds, checksum, reserved word, type-dependent handle | Same parsers; Ruby `lib/emf/wmf/serializer.rb` | Parser specs include in-memory handle preservation and checksum regeneration; Rust `tests/wmf.rs` |
| Word lengths, bounded record progress, one final EOF and opaque trailing bytes | Ruby parser/serializer; Rust WMF core | Same parser specs and Rust WMF framing tests |
| Unknown function payloads and original function high bytes | Ruby `UnknownRecord` and typed `type_id`; Rust original record spans | Ruby parser and native WMF specs, including unknown zero-low-byte functions |
| Edited file size, largest-record length, placeable checksum | Ruby serializer; Rust WMF serializer | Ruby parser specs and Rust WMF edit tests |
| Object table capacity, create/select/delete validation | Ruby `lib/emf/wmf/binary.rb`; Rust `wmf/objects.rs` | `spec/emf/wmf/object_records_spec.rb`; Rust `tests/wmf_objects.rs`; native WMF rejection specs |
| Resource bounds | Ruby input-byte/record-count limits; Rust shared parse/serialize budgets | Ruby parser limit specs; Rust `tests/wmf.rs` budget tests |

The Rust core can retain a malformed recognized record with diagnostics. The Ruby
public parser and native hydrator enforce the Ruby compatibility contract and may
reject it. These behaviors must be described separately from byte preservation.

## Record dispatch

All 70 values in the reference's `RecordType` enumeration, including EOF, have
Ruby and Rust dispatch at this baseline. This is a dispatch inventory, not a
claim that every payload variant or playback behavior has acceptance coverage.

| Family | Ruby implementation | Rust implementation and focused tests |
| --- | --- | --- |
| Geometry, point arrays, clipping, arcs, scaling, pixel/flood operations and PatBlt | `binary.rb`, `geometry_codec.rb` | `wmf/geometry.rs`; `tests/wmf_geometry.rs` |
| State, DC stack, object selection/creation/deletion and palettes | `binary.rb`, `palette_codec.rb`, `dc_escape_codec.rb` | `wmf/state.rs`, `wmf/objects.rs`; `tests/wmf_state.rs`, `tests/wmf_objects.rs`, `tests/palette.rs` |
| TextOut and ExtTextOut | `binary.rb`, `text_codec.rb` | `wmf/text.rs`; `tests/wmf_text.rs` |
| Region creation and drawing | `region_codec.rb` | `wmf/region.rs`; `tests/wmf_region.rs` |
| Six bitmap transfer functions | `bitmap_codec.rb` | `wmf/bitmap.rs`; `tests/wmf_bitmap.rs` |
| Pattern and DIB pattern brushes | `brush_codec.rb` | `wmf/brush.rs`; `tests/wmf_brush.rs` |
| Escape and EOF | `dc_escape_codec.rb`, `parser.rb` | `wmf/escape.rs`, `wmf.rs`; `tests/wmf_escape.rs`, `tests/wmf.rs` |

Ruby codec paths above are relative to `lib/emf/wmf/`; Rust paths are relative
to `emf-rs/crates/emf-core/src/` or its sibling `tests/` directory.

## Nested payloads and native transport

| Payload | Current semantic coverage | Remaining boundary |
| --- | --- | --- |
| Bitmap16 and DIB transfer sources | Rust exposes optional typed views and compatible replacement; Ruby retains bitmap bytes | Ruby nested views would be an additive API. Compressed pixel data remains opaque. |
| Pattern brushes | Rust validates pattern sizing and exposes DIB target views; Ruby retains pattern/target bytes | Ruby nested target views would be additive. |
| Region scans and fonts | Both implementations expose typed scans and fixed font fields | No missing typed interior identified in this inventory. |
| Recognized Escape subtypes | Rust exposes fixed, counted and SPCLPASSTHROUGH2 views; Ruby retains function/data/padding/suffix | Ruby subtype views would be additive; current bytes remain inert. |
| Embedded EMF Escape (0x000F) | Generic Escape preserves bytes; neither side provides a typed sequence API | Metadata, segment bounds and sequence assembly remain unimplemented as semantic views. See the reference's META_ESCAPE_ENHANCED_METAFILE record. |

The native snapshot's families 0–13 carry opaque records, EOF and all typed record
groups above. Full function words, source spans and bitmap presence are retained.
The ABI is documented in
[wmf-snapshot-v1.md](../../emf-rs/crates/emf-ffi/wmf-snapshot-v1.md).
Ruby hydration validates snapshot fields against source bytes. Existing bridge
tests cover unknown siblings, typed high function bytes, trailing bytes, DC state
and Escape padding/suffix. Direct hydrator tests additionally cover optional
bitmap forms and invalid source/family combinations.

`spec/emf/native_wmf_spec.rb` adds public bridge parity for BitBlt with and without
a source bitmap, including reserved words and an absent-source suffix. It checks
typed field equality and exact serialization through both Ruby paths, with Ruby
parsing prohibited during the native phase. This does not establish native
bridge coverage of every optional bitmap function.

Rust's advisory `DibUnsupportedByVersion` diagnostic for version 0x0100 is not
surfaced in Ruby's model. Both the fallback and native Ruby paths accept and
preserve that record; this inventory found no acceptance mismatch to fix.

## Fixtures and independent evidence

The checked-in WMF corpus contains two synthetic line documents:
`spec/fixtures/wmf/standard-line.wmf` and `placeable-line.wmf`. They cover both
containers, signed coordinates and an unknown sibling; generated examples in
`spec/emf/wmf/` cover additional record families. They are not a broad licensed
real-world WMF corpus. `spec/support/fixture_manifest.rb` discovers both files
and labels WMF provenance synthetic. The checked-in manifest at this baseline
contains no WMF rows; reconciling it belongs to the existing manifest owner.

Open acceptance evidence includes licensed real-world examples for the promised
families, rendering goldens or a documented independent semantic oracle for each
applicable family, and WMF resilience/fuzz seed coverage. Passing generated
round-trip examples alone does not close these items. No WMF rendering or fuzz
pass is claimed here.

## Follow-up order

1. Reconcile the fixture manifest through its existing owner; extend optional
   bitmap bridge cases beyond BitBlt when claiming all-function parity.
2. Define the embedded-EMF Escape sequence API before implementation: validate the
   34-byte metadata, 8,192-byte segment limit, record count, total/remaining byte
   arithmetic and completion, with multi-segment and malformed examples.
3. Define Ruby Bitmap16/DIB and brush-target views against the existing Rust
   semantics, followed by Ruby views for already recognized Escape subtypes.
4. Supply the independent corpus, semantic/rendering and resilience evidence
   above before claiming full format acceptance.

Items 2–3 require public API design decisions. Raw preservation currently works;
these are additive capabilities rather than demonstrated codec defects.

## Verification boundary

The preceding typed-record checkpoint passed 200 combined Ruby/native examples
and 64 FFI tests. Those results apply to unchanged source at `704d77a`; this
inventory does not claim a new full-format suite or final-head CI pass. Native
parity checks require a library built from the matching Rust source.
