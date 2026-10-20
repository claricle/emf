# 08 — Deliver prebuilt native libraries and preserve Ruby fallback

Status: **Implemented in part; platform acceptance remains open**. Native packaging, installed-library discovery, availability controls, platform probes and release artifact verification exist. A workflow definition or local check does not qualify every target for delivery. Remaining effort depends on real per-target execution and resolution of failed or unavailable runners.

## Problem and existing behavior

`emf.gemspec` currently packages `lib/**/*.rb`, `README.adoc` and `LICENSE.txt`, describes a pure Ruby parser, requires Ruby >= 3.1 and depends on BinData. `.github/workflows/test.yml` tests Ruby 3.1–3.4 on Linux/macOS. Native CI now includes `.github/workflows/rust.yml` and the glibc/musl/macOS/Windows matrix in `.github/workflows/native-platform-probe.yml`. `.github/workflows/release.yml` publishes through RubyGems OIDC and is manually dispatched; preserve that trigger and authentication model. This plan does not publish a release.

The same gem/API must prefer an available compatible native library while retaining Ruby operation when native loading is unavailable. Installing a source or platform gem must not require Rust, a C compiler, or a dependency that compiles during installation.

## Implemented files and remaining integration

- `emf-rs/Cargo.lock`: committed dependency resolution. An exact supported toolchain pin (`rust-toolchain.toml`) remains open; existing jobs select toolchains explicitly.
- `lib/emf/native/platforms.json` and `provenance.json`: generated in platform gem staging; record platform, library filename, ABI/hash and target/toolchain/revision provenance. They are not checked-in source manifests.
- `lib/emf/native/<platform>/libemf_ffi.so`, `libemf_ffi.dylib` or `emf_ffi.dll`: generated library destinations in platform gem staging only; platform identifier comes from the manifest.
- `lib/emf/native.rb` and `lib/emf/native/`: lazy native loading, installed manifest/ABI/hash checks and backend integration coordinated with [05-ruby-binding.md](05-ruby-binding.md).
- `script/build_native_gem`, `script/check_native_package`, `script/native_install_smoke`: reproducible staging, package manifest checks and clean installation tests.
- `spec/scripts/native_package_spec.rb` and `native_package_availability_spec.rb`: package integrity, isolated installation and installed-gem availability regressions. The no-toolchain smoke controls execute without building Rust.
- `emf.gemspec` retains Ruby-only sources. `.github/workflows/native-platform-probe.yml` exercises real `emf-ffi` artifacts as well as probe libraries. `.github/workflows/release.yml` builds seven platform gems plus the source gem, verifies the set with `script/verify_release_artifacts`, and defaults to a dry run before optional OIDC publication.
- `docs/native-platforms.adoc` remains unimplemented; supported combinations and runtime baselines still require validated evidence before publication as support claims.

## Target acceptance matrix (still open)

Every row requires an actual build, execution test, and clean gem-install smoke test; cross-compilation alone does not qualify. Linux glibc and musl artifacts are distinct. All eight rows remain open here pending a complete retained, passing target/Ruby acceptance result. Existing partial local/CI evidence is useful for diagnosing failures, not a full matrix certification. Windows ARM64 Ruby 3.1 has no compatible setup-ruby distribution in the current probe and is explicitly excluded; Ruby 3.4 remains an experimental probe.

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

`.github/workflows/native-platform-probe.yml` (triggers: pull requests touching native/probe/packaging paths listed in the workflow, plus manual dispatch) runs all eight matrix rows on native runners of each architecture, under Ruby 3.1 and 3.4 except Windows ARM64 Ruby 3.1. It first uses a throwaway crate (`script/platform_probe/hello`), then builds real `emf-ffi` and exercises `script/platform_probe/real_row.sh`; it publishes nothing. Per row and Ruby version it records:

