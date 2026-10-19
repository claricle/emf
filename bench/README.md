# Parser stage baseline

Measures the Ruby parser's stage timings per fixture and writes one JSON file.

```sh
bundle exec ruby bench/parser.rb --manifest spec/fixtures/manifest.json --backend ruby --output tmp/bench/ruby.json
```

| Option | Default | Meaning |
| --- | --- | --- |
| `--iterations N` / `--warmups N` | 20 / 5 | Timed and discarded trials per fixture |
| `--fixture GLOB` | all | Manifest path glob (`File.fnmatch`), repeatable |
| `--limit N` | none | Keep the first N selected fixtures |
| `--outcomes LIST` | `parsed` | Manifest outcomes to run (`parsed,recovered,format_error`) |
| `--cold-runs N` | 3 | Fresh-process cold-load runs |
| `--timeout SECONDS` | 120 | Deadline for each fixture child |

Only `--backend ruby` exists; any other value exits with status 2 and writes nothing.
The exit status is 1 when any fixture child failed, timed out or produced an invalid
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

Wire parsing and model creation are interleaved in `Emf::Emr::Parser.call`, so they
are not reported separately; `parse` covers both (and runs format detection twice).
`method.inseparable_boundaries` lists this in the output.

`slowest_measured_case` is the slowest fixture in this run by median
`parse_to_serialize`. The roughly 12-second file in issue #15 is not identified, so
that result is never claimed to be it.

Memory is per child: Linux reads `VmRSS`/`VmHWM` from `/proc` (true peak); elsewhere
`ps` RSS is sampled between trials and can miss short spikes. `allocated_objects`
counts Ruby objects, not bytes.
