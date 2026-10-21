# Issue #15 slow-workload baseline

Issue #15 says one emfsvg round-trip fixture takes about 12 seconds. This baseline
looked for that fixture with the Ruby backend. It names the slowest candidates on
one recorded machine. It **does not reproduce an exact 12-second case**: the
nearest round trips under the released gem take 15.9 s and 17.9 s, and one takes
88 s. The reported fixture's identity stays unknown.

**Current state.** The under-one-second round trip is **unmet**. The latest
whole-consumer Ruby result for `test-031` is 9.20 s process CPU at `3108916`
(integrated as `a65eac7` on `main`), down from 16.59 s at `d93967d`. Of that,
about 3.7 s is emf and about 5.4 s is emfsvg's own SVG parsing, emission and
rendering, so removing all emf time would still leave more than one second.
Native parse is faster than Ruby at `666f45d` (PR #54, open, not on `main`).
Native conversion was slower than Ruby at `5c45ab9` and has no measurement at
`666f45d`. Details are in [the downstream evidence](downstream-comparison.md).

## Revision, machine and commands

| Item | Value |
| --- | --- |
| Source revision | `b81d6aa0bbfce22bab1a0ef12565c41f154b720c` (local integration head) |
| Machine | Apple M2, 8 cores, 8 GiB, macOS 26.5.1 arm64 |
| Ruby | 3.4.8 (arm64-darwin25), BinData 2.5.1 |
| Backend | `EMF_BACKEND=ruby` |
| Consumer | emfsvg `101356dcf673841fda0693076131bca7a0f34948` (clean checkout) |
| Date | 2026-10-20, load average about 3.5 to 5.3 throughout |

Each fixture ran in a fresh process, one after another, with file IO outside the
timed region. "CPU" is process CPU time; RSS is the process after the fixture.

```sh
# emf parse and serialize, one fixture per process
EMF_BACKEND=ruby bundle exec ruby -Ilib p07_baseline.rb spec/fixtures/emf/test-031.emf
# emfsvg conversion and round trip, run from the consumer checkout
EMF_BACKEND=ruby bundle exec ruby -I<emf>/lib -Ilib emfsvg_trial.rb <emf> <golden svg>
```

The scripts, JSON rows and machine record are execution artifacts; they are not
checked in.

## emf parse and serialize, all 208 valid fixtures

All 208 fixtures in `spec/fixtures/{emf,emf-ea,simple}` parsed with no error, and
every serialize was byte-identical. Parse took 21.1 s of CPU in total and
serialize 4.5 s. Only three fixtures took more than one second.

| Fixture | Bytes | Records | Parse CPU ms | Serialize CPU ms | RSS MiB | SHA-256 prefix |
| --- | --- | --- | --- | --- | --- | --- |
| `emf/test-178.emf` | 1860368 | 41749 | 1584.2 | 525.0 | 145 | `f6d603344821023f` |
| `emf/test-031.emf` | 1512544 | 79055 | 1552.3 | 463.3 | 173 | `6aae9ce8e4702619` |
| `emf/test-105.emf` | 1124756 | 52160 | 1002.3 | 228.0 | 128 | `69f792fa07775b22` |
| `emf/test-172.emf` | 554192 | 37772 | 534.2 | 95.3 | 75 | `c9bb3eb16cb43151` |
| `emf/test-108.emf` | 497228 | 28581 | 498.1 | 100.0 | 73 | `9bcce68e823f31ed` |
| `emf/test-176.emf` | 507968 | 12515 | 424.0 | 156.7 | 62 | `c73e79b7cf3212f0` |
| `emf/test-150.emf` | 445676 | 11944 | 384.6 | 112.5 | 64 | `d39599429b98eeec` |
| `emf/test-069.emf` | 399552 | 21433 | 375.0 | 83.1 | 66 | `717b3a6b2ce57f3f` |

So emf parsing alone cannot be the 12-second workload on this machine. The
consumer round trip is where the time goes.

## emfsvg round trip, six candidates

The six candidates are the slowest emf fixtures plus the largest golden SVGs. Each
row times three wall-clock phases in one process:
- `Emfsvg.from_bytes` on the emf fixture;
- `Emfsvg.from_svg` on the matching `spec/fixtures/emfsvg_golden` SVG;
- `Emfsvg.from_bytes` on the EMF that the second phase produced.

**Released gem, emf 0.1.0, which the consumer bundle resolves:**

| Fixture | emf to SVG | SVG to emf | emf to SVG again | Round-trip total | RSS MiB |
| --- | --- | --- | --- | --- | --- |
| `test-031` | 7.2 s | 45.4 s | 35.7 s | 88.4 s | 864 |
| `test-172` | 1.8 s | 9.2 s | 6.9 s | 17.9 s | 1023 |
| `test-105` | 3.2 s | 7.3 s | 5.4 s | 15.9 s | 813 |
| `test-108` | 1.5 s | 3.7 s | 2.4 s | 7.6 s | 542 |
| `test-178` | 4.6 s | 0.5 s | 0.0 s | 5.1 s | 907 |
| `test-176` | 1.1 s | 0.6 s | 0.2 s | 1.8 s | 283 |

**This revision, with `-I<emf>/lib` ahead of the bundle; the loaded path was checked:**

| Fixture | emf to SVG | SVG to emf | emf to SVG again | Round-trip total | RSS MiB |
| --- | --- | --- | --- | --- | --- |
| `test-172` | 1.1 s | 5.4 s | 2.7 s | 9.2 s | 307 |
| `test-031` | 3.6 s | fails | not run | not run | 233 |
| `test-178` | 3.0 s | fails | not run | not run | 215 |
| `test-105` | 1.8 s | fails | not run | not run | 171 |
| `test-108` | 0.8 s | fails | not run | not run | 102 |
| `test-176` | 0.8 s | fails | not run | not run | 94 |

**Measured findings**
- No candidate takes about 12 s, so the issue's fixture is not identified here.
  `test-105` (15.9 s) and `test-172` (17.9 s) are the nearest. `test-031` (88.4 s)
  is far beyond the stated case. The issue's machine is unknown, so any of these
  could be it.
- The consumer's SVG-to-emf phase and the re-parse of its output dominate the
  round trip, not the first parse.
- On the one candidate that completes on this revision, `test-172`, the round
  trip falls from 17.9 s to 9.2 s and RSS from 1023 MiB to 307 MiB against the
  released gem.
- **Blocker:** on this revision, `Emfsvg.from_svg` fails for every golden SVG
  with text, with `BinData::ValidityError: font body does not match record size`.
  - The error comes from `lib/emf/emr/binary/font.rb`.
  - The consumer builds `CreateFontIndirectW` with a raw body and serializes it
    before setting `n_size`.
  - The size check came in with commit `4030443`, which reached main through
    PR #32.
  - The released 0.1.0 accepts the same call.
  - Until this is fixed, issue acceptance criterion 3 (the round-trip suite stays
    green) fails, and no current-revision round-trip timing exists for five of
    the six candidates.
  - Fixed by commit `0e25e2f`, integrated as `acc2590`: an assigned body keeps its
    size until `n_size` is set, and an explicit size is still validated. The run
    below confirms it.

## emfsvg round-trip golden suite, all 208 fixtures

The pinned consumer's `spec/round_trip_golden_spec.rb` ran once against
integration head `9dce2d6ff88791c000ae9db86d9f5592d16e114a`. The run used the
same machine, with `EMF_BACKEND=ruby`, and the loaded path was checked as this
checkout's `lib/emf.rb`. It ran in an exclusive window, from 16:30:41Z to
16:34:54Z.

```sh
RUBYOPT=-I<emf>/lib EMF_BACKEND=ruby bundle exec rspec spec/round_trip_golden_spec.rb \
  --format json --out round-trip-golden.json --format progress
```

| Outcome | Count |
| --- | --- |
| Examples | 209 (208 fixtures plus the regression-floor example) |
| Failures | 0 (exit status 0) |
| Byte-equal round trips | 9 |
| Pending, "round-trip not yet byte-equal" | 199 |
| Wall time, peak RSS | 248.8 s, 616 MiB |

- The 9 byte-equal fixtures are `test-023`, `test-030`, `test-038`, `test-124`,
  `test-155`, `test-161`, `test-162`, `test-163` and `test-181`.
- The regression-floor example passes.
- No fixture raises any more: the font error above is gone from every golden SVG
  with text.
- The pending outcomes are how the consumer itself classifies SVG features it
  does not yet round-trip byte for byte. They are not emf failures.
- The slowest round trips are `test-031` (20.0 s), `test-172` (9.2 s) and
  `test-105` (7.3 s). Against the released gem those took 88.4 s, 17.9 s and
  15.9 s in the six-candidate trial above. That trial measured three phases per
  fixture, so the figures compare in order of magnitude only.
- 70 of the 208 fixtures take more than one second.
- Not checked: whether the released gem round-trips any additional fixture
  byte-equal. That would need a second full run against 0.1.0, which was not
  run.

The JSON report (SHA-256 `c7cd1c3cae0d0b5d...`), progress log, `time -l` output
and run identity are execution artifacts, not checked in.

## Where the round-trip time goes, and the first fix

A single profiled run of the `test-031` consumer round trip at `d93967d`, with
the Ruby backend, took 19.4 s of CPU:
- `Emfsvg.from_svg` took 12.2 s: the SVG parse 0.7 s, the record build 10.3 s
  (about 61% of it inside emf), and `Emf.serialize` 1.2 s.
- `Emfsvg.from_bytes` took 6.6 s: `Emf.parse` 4.35 s and the SVG render 2.25 s.

About 62% of the round trip is inside emf. The EMF the consumer emits has 194,122
records, and 174,646 of them are fixed-layout types on the fast-fill path. The
largest single cost was BinData instantiating each leaf on first access inside
the fast fill.

Commit `de722ac` (integrated as `3498507`) generates the fill and pack code for
each class and clones an already-instantiated template record. On the emitted
file, `Emf.parse` fell from 4.5 s to 2.2 s and `Emf.serialize` from 1.24 s to
0.67 s (medians of 3 alternating runs). Every one of the 174,646 records matched
a plain BinData read in snapshot and bytes.

The template copy reads BinData internals. It was verified on BinData 2.5.1 only,
while the gemspec allows `~> 2.4`.

Representative series: baseline `54230f8`, candidate `228f404`, Ruby backend,
same machine, load average 5 to 9 (an editor process was using one core).
`bench/emfsvg.rb` ran 1 warmup and 5 samples; `bench/parser.rb` ran 1 warmup
and 3 to 5 samples. That is fewer than the policy's 5 and 20, because each
fixture child is capped at 60 s. These are informational medians, not a
calibrated baseline.

| Fixture | Workload | Baseline | Candidate |
| --- | --- | --- | --- |
| `test-031` | emfsvg `from_bytes` (golden identical) | 3476 ms | 2156 ms |
| `test-105` | emfsvg `from_bytes` (golden identical) | 1833 ms | 1225 ms |
| `test-172` | emfsvg `from_bytes` (golden identical) | 1085 ms | 807 ms |
| `test-031` | emf `parse_to_serialize` | 2881 ms (1 sample; 3 samples exceeded the 60 s cap) | 1567 ms |
| `test-105` | emf `parse_to_serialize` | 1453 ms (1 sample) | 820 ms |
| `test-172` | emf `parse_to_serialize` | 681 ms | 227 ms |

First wire traversal on `test-172` measured 161 ms at the baseline and 187 ms on
the candidate, inside this run's noise but recorded so it is not lost.

**Under-one-second target: not met.** Even after this change, emf-side parse of
the consumer's emitted file is about 2.2 s, and the consumer record build is
still about 6 s of emf wire construction. The next measured step is cheaper wire
construction from attributes, which the consumer uses for every record it emits.
Reaching under one second also needs the native backend. A native conversion
measurement was later taken at `5c45ab9`, not at this revision; see the downstream
evidence.

## Authorized CPU comparison of today's changes

This was a sequential Ruby-only run, authorized as a bounded timing slot and
announced in the shared handoff. It compared the baseline `d93967d`, before
today's fast paths, with the candidate `b12f4bd`. The candidate includes the
fast-fill template, keyword construction, nested assign, the BinData guard,
32-bit and 16-bit point records, and ExtTextOutA/W. Baseline and candidate ran
alternately, 3 times each, one fresh process per run, on the same machine
(Apple M2, 8 GiB, Ruby 3.4.8, `EMF_BACKEND=ruby`). Load average was 13 to 23
throughout, so read the figures as order of magnitude. Every output was
identical: emitted EMF `bc1437fa9a34`, SVG `787b5f25eb01`, and every
`Emf.serialize` byte-identical.

| Workload (process CPU, median of 3) | Baseline `d93967d` | Candidate `b12f4bd` | Change |
| --- | --- | --- | --- |
| emfsvg round trip `test-031`, `from_svg` | 11.46 s | 6.49 s | -43% |
| emfsvg round trip `test-031`, `from_bytes` | 5.60 s | 2.93 s | -48% |
| emfsvg round trip `test-031`, total | 16.84 s | 9.34 s | -45% |
| peak RSS of the round-trip process | 585 MiB | 416 MiB | -29% |
| `Emf.parse` `test-031.emf` | 1618 ms | 618 ms | -62% |
| `Emf.serialize` `test-031.emf` | 491 ms | 173 ms | -65% |
| `Emf.parse` `test-178.emf` | 1566 ms | 671 ms | -57% |
| `Emf.serialize` `test-178.emf` | 532 ms | 257 ms | -52% |

The round trip's allocations fell from 52.9 M to 27.1 M objects, measured
separately and deterministically.

**Verdict on the under-one-second target: not met.** The slowest consumer round
trip takes about 9.3 s of CPU with the Ruby backend. emf parse and serialize of
`test-031.emf` alone now take about 0.8 s, which is under one second for emf's
own work on that fixture. The rest of the round trip is mostly the consumer's
own SVG parsing, emission and rendering, plus emf wire construction for 194k
emitted records. Closing the end-to-end target needs consumer-side changes or
the native backend. No native measurement exists at this revision; later native
results are in the downstream evidence.

The run's commands, scripts and raw output are execution artifacts, not
checked in.

## Final whole-consumer result with generated construction

Commit `3108916` adds a generated build method per class for keyword
construction. The microbenchmark below and the whole-consumer result after it
are kept apart: the first does not imply the second.

- **Construction microbenchmark.** This covers all 194,122 attribute sets the
  consumer passes for `test-031`. `Klass.new(**attrs)` plus `to_binary_s` fell
  from 2621 to 1712 ms, a 34.7% cut and the median of 3 alternating runs. Snapshot,
  BinData-writer bytes and `num_bytes` matched on every set, with 0 mismatches.
- **Whole consumer workload.** The emfsvg `test-031` round trip ran 3 times on
  each side, alternating baseline `d93967d` with candidate `3108916`. Every run
  was a fresh process with `EMF_BACKEND=ruby`. Output hashes were identical in
  every run.
  - The baseline was re-run in this session instead of reusing the earlier runs,
    because macOS Spotlight indexing was loading the machine (load average 14 to
    18). Pairing the runs keeps baseline and candidate under the same conditions.

| Round trip `test-031` | Baseline `d93967d` | Candidate `3108916` |
| --- | --- | --- |
| process CPU, median of 3 | 16.59 s | 9.20 s (-45%) |
| wall clock, median of 3 | 17.6 s | 10.4 s |
| peak RSS, median of 3 | 586 MiB | 419 MiB |

The generated build does not move the whole round trip measurably beyond
`b12f4bd` (9.34 s above). Its construction gain is real, but it falls inside
this machine's run-to-run noise at the whole-workload level.

**Remaining split.** One run on `3108916`, with non-nested timers that inflate
the totals slightly: emf accounts for 3.7 s of about 9.1 s, roughly 40%.

| emf part | CPU |
| --- | --- |
| `Emf.parse` of the 194,122-record EMF the consumer emits | 1.39 s |
| `Record.new` | 1.14 s |
| `Record#to_binary_s` (the consumer's `n_size` pass) | 0.54 s |
| `Emf.serialize` | 0.45 s |
| `WireAdapter.new` | 0.16 s |

The other 5.4 s is the consumer's own SVG parsing, emission and rendering.

**Verdict: the under-one-second target is not met** with the Ruby backend
(9.2 s). Even if emf's share fell to zero, the consumer side alone would still be
over five seconds. The remaining emf-owned lever is the per-record parse path.
The `n_size` pass serializes every record a second time, and changing that is a
consumer change. The roughly 12-second workload from the issue remains
unidentified. The native backend was not measured at `3108916`; native conversion
was measured only at `5c45ab9`, and native parse at `666f45d`.

Evidence: the run's `final-3108916.txt`, `split-3108916.txt`, `rt_cpu.rb` and
`split.rb` artifacts, not checked in.

## Open

- Native conversion on the final Ruby-measured head (`3108916`, on `main` as
  `a65eac7`) is not measured. The last native conversion measurement is at
  `5c45ab9`. Native parse is measured at `666f45d` (PR #54, open, not on `main`).
- The calibrated runner, noise policy and the under-one-second target are still
  open, as described in [the downstream evidence](downstream-comparison.md) and
  `TODO.plan/07-performance.md`.
