# 06 — Bound corrupt-input handling and fuzz native entry points

Status: **Not started**. Estimate: **2–3 engineering days**, after the baseline, core reader, C ABI and Ruby backend selection exist. Ongoing fuzz execution is separate from implementation time.

## Problem and current evidence

`spec/emf/corrupted_resilience_spec.rb` permits parsing, recovery with errors, or `Emf::FormatError`, and uses Ruby `Timeout.timeout(60)`. That cannot reliably interrupt a blocked native call. `lib/emf/emr/parser.rb` rejects input above 200 MiB and limits selected variable arrays to 1,000,000 entries; these are compatibility facts, not proof that every allocation or loop is bounded. In particular, `spec/fixtures/emf-corrupted/bad_corrupted_2014-12-09-002112.emf` needs an explicit native regression.

The shared `spec/fixtures/manifest.json` must reference the original 208 valid and 21 corrupt EMF files. The corrupted directory has 22 files including its README; only 21 are EMF seeds. Do not move fixtures or count that README as input. Additional synthetic/minimized inputs must record provenance and expected outcomes.

## Proposed files

- `emf-rs/crates/emf-core/src/limits.rs`: parser/serializer resource budgets and deterministic resource-limit errors.
- `emf-rs/crates/emf-core/tests/resilience.rs`: arithmetic, budget and recovery regressions.
- `emf-rs/crates/emf-ffi/tests/abi.c`: panic/error/ownership and post-failure handle regressions alongside the C ABI tests.
- `emf-rs/fuzz/Cargo.toml`, `emf-rs/fuzz/fuzz_targets/parse.rs`, `serialize.rs`, `ffi.rs`: separate fuzz entry points.
- `emf-rs/fuzz/seeds.json`: manifest of original fixture paths, hashes, target eligibility and minimized regression seeds; do not duplicate the entire fixture tree.
- `script/native_resilience`, `spec/emf/native_resilience_spec.rb`: subprocess supervision and Ruby-visible outcome checks.
- `.github/workflows/native-fuzz.yml`: bounded scheduled/manual fuzz jobs and failure-artifact retention; `spec/fixtures/regressions/` holds only licensed, minimized regression inputs.

## Execution order and dependencies

1. Depend on [02-baseline-and-parity.md](02-baseline-and-parity.md) for the outcome manifest and [03-rust-core.md](03-rust-core.md) for checked reads. Preserve established error class/message, offsets, raw records, recovered records and trailing bytes wherever the baseline defines them. Explicit resource-limit failures need documented Ruby mapping rather than an unrelated exception or a partial success claim.
2. Give parse and serialize a shared budget: checked offset/length/count multiplication and addition before slicing or allocating; monotonic cursor progress; bounded record count, nested depth, array entries, cumulative decoded allocation and output growth; fuel charged for loops and expanded work. Specify defaults, units and boundary tests in `limits.rs` before tuning. Retain current Ruby input/count behavior unless an intentional compatibility change is separately accepted. Never rely on an allocator abort being catchable.
3. Apply the same limits through [04-c-abi.md](04-c-abi.md), including output buffers and accessor copies. Every public ABI call contains recoverable panics; invalid input returns the specified status. Test failure followed by a valid parse and handle access/free. A rejected operation must not poison a reusable handle or free another caller's allocation. Test valid lifecycle sequences and null/length boundary cases; do not claim arbitrary dangling pointers can be validated safely.
4. Run each corrupt fixture in a child process using forced native selection. The supervisor must enforce a wall deadline of at most 60 seconds per fixture and an explicit RSS ceiling, terminate/kill and reap stalled children, and record exit status, elapsed time, peak RSS and semantic outcome. Choose and commit the RSS ceiling after measuring the valid corpus on supported runners. Use OS process/job controls or sampled RSS supervision on each supported platform. Include a deliberately stalled helper and excessive-memory helper to prove the supervisor fails. A Ruby timeout around Fiddle is insufficient; internal deterministic budgets and external process deadlines serve different purposes.
5. Seed all 229 existing EMF fixtures through the seed manifest. Fuzz parsing arbitrary bytes, parse/serialize/reparse, and valid C ABI lifecycle sequences with malformed payloads. Compare parse outcomes/model/bytes where the baseline defines a stable oracle. Add mutations for zero-size records, truncated headers, extreme counts, offset overflow, overlapping ranges, embedded comments and large output requests. Add WMF/EMF+ seeds as [09-format-extension.md](09-format-extension.md) lands.
6. Proposed execution policy: a short fixed-seed smoke job on changes; nightly/manual 30-minute runs per target with recorded toolchain, seed and budget. Retain crash artifacts as CI artifacts, minimize failures, then commit only a public-safe licensed regression plus deterministic test. A finite clean fuzz run is evidence for that budget, not proof of absence of defects.

## Planned commands

These commands are future checks; their scripts/targets do not exist yet and no result is claimed here. Run from the repository root after implementation:

```sh
cargo test --manifest-path emf-rs/Cargo.toml -p emf-core --test resilience
ruby script/native_resilience --manifest spec/fixtures/manifest.json --backend native --wall-seconds 60 --report tmp/native-resilience.json
EMF_BACKEND=native bundle exec rspec spec/emf/native_resilience_spec.rb spec/emf/corrupted_resilience_spec.rb
cargo +nightly fuzz run --fuzz-dir emf-rs/fuzz parse -- -max_total_time=60
cargo +nightly fuzz run --fuzz-dir emf-rs/fuzz serialize -- -max_total_time=60
cargo +nightly fuzz run --fuzz-dir emf-rs/fuzz ffi -- -max_total_time=60
```

The runner must refuse to execute until its recorded RSS limit is configured. Pin the nightly/fuzzer versions in CI and report the actual seed count and elapsed fuzz time.

## Acceptance

- All 21 corrupt fixtures terminate within supervised limits, including the named pathological file; exact baseline outcomes or explicitly documented resource-limit outcomes are asserted.
- Boundary tests demonstrate rejected arithmetic overflow and allocation/fuel exhaustion without unchecked allocations, process aborts or lost ownership. Valid controls still parse, mutate and serialize correctly.
- Supervisor tests demonstrate wall/RSS enforcement and child cleanup. No success can be recorded for a killed or timed-out process.
- All fuzz targets build and execute their declared smoke budgets with the seed manifest checked; every discovered failure blocks the affected entry point until minimized and fixed.
- Resilience evidence is collected independently for each delivered platform in [08-platform-delivery.md](08-platform-delivery.md); unsupported supervision or OOM behavior remains an explicit delivery gap.
