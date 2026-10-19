# 07 — Measure and improve end-to-end performance

Status: **Not started**. Estimate: **1–2 engineering days** for harness completion and an initial measured optimization pass, after baseline and Ruby binding parity. Further optimization depends on measurements.

## Problem and evidence needed

The roughly 12-second fixture mentioned in [issue #15](https://github.com/claricle/emf/issues/15) has not been identified or reproduced. A subsecond end-to-end result is a target to verify on the identified workload, not an existing benchmark result. Rust parse time alone cannot establish it: the Ruby model, BinData wire compatibility, serialization and real downstream rendering can dominate.

`lib/emf/emr/parser.rb` constructs wire adapters and `lib/emf/model/metafile.rb` exposes the model. Consumers can inspect and mutate wire objects. Improvements must preserve those operations, byte round-trips, error/recovery behavior and downstream output. Parsanol is an architectural reference, not a dependency or a substitute benchmark.

## Proposed files

- `emf-rs/crates/emf-core/benches/parser.rs` and its `Cargo.toml` Criterion bench configuration: isolated parse/serialize kernels over manifest fixtures.
- `bench/parser.rb`: Ruby end-to-end baseline and native comparison using `spec/fixtures/manifest.json`.
- `bench/emfsvg.rb`: pinned downstream checkout/command adapter with golden-output checks.
- `bench/baseline.json`: measured workload identities, fixture hashes, environment, units and distributions; do not populate it with guessed numbers.
- `bench/performance-policy.json`: proposed selected-runner comparison policy, sample counts and explicit thresholds calibrated from repeated baseline runs.
- `.github/workflows/native-benchmark.yml`: stable benchmark job and retained JSON/report artifacts.
- Existing parity specs from [02-baseline-and-parity.md](02-baseline-and-parity.md) and binding work from [05-ruby-binding.md](05-ruby-binding.md): preservation gates for every optimization.

## Execution order and dependencies

1. First identify the reported slow file and machine/runtime. Record revision, CPU, OS/architecture/libc, Ruby/Rust versions, build profile, fixture hash/size/record count and whether file IO is timed. If unavailable, report that uncertainty and select an explicitly named representative large fixture; do not relabel it the reported 12-second case.
2. Reuse the baseline manifest and harness. Record cold library loading separately from warm calls. Measure raw native parse and serialize, C ABI transfer/access, Ruby model hydration, first and repeated wire access, dump traversal, parse-to-serialize, mutation-to-serialize and total time. Also record peak RSS and allocations where supported. Publish distributions, not just the fastest run.
3. Run the same inputs through forced Ruby and native backends, then through pinned emfsvg golden workloads. Compare exact model/bytes/error behavior and rendered golden outputs before accepting a speed claim. The downstream adapter must pin its repository revision, dependency override to this gem, executable command and golden inventory before the gate is enabled; the actual downstream command is a discovery item.
4. Profile the largest measured component. Compare eager and lazy wire materialization with real dump/mutation consumers; track first-access latency and total allocations so deferred work is not reported as eliminated work. Optimize one evidenced bottleneck at a time and rerun relevant parity plus the same benchmark workload.
5. Proposed stable job: one dedicated Linux x86_64 glibc runner class, fixed CPU allocation and pinned image/toolchains, release-mode Rust, idle-runner preflight. Choose the exact runner/image and commit its identity before gating. Other platforms get informational smoke measurements until equivalent stability is demonstrated.
6. Proposed noise policy: run five warmups and at least 20 measured samples per workload; compare medians and p95 over repeated baseline runs. Start with a 10% median regression alert; make it blocking only when it also exceeds a calibrated absolute floor and an independent rerun confirms it. Record the chosen absolute floor and observed baseline variation in `performance-policy.json`. Fail the comparison as inconclusive when runner variation exceeds the calibrated noise bound. These are proposed project gates, not additional acceptance criteria attributed to the issue.

## Planned commands

Future commands after the harness and Criterion targets exist; no benchmark was run for this plan:

```sh
cargo bench --manifest-path emf-rs/Cargo.toml -p emf-core --bench parser
bundle exec ruby bench/parser.rb --manifest spec/fixtures/manifest.json --backend ruby --output tmp/bench/ruby.json
bundle exec ruby bench/parser.rb --manifest spec/fixtures/manifest.json --backend native --output tmp/bench/native.json
EMFSVG_PATH=/path/to/emfsvg bundle exec ruby bench/emfsvg.rb --backend native --output tmp/bench/emfsvg-native.json
EMF_BACKEND=native bundle exec rspec spec/emf/backend_parity_spec.rb spec/emf/round_trip_spec.rb spec/emf/visitors_spec.rb
```

`EMFSVG_PATH` must refer to the pinned downstream checkout; run the corresponding Ruby backend workload as a control. Record command exit status and golden differences alongside timings.

## Acceptance

- A reproducible baseline identifies the slow workload or explicitly records that its identity remains unknown. Native and Ruby measurements share fixture hashes, timing boundaries and machine class.
- Kernel and Ruby end-to-end numbers include model hydration, dumping, mutable wire access/serialization and emfsvg rendering, with all compatibility/golden gates green.
- The identified slow fixture achieves the issue's under-one-second target for the agreed end-to-end boundary on the recorded machine, or the unmet target is reported as an open issue requirement with evidence and a revised optimization task.
- No optimization is accepted solely because native parsing is faster. Reports include total latency, memory, variance and any workload regression.
- The selected stable CI job, calibrated noise/absolute thresholds and baseline update procedure are explicit before enabling a blocking regression gate. Until then performance CI is informational and completion of the issue's target remains unclaimed.
