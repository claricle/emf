# 08 — Deliver prebuilt native libraries and preserve Ruby fallback

Status: **Not started**. Estimate: **3–4 engineering days**, after a versioned C ABI and Ruby binding can pass parity. Target availability and cross-platform runner discovery can extend this estimate.

## Problem and existing behavior

`emf.gemspec` currently packages `lib/**/*.rb`, `README.adoc` and `LICENSE.txt`, describes a pure Ruby parser, requires Ruby >= 3.1 and depends on BinData. `.github/workflows/test.yml` tests Ruby 3.1–3.4 on Linux/macOS. It has no native, musl or Windows jobs. `.github/workflows/release.yml` publishes through RubyGems OIDC and is manually dispatched; preserve that trigger and authentication model. This plan does not publish a release.

The same gem/API must prefer an available compatible native library while retaining Ruby operation when native loading is unavailable. Installing a source or platform gem must not require Rust, a C compiler, or a dependency that compiles during installation.

## Proposed files

- `emf-rs/Cargo.lock`, `emf-rs/rust-toolchain.toml`: committed dependency resolution and exact supported build toolchain.
- `lib/emf/native/platforms.json`: target triples, RubyGems platform names, library filenames, ABI version and per-artifact hashes.
- `lib/emf/native/<platform>/libemf_ffi.so`, `libemf_ffi.dylib` or `emf_ffi.dll`: generated library destinations in platform gem staging only; platform identifier comes from the manifest.
- `lib/emf/native/loader.rb`: lazy Fiddle load, ABI/platform verification and availability reporting coordinated with [05-ruby-binding.md](05-ruby-binding.md).
- `script/build_native_gem`, `script/check_native_package`, `script/native_install_smoke`: reproducible staging, package manifest checks and clean installation tests.
- `spec/emf/native_package_spec.rb`: native selection, source fallback and loader regressions.
- `emf.gemspec`, `Rakefile`, `.github/workflows/test.yml`, `.github/workflows/release.yml`: explicit package lists and integration; `.github/workflows/native-build.yml` builds/tests target artifacts before release consumption.
- `docs/native-platforms.adoc`: supported Ruby/runtime/platform combinations, ABI compatibility and fallback behavior.

## Proposed target matrix

Every row requires an actual build, execution test, and clean gem-install smoke test; cross-compilation alone does not qualify. Linux glibc and musl artifacts are distinct.

| Rust target | Intended RubyGems platform | Required execution environment |
| --- | --- | --- |
| `x86_64-unknown-linux-gnu` | `x86_64-linux-gnu` | x86_64 Linux glibc |
| `aarch64-unknown-linux-gnu` | `aarch64-linux-gnu` | aarch64 Linux glibc |
| `x86_64-unknown-linux-musl` | `x86_64-linux-musl` | x86_64 Linux musl |
| `aarch64-unknown-linux-musl` | `aarch64-linux-musl` | aarch64 Linux musl |
| `x86_64-apple-darwin` | `x86_64-darwin` | Intel macOS |
| `aarch64-apple-darwin` | `arm64-darwin` | Apple Silicon macOS |
| `x86_64-pc-windows-gnu` | `x64-mingw-ucrt` | Windows x64 UCRT Ruby |
| `aarch64-pc-windows-gnullvm` | To verify for aarch64 Windows mingw Ruby | Windows ARM64 compatible mingw Ruby |

The final row is a feasibility gate: verify Rust target maturity/toolchain, runtime libraries, available Ruby distribution, RubyGems platform resolution, Fiddle loading and executable runner access before promising support. The other RubyGems names also require resolution tests at the declared RubyGems floor. If Windows ARM64 cannot satisfy these checks, record the blocker, owner and follow-up; do not silently delete the row or call the complete proposed matrix delivered. No MSVC-only substitute establishes mingw support.

## Feasibility probe

`.github/workflows/native-platform-probe.yml` (triggers: pull requests touching `script/platform_probe/**` or the workflow, plus manual dispatch) runs all eight matrix rows on native runners of each architecture, each under Ruby 3.1 and 3.4. It uses a throwaway crate (`script/platform_probe/hello`), not `emf-rs/`, and publishes nothing. Per row and Ruby version it records:

