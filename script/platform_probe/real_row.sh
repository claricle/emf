#!/usr/bin/env bash
# Usage: real_row.sh RUST_TARGET INTENDED_PLATFORM OUTPUT_DIR
# Acceptance for the real library: builds the emf-ffi cdylib, stages and checks the platform gem,
# install-smokes it with no compiler on PATH, installs it and runs a forced-native workload from
# the installed gem. Every failing element is a BLOCKER line in OUTPUT_DIR/summary.txt.
set -u -o pipefail

target=$1
platform=$2
out=$3/real
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
status=0
# run_row.sh may have bootstrapped rustup here on a Windows runner without it.
PATH="$HOME/.cargo/bin:$PATH"

# Keep paths supplied by the caller anchored to its cwd before package steps cd.
# cygpath also handles Windows drive paths while preserving native path syntax.
absolute_path() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -am "$1"
    return
  fi
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *)
      local parent base
      parent=$(dirname "$1")
      base=$(basename "$1")
      mkdir -p "$parent"
      (cd "$parent" && printf '%s/%s\n' "$PWD" "$base")
      ;;
  esac
}

out=$(absolute_path "$out")

rm -rf "${out:?}"
mkdir -p "$out"
summary=$out/summary.txt
note() { echo "$*" | tee -a "$summary"; }
blocker() {
  note "BLOCKER $*"
  status=1
}
native_path() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else echo "$1"; fi; }

# step NAME LOG COMMAND... : runs the command, logging to OUT/LOG, BLOCKER on failure
step() {
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
build_cdylib() {
  case "$target" in
    # A musl cdylib cannot link statically; Alpine's rustc defaults crt-static on.
    *-musl) export RUSTFLAGS="${RUSTFLAGS:-} -C target-feature=-crt-static" ;;
    # llvm-mingw links libunwind.dll dynamically, and a clean Windows ARM64 machine lacks it.
    # Candidate only: the dll_closure step on a real runner decides whether this is enough.
    aarch64-pc-windows-gnullvm) export RUSTFLAGS="${RUSTFLAGS:-} -C link-arg=-static" ;;
  esac
  (
    cd "$root/emf-rs" &&
    rustup toolchain install stable --profile minimal &&
    rustup target add "$target" &&
    cargo +stable build --locked --release -p emf-ffi --target "$target"
  )
}

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

# shellcheck disable=SC2329  # invoked through step
fetch_in() { (cd "$1" && gem fetch "$2" --version "$3"); }

# shellcheck disable=SC2329  # invoked through step
install_gem() { # install_gem HOME STAGE VERSION : same command as native_install_smoke, RubyGems in-process
  (cd "$2" && env -u RUBYOPT -u RUBYLIB -u BUNDLE_GEMFILE PATH="$isolated" GEM_HOME="$1" GEM_PATH="$1" \
    "$ruby" -rrubygems/gem_runner -e 'Gem::GemRunner.new.run(ARGV)' -- \
    install emf --version "$3" --local --no-document)
}

# A Windows DLL's imports resolve against PATH and the msys toolchain dirs on the build host, so
# a missing runtime DLL (libunwind.dll) passes the workload but fails on a user's machine.
# shellcheck disable=SC2329  # invoked through step
check_dll_closure() { # check_dll_closure HOME
  local dll
  dll=$(find "$1"/gems -path "*/lib/emf/native/*/emf_ffi.dll" 2>/dev/null | head -n 1)
  [ -n "$dll" ] || { echo "no installed emf_ffi.dll under $1"; return 1; }
  ruby "$here/dll_closure.rb" "$dll"
}

# shellcheck disable=SC2329  # invoked through step
run_workload() { # run_workload HOME FIXTURE : cwd outside the checkout so nothing loads from lib/
  (cd "$out" && env -u RUBYOPT -u RUBYLIB -u BUNDLE_GEMFILE PATH="$isolated" GEM_HOME="$1" GEM_PATH="$1" \
    "$ruby" "$2" "$3")
}

# shellcheck disable=SC2329  # invoked through step
run_availability() { # run_availability HOME SCRIPT LIBRARY FIXTURE : the script gives its children a ruby-only PATH
  (cd "$out" && env -u RUBYOPT -u RUBYLIB -u BUNDLE_GEMFILE GEM_HOME="$1" GEM_PATH="$1" \
    "$ruby" "$2" --library "$3" --fixture "$4")
}

