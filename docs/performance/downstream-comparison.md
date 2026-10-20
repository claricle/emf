# Downstream performance acceptance evidence

The saved forced Ruby/native conversion reports pass the current comparator with
an **informational** verdict. They establish exact golden output for one input
and exercise the reporting path. Two concurrent samples without warmups do not
establish a controlled speed comparison or the under-one-second requirement in
issue #15. The reported roughly 12-second workload remains unidentified.

## Saved inputs and provenance

The original reports are local execution artifacts, not checked-in baselines:
`/private/tmp/emf-execution/downstream-native/{ruby,native}.json` and
`input-manifest.json`. They were generated at `2026-10-20T09:47:58Z`.
Retain these files with their hashes when sharing the result; the commands below
need the saved files or equivalent newly captured reports.

| Artifact | SHA-256 |
| --- | --- |
| `ruby.json` | `a4607185feab3da0c05b9e79485ba0507c264ea0696a9a618ad5e6c37d8fb5dd` |
| `native.json` | `370e91d65bd85dbb92ea19a476eccd9c5c02666e5b409575afad7248085e0bb2` |
| `input-manifest.json` (schema 2) | `23e184683d0e26a8f34251ea60b3a944ea3f4f7fe8d8499e2ea5d3068b8089bb` |

Both reports record parser checkout revision
`eeef5973696017e666f40163d6cc405054af7046` with tracked benchmark edits.
Those edits were subsequently delivered in
`43daec2d75a65a9f8febded9d4ee83b6cbfd22b4`; the measurements are historical,
not measurements of the current branch. Both the loaded parser-source digest
and manifest parser-source digest are
`97329cec4f1313eb5875ae17b1f41945763087d29c0d5f0cebbcb8db57e38fc3`.
The loaded parser path is `/private/tmp/emf-benchmark-mutation/lib/emf.rb`.

The consumer checkout `/private/tmp/emfsvg-issue15-baseline` was clean at
`101356dcf673841fda0693076131bca7a0f34948`, with this gem supplied through
`/private/tmp/emf-benchmark-mutation/lib`. Its source digest is
`3132e11eb58c873f9d7e6912b4efe62f5364142b984fac5984ba8c30824a5aba`;
`spec/golden_spec.rb` has digest
`d3796af97ca1e7645099706cd3ef0ab0450d2ae1aaca5801017f5a07b69ae0bf`.

The selected native library was
`/private/tmp/emf-pr-bitmap-core/emf-rs/target/debug/libemf_ffi.dylib`,
1,166,512 bytes, SHA-256
`d8525c4648f14efbc943b9c90e5a3fa9c26c586a77dc53f2a8d2a8bf607c3e8a`.
Its build profile and Rust compiler are unknown; the path does not prove either.
The runtime was Ruby 3.4.8 on arm64 Darwin 25.5.0, eight reported CPUs,
BinData 2.5.1 and Bundler 4.0.17. CPU model is null. Reports retain exact Ruby,
OS and loaded worker gem metadata; native workers additionally load Fiddle 1.1.8.

## Workload and golden verdict

Both backends selected only `spec/fixtures/simple/image1.emf`: 92,904 bytes,
SHA-256 `64f44502f49ad9bc40cc9bb3061b0e7697cbd8f382ec1dbc92a2dcc5db53bdc0`,
manifest outcome `parsed`. Both commands exited 0 with one fixture and no failures.
Warm and cold results matched the pinned `spec/fixtures/golden/image1.svg`
exactly: 39,849 bytes, SHA-256
`2884a0704c041c725f2db0b7d888e1d751f339a129d085cc79164a1c4b6a74e1`.
This is EMF-to-SVG evidence for that fixture, not full consumer round-trip or
whole-corpus performance acceptance.

## Timing boundaries and observed distributions

Each stage has two measured samples, zero discarded warmups and one separate
cold process; fixture children had a 60-second deadline. These historical reports
predate the required RSS-ceiling option in the current harness and do not record
an enforced RSS ceiling. Their RSS observations are null. Run the current harness
with an explicit ceiling when collecting new evidence.

`from_bytes` times parsing plus SVG rendering with the input bytes already read.
`from_file` includes file reading, parsing and rendering. The native timed region
includes backend selection/loading, Rust parse, ABI snapshot transfer and Ruby
model/wire hydration. These components are inseparable in this downstream report.
Monotonic nanoseconds are used. Forced GC and exact golden comparison are outside
the timer; GC remains enabled during conversion.

The table converts raw nanoseconds to milliseconds without dropping either sample.
With two samples the recorded nearest-rank p95 equals the maximum; it is not a
stable tail-latency estimate.

