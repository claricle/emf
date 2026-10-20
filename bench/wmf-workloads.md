# Synthetic WMF workloads

Generate repeatable WMF inputs for correctness checks and future parser benchmark
runs:

```sh
bundle exec ruby bench/wmf_workloads.rb --output-dir /tmp/emf-wmf-workloads --repetitions 100
```

The command prints the path to `workload-manifest.json`. Repetitions must be an
integer from 1 through 10,000; the default is 100. Keep generated output outside
the checked-in fixture inventory.

Each run writes standard and Aldus placeable variants of four families:

| Family | Repeated content | Purpose |
| --- | --- | --- |
| `geometry` | MoveTo and LineTo | Signed coordinates and typed geometry |
| `text` | TextOut | Text bytes, padding and signed positioning |
| `bitmap` | DibStretchBlt with a small DIB | Bitmap record framing and image bytes |
| `unknown` | Unknown function `0x80FE` | Full function identity and opaque payload preservation |

All files contain EOF. Header word counts, maximum record size and placeable
checksums are generated from their contents. These are synthetic test inputs;
they provide neither licensed application samples nor independent rendering
evidence.

The manifest records each relative filename, SHA-256, size in bytes, family,
repetition count, container variant and synthetic provenance. Resolve file paths
relative to the manifest directory. Generate one directory and use those exact
bytes for both backends; retain the manifest with any resulting measurements.
Repetitions change workload size, so compare matching repetition counts and hashes.

The workload manifest is an input inventory, separate from the existing fixture
manifest schema. It is not accepted directly by `bench/parser.rb`. The current
stage runner assumes every record exposes an EMF `wire.snapshot`, which WMF
models do not expose, and its mutation stage targets EMF SetMapMode. Benchmark
integration must define the WMF traversal and mutation stages and adapt the input
inventory through the existing supervised runner before claiming WMF timings.

Focused checks exercise Ruby and native parsing, exact unchanged serialization
and typed edits. They establish input validity and preservation, not throughput,
memory limits, speedup or completion of the format inventory. See the broader
[performance plan](../TODO.plan/07-performance.md) and
[format extension acceptance](../TODO.plan/09-format-extension.md).