note "real library: target=$target intended_platform=$platform runner_os=${RUNNER_OS:-local} uname=$(uname -sm)"
note "ruby=$(ruby -v)"

# EMF_REAL_LIBRARY is preset only for a local dry run; CI builds the library.
lib=${EMF_REAL_LIBRARY:-}
if [ -n "$lib" ]; then
  lib=$(absolute_path "$lib")
fi
if [ -z "$lib" ]; then
  if step "build_cdylib" build.log build_cdylib; then
    for candidate in libemf_ffi.so libemf_ffi.dylib emf_ffi.dll; do
      [ -f "$root/emf-rs/target/$target/release/$candidate" ] && lib=$root/emf-rs/target/$target/release/$candidate
    done
    [ -n "$lib" ] || blocker "no emf-ffi library under emf-rs/target/$target/release"
  fi
fi

package_steps() {
  local pkg=$out/package stage=$out/stage home=$out/gem-home
  local nroot nlib npkg nstage nhome nhere nfixture req
  # Both gems and the package check are bound to one source revision: the release
  # revision in CI, else the checkout's HEAD.
  local revision=${EMF_RELEASE_REVISION:-${GITHUB_SHA:-}}
  if [ -z "$revision" ]; then
    revision=$(git -C "$root" rev-parse HEAD 2>/dev/null) || { blocker "cannot determine the source revision"; return; }
  fi
  nroot=$(native_path "$root") nlib=$(native_path "$lib") npkg=$(native_path "$pkg")
  nstage=$(native_path "$stage") nhome=$(native_path "$home") nhere=$(native_path "$here")
  nfixture=$(native_path "$out/fixture.emf")
  rm -rf "${pkg:?}" "${stage:?}" "${home:?}" "${out:?}/bin"
  ruby="$(ruby -e 'print RbConfig.ruby')"
  step "build_platform_gem" package-build-platform.log \
    ruby "$nroot/script/build_native_gem" --platform "$platform" --library "$nlib" --abi-version 1 --target "$target" --revision "$revision" --output "$npkg" || return
  step "build_source_gem" package-build-source.log \
    ruby "$nroot/script/build_source_release_gem" --revision "$revision" --output "$npkg" || return
  step "package_check" package-check.log \
    ruby "$nroot/script/check_native_package" --directory "$npkg" --revision "$revision" || return
  req=$(cd "$root" && ruby -e 'print Gem::Specification.load("emf.gemspec").dependencies.find { |d| d.name == "bindata" }.requirement') ||
    { blocker "could not read the bindata requirement from emf.gemspec"; return; }
  if ! { mkdir -p "$stage" && cp "$pkg"/*.gem "$stage"/; }; then
    blocker "could not stage gems for install"
    return
  fi
  step "fetch_dependency" package-fetch.log fetch_in "$stage" bindata "$req" || return
  isolated=$(compiler_free_path) || { blocker "could not build a compiler-free PATH"; return; }
  step "install_smoke" package-install.log env PATH="$isolated" "$ruby" "$nroot/script/native_install_smoke" \
    --directory "$nstage" --platform "$platform" \
    --require-native --forbid-compiler --resolve-dependencies || return
  version=$(cd "$root" && ruby -e 'print Gem::Specification.load("emf.gemspec").version')
  step "install_gem" install.log install_gem "$nhome" "$nstage" "$version" || return
  if [ "${RUNNER_OS:-}" = Windows ]; then
    step "dll_closure" dll-closure.log check_dll_closure "$nhome" || return
  fi
  cp "$root/spec/fixtures/emf/test-000.emf" "$out/fixture.emf"
  step "installed_workload" workload.log run_workload "$nhome" "$nhere/installed_workload.rb" "$nfixture"
  grep -E '^(installed gem|discovery)' "$out/workload.log" | while IFS= read -r line; do note "$line"; done
  step "availability_matrix" availability.log run_availability "$nhome" "$nroot/script/platform_probe/availability_matrix.rb" "$nlib" "$nfixture" || return
  grep -E '^availability ' "$out/availability.log" | while IFS= read -r line; do note "$line"; done
}

if [ -n "$lib" ]; then
  package_steps
fi

note "result=$([ "$status" -eq 0 ] && echo PASS || echo BLOCKED)"
exit "$status"
