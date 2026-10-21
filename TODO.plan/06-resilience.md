# 06 — Bound corrupt-input handling and fuzz native entry points

Status: **In progress**. Core budgets, subprocess supervision, corrupt-corpus CI and three instrumented fuzz targets are implemented. Platform-specific resilience certification remains open. The original **2–3 engineering days** estimate describes implementation scope, not remaining time; ongoing fuzz execution is separate.

## Problem and current evidence

`spec/emf/corrupted_resilience_spec.rb` permits parsing, recovery with errors, or `Emf::FormatError`, and uses Ruby `Timeout.timeout(60)`. That cannot reliably interrupt a blocked native call. `lib/emf/emr/parser.rb` rejects input above 200 MiB and limits selected variable arrays to 1,000,000 entries; these are compatibility facts, not proof that every allocation or loop is bounded. In particular, `spec/fixtures/emf-corrupted/bad_corrupted_2014-12-09-002112.emf` needs an explicit native regression.

The shared `spec/fixtures/manifest.json` must reference the original 208 valid and 21 corrupt EMF files. The corrupted directory has 22 files including its README; only 21 are EMF seeds. Do not move fixtures or count that README as input. Additional synthetic/minimized inputs must record provenance and expected outcomes.

## Implemented files

- `emf-rs/crates/emf-core/src/limits.rs`: parser/serializer resource budgets and deterministic resource-limit errors.
- `emf-rs/crates/emf-core/tests/resilience.rs`: arithmetic, budget and recovery regressions.
- `emf-rs/crates/emf-ffi/tests/abi.c`: panic/error/ownership and post-failure handle regressions alongside the C ABI tests.
- `emf-rs/fuzz/Cargo.toml`, `emf-rs/fuzz/fuzz_targets/parse.rs`, `serialize.rs`, `ffi.rs`: separate fuzz entry points.
- `emf-rs/fuzz/seeds.json`: manifest of original fixture paths, hashes, target eligibility and minimized regression seeds; do not duplicate the entire fixture tree.
- `script/native_resilience`, `spec/emf/native_resilience_spec.rb`: subprocess supervision and Ruby-visible outcome checks.
- `.github/workflows/native-fuzz.yml`: bounded change/scheduled/manual fuzz jobs and failure-artifact retention.
- `.github/workflows/native-resilience.yml`: forced-native original corrupt-corpus supervision on Ubuntu and Windows supervisor runtime checks on x64/ARM runners. New minimized regressions must retain provenance and licensing.

## Execution order and dependencies

1. Depend on [02-baseline-and-parity.md](02-baseline-and-parity.md) for the outcome manifest and [03-rust-core.md](03-rust-core.md) for checked reads. Preserve established error class/message, offsets, raw records, recovered records and trailing bytes wherever the baseline defines them. Explicit resource-limit failures need documented Ruby mapping rather than an unrelated exception or a partial success claim.
2. Give parse and serialize a shared budget: checked offset/length/count multiplication and addition before slicing or allocating; monotonic cursor progress; bounded record count, nested depth, array entries, cumulative decoded allocation and output growth; fuel charged for loops and expanded work. Specify defaults, units and boundary tests in `limits.rs` before tuning. Retain current Ruby input/count behavior unless an intentional compatibility change is separately accepted. Never rely on an allocator abort being catchable.
3. Apply the same limits through [04-c-abi.md](04-c-abi.md), including output buffers and accessor copies. Every public ABI call contains recoverable panics; invalid input returns the specified status. Test failure followed by a valid parse and handle access/free. A rejected operation must not poison a reusable handle or free another caller's allocation. Test valid lifecycle sequences and null/length boundary cases; do not claim arbitrary dangling pointers can be validated safely.
4. Run each corrupt fixture in a child process using forced native selection. The supervisor must enforce a wall deadline of at most 60 seconds per fixture and an explicit RSS ceiling, terminate/kill and reap stalled children, and record exit status, elapsed time, peak RSS and semantic outcome. Choose and commit the RSS ceiling after measuring the valid corpus on supported runners. Use OS process/job controls or sampled RSS supervision on each supported platform. Include a deliberately stalled helper and excessive-memory helper to prove the supervisor fails. A Ruby timeout around Fiddle is insufficient; internal deterministic budgets and external process deadlines serve different purposes.
5. Seed all 229 existing EMF fixtures through the seed manifest. Fuzz parsing arbitrary bytes, parse/serialize/reparse, and valid C ABI lifecycle sequences with malformed payloads. Compare parse outcomes/model/bytes where the baseline defines a stable oracle. Add mutations for zero-size records, truncated headers, extreme counts, offset overflow, overlapping ranges, embedded comments and large output requests. Add WMF/EMF+ seeds as [09-format-extension.md](09-format-extension.md) lands.
6. Proposed execution policy: a short fixed-seed smoke job on changes; nightly/manual 30-minute runs per target with recorded toolchain, seed and budget. Retain crash artifacts as CI artifacts, minimize failures, then commit only a public-safe licensed regression plus deterministic test. A finite clean fuzz run is evidence for that budget, not proof of absence of defects.

