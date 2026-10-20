#!/usr/bin/env bash
# Regression for real_row.sh: building the cdylib must not change the caller's cwd.
set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)
repo_root=$(cd "$script_dir/../.." && pwd)
script_under_test=${1:-$script_dir/real_row.sh}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin" "$tmp/caller"
cat >"$tmp/bin/rustup" <<'SH'
#!/usr/bin/env bash
exit 0
SH
cat >"$tmp/bin/cargo" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "$tmp/bin/rustup" "$tmp/bin/cargo"
sed -n '/^build_cdylib() {/,/^}/p' "$script_under_test" >"$tmp/build_cdylib.sh"

(
  cd "$tmp/caller"
  PATH="$tmp/bin:$PATH" bash -c '
    set -euo pipefail
    root=$1
    target=cwd-regression-target
    export root target
    before=$PWD
    source "$2"
    build_cdylib
    if [[ "$PWD" != "$before" ]]; then
      printf "cwd changed: expected %s, got %s\\n" "$before" "$PWD" >&2
      exit 1
    fi
  ' bash "$repo_root" "$tmp/build_cdylib.sh"
)

echo "real_row build_cdylib preserves caller cwd"
