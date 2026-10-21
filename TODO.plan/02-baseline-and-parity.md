# 02 — Baseline and parity

Status: **Partial — revision-bound Ruby corpus and valid-corpus native checks
recorded; complete parity, stage-cost and downstream acceptance remain open.** Ruby evidence is bound to the
exact source revision below; later relevant parser changes require a new capture.

Depends on [requirements](01-requirements.md). Supplies acceptance data to
[the core](03-rust-core.md), [binding](05-ruby-binding.md),
[resilience](06-resilience.md), and [performance](07-performance.md).
Track completion in [progress](10-progress.md); overall sequencing is in
[the overview](00-overview.md).

## Planned artifacts

| Path | Planned responsibility |
| --- | --- |
| `spec/fixtures/manifest.json` | Versioned inventory shared by Ruby specs, Rust integration tests, benchmarks and fuzz corpus selection |
| `script/fixture_manifest` | Generate/check inventory without moving existing fixtures |
| `spec/support/backend_parity.rb` | Canonical observations, mutation scenarios and isolated backend runner |
| `spec/emf/backend_parity_spec.rb` | Public API, model, wire, diagnostics and byte comparisons |
| `bench/parser.rb` | Stage timings, process memory and machine metadata per fixture/backend |
| `bench/emfsvg.rb` | Reproducible downstream golden-suite adapter against a pinned checkout |

The current valid corpus is 186 files in `spec/fixtures/emf/`, 21 in
`spec/fixtures/emf-ea/`, and one in `spec/fixtures/simple/`: **208 valid fixtures**.
`spec/fixtures/emf-corrupted/` contains **21 corrupt `.emf` fixtures**; its README
is not a fixture. Two synthetic WMF fixtures extend the current inventory to
**231 fixtures** (208 valid EMF, 21 corrupt EMF, two WMF). The manifest must verify
these counts against the checkout,
record repository-relative path, SHA-256, byte size, expected detected format,
and observed outcome (`parsed`, `recovered`, or `format_error`). Record backend
exceptions and reviewed safety deviations separately rather than declaring every
corrupt fixture an unconditional byte-round-trip target. Existing RSpec fixture
paths remain valid. Later WMF/EMF+ cases extend this schema under
[format extension](09-format-extension.md).

## Planned baseline capture

1. Run the existing Ruby suite and valid round-trip suite at a recorded revision.
   Capture each corrupt fixture in a separate child process with an external
   deadline, bounded output and a kill/reap path. A parent-side Ruby `Timeout`
   around a native call cannot establish a native hang bound.
2. Capture `Emf.detect_format`, `Emf.parse`, `Emf.parse_file`, `Emf.serialize`, and
   `Emf.serialize_file` behavior, including return values, file bytes and errors.
   The public API has these names; no `from_*` aliases are proposed.
3. Identify the issue's reported 12-second fixture and environment. If these
   cannot be recovered, report the corpus's measured slowest fixture and leave
   the original claim unverified. Measure detection, wire parse, model creation,
   first full wire traversal, repeated wire traversal, dump, serialization and
   downstream conversion independently. Report cold load separately from warmed
   parsing; do not compare one backend's parse-only time to another's conversion.
4. Pin the downstream `emfsvg` revision, Ruby/dependency versions, golden inputs
   and exact test command. Make `bench/emfsvg.rb` supply this checkout as the
   dependency and record the resolved gem path. Capture the unmodified Ruby
   golden result before native comparisons. If access or the golden command is
   unavailable, this gate remains open; parser parity alone cannot close it.

## Planned parity contract

The canonical observation is a test artifact, not a new public model. It includes
format, header class and all exposed header fields, record order, record model
class, type IDs, offsets, actual `wire.class.name`, typed field observations,
visitor dispatch, `Visitors::Dump` text, errors in order with class/message/offset/
record code, opaque EMF+ comment bytes, and trailing bytes. Keep exact binary
slices or digests alongside human-readable snapshots. Compare floats by their
wire bit pattern where identity matters: NaN payloads, signed zero, padding and
unknown payloads must not drift through a JSON number conversion.