- Rust target and pinned toolchain build (`cargo build --locked --release --target`);
- runtime libraries the built library links (`ldd`, `otool -L` or `objdump -p`), in `linkage.txt`;
- whether a compatible Ruby could be installed (`ruby/setup-ruby`, or `apk` in Alpine for the musl rows);
- RubyGems platform resolution: a throwaway `emf-platform-probe` 0.0.0 platform gem is built in a temp dir, installed with `gem install --local` into an isolated `GEM_HOME`, and checked for selection over a `ruby`-platform decoy;
- Fiddle loading of the installed library: ABI version call and a pointer+length round trip, plus `Gem::Platform.local` against the intended name;
- packaging: the probe library is wrapped by `script/build_native_gem` into an emf platform gem (plus the source gem), both pass `script/check_native_package`, and `script/native_install_smoke --require-native --forbid-compiler --resolve-dependencies` installs them with a fetched `bindata` from a PATH holding only `ruby`, proving a no-compiler install per row (`package-*.log`, `package_*=ok` lines in `summary.txt`);
- runner access: a job that never starts on the expected architecture shows as a missing artifact.

Failed elements are written as `BLOCKER` lines in each artifact's `summary.txt`. The Windows ARM64 row (`windows-11-arm`) is `continue-on-error` so it reports without blocking. Results come from CI runs and are not recorded here yet; no row is delivered by this probe.

## Execution order and dependencies

1. Depend on [04-c-abi.md](04-c-abi.md), [05-ruby-binding.md](05-ruby-binding.md) and [06-resilience.md](06-resilience.md). Pin Rust/toolchain/build images and define the minimum glibc/macOS/Windows runtime baselines in the manifest. Inventory dynamically linked libraries and licenses. Choose runners or emulated environments for every row; record emulation and its limits.
2. Build `emf-ffi` in release mode for each exact target, then exercise the C ABI harness and forced-native Ruby parity on that target. Keep the existing Ruby 3.1–3.4 matrix; test the loader/API on every declared Ruby version/platform combination, with documented exclusions treated as gaps. Check Fiddle availability independently on every runtime: it must be loaded lazily, and its dependency closure must not introduce compilation at install time. Future Ruby additions need their own Fiddle check.
3. Stage one platform gem per validated row with only the matching binary, Ruby sources, license and manifest. Update the gemspec's summary/description and explicit file list; verify executable inclusion too. Build a separate `ruby` source gem containing the Ruby fallback and no native binary, Rust sources, Cargo build hook or native extension compilation step. Retain BinData for fallback and wire compatibility.
4. In clean environments without Rust/C compilers, install each packaged gem with normal dependency resolution, then parse, dump, mutate and serialize a fixture. Verify the native artifact actually loads in forced-native mode; a fallback parse is not evidence that the platform gem works. Install the source gem separately and assert Ruby selection. Exercise missing/corrupt library, missing Fiddle, wrong architecture, missing dependent library and wrong ABI: auto mode uses Ruby for availability failures, forced native reports a useful load error. Parser defects never trigger an automatic retry through Ruby.
5. Generate hashes, target/toolchain/dependency metadata and build provenance bound to revision and gem version. Verify `Cargo.lock` resolution, dependency/license policy and available vulnerability checks; establish tool versions and remediation policy before treating these as gates. Test reproducibility on a sample target and record unavoidable differences rather than promising bit-identical binaries without evidence.
6. Extend the current manually dispatched release workflow to consume only verified artifacts from that revision, verify checksums/ABI/manifests and publish platform gems plus the Ruby source gem through the existing OIDC trusted publisher. Check RubyGems publisher settings for the revised workflow identity before release. Keep release credentials out of build jobs. Validate artifact handling without invoking publication in this workstream.

## Planned commands

Future commands after scripts exist; these are not executed results:

```sh
cargo build --locked --release --manifest-path emf-rs/Cargo.toml -p emf-ffi --target x86_64-unknown-linux-gnu
ruby script/build_native_gem --target x86_64-unknown-linux-gnu --output pkg
ruby script/build_native_gem --platform ruby --output pkg
ruby script/check_native_package --directory pkg
ruby script/native_install_smoke --directory pkg --target x86_64-unknown-linux-gnu --require-native
EMF_BACKEND=native bundle exec rspec spec/emf/native_package_spec.rb spec/emf/backend_parity_spec.rb
```

Repeat the target build and execution commands for all eight matrix rows after feasibility checks. The smoke runner must fail if a compiler is available or backend selection does not match its expectation, and must inspect actual installed dependency/package contents.

## Acceptance

- Every claimed supported platform has a tested artifact, matching ABI/hash metadata, clean no-compiler installation evidence and forced-native parse/mutate/serialize parity. All eight proposed rows are either delivered or explicitly open; a blocked row prevents claiming full matrix completion.
- Ruby 3.1–3.4 preserve the existing API and fallback, with Fiddle availability and installation behavior verified across the declared matrix.
- The source gem installs and runs Ruby without Rust or a compiled dependency; platform gems include their binaries through a verified gemspec file list.
- Availability failures follow the agreed auto/forced-native behavior; malformed parser input does not cause hidden fallback.
- Release validation preserves manual dispatch and OIDC; provenance is tied to the tested revision. Publication remains a separate release action.
