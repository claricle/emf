# 05 — Ruby binding and backend compatibility

Status: **Implemented binding; bounded ownership acceptance verified on Apple
arm64 / Ruby 3.4.8. Broader delivery gates remain open.** Native EMF/EMF+ and
standard/placeable WMF construct existing Ruby models. The original 3–4 day
estimate and proposed file map no longer describe the implementation. See
[baseline](02-baseline-and-parity.md), [performance](07-performance.md),
[platform delivery](08-platform-delivery.md), and [progress](10-progress.md) for
whole-project gates; this lane does not certify them.

[Ruby execution sequence](05-ruby-execution.md) retains the original integration
sequence. The implemented paths and ownership below supersede this document's
former proposed owner/model/backend split.

## Implemented files and dispatch

| Path | Actual responsibility |
| --- | --- |
| `lib/emf/backend.rb` | Internal selection for the existing public API |
| `lib/emf/native.rb` | Lazy native entry point, adapter, Ruby serializer dispatch |
| `lib/emf/native/library_path.rb` | Explicit library override or validated packaged manifest lookup |
| `lib/emf/native/loader.rb` | Fiddle signatures, ABI validation, scoped document/buffer/error ownership |
| `lib/emf/native/snapshot.rb`, `wmf_snapshot.rb` | Batched snapshot decoding |
| `lib/emf/native/hydrator.rb`, `wmf_hydrator.rb` | Existing EMF/WMF model construction |
| `lib/emf/native/lazy_wire.rb` | Ruby-owned lazy EMF wire values and preserved bytes |
| `spec/emf/native/backend_spec.rb` | Selection, availability, subprocess checks |
| `spec/emf/native/adapter_spec.rb`, `lazy_wire_spec.rb` | Hydration, mutation, serialization and cleanup regressions |
| `spec/emf/native/lifetime_acceptance_spec.rb` | Real-library ownership, exception cleanup and bounded repetition |
| `spec/emf/backend_parity_spec.rb` | Public behavioral and mutation parity |

There is no `native/owner.rb`, `native/backend.rb` or `native/model.rb`.
`Emf.parse`, `parse_file`, `serialize`, `serialize_file` and `detect_format` retain
the existing API and public model classes. BinData remains available for the Ruby
backend and mutable native EMF wire compatibility. Serialization currently uses
the existing Ruby EMF/WMF writers for both backends, not the ABI serializer.

Fiddle loads only when native use is attempted. No binding compilation step is
introduced. Ruby 3.1–3.4 / Linux and macOS availability, pointer mappings and gem
installation still require their advertised matrix evidence; this ownership run
only measures Ruby 3.4.8 on Apple arm64. Ruby 4.0 Fiddle packaging remains a
separate dependency decision; do not infer availability from a version string.

## Implemented selection and remaining error policy

`EMF_BACKEND` is read at selection; `EMF_NATIVE_LIBRARY` is an explicit library
path override, including for development/testing.

| Backend value | Implemented behavior |
| --- | --- |
| unset or `auto` | Attempt native; select Ruby on `Native::Unavailable` during setup |
| `ruby` | Select Ruby without requiring Fiddle/library loading |
| `native` | Require the native backend; raise `Native::Unavailable` (an `Emf::Error`) on unavailable setup |
| anything else | Raise `ArgumentError` |

Without a library override, `LibraryPath` reads packaged
`lib/emf/native/platforms.json`, validates platform, ABI version and SHA-256, and
resolves the library beneath the native directory. This manifest is a generated
packaging asset, not a checked-in source-platform list. Missing assets, load
failures and ABI mismatch allow `auto` setup fallback. Parsing errors after native
selection propagate without Ruby retry. Malformed input is not an availability
failure. Native default-delivery acceptance remains subject to the platform and
performance gates.

**Implemented error-class contract:** `Loader#checked` and buffer-view failures
map `FORMAT_ERROR` / `LIMIT_EXCEEDED` to `Emf::FormatError`,
`SERIALIZE_ERROR` to `Emf::SerializeError`, and invalid argument,
internal/allocation or unknown status to `Emf::Error`, with copied native detail.
`spec/emf/native/loader_status_spec.rb` exercises all seven nonzero status cases,
success cleanup and failures while copying error or buffer data (10 examples).
These use controlled Fiddle-boundary responses; they do not inject an actual
allocator failure or native panic. The real-library lifetime suite separately
proves parse-error cleanup. Native ABI serialization is not called by the Ruby
adapter, so its error mapping is boundary-tested rather than an end-to-end
serialization failure. Successful parse diagnostics become ordered
`Emf::ParseError` values.

## Implemented wire and lifetime contract

