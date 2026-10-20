# Issue #15 slow-workload baseline

Issue #15 says one emfsvg round-trip fixture takes about 12 seconds. This baseline
looked for that fixture with the Ruby backend. It names the slowest candidates on
one recorded machine. It **does not reproduce an exact 12-second case**: the
nearest round trips under the released gem take 15.9 s and 17.9 s, and one takes
88 s. The reported fixture's identity stays unknown. Native and head-to-head
speed criteria remain open.

## Revision, machine and commands

| Item | Value |
| --- | --- |
| Source revision | `b81d6aa0bbfce22bab1a0ef12565c41f154b720c` (local integration head) |
| Machine | Apple M2, 8 cores, 8 GiB, macOS 26.5.1 arm64 |
| Ruby | 3.4.8 (arm64-darwin25), BinData 2.5.1 |
| Backend | `EMF_BACKEND=ruby` |
| Consumer | emfsvg `101356dcf673841fda0693076131bca7a0f34948`, `/private/tmp/emfsvg-issue15-baseline` |
| Date | 2026-10-20, load average about 3.5 to 5.3 throughout |

Each fixture ran in a fresh process, one after another, with file IO outside the
timed region. "CPU" is process CPU time; RSS is the process after the fixture.

```sh
# emf parse and serialize, one fixture per process
EMF_BACKEND=ruby bundle exec ruby -Ilib p07_baseline.rb spec/fixtures/emf/test-031.emf
# emfsvg conversion and round trip, run from the consumer checkout
EMF_BACKEND=ruby bundle exec ruby -I<emf>/lib -Ilib emfsvg_trial.rb <emf> <golden svg>
```

The scripts, JSON rows and machine record are local evidence in
`/private/tmp/emf-execution/p07-slow-workload/`; they are not checked in.

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
and run identity are local evidence in
`/private/tmp/emf-execution/p07-consumer-acceptance/`.

## Open

- The native backend measurements over the same fixtures need a library built
  from the final head; the build hold blocks them.
- The calibrated runner, noise policy and the under-one-second target are still
  open, as described in [the downstream evidence](downstream-comparison.md) and
  `TODO.plan/07-performance.md`.
