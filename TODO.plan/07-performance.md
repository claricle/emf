# 07 — Measure and improve end-to-end performance

Status: **In progress — harnesses and informational downstream comparison implemented; target acceptance remains open**. Parser stages, native adapter components, forced-backend downstream golden conversion, saved-report comparison and a bounded parser CI smoke job exist. The original downstream comparison is a concurrent two-sample correctness trial. A later paired Ruby-only consumer comparison demonstrates a 45% CPU reduction, but does not establish a calibrated performance baseline or meet the subsecond target. Further optimization and its ETA depend on the identified bottleneck and workload; the original harness estimate no longer describes completed work. See [downstream comparison evidence](../docs/performance/downstream-comparison.md).

## Problem and evidence needed

The roughly 12-second fixture mentioned in [issue #15](https://github.com/claricle/emf/issues/15) has not been identified or reproduced. A subsecond end-to-end result is a target to verify on the identified workload, not an existing benchmark result. Rust parse time alone cannot establish it: the Ruby model, BinData wire compatibility, serialization and real downstream rendering can dominate.

`lib/emf/emr/parser.rb` constructs wire adapters and `lib/emf/model/metafile.rb` exposes the model. Consumers can inspect and mutate wire objects. Improvements must preserve those operations, byte round-trips, error/recovery behavior and downstream output. Parsanol is an architectural reference, not a dependency or a substitute benchmark.

## Current workload evidence

The [recorded Ruby slow-workload baseline](../docs/performance/issue-15-slow-workload.md) covers all 208 valid fixtures at `b81d6aa`: every parse succeeded and unchanged serialization was byte-identical. Six pinned emfsvg candidates were measured against the released gem and this revision. The reported approximately 12-second case remains unidentified. The font-construction failures in that historical comparison were subsequently resolved, as recorded in the workload guide; they are not the current blocker. The guide also records a later Ruby fast-fill comparison at `228f404` against `54230f8`, with preserved downstream golden output. Its reduced sample counts and concurrent machine load make it informational rather than a calibrated baseline. The later paired comparison below supersedes these reduced-sample figures for the named Ruby consumer workload. Policy-sized distributions on a calibrated runner, final-head native comparisons and the subsecond target remain open.

Ruby implementation through `d08a9c0` additionally includes guarded BinData template copying, attribute construction, nested structure assignment and 16-/32-bit point-array paths. Focused equivalence checks accompany those changes; they do not qualify final-head end-to-end latency. The shared deadline implementation now supports an explicit bounded benchmark series, documented in [the parser harness guide](../bench/README.md), without reducing the policy sample counts. Measurements must still record the exact source and preserve the same correctness controls.

## Measured Ruby consumer result

The [slow-workload guide](../docs/performance/issue-15-slow-workload.md#final-whole-consumer-result-with-generated-construction) records three alternating fresh-process runs per revision for pinned emfsvg `test-031`, baseline `d93967d` against candidate `3108916` (integrated as `a65eac7`). Median process CPU fell from 16.59 to 9.20 seconds, about 45%; wall time fell from 17.6 to 10.4 seconds and peak RSS from 586 to 419 MiB. Emitted EMF and SVG hashes matched in every run. This is measured Ruby improvement, with concurrent machine load disclosed; it is not a final-head native comparison or the policy-sized calibrated baseline.

Generated construction over all 194,122 consumer attribute sets separately fell from 2621 to 1712 ms for construction plus writing, with zero snapshot, byte or size mismatches. That microbenchmark does not imply a further whole-consumer gain beyond the earlier text/point fast paths. A subsequent per-record parser experiment produced no material speedup and was not integrated; it is not an outstanding implementation item.

**The under-one-second end-to-end target remains unmet.** The measured consumer round trip takes 9.20 seconds of CPU; an instrumented split attributes approximately 3.7 seconds to emf and 5.4 seconds to consumer SVG work. The split is diagnostic, not a separate calibrated benchmark. The roughly 12-second input from the issue remains unidentified, and final-head native measurements remain outstanding. Preserve these limits when assessing performance acceptance.

## Implemented measurement surface

- `bench/parser.rb` and [its guide](../bench/README.md) measure format detection, public parse, first/repeated wire traversal, dump, serialization, representative EMF wire mutation/serialization, parse-to-serialize and parse-file. Unsupported mutation workloads are explicit rather than successful timings.
- The dependency-free `emf-core` native kernel CLI (`emf-rs/crates/emf-core/benches/parser.rs`, [guide](../bench/native-kernels.md)) measures isolated in-memory parse, unchanged serialize, parse/serialize and guarded typed-edit serialization. It records exact round-trip guards, input SHA-256 and median/p95 distributions; unsupported edits are explicit. Implementation is present; compilation, CLI controls and runtime measurement validation remain pending the explicit build pause. No native kernel timing result is claimed.
- `bench/native_components.rb` separates the available native adapter boundaries: parse handle, snapshot copy/decode, hydration and cleanup, with separate public parse samples. It is an EMF/EMF+ diagnostic; it does not isolate a Rust serialization kernel or support WMF.
- `bench/emfsvg.rb` and [its guide](../bench/emfsvg.md) force Ruby/native conversion against a pinned clean consumer and exact golden SVGs. Cold loading and first calls are separate from warm conversion distributions.
- `bench/compare_emfsvg.rb` validates saved downstream identities, method, samples and golden results before emitting informational native-over-Ruby ratios. See [the saved evidence and reproduction commands](../docs/performance/downstream-comparison.md).
- `.github/workflows/parser-benchmark.yml` builds a locked release native library and retains schema-v2 input manifest plus forced Ruby/native reports for `simple/image1.emf`; it uses bounded children and three samples after one warmup. Its floating Ubuntu/Ruby/Rust setup is a smoke environment, not the dedicated calibrated runner proposed below.
- Focused coverage lives under `spec/bench/`, with wire/model and downstream golden preservation checks accompanying optimizations.

The tracked [performance policy](../bench/performance-policy.json) exists in informational mode: five warmups, at least 20 samples and two baseline runs, median/p95 statistics, and a 10% alert ratio. Runner identity, absolute floors and noise bounds remain unset. A controlled, representative `bench/baseline.json` and a calibrated pinned-runner regression gate remain outstanding; neither is established by the smoke workflow. The isolated native kernel target uses the standard library rather than adding Criterion dependencies.

## Execution order and dependencies

1. First identify the reported slow file and machine/runtime. Record revision, CPU, OS/architecture/libc, Ruby/Rust versions, build profile, fixture hash/size/record count and whether file IO is timed. If unavailable, report that uncertainty and select an explicitly named representative large fixture; do not relabel it the reported 12-second case.
2. Reuse the manifest and implemented harnesses above, refreshing the manifest source digest for the measured revision. Record cold library loading separately from warm calls. Measure raw native parse and serialize, C ABI transfer/access, Ruby model hydration, first and repeated wire access, dump traversal, parse-to-serialize, mutation-to-serialize and total time. Also record peak RSS and allocations where supported. Publish distributions, not just the fastest run.
3. Run the same inputs through forced Ruby and native backends, then through pinned emfsvg golden workloads. Compare exact model/bytes/error behavior and rendered golden outputs before accepting a speed claim. The implemented downstream adapter records the pinned repository revision, dependency override to this gem, executable command and golden inventory. Use its documented command; broader workloads and a controlled gate remain to be measured.
4. Profile the largest measured component. Compare eager and lazy wire materialization with real dump/mutation consumers; track first-access latency and total allocations so deferred work is not reported as eliminated work. Optimize one evidenced bottleneck at a time and rerun relevant parity plus the same benchmark workload.
5. Proposed stable job: one dedicated Linux x86_64 glibc runner class, fixed CPU allocation and pinned image/toolchains, release-mode Rust, idle-runner preflight. Choose the exact runner/image and commit its identity before gating. Other platforms get informational smoke measurements until equivalent stability is demonstrated.
6. Proposed noise policy: run five warmups and at least 20 measured samples per workload; compare medians and p95 over repeated baseline runs. Start with a 10% median regression alert; make it blocking only when it also exceeds a calibrated absolute floor and an independent rerun confirms it. Record the chosen absolute floor and observed baseline variation in `performance-policy.json`. Fail the comparison as inconclusive when runner variation exceeds the calibrated noise bound. These are proposed project gates, not additional acceptance criteria attributed to the issue.

## Available commands and remaining measurements

Current harness commands, after provisioning the pinned consumer/runtime gems and a native library; choose the child RSS bound from the target runner and ensure the input manifest matches the measured parser source:

```sh
mkdir -p tmp/bench
bundle exec ruby bench/parser.rb --manifest spec/fixtures/manifest.json --backend ruby --rss-limit-mb 2048 --output tmp/bench/ruby.json
EMF_NATIVE_LIBRARY=/path/to/libemf_ffi.dylib bundle exec ruby bench/parser.rb --manifest spec/fixtures/manifest.json --backend native --rss-limit-mb 2048 --output tmp/bench/native.json
EMF_NATIVE_LIBRARY=/path/to/libemf_ffi.dylib bundle exec ruby bench/native_components.rb --manifest spec/fixtures/manifest.json --fixture spec/fixtures/simple/image1.emf --rss-limit-mb 2048 --output tmp/bench/components.json
EMFSVG_PATH=/path/to/emfsvg bundle exec ruby bench/emfsvg.rb --manifest spec/fixtures/manifest.json --backend ruby --rss-limit-mb 2048 --output tmp/bench/emfsvg-ruby.json
EMFSVG_PATH=/path/to/emfsvg EMF_NATIVE_LIBRARY=/path/to/libemf_ffi.dylib bundle exec ruby bench/emfsvg.rb --manifest spec/fixtures/manifest.json --backend native --rss-limit-mb 2048 --output tmp/bench/emfsvg-native.json
bundle exec ruby bench/compare_emfsvg.rb --ruby tmp/bench/emfsvg-ruby.json --native tmp/bench/emfsvg-native.json --output tmp/bench/emfsvg-comparison.json
```

Run measurements sequentially on an otherwise idle recorded runner for performance conclusions. The default consumer pin is `101356dcf673841fda0693076131bca7a0f34948`; exact golden checks and command exit status accompany timings. The saved historical smoke reports can be compared without rerendering, as documented in the evidence guide. The native kernel command and timing boundaries are documented in [the kernel guide](../bench/native-kernels.md); a development-profile smoke would verify execution only and would not establish release performance.

## Acceptance

- A reproducible baseline identifies the slow workload or explicitly records that its identity remains unknown. Native and Ruby measurements share fixture hashes, timing boundaries and machine class.
- Kernel and Ruby end-to-end numbers include model hydration, dumping, mutable wire access/serialization and emfsvg rendering, with all compatibility/golden gates green.
- The identified slow fixture achieves the issue's under-one-second target for the agreed end-to-end boundary on the recorded machine, or the unmet target is reported as an open issue requirement with evidence and a revised optimization task.
- No optimization is accepted solely because native parsing is faster. Reports include total latency, memory, variance and any workload regression.
- The selected stable CI job, calibrated noise/absolute thresholds and baseline update procedure are explicit before enabling a blocking regression gate. Until then performance CI is informational and completion of the issue's target remains unclaimed.

## Current representative conversion measurement

Five measured conversions after one warmup on `test031`, using current production
source at `6669366` and pinned emfsvg `101356dc`, retained identical SVG goldens.
Forced Ruby medians were 1.729715 seconds from bytes and 1.696344 seconds from file;
forced native medians were 2.279385 and 2.274567 seconds respectively. The retained
`d3588c5` native library is a **debug build**. These raw observations demonstrate
neither release-mode speedup nor the requested subsecond outcome. They are not
an accepted performance-policy baseline: the reports used the stale manifest
fingerprint, and the native report includes documentation-only working-tree
changes. The original reported twelve-second workload remains unidentified.