EMF hydration builds existing headers, metafiles and `WireAdapter` records from
batched native snapshots. Lazy wires retain validated Ruby field values and
per-record bytes. First `.wire` access constructs the actual BinData class with
those fields (`klass.new`, not an input reparse), caches it, and preserves relevant
text/scale payloads. WMF hydration builds existing typed WMF records directly.
Opaque/recovery records retain their applicable preserved bytes.

Exposed wire edits, including nested edits, are observed by serialization, value
operations and visitor dispatch. Unexposed EMF records can use preserved bytes;
existing manually constructed records and mixed models still use the Ruby writer.
Hash values can change with wire mutation, as in the Ruby backend. Existing
`adapter_spec.rb` and `lazy_wire_spec.rb` cover these preservation behaviors.

Native document ownership is **scoped**, not GC/finalizer based. `Loader#document`
and `#wmf_document` free the document in `ensure`, including exceptions during
hydration. Snapshot buffers are copied into Ruby strings and freed in `ensure`;
error messages are copied and native error handles freed in `ensure`. Returned
models and lazy wires have no live native document dependency. A retained record
must therefore work after its metafile is collected, without a finalizer or a
same-handle owner lock.

## Measured ownership acceptance and exit gates

`lifetime_acceptance_spec.rb` observes real Fiddle calls and returned handles. It
checks allocated/freed handle multiplicities rather than replacing native parse
results. The bounded cases establish:

- Weak references prove metafile collection before lazy/exposed EMF record use;
  a standalone exposed wire also survives both adapter and metafile collection.
- Standard/placeable WMF records survive metafile collection and input-string
  replacement, then support mutation and serialize/reparse.
- Exceptions after one real lazy EMF record, during WMF typed construction, after
  native buffer view, and while converting an actual native error release their
  acquired handles. The same adapter subsequently parses successfully.
- `Loader#record_bytes` rejects an out-of-range index, then returns independent
  Ruby strings from the same valid document. Both strings remain usable after
  native buffer/document release and GC; mutating one leaves the other intact.
- Twelve rounds of EMF and WMF successful parse/serialize plus real failing parse
  calls release 24 documents, 24 snapshot buffers and 24 errors; copied error
  messages remain usable after native error release.

### Additional bounded public parity evidence

`spec/emf/native/wmf_collection_parity_spec.rb` adds structural WMF collection
controls for removal, insertion and replacement on standard and placeable WMF.
The retained Apple Silicon library at
`/private/tmp/emf-execution/apple-repro/clean-a/aarch64-apple-darwin/release/libemf_ffi.dylib`
(SHA-256 `a167eae1e2ed3ebeaa7066b8ea870508185a9304416e4f8740e8ea4f5fb67ef3`)
passed 12 examples with 0 failures (seed 14873). The cases verify exact bytes,
two serialize/reparse generations, regenerated size/count fields, opaque
siblings, trailing bytes and placeable-header checksums. This is bounded
Apple-arm64 evidence against a retained library; it does not qualify final Rust
HEAD or other platforms. See `/private/tmp/emf-execution/wmf-collection-parity.log`.

The same retained library ran `spec/emf/native_wmf_resilience_seeds_spec.rb`:
2 examples, 0 failures (seed 11231). Eight named malformed WMF seeds were
rejected with Ruby fallback forbidden, then valid generated input was parsed,
serialized and compared byte-for-byte. This adds malformed-input controls, not
whole-corpus or cross-platform acceptance; see the resilience plan's bounded
evidence and the shared handoff.

`spec/scripts/installed_wmf_workload_spec.rb` also exercises the installed
workload's native WMF path against that retained library: 14 examples, 0
failures (seed 30005). Standard and placeable WMF are parsed, dumped exactly,
mutated through typed `MoveTo.x`, reparsed and serialized again; the workload
retains EMF+ format reporting. Discovery is stubbed in these specs, so this
does not establish real installed-gem or final-Rust-HEAD behavior. See the
platform-delivery plan and shared handoff for the environment controls.

Run the focused checks against an actual built library:

```sh
EMF_TEST_NATIVE_LIBRARY=/path/to/libemf_ffi.dylib bundle exec rspec spec/emf/native/lifetime_acceptance_spec.rb spec/emf/native/lazy_wire_spec.rb spec/emf/native/adapter_spec.rb spec/emf/native/backend_spec.rb
bundle exec rubocop --cache false spec/emf/native/lifetime_acceptance_spec.rb spec/support/native_lifetime_acceptance.rb
```

These are bounded ownership checks, not a memory-plateau or concurrency claim.
Long-running GC stress, platform/Ruby matrix coverage, complete forced-backend
suites, downstream golden parity, native installation without a compiler and
wire-heavy performance remain separate acceptance gates. No Rust rebuild or
corpus replay is required for this focused check. A fallback run is never native
evidence: these cases instantiate `Emf::Native.backend` directly with an explicit
real-library path and skip if that file is absent.
