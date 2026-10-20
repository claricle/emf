#!/usr/bin/env bash
# The provenance probe must use the same rustup toolchain selected in the crate.
set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)
script_under_test=${1:-$script_dir/run_row.sh}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"

cat >"$tmp/bin/rustup" <<'RUSTUP'
#!/usr/bin/env bash
case "$1" in
  show) echo '1.99.1-x86_64-unknown-linux-musl (directory override)' ;;
  toolchain|target) ;;
  *) echo "unexpected rustup command: $*" >&2; exit 2 ;;
esac
RUSTUP
cat >"$tmp/bin/rustc" <<'RUSTC'
#!/usr/bin/env bash
echo 'rustc 1.99.1'
RUSTC
cat >"$tmp/bin/cargo" <<'CARGO'
#!/usr/bin/env bash
mkdir -p "$PWD/target/aarch64-unknown-linux-musl/release"
: >"$PWD/target/aarch64-unknown-linux-musl/release/libemf_probe_hello.so"
CARGO
cat >"$tmp/bin/file" <<'FILE'
#!/usr/bin/env bash
echo 'ELF shared object'
FILE
cat >"$tmp/bin/ldd" <<'LDD'
#!/usr/bin/env bash
echo 'libc.musl.so => /lib/libc.musl.so'
LDD
cat >"$tmp/bin/gem" <<'GEM'
#!/usr/bin/env bash
exit 0
GEM
cat >"$tmp/bin/ruby" <<'RUBY'
#!/bin/bash
case "${1:-}" in
  -v) echo 'ruby fake' ;;
  -e)
    case "$2" in
      *RUBY_VERSION*) printf '3.4' ;;
      *RbConfig.ruby*) printf '%s' "$TEST_RUBY" ;;
      *dependencies.find*) printf '>= 0' ;;
      *) echo "unexpected Ruby expression: $2" >&2; exit 2 ;;
    esac
    ;;
  */build_native_gem)
    if [[ " $* " == *' --library '* ]]; then
      [[ "${RUSTUP_TOOLCHAIN:-}" == 1.99.1-x86_64-unknown-linux-musl ]] || {
        echo "provenance used wrong toolchain: ${RUSTUP_TOOLCHAIN:-unset}" >&2; exit 1;
      }
    fi
    output=
    while (($#)); do
      if [[ "$1" == --output ]]; then output=$2; shift 2; else shift; fi
    done
    mkdir -p "$output"
    : >"$output/emf-1.0.0.gem"
    ;;
  */load.rb|*/platform_gem.rb|*/check_native_package|*/native_install_smoke) ;;
  *) echo "unexpected fake Ruby invocation: $*" >&2; exit 2 ;;
esac
RUBY
chmod +x "$tmp/bin"/*

out=$tmp/output
if ! PATH="$tmp/bin:$PATH" TEST_RUBY="$tmp/bin/ruby" \
  bash "$script_under_test" aarch64-unknown-linux-musl aarch64-linux-musl "$out"; then
  cat "$out/summary.txt" >&2
  cat "$out/package-build-platform.log" >&2
  exit 1
fi
grep -q '^build_platform_gem=ok$' "$out/summary.txt"
echo 'run_row provenance uses the crate-selected Rust toolchain'