## Implemented commands

Run from the repository root with the declared native library/toolchain available. These commands describe reproducible checks; execution evidence is distinguished below:

```sh
cargo test --manifest-path emf-rs/Cargo.toml -p emf-core --test resilience
bundle exec ruby script/native_resilience --manifest spec/fixtures/manifest.json --backend native --scope corrupted --wall-seconds 60 --rss-limit-mb 1024 --report tmp/native-resilience.json
EMF_BACKEND=native bundle exec rspec spec/emf/native_resilience_spec.rb spec/emf/corrupted_resilience_spec.rb
python3 -m unittest discover -s emf-rs/fuzz/tests -p 'test_*.py'
python3 emf-rs/fuzz/seeds.py --corpus emf-rs/fuzz/corpus
# Install cargo-fuzz 0.12.0 with nightly-2025-04-01 as documented in emf-rs/fuzz/README.md.
(cd emf-rs && cargo +nightly-2025-04-01 fuzz build --fuzz-dir fuzz parse)
RUSTUP_TOOLCHAIN=nightly-2025-04-01 python3 emf-rs/fuzz/run.py parse --seconds 30
# Repeat build/run for serialize and ffi.
```

The runner must refuse to execute until its recorded RSS limit is configured. Pin the nightly/fuzzer versions in CI and report the actual seed count and elapsed fuzz time.

## Current implementation and evidence

`ParseLimits` defaults in `limits.rs` cap input at 200 MiB, a record at
128 MiB, record count at 4,000,000, accounted allocation at 640 MiB and work
at 64 Mi units. Serialization defaults cap output at 200 MiB and work at
64 Mi units. Accounted allocation is an internal budget, not a physical RSS
guarantee or a guarantee that allocator aborts are recoverable.

The supervisor requires an explicit RSS limit and a wall deadline in 1–60
seconds. Its checks cover timeout/RSS enforcement, termination and reaping,
monitor failures, expected semantic outcomes, unchanged fixture hashes and
serialize/reparse/reserialize byte identity for successful parses. A native
availability failure cannot pass by falling back to Ruby. Focused runner
verification passed 32 examples with one optional real-corpus example pending;
that pending example is not corpus execution evidence.

