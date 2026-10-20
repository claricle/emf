# Native fuzz targets

`parse`, `serialize`, and `ffi` exercise the actual core and ABI with bounded
inputs. Serialize checks preserved EMF/WMF bytes and stable EMF+ encoding; FFI
uses only live owned handles or null pointers and verifies a valid lifecycle
after every payload. Arbitrary pointer addresses are outside the ABI contract.

Run from the repository root:

```sh
python3 -m unittest discover -s emf-rs/fuzz/tests -p 'test_*.py'
python3 emf-rs/fuzz/seeds.py --corpus emf-rs/fuzz/corpus
cargo +nightly-2025-04-01 install cargo-fuzz --version 0.12.0 --locked
(cd emf-rs && cargo +nightly-2025-04-01 fuzz build --fuzz-dir fuzz parse)
RUSTUP_TOOLCHAIN=nightly-2025-04-01 python3 emf-rs/fuzz/run.py parse --seconds 30
```

Repeat build/run for `serialize` and `ffi`. CI uses the pinned nightly and
cargo-fuzz version, fixed seed 12345, 30 seconds per target on changes and 1800
seconds on scheduled/manual runs. Each input has a 10-second timeout; the job
has an external deadline and explicit libFuzzer memory limits. Reports include
actual toolchain versions, seed count, elapsed time, command and exit status;
CI uploads reports and crash artifacts even on failure. Minimize any discovered
failure and commit only public-safe licensed regressions.

Cargo fuzz build and run commands use `emf-rs` as their working directory; the
Python runner resolves reports, artifacts, and corpus paths from its own location,
so it can be launched from any caller directory.

`seeds.json` references all original 229 EMF files without duplicating them,
plus two existing WMF fixtures and six project-authored synthetic boundaries.
The validator checks hashes, eligibility and completeness before copying inputs.
Synthetic malformed inputs may reject or recover; successful parses must satisfy
the target's round-trip/lifecycle assertions. Embedded EMF+ is exercised from
EMF fixtures and standalone EMF+ framing from synthetic seeds.

For environments without nightly, set an absolute separate `CARGO_TARGET_DIR`
and run `bash emf-rs/fuzz/check-stable.sh`. This runs all shared harness functions
against every seed plus deterministic truncation/count mutations. It is a corpus
regression check, not instrumented libFuzzer execution. Finite clean runs only
establish evidence for their executed budgets. Generated corpus, artifacts,
reports and Python caches are ignored.
