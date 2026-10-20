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

**Unfinished error-class contract:** `Loader#checked` currently raises
`Emf::FormatError` for every nonzero ABI status, with copied native error detail.
The intended policy remains `FORMAT_ERROR` / `LIMIT_EXCEEDED` → `FormatError`,
`SERIALIZE_ERROR` → `SerializeError`, internal/allocation failure → `Emf::Error`,
and binding-owned invalid arguments treated as an adapter defect. The bounded
lifetime tests prove real parse failures and error cleanup, not status-specific
internal/allocation mapping. Native ABI serialization is not called by the Ruby
adapter, so its `SERIALIZE_ERROR` path is not measured here. Preserve this gap
until implemented and exercised; do not count cleanup coverage as error-policy
completion. Successful parse diagnostics become ordered `Emf::ParseError` values.

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
- Twelve rounds of EMF and WMF successful parse/serialize plus real failing parse
  calls release 24 documents, 24 snapshot buffers and 24 errors; copied error
  messages remain usable after native error release.

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
