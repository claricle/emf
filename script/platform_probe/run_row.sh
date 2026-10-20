#!/usr/bin/env bash
# Usage: run_row.sh RUST_TARGET INTENDED_PLATFORM OUTPUT_DIR
# Records build, linkage, gem-resolution and Fiddle-load evidence for one row.
# Every failing element is written to OUTPUT_DIR/summary.txt as a BLOCKER line.
set -u -o pipefail

target=$1
platform=$2
out=$3
here=$(cd "$(dirname "$0")" && pwd)
crate=$here/hello
status=0

mkdir -p "$out"
summary=$out/summary.txt
note() { echo "$*" | tee -a "$summary"; }
blocker() {
  note "BLOCKER $*"
  status=1
}
native_path() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else echo "$1"; fi; }

note "target=$target intended_platform=$platform runner_os=${RUNNER_OS:-local} runner_arch=${RUNNER_ARCH:-unknown} uname=$(uname -sm)"
note "ruby_setup_outcome=${RUBY_SETUP_OUTCOME:-n/a} linker_setup_outcome=${LINKER_SETUP_OUTCOME:-n/a} (reasons are in the job log)"
# Each setup step is checked here, unconditionally: a later step can succeed on a preinstalled
# tool and must not hide that the requested setup failed.
[ "${RUBY_SETUP_OUTCOME:-}" = failure ] && blocker "ruby setup failed (reason is in the job log)"
[ "${LINKER_SETUP_OUTCOME:-}" = failure ] && blocker "linker setup failed (reason is in the job log)"
# alpine.sh records each failed bootstrap step here.
if [ -s "$out/bootstrap-failures.txt" ]; then
  while IFS= read -r failure; do blocker "bootstrap: $failure"; done <"$out/bootstrap-failures.txt"
fi
ruby_minor=$(ruby -e 'print RUBY_VERSION[/\A\d+\.\d+/]' 2>/dev/null)
if [ -n "${EXPECTED_RUBY:-}" ] && [ "$ruby_minor" != "$EXPECTED_RUBY" ]; then
  blocker "ruby on PATH is '${ruby_minor:-none}', expected $EXPECTED_RUBY"
fi

# Some runner images (notably Windows ARM64) may not ship rustup.
if ! command -v rustup >/dev/null 2>&1 && [ "${RUNNER_OS:-}" = Windows ]; then
  case "${RUNNER_ARCH:-}" in ARM64) arch=aarch64 ;; *) arch=x86_64 ;; esac
  if ! { curl -sSfL "https://win.rustup.rs/$arch" -o "$out/rustup-init.exe" >"$out/rustup-bootstrap.log" 2>&1 &&
    "$out/rustup-init.exe" -y --profile minimal --default-toolchain none >>"$out/rustup-bootstrap.log" 2>&1; }; then
    blocker "rustup bootstrap failed: $(tail -n 3 "$out/rustup-bootstrap.log" | tr '\n' ' ')"
  fi
  PATH="$HOME/.cargo/bin:$PATH"
  note "rustup bootstrapped on Windows: $(command -v rustup || echo FAILED)"
fi

build() {
  (
    cd "$crate" &&
      rustup toolchain install &&
      rustup target add "$target" &&
      rustc -Vv &&
      cargo build --locked --release --target "$target"
  ) >"$out/build.log" 2>&1
}

if build; then
  note "build=ok $(grep -m1 '^rustc' "$out/build.log")"
else
  blocker "build failed: $(tail -n 3 "$out/build.log" | tr '\n' ' ')"
fi

lib=""
for candidate in libemf_probe_hello.so libemf_probe_hello.dylib emf_probe_hello.dll; do
  [ -f "$crate/target/$target/release/$candidate" ] && lib=$crate/target/$target/release/$candidate
done

inventory() {
  case "$target" in
    *-apple-darwin) otool -L "$lib" ;;
    *-windows-*) (objdump -p "$lib" || llvm-objdump -p "$lib") | grep -i 'DLL Name' ;;
    *) file "$lib" && ldd "$lib" ;;
  esac
}

if [ -z "$lib" ]; then
  blocker "no built library found under $crate/target/$target/release"
elif inventory >"$out/linkage.txt" 2>&1; then
  note "linkage=ok $(tr '\n' ';' <"$out/linkage.txt" | tr -s ' \t' ' ')"
else
  blocker "linkage inspection failed: $(tr '\n' ' ' <"$out/linkage.txt")"
fi