| Backend / stage | Samples (ms) | Median (ms) | p95 (ms) | Median Ruby objects |
| --- | --- | --- | --- | --- |
| Ruby / `from_bytes` | 1253.925, 1452.356 | 1353.1405 | 1452.356 | 590,513 |
| Native / `from_bytes` | 1457.206, 1120.180 | 1288.693 | 1457.206 | 670,524 |
| Ruby / `from_file` | 1032.089, 920.007 | 976.048 | 1032.089 | 590,516 |
| Native / `from_file` | 1115.150, 734.238 | 924.694 | 1115.150 | 670,528 |

Native-over-Ruby median time ratios are `0.9523719082` (`from_bytes`) and
`0.9473857843` (`from_file`). Ruby object ratios are `1.1354940535` and
`1.1354950586`, respectively. These ratios describe concurrent smoke reports;
they support no calibrated speedup or regression verdict. Object counts exclude
Rust allocations and are neither total allocation nor memory consumption.

| Backend | Cold require (ms) | First `from_bytes` (ms) | Following first `from_file` (ms) |
| --- | --- | --- | --- |
| Ruby | 1374.325 | 2136.005 | 364.187 |
| Native | 759.697 | 2197.485 | 538.879 |

Each cold child loads emfsvg and then calls the two conversion APIs in order.
The second call shares that process and its earlier loading; the three values
are separate regions, not independent fresh-process conversion measurements.

## Reproduce comparison and collect new evidence

Comparing the unchanged saved files needs no consumer checkout, native library
or rendering job. Run from this repository:

```sh
mkdir -p tmp/bench
bundle exec ruby bench/compare_emfsvg.rb \
  --ruby /private/tmp/emf-execution/downstream-native/ruby.json \
  --native /private/tmp/emf-execution/downstream-native/native.json \
  --output tmp/bench/saved-emfsvg-comparison.json
```

The expected exit status is 0 and output `status` is `informational`. Source
report SHA-256 values are retained in `reports`; per-stage raw medians and
native-over-Ruby time/object ratios are in `fixtures[].stages`. Historical CLI
controls also rejected a mismatched manifest and an output alias of an input
with exit 2, preserving both inputs. Focused comparator acceptance coverage is in
`spec/bench/emfsvg_comparison_spec.rb`.

For a new measurement, use a manifest whose parser-source digest matches the
revision being measured. The [parser guide](../../bench/README.md) includes
bounded manifest capture. Provision the clean pinned consumer, reported runtime
gems and fonts, and an explicitly identified native library. Create the output
directory and run the following commands **sequentially**, on an otherwise idle
recorded machine. The 2048 MiB bound is the existing CI smoke bound; select and
record a suitable bound for a different runner.

```sh
mkdir -p tmp/bench
EMFSVG_PATH=/path/to/emfsvg bundle exec ruby bench/emfsvg.rb \
  --manifest /path/to/current-manifest.json --backend ruby \
  --fixture spec/fixtures/simple/image1.emf --iterations 20 --warmups 5 \
  --cold-runs 3 --timeout 60 --rss-limit-mb 2048 \
  --output tmp/bench/emfsvg-ruby.json
EMFSVG_PATH=/path/to/emfsvg EMF_NATIVE_LIBRARY=/path/to/libemf_ffi.dylib \
  bundle exec ruby bench/emfsvg.rb \
  --manifest /path/to/current-manifest.json --backend native \
  --fixture spec/fixtures/simple/image1.emf --iterations 20 --warmups 5 \
  --cold-runs 3 --timeout 60 --rss-limit-mb 2048 \
  --output tmp/bench/emfsvg-native.json
bundle exec ruby bench/compare_emfsvg.rb \
  --ruby tmp/bench/emfsvg-ruby.json --native tmp/bench/emfsvg-native.json \
  --output tmp/bench/emfsvg-comparison.json
```

Retain commands, exit statuses, reports, manifest and library/build identities.
A timed-out or failed fixture is a failed measurement, not accepted partial timing.
See the [downstream guide](../../bench/emfsvg.md) for consumer pinning and separate
consumer specs. Reported runtime gems do not establish gemspec constraint
resolution; fonts and external font lookup remain reproduction dependencies.

## Remaining acceptance work

Identify the issue's slow workload and end-to-end boundary, or explicitly select
a named representative large fixture without calling it the reported case.
Measure controlled Ruby/native distributions, total latency, memory and regression
workloads; profile the largest component and preserve models, wire edits, bytes,
errors and downstream goldens when optimizing. Revalidate against the optimized
revision rather than transferring these historical numbers to it.

The parser benchmark CI job is a bounded informational smoke measurement. A
pinned runner, repeated baseline variation, calibrated relative and absolute
thresholds, and an update policy remain open before a blocking performance gate.
Neither these reports nor a median below one second for this different fixture
satisfies issue #15's unidentified-workload target. Track the full requirements
in [P07](../../TODO.plan/07-performance.md).
