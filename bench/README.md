# Parser stage baseline

Measures public parser stage timings per fixture and writes one JSON file. Ruby is the default backend; native runs must be explicitly selected. These measurements do not establish a native speedup.

```sh
bundle exec ruby bench/parser.rb --manifest spec/fixtures/manifest.json --backend ruby --output tmp/bench/ruby.json
```

| Option | Default | Meaning |
| --- | --- | --- |
| `--backend NAME` | `ruby` | Forced backend: `ruby` or `native` |
| `--iterations N` / `--warmups N` | 20 / 5 | Timed and discarded trials per fixture |
| `--fixture GLOB` | all | Manifest path glob (`File.fnmatch`), repeatable |
| `--limit N` | none | Keep the first N selected fixtures |
| `--outcomes LIST` | `parsed` | Manifest outcomes to run (`parsed,recovered,format_error`) |
| `--cold-runs N` | 3 | Fresh-process cold-load runs |
| `--timeout SECONDS` | 120 | Deadline for each fixture child |

For native runs, point to the exact compiled library being measured:

```sh
EMF_NATIVE_LIBRARY=/absolute/path/to/libemf_ffi.dylib bundle exec ruby bench/parser.rb --manifest spec/fixtures/manifest.json --backend native --output tmp/bench/native.json
```

The selected backend is forced in every warm and cold child, regardless of the
caller's `EMF_BACKEND`. Unknown backend names exit with status 2 and write nothing.
Missing native libraries and unsupported records fail the run without Ruby fallback.
The `native_library` report records the configured and resolved paths, SHA-256,
size and modification time when readable. Build profile and compiler remain null:
the library exposes no build metadata, so a filename does not establish a release build.
The exit status is 1 when any warm or cold fixture child failed, timed out or produced an invalid
result (the JSON is still written with a `failures` list).

## What is measured

Each fixture runs in its own child process with an external deadline and a bounded
output pipe, so a corrupt input cannot crash or hang the run. By default only
manifest-`parsed` fixtures run; include the others with `--outcomes`.
Cold loading runs in separate fresh children (`cold_load`), apart from the warm
trials. Times are `CLOCK_MONOTONIC` nanoseconds, with `GC.start` before each stage
outside the timed region.

Stages: `detect_format`, `parse`, `wire_first_traversal`, `wire_repeated_traversal`,
`dump`, `serialize`, `parse_to_serialize`, `parse_file` (the only stage that includes
file IO). Definitions are in the output's `method.stages`.

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