For every valid fixture assert both backends serialize to the original bytes,
and cross-compare parsed observations and reparsed output. Existing header
conversion (`Header.from_wire`/`to_wire`) remains part of this check. Synthetic
cases must cover unknown record IDs, variable arrays, comments, EOF plus trailing
bytes, optional header data, padding and floating-point bit patterns.

`WireAdapter#wire` currently returns a mutable BinData record; its identity and
class affect consumers, equality, hash, inspect, visitor output and serialization.
Add public regressions that read the same wire twice, mutate scalar and nested
array fields, serialize, reparse, and compare with the Ruby backend. Include
unmodified sibling records, existing header conversion, manually constructed
models, and unsupported-record serialization errors as preservation controls.
A native-only proxy with similar field names is insufficient.

Assert `==`, `eql?`, `hash`, `type_id` and `inspect` before and after scalar and
nested-array edits. Compare independently parsed equivalent records and a changed
record against the Ruby control; equal records must have equal hashes within the
same process. Compare equality outcomes across isolated backend runs, not numeric
hash values, which Ruby may randomize per process. Do not require unequal records
to have distinct hashes. Check first-access hydration and repeated access so
cached original bytes cannot conceal edits in equality, hashing or inspection.

For malformed input, compare established safe outcomes: rejection versus recovery,
public error class, error ordering and diagnostic positions, raw preservation and
trailing handling where reachable. Preserve existing messages where behavior is
intentionally equivalent. A reviewed safety delta may reject earlier with a
bounded `Emf::FormatError` rather than reproduce a dangerous allocation or
incidental BinData exception text. Every such delta needs its own manifest entry,
reason and regression; it cannot be hidden by snapshot normalization. Native
crashes, hangs, silent retry through Ruby and lost valid bytes always fail.

## Planned checks and exit gate

Run from the repository root after the named harnesses exist:

```sh
ruby script/fixture_manifest --check
EMF_BACKEND=ruby bundle exec rspec spec/emf/backend_parity_spec.rb spec/emf/round_trip_spec.rb spec/emf/visitors_spec.rb
EMF_BACKEND=native bundle exec rspec spec/emf/backend_parity_spec.rb spec/emf/round_trip_spec.rb spec/emf/visitors_spec.rb
bundle exec ruby bench/parser.rb --manifest spec/fixtures/manifest.json --backend ruby --output tmp/bench/ruby.json
EMFSVG_PATH=/path/to/emfsvg bundle exec ruby bench/emfsvg.rb --backend ruby --output tmp/bench/emfsvg-ruby.json
```

The native invocation is deferred until [the ABI](04-c-abi.md) and binding exist;
it must fail if the native library is unavailable. Baseline completion requires
manifest coverage, a saved Ruby observation for all 231 fixtures, measured stage
costs, and a reproducible downstream baseline. Resolve the wire-heavy cost and
slow-fixture uncertainties before committing to the full port estimate. The current
Ruby qualification below does not establish native parity, stage performance,
downstream equivalence or whole-phase completion.

## Current-source Ruby qualification

Source base: `0f63318655f49dcdc65756d780b94fda0e1602c0`, clean before capture.
Parser-source SHA-256:
`a9196b792eff75af9006f31f4059cd5a98012c362b266e00dd219188425aad00`.
Environment: Ruby 3.4.8, arm64-darwin25, BinData 2.5.1; forced Ruby backend.
Evidence directory: `/private/tmp/emf-execution/p02-current-head-qualification/`.
The original manifest and historical `source-stable-v3-manifest.json` are preserved;
the generated manifest is isolated evidence, not a replacement committed inventory.

