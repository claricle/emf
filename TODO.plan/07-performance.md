# 07 — Measure and improve end-to-end performance

Status: **In progress — harnesses and informational downstream comparison implemented; target acceptance remains open**. Parser stages, native adapter components, forced-backend downstream golden conversion, saved-report comparison and a bounded parser CI smoke job exist. Existing downstream evidence is a concurrent two-sample correctness trial, not a calibrated performance baseline. Further optimization and its ETA depend on the identified bottleneck and workload; the original harness estimate no longer describes completed work. See [downstream comparison evidence](../docs/performance/downstream-comparison.md).

## Problem and evidence needed

The roughly 12-second fixture mentioned in [issue #15](https://github.com/claricle/emf/issues/15) has not been identified or reproduced. A subsecond end-to-end result is a target to verify on the identified workload, not an existing benchmark result. Rust parse time alone cannot establish it: the Ruby model, BinData wire compatibility, serialization and real downstream rendering can dominate.

`lib/emf/emr/parser.rb` constructs wire adapters and `lib/emf/model/metafile.rb` exposes the model. Consumers can inspect and mutate wire objects. Improvements must preserve those operations, byte round-trips, error/recovery behavior and downstream output. Parsanol is an architectural reference, not a dependency or a substitute benchmark.

## Implemented measurement surface

- `bench/parser.rb` and [its guide](../bench/README.md) measure format detection, public parse, first/repeated wire traversal, dump, serialization, representative EMF wire mutation/serialization, parse-to-serialize and parse-file. Unsupported mutation workloads are explicit rather than successful timings.
- `bench/native_components.rb` separates the available native adapter boundaries: parse handle, snapshot copy/decode, hydration and cleanup, with separate public parse samples. It is an EMF/EMF+ diagnostic; it does not isolate a Rust serialization kernel or support WMF.
- `bench/emfsvg.rb` and [its guide](../bench/emfsvg.md) force Ruby/native conversion against a pinned clean consumer and exact golden SVGs. Cold loading and first calls are separate from warm conversion distributions.
- `bench/compare_emfsvg.rb` validates saved downstream identities, method, samples and golden results before emitting informational native-over-Ruby ratios. See [the saved evidence and reproduction commands](../docs/performance/downstream-comparison.md).
- `.github/workflows/parser-benchmark.yml` builds a locked release native library and retains schema-v2 input manifest plus forced Ruby/native reports for `simple/image1.emf`; it uses bounded children and three samples after one warmup. Its floating Ubuntu/Ruby/Rust setup is a smoke environment, not the dedicated calibrated runner proposed below.
- Focused coverage lives under `spec/bench/`, with wire/model and downstream golden preservation checks accompanying optimizations.

Still proposed: isolated Criterion parse/serialize kernels at `emf-rs/crates/emf-core/benches/parser.rs`; a controlled, representative `bench/baseline.json`; calibrated `bench/performance-policy.json`; and a pinned runner regression gate. These artifacts are not present and must not be inferred from the smoke workflow.

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

Run measurements sequentially on an otherwise idle recorded runner for performance conclusions. The default consumer pin is `101356dcf673841fda0693076131bca7a0f34948`; exact golden checks and command exit status accompany timings. The saved historical smoke reports can be compared without rerendering, as documented in the evidence guide. Criterion commands remain unavailable until their proposed target is implemented.

## Acceptance

- A reproducible baseline identifies the slow workload or explicitly records that its identity remains unknown. Native and Ruby measurements share fixture hashes, timing boundaries and machine class.
- Kernel and Ruby end-to-end numbers include model hydration, dumping, mutable wire access/serialization and emfsvg rendering, with all compatibility/golden gates green.
- The identified slow fixture achieves the issue's under-one-second target for the agreed end-to-end boundary on the recorded machine, or the unmet target is reported as an open issue requirement with evidence and a revised optimization task.
- No optimization is accepted solely because native parsing is faster. Reports include total latency, memory, variance and any workload regression.
- The selected stable CI job, calibrated noise/absolute thresholds and baseline update procedure are explicit before enabling a blocking regression gate. Until then performance CI is informational and completion of the issue's target remains unclaimed.
