# Native in-memory kernels

The dependency-free `emf-core` `harness = false` benchmark implementation is
committed; compilation and runtime validation are pending the current build pause.
No native kernel measurements or CLI execution checks are claimed yet. Run from
`emf-rs` and name existing workload files explicitly (paths are relative to the
current directory):

```sh
EMF_BENCH_PROFILE=release EMF_BENCH_RUSTC="$(rustc -Vv)" \
  cargo bench --locked -p emf-core --bench parser -- \
  --warmups 5 --samples 20 -- ../spec/fixtures/simple/image1.emf
```

Capture stdout and stderr with the command and exit status. Set the two build
identity environment variables when compiling: they are embedded in the binary,
not read from its runtime environment. Missing values report `unavailable` and
make the report unsuitable for profile/toolchain comparisons. `debug_assertions`
is reported separately; it cannot establish optimization level. Cargo's default
bench profile is release; custom profiles must be labeled accurately. For a
correctness-only smoke using an existing debug target, use `--profile dev` and
`EMF_BENCH_PROFILE=dev`; its timings are not release performance evidence.

The report includes the input SHA-256 (the existing standalone corpus helper),
size, framed record count excluding the header, diagnostic count, revision, git
working-tree changes, OS/architecture, host and CPU discovery. Discovery failures
are `unavailable`; record machine/CPU allocation, libc, thermal/load conditions,
compiler flags and target configuration separately for comparable runs. Revision
and dirty status are discovered in the invocation directory; run inside this
checkout. There is no native shared-library or Ruby dependency.

Before each fixture's measurements, exact unchanged serialization must equal the
input. Recoverable parser diagnostics are counted, not silently treated as fully
typed decoding. Fatal parse errors (including unsupported WMF containers) fail the
command with a nonzero exit; there is no successful timing for an unsupported
fixture. Earlier fixture output in a failed command is only a partial report.

Each kernel has independent warmups and one operation per measured sample:

- `parse_only`: `emf_core::parse` with default resource limits, including source
  ownership and model construction. The input is already in memory. EMF+ comment
  bytes use the core EMR parse boundary; this does not invoke rich structured
  EMF+ object extraction/decoding.
- `serialize_only`: `emf_core::serialize` on an unchanged document parsed before
  timing, including output allocation/copying.
- `parse_serialize`: parse and serialize in one timed interval.
- `editable_serialize`: serialize a pre-edited document. Setup selects the first
  typed SetTextColor, SetBkColor or MoveToEx record and flips one low bit. Before
  timing, bytes must change, the edited typed value must survive reparsing, and
  the edited output must round-trip exactly. This measures edited serialization,
  not edit latency. If no supported record exists, the report explicitly says
  `editable_serialize=unsupported` and emits no timing for that kernel.

Input loading/hash, guards, setup/cloning, reporting, and destruction of the
returned document/output are outside every timed interval. In particular, the
combined kernel retains both document and output until the end timestamp.
Allocations inside parse/serialize are included; allocator reuse across samples
is possible. Samples use `Instant`, with one timestamp pair and black-box result
per operation. Timer/closure/error-path wrapper overhead is included and is not
subtracted. Very small inputs can be dominated by this overhead. No batches of
retained documents grow memory with the sample count. There is no process timeout,
RSS measurement or allocation counter; run large/untrusted inputs under the
existing external resource supervisor. Default parser/serializer budgets apply.

Reports retain all nanosecond samples, arithmetic median (middle pair averaged
for even counts), and nearest-rank p95. Bounds are 0–100 warmups, 1–1000 samples,
and 1–32 fixtures. Defaults are five warmups and twenty measured samples. Samples
are sequential and kernels run in a fixed order; use repeated idle-runner runs to
assess noise/order effects before comparisons.

`simple/image1.emf` is a real existing 92,904-byte fixture suitable for a bounded
smoke. It is not the unidentified roughly twelve-second issue workload or an
agreed large representative workload. Explicitly choose and record that workload
before drawing performance conclusions. This CLI fills the isolated Rust kernel
measurement gap; it establishes no calibrated baseline, regression gate,
subsecond end-to-end acceptance, Ruby hydration/wire compatibility or rendering
performance claim. Use the public Ruby/downstream harnesses for those boundaries.