if [ -n "$lib" ]; then
  if command -v ruby >/dev/null 2>&1; then
    note "ruby=$(ruby -v)"
    nlib=$(native_path "$lib")
    nhere=$(native_path "$here")
    ruby "$nhere/load.rb" "$nlib" "$platform" >"$out/load-direct.jsonl" 2>"$out/load-direct.err" ||
      blocker "direct Fiddle load failed: $(tr '\n' ' ' <"$out/load-direct.jsonl")"
    ruby "$nhere/platform_gem.rb" "$nlib" "$platform" >"$out/platform-gem.jsonl" 2>"$out/platform-gem.err" ||
      blocker "platform gem resolution or load failed: $(tr '\n' ' ' <"$out/platform-gem.jsonl") $(tail -n 3 "$out/platform-gem.err" | tr '\n' ' ')"
  else
    blocker "no ruby on PATH (ruby setup outcome: ${RUBY_SETUP_OUTCOME:-n/a})"
  fi
fi

# Packaging proof: build the platform gem from the probe library and the source gem, check both,
# then install without a compiler on PATH. Every step that fails is a BLOCKER, and a step whose
# prerequisite failed is a BLOCKER too, never a silent skip.
root=$(cd "$here/../.." && pwd)

# Writes a PATH holding only ruby, so no cc/gcc/clang/rustc shim can leak into the install.
compiler_free_path() {
  local ruby_bin
  ruby_bin=$(ruby -e 'print RbConfig.ruby') || return 1
  if [ "${RUNNER_OS:-}" = Windows ]; then
    dirname "$ruby_bin"
  else
    mkdir -p "$out/bin" && ln -sf "$ruby_bin" "$out/bin/ruby" && echo "$out/bin"
  fi
}

step() { # step NAME LOG COMMAND... : runs the command, logging to OUT/LOG, BLOCKER on failure
  local name=$1 log=$2
  shift 2
  if "$@" >"$out/$log" 2>&1; then
    note "$name=ok"
    return 0
  fi
  blocker "$name failed: $(tail -n 3 "$out/$log" | tr '\n' ' ')"
  return 1
}

# shellcheck disable=SC2329  # invoked through step
fetch_in() { (cd "$1" && gem fetch "$2" --version "$3"); }

package_steps() {
  local pkg=$out/package install_dir=$out/package-install req isolated
  local build_toolchain
  local nroot nlib npkg ninstall
  build_toolchain=$(cd "$crate" && rustup show active-toolchain 2>/dev/null | awk 'NR == 1 { print $1 }')
  if [ -z "$build_toolchain" ]; then
    blocker "could not identify the Rust toolchain used to build the probe"
    return 1
  fi
  nroot=$(native_path "$root") nlib=$(native_path "$lib") npkg=$(native_path "$pkg") ninstall=$(native_path "$install_dir")
  rm -rf "${pkg:?}" "${install_dir:?}" "${out:?}/bin"
  step "build_platform_gem" package-build-platform.log \
    env RUSTUP_TOOLCHAIN="$build_toolchain" ruby "$nroot/script/build_native_gem" --platform "$platform" --library "$nlib" --abi-version 1 --target "$target" ${GITHUB_SHA:+--revision "$GITHUB_SHA"} --output "$npkg" || return
  step "build_source_gem" package-build-source.log \
    ruby "$nroot/script/build_native_gem" --platform ruby --output "$npkg" || return
  step "package_check" package-check.log ruby "$nroot/script/check_native_package" --directory "$npkg" || return
  if ! { mkdir -p "$install_dir" && cp "$pkg"/*.gem "$install_dir"/; }; then
    blocker "could not stage gems for install"
    return
  fi
  req=$(cd "$root" && ruby -e 'print Gem::Specification.load("emf.gemspec").dependencies.find { |d| d.name == "bindata" }.requirement') ||
    { blocker "could not read the bindata requirement from emf.gemspec"; return; }
  step "fetch_dependency" package-fetch.log fetch_in "$install_dir" bindata "$req" || return
  isolated=$(compiler_free_path) || { blocker "could not build a compiler-free PATH"; return; }
  step "install_smoke" package-install.log env PATH="$isolated" "$(ruby -e 'print RbConfig.ruby')" "$nroot/script/native_install_smoke" \
    --directory "$ninstall" --platform "$platform" --abi-symbol emf_probe_abi_version \
    --require-native --forbid-compiler --resolve-dependencies
}

if [ -n "$lib" ] && command -v ruby >/dev/null 2>&1; then
  package_steps
fi

note "result=$([ "$status" -eq 0 ] && echo PASS || echo BLOCKED)"
exit "$status"
