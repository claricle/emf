#!/usr/bin/env bash
# Exercise real_row.sh end-to-end with fake package tools and caller-relative paths.
set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)
script_under_test=${1:-$script_dir/real_row.sh}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin" "$tmp/caller/relative-output" "$tmp/caller/relative-library"
printf 'fake native library\n' >"$tmp/caller/relative-library/libemf_ffi.so"
cat >"$tmp/bin/ruby" <<'RUBY'
#!/bin/bash
set -euo pipefail
record() { printf '%s|%s|%s|%s\n' "$1" "${GEM_HOME:-}" "$PWD" "${*:2}" >>"$TEST_RECORD"; }
if [[ "${1:-}" == "-v" ]]; then
  echo 'ruby fake'
  exit 0
fi
if [[ "${1:-}" == "-e" ]]; then
  case "${2:-}" in
    *RbConfig.ruby*) printf '%s' "$TEST_RUBY_PATH" ;;
    *dependencies.find*) printf '>= 0' ;;
    *Gem::Specification.load*) printf '1.0.0' ;;
    *) echo "unexpected ruby -e: ${2:-}" >&2; exit 2 ;;
  esac
  exit 0
fi
case "${1:-}" in
  */build_native_gem)
    output=
    has_library=0
    revision=
    while (($#)); do
      case "$1" in
        --output) output=$2; shift 2 ;;
        --library) has_library=1; shift 2 ;;
        --revision) revision=$2; shift 2 ;;
        *) shift ;;
      esac
    done
    if [[ "$has_library" == 1 ]]; then
      [[ "$revision" == "$TEST_EXPECTED_REVISION" ]] || { echo "platform gem revision changed: $revision" >&2; exit 1; }
      printf '%s\n' "$revision" >"$TEST_REVISION_RESULT"
    fi
    mkdir -p "$output"
    : >"$output/emf-1.0.0.gem"
    ;;
  */check_native_package|*/native_install_smoke)
    ;;
  -rrubygems/gem_runner)
    record install
    [[ "$GEM_HOME" == "$TEST_EXPECTED_HOME" ]] || { echo "install GEM_HOME changed: $GEM_HOME" >&2; exit 1; }
    ;;
  */installed_workload.rb)
    record workload
    [[ "$GEM_HOME" == "$TEST_EXPECTED_HOME" && "$PWD" == "${TEST_EXPECTED_HOME%/gem-home}" ]] || { echo "workload path changed: GEM_HOME=$GEM_HOME cwd=$PWD" >&2; exit 1; }
    printf 'installed gem: fake\ndiscovery fake\n'
    ;;
  */availability_matrix.rb)
    record availability
    [[ "$GEM_HOME" == "$TEST_EXPECTED_HOME" && "$PWD" == "${TEST_EXPECTED_HOME%/gem-home}" ]] || { echo "availability path changed: GEM_HOME=$GEM_HOME cwd=$PWD" >&2; exit 1; }
    library=
    while (($#)); do
      if [[ "$1" == --library ]]; then library=$2; shift 2; else shift; fi
    done
    [[ "$library" == "$TEST_EXPECTED_LIBRARY" ]] || { echo "relative library passed: $library" >&2; exit 1; }
    printf 'availability fake\n'
    ;;
  *) echo "unexpected fake ruby invocation: $*" >&2; exit 2 ;;
esac
RUBY
cat >"$tmp/bin/gem" <<'GEM'
#!/usr/bin/env bash
exit 0
GEM
chmod +x "$tmp/bin/ruby" "$tmp/bin/gem"

run_case() {
  local script=$1 expected_status=$2 revision_mode=${3:-override} caller="$tmp/caller"
  local expected_out="$caller/relative-output/real"
  local expected_home="$expected_out/gem-home"
  local expected_library="$caller/relative-library/libemf_ffi.so"
  local expected_revision=github-sha-fixture
  local result
  if [[ "$revision_mode" == override ]]; then expected_revision=release-sha-fixture; fi
  : >"$tmp/records"
  : >"$tmp/revision-result"
  mkdir -p "$caller/relative-output"
  if (
    cd "$caller"
    export PATH="$tmp/bin:$PATH"
    export TEST_RECORD="$tmp/records" TEST_RUBY_PATH="$tmp/bin/ruby"
    export TEST_EXPECTED_HOME="$expected_home" TEST_EXPECTED_LIBRARY="$expected_library"
    export TEST_EXPECTED_REVISION="$expected_revision" TEST_REVISION_RESULT="$tmp/revision-result"
    export GITHUB_SHA=github-sha-fixture
    unset EMF_RELEASE_REVISION
    if [[ "$revision_mode" == override ]]; then export EMF_RELEASE_REVISION=release-sha-fixture; fi
    EMF_REAL_LIBRARY=relative-library/libemf_ffi.so bash "$script" fake-target ruby relative-output
  ) >"$tmp/run.log" 2>&1; then
    result=0
  else
    result=$?
  fi
  if [[ "$result" != "$expected_status" ]]; then
    cat "$tmp/run.log" >&2
    echo "expected exit $expected_status, got $result for $script" >&2
    return 1
  fi
  if [[ "$expected_status" == 0 ]]; then
    [[ "$(cat "$tmp/revision-result")" == "$expected_revision" ]]
    grep -F "install|$expected_home|$expected_out/stage|" "$tmp/records" >/dev/null
    grep -F "workload|$expected_home|$expected_out|" "$tmp/records" >/dev/null
    grep -F "availability|$expected_home|$expected_out|" "$tmp/records" >/dev/null
    [[ $(wc -l <"$tmp/records" | tr -d ' ') == 3 ]]
    grep -F 'installed_workload=ok' "$expected_out/summary.txt" >/dev/null
    grep -F 'availability_matrix=ok' "$expected_out/summary.txt" >/dev/null
  fi
}

run_case "$script_under_test" 0 override
run_case "$script_under_test" 0 fallback

# Mutation controls: removing either actual normalization callsite must break this regression.
# shellcheck disable=SC2016  # these sed expressions intentionally match literal shell syntax
sed -e '/^out=\$(absolute_path/d' \
  -e "s|^here=.*$|here=\"$script_dir\"|" "$script_under_test" >"$tmp/no-output-normalization.sh"
# shellcheck disable=SC2016  # this sed expression intentionally replaces the normalization call
sed -e 's|^  lib=\$(absolute_path.*$|  :|' \
  -e "s|^here=.*$|here=\"$script_dir\"|" "$script_under_test" >"$tmp/no-library-normalization.sh"
run_case "$tmp/no-output-normalization.sh" 1
run_case "$tmp/no-library-normalization.sh" 1

# The former GITHUB_SHA-only command must fail when release revision differs.
# shellcheck disable=SC2016  # replace the revision expansion with the former command
sed -e 's|${revision:+--revision "$revision"}|${GITHUB_SHA:+--revision "$GITHUB_SHA"}|' \
  -e "s|^here=.*$|here=\"$script_dir\"|" "$script_under_test" >"$tmp/github-sha-only.sh"
run_case "$tmp/github-sha-only.sh" 1 override

echo "real_row relative output and library paths reach install/workload/availability unchanged"
echo "removing either real_row normalization callsite makes the regression fail"
echo "platform gem revision honors EMF_RELEASE_REVISION and falls back to GITHUB_SHA"
echo "the former GITHUB_SHA-only revision command fails when the release override differs"