[PR #33](https://github.com/claricle/emf/pull/33) head `9a51cfa` passed
the **Forced native corrupt corpus** CI check on Ubuntu: all original 21
corrupt fixtures ran with 60-second per-fixture deadlines and a 1024 MiB
RSS ceiling. This is Linux evidence under the workflow's declared limits,
not per-platform calibration or a promise about all possible inputs. The
named `bad_corrupted_2014-12-09-002112.emf` remains in the original manifest.
The workflow always retains its report and log for 14 days.

At the same head all three instrumented fuzz smoke CI checks passed. The
workflow pins nightly `2025-04-01` and cargo-fuzz `0.12.0`; each target runs
30 seconds on changes or 1800 seconds on scheduled/manual execution with
seed 12345, a 10-second input timeout, 2048 MiB RSS limit, 512 MiB allocation
limit and 8 MiB generated-input limit. The seed manifest currently contains
253 entries, including all 229 original EMF fixtures and additional WMF /
synthetic format boundaries. Hash validation and target eligibility precede
execution. Actual reports retain toolchain, seed count, elapsed time and exit
status; finite clean smoke runs establish only their executed budgets.

Remaining acceptance includes equivalent supervised evidence on each delivered
platform, supported-runner RSS calibration using the valid corpus, longer
scheduled budgets, and complete allocation/work boundary coverage across the
implemented record/accessor paths. Native C lifetime controls are tracked in
[04](04-c-abi.md). Do not infer whole-phase completion from Linux smoke checks.

### Windows supervision implementation and demonstrated runtime acceptance

`spec/support/process_supervisor.rb` selects the Windows implementation in
`spec/support/windows_process_supervisor.rb` through the existing public API.
It creates a suspended child, assigns a kill-on-close Windows Job Object before
resuming, samples aggregate working-set RSS across job members, bounds captured
output and terminates/reaps the job on completion or failure. Failed monitoring
or cleanup cannot produce success. RSS remains sampled rather than an
allocator-level hard limit.

The affected POSIX and Windows contract specs passed together on macOS Ruby
3.4.8: **33 examples, 0 failures** (seed 35583). The Windows adapter's three
changed Ruby files passed RuboCop. These checks establish contract behavior and
preservation of POSIX supervision, not Windows ABI or runtime acceptance.
The workflow now runs `spec/scripts/windows_process_supervisor_spec.rb` on
`windows-2025` and `windows-11-arm`. At source revision
`29858fc0065399e1766dfe33f6b988878fbebd8e`, both real runners passed **32 examples,
0 failures**, including deadline/RSS/output enforcement and descendant cleanup:
[Windows x64 job](https://github.com/claricle/emf/actions/runs/39583032372/job/119165030525)
and [Windows ARM64 job](https://github.com/claricle/emf/actions/runs/39583032372/job/119165030936).
This demonstrates the supervision contract on those runners at that revision.
Supported-platform valid-corpus RSS calibration, installed native qualification
and the remaining resilience acceptance above remain **OPEN**; these runner
results do not certify those separate criteria.

### Additional bounded WMF malformed-input evidence

`spec/emf/native_wmf_resilience_seeds_spec.rb` pins eight generated malformed
WMF seeds (`header-size`, `file-size`, `max-record`, `zero-record`,
`missing-eof`, `negative-text-count`, `placeable-checksum`, and
`bitmap-short-record`) as rejected outcomes. With Ruby parser fallback forbidden,
the forced-native check rejected all eight and then parsed/serialized valid
generated input with exact byte preservation: 2 examples, 0 failures (seed
11231), using the retained Apple Silicon library with SHA-256
`a167eae1e2ed3ebeaa7066b8ea870508185a9304416e4f8740e8ea4f5fb67ef3`.
This is a finite seed check on a retained artifact, not final-head, full-corpus,
fuzz-budget or per-platform resilience certification. The log was not retained;
the command and verdict are recorded in
`/private/tmp/emf-execution/native-corpus-parity-handoff.md`.

## Acceptance

- All 21 corrupt fixtures terminate within supervised limits, including the named pathological file; exact baseline outcomes or explicitly documented resource-limit outcomes are asserted.
- Boundary tests demonstrate rejected arithmetic overflow and allocation/fuel exhaustion without unchecked allocations, process aborts or lost ownership. Valid controls still parse, mutate and serialize correctly.
- Supervisor tests demonstrate wall/RSS enforcement and child cleanup. No success can be recorded for a killed or timed-out process.
- All fuzz targets build and execute their declared smoke budgets with the seed manifest checked; every discovered failure blocks the affected entry point until minimized and fixed.
- Resilience evidence is collected independently for each delivered platform in [08-platform-delivery.md](08-platform-delivery.md); unsupported supervision or OOM behavior remains an explicit delivery gap.

### Region allocation recovery — 2026-10-21

Malformed region records 71–75 now validate their declared region byte length
against the enclosing record before typed decoding. RegionData validates the
rectangle count against that bounded length before BinData creates array entries.
This closes the observed 83-byte PaintRgn allocation reproducer, including its
oversized nested byte-length declaration. Invalid records remain Raw with a
ParseError, preserve all input bytes, and allow subsequent records to parse.

Focused verification: 18 examples, zero failures (seed 48328), including the
original reproducer, oversized byte lengths for all five types, oversized counts,
valid region layouts and truncated-tail preservation. This is one resilience
criterion; it does not complete fuzz, whole-corpus or whole-issue qualification.
Evidence: `/private/tmp/emf-execution/p06-region-allocation-bound/checks.log`.

### Incomplete terminal record headers

Source `6669366b4946c825b40e0b514a3b7cb5ad59571e` also preserves terminal
record headers of one through seven bytes. Each incomplete header produces an
explicit ParseError and remains in trailing bytes, preserving exact serialization
and the preceding complete record. Previously these inputs raised from parsing.
Seven regression cases failed before the correction; the composed truncated-tail,
region-allocation and region-wire checks passed **25 examples, zero failures**
(seed 48328). Both changed Ruby files passed RuboCop. Evidence:
`/private/tmp/emf-execution/p06-region-allocation-bound/short-tail-result.json`.
This closes the witnessed short-header defect, not whole-corpus or fuzz acceptance.
