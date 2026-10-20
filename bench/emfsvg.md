# Downstream conversion baseline

Run from this repository, with the consumer's runtime gems installed and `fc-match`
available on PATH:

```sh
EMFSVG_PATH=/path/to/emfsvg ruby bench/emfsvg.rb \
  --manifest spec/fixtures/manifest.json --backend ruby \
  --output tmp/bench/emfsvg-ruby.json
```

The default consumer commit is `101356dcf673841fda0693076131bca7a0f34948`.
`--revision SHA` selects another explicit pin. A different HEAD or tracked consumer
changes exits 2 before measurements. Both `--backend ruby` and `--backend native`
force that parser backend in every warm and cold child, overriding `EMF_BACKEND`.
For native conversion, supply the library explicitly:

```sh
EMFSVG_PATH=/path/to/emfsvg EMF_NATIVE_LIBRARY=/path/to/libemf_ffi.dylib \
  ruby bench/emfsvg.rb --manifest spec/fixtures/manifest.json \
  --backend native --output tmp/bench/emfsvg-native.json
```

An unavailable library, unsupported input or conversion error fails the run with
exit 1 and a reported child error; native never falls back to Ruby. The adapter
never updates golden files. It shares the parser benchmark's manifest selection,
iteration, warmup, cold-run, timeout and output controls; see [README.md](README.md).
For a small trial, add `--fixture 'spec/fixtures/simple/*' --iterations 2 --warmups 0
--cold-runs 1`. The default is 20 timed samples after five discarded warmups.

Each fixture has a bounded child process. `from_bytes` measures parsing and SVG
rendering using bytes read outside the timed region; `from_file` includes the file
read. Every result must equal the pinned consumer's golden SVG bytes. Comparison
and forced GC occur outside timing. Allocations and sampled process memory follow
the parser harness's documented limitations. Cold runs separately report library
loading and first conversion calls. Cold failures also make the command exit 1.
Missing goldens are an input error rather than silently skipped fixtures.

Children run outside Bundler with this repository's `lib` and the consumer's `lib`
explicitly on the load path. They verify the resolved `Emf.parse` and
`Emfsvg.from_bytes` source files. The report includes consumer revision and source
digest, parser revision/source digest, input manifest and fixture hashes, golden
hashes, Ruby/OS/CPU metadata, resolved source paths, and actual loaded gem versions.
Native reports also identify the selected library path, SHA-256 and size; build
profile and compiler remain unknown because the library exposes no build metadata.
Native parsing, ABI snapshot transfer, Ruby model/wire hydration and SVG rendering
share each conversion's timed region. Native adapter loading is included; Ruby
allocation counts exclude Rust allocations. These are complete conversion timings,
not isolated Rust parsing timings.
Installed runtime gems must be supplied by the caller; this adapter does not resolve
or validate the consumer gemspec constraints. To reproduce a run, provision the
reported runtime gems and external font environment. In particular, font lookup
uses PATH and installed fonts, so golden checks can expose environment differences.

This measures the EMF-to-SVG golden workload, not SVG-to-EMF round-trip coverage.
Run the unmodified consumer specs separately from the consumer checkout, supplying
this repository as the parser dependency:

```sh
ruby -I /path/to/emf/lib -I lib -S rspec \
  spec/golden_spec.rb spec/round_trip_spec.rb spec/round_trip_golden_spec.rb \
  --format json --out /path/to/downstream-specs.json
```

The result identifies the slowest selected conversion; it does not identify the
unrecovered roughly 12-second workload. No timing threshold or speed claim follows
from a small trial.

## Compare saved backend reports

After saving one Ruby and one native report, compare them with:

```sh
ruby bench/compare_emfsvg.rb \
  --ruby tmp/bench/emfsvg-ruby.json \
  --native tmp/bench/emfsvg-native.json \
  --output tmp/bench/emfsvg-comparison.json
```

The comparator accepts only successful, well-formed schema-v1 conversion reports:
their failure lists must be empty, each selected fixture must have passed its
golden check, and each stage must contain the requested number of valid samples.
It rejects reports unless parser revision and source, manifest and selected
fixtures, consumer revision/source and clean tracked state, golden inventory,
resolved worker sources, Ruby/OS/host environment, runtime gems, and benchmark
method are compatible. The Ruby report may omit the `fiddle` gem that is needed
by the native report. Incompatible, malformed, missing, or failed reports exit 2
and do not produce a comparison.

Each stage reports median times and `native_over_ruby_time`, calculated as the
native median divided by the Ruby median. Values below 1 mean the native median
was lower for that stage; values above 1 mean it was higher. The allocation ratio
uses the same native-over-Ruby direction, and is null when the Ruby allocation
baseline is zero. Allocation counts are Ruby object counts and exclude Rust
allocations; they do not measure total allocation or memory use. The output is
informational: small or concurrent trials remain descriptive and support no
calibrated threshold or speed claim.
