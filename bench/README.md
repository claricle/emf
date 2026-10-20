# Parser stage baseline

Measures public parser stage timings per fixture and writes one JSON file. Ruby is the default backend; native runs must be explicitly selected. These measurements do not establish a native speedup.

```sh
bundle exec ruby bench/parser.rb --manifest spec/fixtures/manifest.json --backend ruby --output tmp/bench/ruby.json --rss-limit-mb 512
```

| Option | Default | Meaning |
| --- | --- | --- |
| `--backend NAME` | `ruby` | Forced backend: `ruby` or `native` |
| `--iterations N` / `--warmups N` | 20 / 5 | Timed and discarded trials per fixture |
| `--fixture GLOB` | all | Manifest path glob (`File.fnmatch`), repeatable |
| `--limit N` | none | Keep the first N selected fixtures |
| `--outcomes LIST` | `parsed` | Manifest outcomes to run (`parsed,recovered,format_error`) |
| `--cold-runs N` | 3 | Fresh-process cold-load runs |
| `--rss-limit-mb MB` | required | RSS ceiling for each child process group, in MiB; measure the target runner, there is no default |
| `--timeout SECONDS` | 60 | Deadline for each fixture child, 1 to 60 |

For native runs, point to the exact compiled library being measured:

```sh
EMF_NATIVE_LIBRARY=/absolute/path/to/libemf_ffi.dylib bundle exec ruby bench/parser.rb --manifest spec/fixtures/manifest.json --backend native --output tmp/bench/native.json --rss-limit-mb 512
```

The selected backend is forced in every warm and cold child, regardless of the
caller's `EMF_BACKEND`. Unknown backend names exit with status 2 and write nothing.
Missing native libraries and unsupported records fail the run without Ruby fallback.
The `native_library` report records the configured and resolved paths, SHA-256,
size and modification time when readable. Build profile and compiler remain null:
the library exposes no build metadata, so a filename does not establish a release build.
The exit status is 1 when any warm or cold fixture child failed, timed out, exceeded the RSS ceiling or produced an invalid
result (the JSON is still written with a `failures` list).

## CI smoke benchmark

The single-runner [parser benchmark workflow](../.github/workflows/parser-benchmark.yml)
builds the locked Rust release library, then saves forced Ruby and native reports
for `spec/fixtures/simple/image1.emf` under `tmp/bench/`. It uses 3 iterations,
1 warmup, 1 cold run, a 60-second per-fixture deadline and a 2048 MiB
child-process-group RSS ceiling. Manifest capture uses the same RSS ceiling
and a 15-second deadline. The native run sets
`EMF_NATIVE_LIBRARY` to `emf-rs/target/release/libemf_ffi.so`. Both reports are
uploaded as the `parser-benchmark-reports` artifact, including when a benchmark
fails. This small smoke workload checks reportable runs and makes no speedup
claim or timing threshold assertion. The workflow creates and uploads a
single-fixture schema-v2 manifest using the current `FixtureManifest` helpers;
the manifest and reports preserve the fixture and source identity used by both runs.

The equivalent local commands on Linux, after building the native library, are:

```sh
cargo build --release --locked -p emf-ffi --manifest-path emf-rs/Cargo.toml
mkdir -p tmp/bench
bundle exec ruby -Ilib <<'RUBY'
require "json"
require_relative "spec/support/fixture_manifest"
root = Dir.pwd
path = "spec/fixtures/simple/image1.emf"
entry = FixtureManifest.fixtures(root).find { |fixture| fixture.fetch("path") == path }
abort "fixture missing from manifest" unless entry
runner = FixtureManifest::Runner.new(timeout: 15, rss_limit_bytes: 2048 * 1024 * 1024)
observation = runner.call(File.join(root, path))
abort "fixture observation failed: #{observation.inspect}" if observation["safety_failure"]
manifest = {
  "schema_version" => FixtureManifest::SCHEMA_VERSION,
  "capture" => FixtureManifest::CAPTURE_METADATA,
  "backend" => {
    "name" => "ruby",
    "ruby_version" => RUBY_VERSION,
    "bindata_version" => Gem.loaded_specs.fetch("bindata").version.to_s,
    "parser_source_sha256" => FixtureManifest.source_sha256(root)
  },
  "counts" => FixtureManifest.counts([entry]),
  "fixtures" => [entry.merge(observation)]
}
File.write("tmp/bench/manifest-v2.json", JSON.pretty_generate(manifest))
RUBY
bundle exec ruby bench/parser.rb --manifest tmp/bench/manifest-v2.json --backend ruby --fixture spec/fixtures/simple/image1.emf --iterations 3 --warmups 1 --cold-runs 1 --timeout 60 --rss-limit-mb 2048 --output tmp/bench/parser-ruby.json
EMF_NATIVE_LIBRARY="$PWD/emf-rs/target/release/libemf_ffi.so" bundle exec ruby bench/parser.rb --manifest tmp/bench/manifest-v2.json --backend native --fixture spec/fixtures/simple/image1.emf --iterations 3 --warmups 1 --cold-runs 1 --timeout 60 --rss-limit-mb 2048 --output tmp/bench/parser-native.json
```

On macOS, set the native library path to the built `.dylib` instead.

## What is measured

Each fixture runs in its own child process with an external deadline and a bounded
output pipe, so a corrupt input cannot crash or hang the run. By default only
manifest-`parsed` fixtures run; include the others with `--outcomes`.
Cold loading runs in separate fresh children (`cold_load`), apart from the warm
trials. Times are `CLOCK_MONOTONIC` nanoseconds, with `GC.start` before each stage
outside the timed region.

Stages: `detect_format`, `parse`, `wire_first_traversal`, `wire_repeated_traversal`,
`dump`, `serialize`, `mutation_to_serialize`, `parse_to_serialize`, `parse_file` (the only stage that includes
file IO). Definitions are in the output's `method.stages`.

`mutation_to_serialize` measures one representative public wire edit followed by
`Emf.serialize`: the first EMF `SetMapMode` record (type 17) has `wire.map_mode`
changed from 8 to 1, or from any other value to 8. Every warmup and timed trial
starts with a fresh parse of the original bytes outside the timed region. The
timer and allocation count cover the assignment and serialization; candidate
selection, parsing, output hashing and reparsing verification are excluded.
After every edit, the worker checks that serialized bytes changed and that
reparsing preserves the edited value without parse errors. A failed supported
edit fails the fixture. The fixture's `mutation` metadata records the record
index (zero based), type, field, before/after values, edited output SHA-256 and
reparsed value. The existing `serialize`, `parse_to_serialize` and round-trip
validity checks continue to use unchanged models.

Fixtures without an EMF `SetMapMode` record report `mutation.status` and that
stage's `status` as `unsupported`, with a reason, empty timing samples and a null
summary; their other stages still run. This workload covers one scalar EMF wire
edit, not all record families, WMF edits or universal corpus mutation acceptance.

For Ruby, wire parsing and model creation are interleaved in `Emf::Emr::Parser.call`, so they
are not reported separately; `parse` covers both (and runs format detection twice).
`method.inseparable_boundaries` lists this in the output.

For native, `parse` includes backend selection/loading, Rust parsing, ABI snapshot
transfer and Ruby model/wire hydration. These costs are not timed separately.
The current adapter loads on each parse and serialize call; serialization uses the
Ruby serializer. Wire traversal snapshots already hydrated BinData wires. Native
`parse_file` includes the same public parsing costs plus file IO. Fresh-process
first-call timings include initial loading and hydration, separately from warm trials.

`slowest_measured_case` is the slowest fixture in this run by median
`parse_to_serialize`. The roughly 12-second file in issue #15 is not identified, so
that result is never claimed to be it.

Memory is per child: Linux reads `VmRSS`/`VmHWM` from `/proc` (true peak); elsewhere
`ps` RSS is sampled between trials and can miss short spikes. `allocated_objects`
counts Ruby objects, not bytes or Rust allocations.
