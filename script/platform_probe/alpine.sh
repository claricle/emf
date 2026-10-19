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
apk add --no-cache bash curl file build-base ruby ruby-json >"$out/apk.log" 2>&1 || echo "apk base install failed (apk.log)" >>"$failures"
# Alpine splits Fiddle out of the ruby package; its absence is a finding, not a fix.
apk add --no-cache ruby-fiddle >>"$out/apk.log" 2>&1 || echo "ruby-fiddle not installable (apk.log)" >>"$failures"
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
exec bash "$here/run_row.sh" "$@"
