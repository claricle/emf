# 02 — Baseline and parity

Status: **Not started**. Estimate: **2–3 engineering days**, revised after the
fixture inventory and downstream checkout are available. This phase is the first
executable milestone; it does not require Rust.

Depends on [requirements](01-requirements.md). Supplies acceptance data to
[the core](../TODO.rust/03-rust-core.md), [binding](../TODO.ruby/05-ruby-binding.md),
[resilience](../TODO.delivery/06-resilience.md), and [performance](../TODO.delivery/07-performance.md).
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
is not a fixture. The manifest must verify these counts against the checkout,
record repository-relative path, SHA-256, byte size, expected detected format,
and observed outcome (`parsed`, `recovered`, or `format_error`). Record backend
exceptions and reviewed safety deviations separately rather than declaring every
corrupt fixture an unconditional byte-round-trip target. Existing RSpec fixture
paths remain valid. Later WMF/EMF+ cases extend this schema under
[format extension](../TODO.formats/09-format-extension.md).

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

The native invocation is deferred until [the ABI](../TODO.rust/04-c-abi.md) and binding exist;
it must fail if the native library is unavailable. Baseline completion requires
manifest coverage, a saved Ruby observation for all 229 fixtures, measured stage
costs, and a reproducible downstream baseline. Resolve the wire-heavy cost and
slow-fixture uncertainties before committing to the full port estimate. No
benchmark or parity result is claimed by this planning document.
