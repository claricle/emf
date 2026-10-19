# 09 — Complete typed WMF and structured EMF+

Status: **Not started**. Estimate: **15–25 additional engineering days**, provisional after specification/fixture discovery. This is additional to the estimated 20–30 days for the initial EMF/native delivery; it is not an implied promise that all new-format scope fits that initial estimate.

## Problem and scope

[Issue #15](https://github.com/claricle/emf/issues/15) includes typed EMF, EMF+ and WMF. Staging EMF parity first does not remove the other formats from issue completion.

`lib/emf/detector.rb` recognizes standard and Aldus placeable WMF, but `lib/emf/wmf/parser.rb` and `serializer.rb` raise unimplemented errors; `binary.rb` is a placeholder. There are no existing WMF fixtures. `lib/emf/emf_plus/parser.rb` and `serializer.rb` are also stubs. The current EMF parser concatenates EMF+ comment payloads into raw bytes and exposes them through `Model::Metafile#emf_plus`; this is not structured EMF+ decoding.

Use `reference-docs/ms-wmf/`, `reference-docs/ms-emfplus/`, `reference-docs/ms-emf/` and their source specifications to build the coverage inventory. `kaitai-struct-wmf.ksy` can inform investigation but does not establish specification coverage or a new dependency. Parsanol remains an architectural reference only.

## Proposed files

- `docs/format-coverage/wmf.md`, `docs/format-coverage/emf-plus.md`: every normative header/record/object family, flags, version/conditional rules, implementation paths, serializer status and positive/negative fixture coverage.
- `spec/fixtures/wmf/`, `spec/fixtures/emf-plus/`, `spec/fixtures/regressions/` and `spec/fixtures/manifest.json`: licensed originals and minimal generated regressions, with provenance/license/hash/expected outcome and standard/placeable/embedded distinctions.
- `emf-rs/crates/emf-core/src/wmf/{mod.rs,header.rs,records.rs,parser.rs,serializer.rs}`: typed WMF and preserved unknown records.
- `emf-rs/crates/emf-core/src/emf_plus/{mod.rs,header.rs,objects.rs,records.rs,parser.rs,serializer.rs}`: structured stream, object-table and continuation handling.
- `emf-rs/crates/emf-core/tests/wmf.rs`, `tests/emf_plus.rs`: typed semantics, errors, mutation/serialization and byte preservation.
- `lib/emf/wmf/parser.rb`, `lib/emf/wmf/serializer.rb`, `lib/emf/wmf/binary.rb`, `lib/emf/emf_plus/parser.rb`, `lib/emf/emf_plus/serializer.rb`, `lib/emf/emf_plus/binary.rb`: replace placeholders in the Ruby compatibility/fallback layer as required by the agreed backend contract.
- `lib/emf/model/wmf/`, `lib/emf/model/emf_plus/`, `spec/emf/wmf_spec.rb`, `spec/emf/emf_plus_spec.rb`: Ruby model mapping and public API regressions; changes to `lib/emf/model/metafile.rb` require the representation decision below.
- Existing C ABI header/accessors, binding parity harness, seed manifest and downstream golden adapter: extend explicitly for both formats rather than creating parallel incompatible APIs.

## Execution order and dependencies

1. Depend on [01-requirements.md](../TODO.plan/01-requirements.md) for public compatibility, [03-rust-core.md](../TODO.rust/03-rust-core.md) for independent typed data and serialization, and [04-c-abi.md](../TODO.rust/04-c-abi.md)/[05-ruby-binding.md](../TODO.ruby/05-ruby-binding.md) for mapping. First inventory the specifications and implemented EMF families. Count uncovered families and identify fixtures/licenses before confirming the estimate. Do not use the absence of fixtures to mark a record family complete.
2. Acquire licensed WMF fixtures covering standard and placeable headers, both standard types, coordinate mapping, object creation/selection/deletion, drawing, text, palettes, bitmaps and escapes. Add minimal generated fixtures for missing families, invalid sizes/counts, handle misuse and checksum/header edge cases. Record which cases require rendering goldens or a trusted independent oracle; current Ruby stub behavior is not a correctness oracle.
3. Implement WMF detection/header validation and typed record decoding with checked word-to-byte conversion, signedness, units, object table bounds and record progress. Preserve placeable metadata, unknown payloads, padding and trailing bytes where required. Implement serialization in the same family increments, including unchanged byte-identical output and explicit length/header/checksum updates after edits. Test standard/placeable detection ambiguity and malformed inputs. Prove any new interpretation with fixture assertions.
4. Inventory EMF+ framing, flags, versions, object definitions/references, continuation/multi-record objects, drawing/text/image families, nested data and EMF dual-mode comments. Acquire licensed embedded examples and minimal boundary fixtures. Preserve comment segmentation and bytes for unchanged EMF serialization, even when the logical EMF+ stream spans comments; concatenated bytes alone do not retain all framing information.
5. Resolve the representation gate before adding public accessors: retain the current `Metafile#emf_plus` raw-byte value and its CLI/dump byte-array representation. Design an optional typed model alongside it without changing existing return types or silently replacing raw data. Specify how typed edits map back to comment chunks, how raw-byte/wire mutations invalidate typed caches, and which source wins if both are edited. Record this decision and its compatibility tests in the coverage document. New optional API names remain undecided until this gate is resolved.
6. Implement EMF+ record/object decoding and serialization by family, with bounds for recursive/nested structures and expanded data. Extend ABI batch metadata/accessors and Ruby visitors without breaking EMF callers. Define standalone EMF+ parsing behavior from the specification/API inventory rather than assuming the current top-level detector supports it. An unimplemented typed family must remain visibly open even if its raw bytes round-trip.
7. For each family add positive typed assertions, negative/resource-limit cases, exact unedited round-trips, mutable round-trips and rendering goldens where applicable. Extend [06-resilience.md](../TODO.delivery/06-resilience.md) fuzz targets and [07-performance.md](../TODO.delivery/07-performance.md) workloads. Test Ruby fallback behavior for the newly advertised formats: a native-only implementation cannot silently claim equivalent fallback coverage.
8. Close the coverage inventory only after every promised family has implementation and tests, all conditional/version cases have a stated outcome, and unresolved interpretation/fixture gaps are tracked. An EMF-only milestone may ship separately, but complete issue scope remains open until WMF and structured EMF+ acceptance is met.

## Planned commands

Future commands after fixtures, modules and tests exist; no new-format tests have been executed for this plan:

```sh
ruby script/fixture_manifest --check
cargo test --manifest-path emf-rs/Cargo.toml -p emf-core --test wmf --test emf_plus
EMF_BACKEND=native bundle exec rspec spec/emf/wmf_spec.rb spec/emf/emf_plus_spec.rb spec/emf/backend_parity_spec.rb
EMF_BACKEND=ruby bundle exec rspec spec/emf/wmf_spec.rb spec/emf/emf_plus_spec.rb spec/emf/backend_parity_spec.rb
EMFSVG_PATH=/path/to/emfsvg bundle exec ruby bench/emfsvg.rb --backend native --output tmp/bench/emfsvg-formats.json
```

The downstream command requires the pinned compatible consumer and its expanded golden inventory; if it does not yet support a promised family, record that coverage gap and add an independent semantic/serialization oracle instead of claiming a rendering pass.

## Acceptance

- Standard and placeable WMF parse into typed models and serialize correctly; licensed fixtures and minimal regressions cover the promised record families and header variants.
- Structured EMF+ covers the promised specification inventory, objects, continuation and embedded framing; raw `emf_plus` bytes and existing dump output remain compatible.
- Both formats have asserted typed semantics, mutation behavior, unknown-byte preservation, errors/resource limits, fuzz seeds and C ABI/Ruby mapping tests. No unchecked recursion, expansion or object reference escapes the shared limits.
- Native and fallback capability declarations match tested behavior, and all existing 208 valid/21 corrupt EMF fixtures retain their established contracts.
- Coverage documents identify remaining gaps honestly. Full-format and full-issue completion are claimed only after those gaps are resolved and the broader acceptance evidence exists.
