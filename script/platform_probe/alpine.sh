#!/bin/sh
# Runs inside an Alpine container: installs Ruby and Rust the way a musl user
# would, then hands over to run_row.sh. Usage: alpine.sh RUST_TARGET PLATFORM OUTPUT_DIR
set -u

here=$(cd "$(dirname "$0")" && pwd)
out=$3
mkdir -p "$out"

# Each failed step is recorded; run_row.sh turns every line into a BLOCKER.
failures=$out/bootstrap-failures.txt
: >"$failures"
apk add --no-cache bash curl file build-base ruby git >"$out/apk.log" 2>&1 || echo "apk base install failed (apk.log)" >>"$failures"
# json and Fiddle ship inside the ruby package (3.17 lists ruby-json and
# ruby-fiddle only as its virtual names; 3.22 has no such names, so naming them
# fails the install). Judge by whether Ruby loads them: a missing Fiddle is a
# finding, not a fix.
ruby -e 'require "json"; require "fiddle"' >>"$out/apk.log" 2>&1 || echo "ruby cannot load json and fiddle (apk.log)" >>"$failures"
{ curl -sSf https://sh.rustup.rs -o /tmp/rustup-init.sh &&
  sh /tmp/rustup-init.sh -y --profile minimal --default-toolchain none; } >"$out/rustup.log" 2>&1 ||
  echo "rustup install failed (rustup.log)" >>"$failures"
PATH="$HOME/.cargo/bin:$PATH"
export PATH
RUBY_SETUP_OUTCOME="apk: $(tr '\n' ' ' <"$out/apk.log" | tail -c 300)"
export RUBY_SETUP_OUTCOME
if ! command -v bash >/dev/null 2>&1; then
  echo "BLOCKER alpine bootstrap failed, no bash: $(tail -n 3 "$out/apk.log" | tr '\n' ' ')" >>"$out/summary.txt"
  echo "result=BLOCKED" >>"$out/summary.txt"
  exit 1
fi
bash "$here/run_row.sh" "$@"
probe=$?
bash "$here/real_row.sh" "$@"
real=$?
[ "$probe" -eq 0 ] && [ "$real" -eq 0 ]