The regenerated 15-second/16-KiB manifest records **219 parsed, 10 recovered,
2 format errors and no safety failures** across all 231 fixtures. Historical v3
recorded 221 parsed, six recovered, two format errors and two timeouts. Both prior
timeout fixtures now complete (one parsed, one recovered); three corrupt inputs
previously marked parsed now report recovery diagnostics. These are observed
outcome changes; successful completion does not establish why the earlier capture
timed out. All three newly recovered inputs preserve their original bytes: two
report variable-array bounds diagnostics (offsets 46984 and 103240), and one reports
a short LOGFONT body (offset 99368). `comparison.json` retains exact paths and errors.

Canonical observations cover all 231 unchanged fixture identities: **229 byte-exact
roundtrips**, each also passing reparse equality, serialized-file equality and
parse-file equality. Two corrupt fixtures explicitly raise `Emf::FormatError`:
`bad_corrupted_2014-12-02-215338.emf` has a truncated header, and
`bad_corrupted_2014-12-02-215428.emf` has an unrecognised format. These rejections
have no successful serialization/equality claim. There are no identity mismatches,
nonidentical successful serializations or safety failures. Both capture commands
and the regenerated-manifest check exited zero; stage exceptions remain recorded
as exceptions, independently of child-process success.

Exact commands are retained in `capture.sh`; `capture.rb` wraps the unchanged
harnesses solely for bounded supervision and telemetry. `preflight.json` binds the
clean source and fixture identities, `current-manifest.json` and
`current-observations.json` hold results, and `SHA256SUMS` binds retained artifacts.
The canonical artifact records the exact source revision with `lib_dirty: false`.

The exclusive capture window followed Claude's explicit timing release. Existing
harnesses ran sequential isolated children with a 1-GiB RSS ceiling; manifest
limits stayed 15 seconds/16 KiB, and canonical observations used 60 seconds/64 MiB.
A 4-GiB per-artifact file-size ceiling bounds retained output. The supervised
simple-fixture preflight measured 23,003,136 bytes peak RSS; per-child capture
telemetry records actual elapsed time, peak RSS and output bytes. The historical
manifest has no RSS measurements. Manifest peak child RSS was 133,922,816 bytes;
canonical peak child RSS was 822,804,480 bytes, maximum child output 57,794,180 bytes
and maximum elapsed time 35.10 seconds, all within declared bounds. Both captures
completed 231 children with exit zero. These supervised elapsed times are capture
telemetry, not the independently measured stage-cost benchmark. The capture window
is released. Safety-limit failures remain failures, not passes.

Native comparison remains open under the assigned build/install hold. Current-source
Ruby capture alone does not close the public mutation, final-head native, stage-cost,
slow-fixture, downstream golden or required CI acceptance criteria above.

## Current-source inventory refresh

At `6669366`, all 231 fixture identities were independently verified against the
committed inventory and on-disk SHA-256 values. The bounded Ruby capture completed
in 46.09 seconds: **219 parsed, 10 recovered, two explicit format errors**, with
zero safety failures or backend exceptions. No fixture outcome changed.
`spec/fixtures/manifest.json` now records the current parser-source digest
`116efa7477dba266e7ab396afb92c682771c5764bd5e41abb8077907cf3718d5`;
`ruby script/fixture_manifest --check` passes. This refresh establishes inventory
acceptance, not current-source canonical roundtrip or native parity acceptance.

The subsequent canonical capture at clean `67a6fc54a9f590808d79c6eaf59ab72a6e463f64`
completed in 180.27 seconds. All 231 isolated children exited normally. **229
inputs serialized byte-identically and retained identical reparsed models, file
serialization and file reparsing**; the same two malformed headers were explicit
`Emf::FormatError` rejections. All input identities matched the manifest. Child
limits were 60 seconds, 1 GiB RSS and 64 MiB output: observed maxima were
11.40 seconds, 899,809,280 bytes RSS and 57,794,180 bytes output. This qualifies
the current Ruby corpus; it does not establish full native corpus parity.