- Rust target and selected toolchain build (`cargo build --locked --release --target`); the real-library phase currently selects `stable`, so an exact version pin remains open;
- runtime libraries the built library links (`ldd`, `otool -L` or `objdump -p`), in `linkage.txt`;
- whether a compatible Ruby could be installed (`ruby/setup-ruby`, or `apk` in Alpine for the musl rows);
- RubyGems platform resolution: a throwaway `emf-platform-probe` 0.0.0 platform gem is built in a temp dir, installed with `gem install --local` into an isolated `GEM_HOME`, and checked for selection over a `ruby`-platform decoy;
- Fiddle loading of the installed library: ABI version call and a pointer+length round trip, plus `Gem::Platform.local` against the intended name;
- packaging: the probe library is wrapped by `script/build_native_gem` into an emf platform gem (plus the source gem), both pass `script/check_native_package`, and `script/native_install_smoke --require-native --forbid-compiler --resolve-dependencies` installs them with a fetched `bindata` from a PATH holding only `ruby`, proving a no-compiler install per row (`package-*.log`, `package_*=ok` lines in `summary.txt`);
- runner access: a job that never starts on the expected architecture shows as a missing artifact.

Failed elements are written as `BLOCKER` lines in each artifact's `summary.txt`. The Windows ARM64 row (`windows-11-arm`) is `continue-on-error` so it reports without blocking. The real-library phase additionally exercises installed forced-native parse/dump/mutate/serialize and the availability matrix. The matrix checks missing/corrupt/wrong-architecture libraries, missing Fiddle, wrong ABI and missing dynamic dependencies (the last two require a compiler to prepare fixtures), plus damaged installed metadata/library discovery. Child processes use a Ruby-only PATH. A checked-in test verifies that an unloadable control library makes the matrix fail. No row is declared delivered without its complete result.

## Execution order and dependencies

1. Depend on [04-c-abi.md](04-c-abi.md), [05-ruby-binding.md](05-ruby-binding.md) and [06-resilience.md](06-resilience.md). Pin Rust/toolchain/build images and define the minimum glibc/macOS/Windows runtime baselines in the manifest. Inventory dynamically linked libraries and licenses. Choose runners or emulated environments for every row; record emulation and its limits.
2. Build `emf-ffi` in release mode for each exact target, then exercise the C ABI harness and forced-native Ruby parity on that target. Keep the existing Ruby 3.1–3.4 matrix; test the loader/API on every declared Ruby version/platform combination, with documented exclusions treated as gaps. Check Fiddle availability independently on every runtime: it must be loaded lazily, and its dependency closure must not introduce compilation at install time. Future Ruby additions need their own Fiddle check.
3. Stage one platform gem per validated row with only the matching binary, Ruby sources, license and manifest. Update the gemspec's summary/description and explicit file list; verify executable inclusion too. Build a separate `ruby` source gem containing the Ruby fallback and no native binary, Rust sources, Cargo build hook or native extension compilation step. Retain BinData for fallback and wire compatibility.
4. In clean environments without Rust/C compilers, install each packaged gem with normal dependency resolution, then parse, dump, mutate and serialize a fixture. Verify the native artifact actually loads in forced-native mode; a fallback parse is not evidence that the platform gem works. Install the source gem separately and assert Ruby selection. Exercise missing/corrupt library, missing Fiddle, wrong architecture, missing dependent library and wrong ABI: auto mode uses Ruby for availability failures, forced native reports a useful load error. Parser defects never trigger an automatic retry through Ruby.
5. Generate hashes, target/toolchain/dependency metadata and build provenance bound to revision and gem version. Verify `Cargo.lock` resolution, dependency/license policy and available vulnerability checks; establish tool versions and remediation policy before treating these as gates. Test reproducibility on a sample target and record unavoidable differences rather than promising bit-identical binaries without evidence.
6. Extend the current manually dispatched release workflow to consume only verified artifacts from that revision, verify checksums/ABI/manifests and publish platform gems plus the Ruby source gem through the existing OIDC trusted publisher. Check RubyGems publisher settings for the revised workflow identity before release. Keep release credentials out of build jobs. Validate artifact handling without invoking publication in this workstream.

## Reproduction commands

These scripts exist. The commands below illustrate execution and are not evidence of a passing target:

```sh
cargo build --locked --release --manifest-path emf-rs/Cargo.toml -p emf-ffi --target x86_64-unknown-linux-gnu
ruby script/build_native_gem --platform x86_64-linux-gnu --target x86_64-unknown-linux-gnu \
  --library emf-rs/target/x86_64-unknown-linux-gnu/release/libemf_ffi.so --abi-version 1 --output pkg
ruby script/build_native_gem --platform ruby --output pkg
ruby script/check_native_package --directory pkg
ruby script/native_install_smoke --directory pkg --platform x86_64-linux-gnu --require-native
EMF_BACKEND=ruby bundle exec rspec spec/scripts/native_package_spec.rb
EMF_BACKEND=ruby EMF_REAL_LIBRARY=/absolute/path/to/libemf_ffi.so \
  bundle exec rspec spec/scripts/native_package_availability_spec.rb
```

Repeat the target build and execution commands for all eight matrix rows after feasibility checks. For no-compiler acceptance, run the smoke script with `--forbid-compiler --resolve-dependencies` on a Ruby-only PATH with the dependency gems staged locally. The smoke checks package selection and actual installed library contents; the separate installed workload must confirm backend selection and parse/mutate/serialize behavior.

## Current bounded evidence and remaining acceptance

The no-toolchain smoke regressions cover source installation with an empty PATH, missing platform library, corrupt bytes with a matching hash, and mismatched installed hash rejected before loading. The package smoke verifies installed platform selection, no extension/build directory, declared BinData dependency, library SHA-256 and ABI. Dependency resolution is optional locally and explicitly enabled in the target probe. Source smoke now requires an actual installed runtime: independent auto and Ruby child processes resolve `emf` from the isolated GEM_HOME, parse a minimal EMF, preserve byte identity, mutate the COLORREF wire API, serialize/reparse with exact edited bytes, and reject malformed input with `Emf::FormatError`. They assert no eager Fiddle/native machinery loading. Native workload parity remains separate evidence.

`spec/scripts/source_install_runtime_spec.rb` exercises clean offline source installation with the real locally installed BinData repackaged as a dependency gem, an empty compiler PATH, missing dependency resolution, and contaminated parent Ruby/Bundler/backend environment controls. The no-dependency installation control also fails at actual runtime even when installation ignores dependencies. Stage BinData and use `--resolve-dependencies` for a successful source smoke. This bounded local check is not a complete per-platform/Ruby source runtime matrix; each claimed environment still needs its own retained acceptance record. Ruby 3.2/3.3 are in ordinary Ruby CI but not the native target probe. Minimum runtime baselines, complete dependency/license/vulnerability policy, target reproducibility evidence and publisher identity verification remain open. No release, tag or workflow dispatch is authorized by this plan update.

`ruby script/platform_probe/acceptance_report.rb ARTIFACT_DIRECTORY --json` now inventories retained probe artifacts offline. The JSON/text report keeps all eight targets and both probe Ruby versions visible, including Windows ARM64 Ruby 3.1 as explicitly excluded and open. It records summary/log results, installed forced-native workload and availability controls, and revisions read from the packaged platform gems; missing/truncated evidence and skipped controls stay open, blockers fail, and duplicate/mislabeled rows or mixed revisions are rejected. Exit zero means collection succeeded, not that the matrix is supported; inspect the report status and per-row checks. This is observed evidence, not build attestation. The retained local Apple Silicon throwaway-probe artifact lacks its real-library phase and packaged revision metadata, so its revision is unknown and acceptance remains open; no platform job was rerun for the collector. Source-gem revision binding and unexecuted platform/Ruby acceptance still require their separate evidence.

## Acceptance

- Every claimed supported platform has a tested artifact, matching ABI/hash metadata, clean no-compiler installation evidence and forced-native parse/mutate/serialize parity. All eight proposed rows are either delivered or explicitly open; a blocked row prevents claiming full matrix completion.
- Ruby 3.1–3.4 preserve the existing API and fallback, with Fiddle availability and installation behavior verified across the declared matrix.
- The source gem installs and runs Ruby without Rust or a compiled dependency; platform gems include their binaries through a verified gemspec file list.
- Availability failures follow the agreed auto/forced-native behavior; malformed parser input does not cause hidden fallback.
- Release validation preserves manual dispatch and OIDC; provenance is tied to the tested revision. Publication remains a separate release action.
