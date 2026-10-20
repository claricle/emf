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
changes exits 2 before measurements. Native is unavailable and exits 2. The adapter
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
