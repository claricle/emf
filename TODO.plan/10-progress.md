# Delivery progress and handoff

Status: execution plan merged; baseline, Rust core and Ruby integration work in progress.

## Work record

| Package | State | Evidence / remaining work |
| --- | --- | --- |
| 01 Requirements | Baseline documented | Validate contracts through executable oracle in 02 |
| 02 Baseline/parity | In progress | Fixture inventory, API/mutation controls, canonical observation/comparison harness and parser/consumer timing drivers added; reported slow workload and native comparisons pending |
| 03 Rust core | In progress | Checked reader, bounded framing and exact unchanged serialization added; typed header/EOF, scalar state, signed coordinates, color, rectangle, polyline and comment cohorts added; remaining record families and corpus parity pending |
| 04 C ABI | In progress | Versioned interface, owned typed snapshots, boundary tests and linked C client verified locally; full model/edit and platform checks pending |
| 05 Ruby binding | In progress | [R1–R5](05-ruby-execution.md): contracts, dispatch, model adaptation, edited serialization, consumers |
| 06 Resilience | In progress | Ruby subprocess supervisor and Rust budget regressions underway; forced-native corpus and fuzz budgets pending |
| 07 Performance | Not started | Comparable measured end-to-end target and regression budget |
| 08 Platform delivery | In progress | Feasibility probe underway; artifacts, clean installs and complete CI/release integration pending |
| 09 Format extensions | In progress | Bounded Ruby standard/placeable WMF headers, EOF/move/line and raw unknown preservation verified; full WMF and structured EMF+ pending |
| 11 Record coverage | In progress | Header and bounded scalar/coordinate/variable cohorts cross core, ABI and Ruby; color/rectangle and fixed state/path parity verified; remaining registry entries and variants pending |

Documentation of a requirement is not implementation completion. Keep package
states as `Not started`, `In progress`, `Blocked` or `Complete`; a blocked entry
must name the concrete missing input and the next action that can resolve it.

## Execution checkpoints

| Checkpoint | Required output | Exit condition |
| --- | --- | --- |
| Baseline | Shared manifest, canonical comparisons, consumer revision, measured slow case | Oracle is reproducible; remaining contract differences classified |
| Native slice | Header/fixed/variable/raw/EOF/trailing through core, ABI and Ruby | Reads, mutation, errors, lifetimes and full consumption tested; binding design validated |
| EMF coverage | Every registry entry classified with typed-field tests; valid corpus parity | No unexplained model/bytes/dump differences; serializer honors edits |
| Safety and performance | Bounded corrupted corpus; measured complete API and consumer costs | Named corruption and sub-second target evidenced, or delivery gap remains open |
| Distribution | Platform matrix and pure-Ruby gem built and installed in clean environments | All required cells verified without compiler install; both backends tested |
| New formats | WMF/EMF+ supported inventory and documented unknown boundaries | Typed parsing, serialization, safety and consumer evidence meet 09 |
| Issue completion | All requirements linked to passing evidence | No unmet requirement hidden behind a partial milestone |

## Evidence to add as implementation lands

For each package, record the implementation PR and commit, exact command and input
identity, observed result, and remaining gap. Link to durable CI artifacts for
machine-specific benchmark and platform results. Update the relevant coverage rows
and package status in the same PR that changes the implementation. Keep estimates
current when a discovery changes scope or invalidates a baseline assumption.

Use a compact entry per completed substage:

```text
Package / substage:
State:
PR and commit:
Contract or record variants covered:
Checks and input/revision identity:
Observed result:
Remaining acceptance gaps / blocker:
Next action and estimate adjustment:
```

Do not mark a command passed based on an expected result in this plan. A downstream
suite must identify the tested consumer revision and local gem revision. A native
benchmark must identify backend, platform, compiler profile, workload, hydration
and serialization boundaries. Changes after a passing run require affected checks
on the new implementation before the evidence describes that version.

## Next action

Continue [02](02-baseline-and-parity.md): identify the reported slow workload and
retain the pinned downstream baseline as the native compatibility oracle. Use the canonical
oracle and timing drivers for the bounded native slice in [03](03-rust-core.md),
and extend the working [04](04-c-abi.md) / [05](05-ruby-binding.md) slice across
remaining record families. Preserve full-wire parity and mutation checks for each cohort.
The initial estimates in [00](00-overview.md) should be revised after this milestone
and after the integrated native slice.

### Ruby API and mutable wire controls

`bundle exec rspec spec/emf/backend_parity_spec.rb` records the existing Ruby
behavior for EMF detection versus EMF+ model format, header bytes, file API return
values, binary output and format-error messages. Scalar, nested and array edits
are serialized after prior reads and serialization, then reparsed. The controls
also cover wire identity, equality, `eql?`, compatible hashes, type IDs, inspection
and unchanged sibling records.

These are preservation controls for the existing implementation. They do not yet
exercise a native backend or provide the complete canonical observation oracle.
The downstream revision and commands are documented in `bench/emfsvg.md`. The
reported 12-second workload remains unidentified; local samples do not establish
the issue performance target.

### Fixture inventory

`bundle exec ruby script/fixture_manifest` captures every EMF/WMF fixture in
`spec/fixtures/manifest.json`, including source fingerprints, input hashes,
detected format and forced Ruby parse outcome. Each parse runs in a child with a
15-second observation deadline and a 16 KiB output limit. These are capture
limits for recording a baseline, not performance or resource-budget acceptance.
Timeout, process failure and unexpected backend exceptions remain distinct from
format rejection and make the capture unsafe.

The latest 231-fixture capture is **not an accepted baseline**: 221 parsed,
six recovered, two raised format errors and two hit the 15-second child deadline.
Source files were held stable throughout this capture. Both timeouts are 1.5 MB
inputs: `emf/test-031.emf` and `emf-corrupted/bad_corrupted_2014-12-09-002112.emf`.
Preserve these outcomes and investigate their parse cost before accepting the
inventory. Further parser edits require a new source fingerprint and capture.
The timeout cause remains undetermined. An earlier capture also timed out on
seven additional inputs; those failures remain historical observations.

The initial capture contains 229 fixtures: 220 parsed without diagnostics, seven
recovered with diagnostics and two rejected with `Emf::FormatError`. No child
safety failures or unexpected backend exceptions were observed. These counts
describe Ruby outcomes, not a classification of valid versus corrupt input.

`bundle exec ruby script/fixture_manifest --check` validates fixture metadata and
the parser source fingerprint against the saved capture without parsing again.
Regenerate and review the capture after intentional fixture or parser changes.
The capture forces the Ruby backend regardless of the ambient `EMF_BACKEND`
setting and records its observation limits in schema metadata. Prior five-second
captures recorded timeouts; those remain evidence about that capture bound and
are not converted into successful outcomes. The reported performance workload
remains unidentified.

### Canonical observations and timing drivers

`ruby script/backend_observations --output tmp/ruby-observations.json` captures
model and wire fields, ordered diagnostics, binary/float representations, raw
records, trailing bytes, serialization and reparse outcomes. The comparator
reports differing leaf paths and distinguishes missing fields from explicit nil.
Focused coverage includes NaN payloads, signed zero, mutable fields and truncated
record behavior. A full local capture covered 229 inputs: 226 parsed, two raised
format errors and one corrupt input exceeded the 120-second child deadline. All
208 valid inputs serialized identically and reparsed equally. The timeout is an
explicit incomplete observation, not a passing parse result.

`bench/parser.rb` measures Ruby parsing, serialization and full model/wire
consumption with fixture/source identities, subprocess bounds and separately
reported cold loading. `bench/emfsvg.rb` measures real `from_bytes` and `from_file`
calls against consumer commit `101356dcf673841fda0693076131bca7a0f34948`,
checking exact SVG bytes outside timed regions. See `bench/README.md` and
`bench/emfsvg.md` for reproduction and measurement limits. Both drivers propagate
cold-child failures into the command result.

The combined canonical/parser/consumer focused checks passed 34 examples on
commit `14fb505`. Consumer checks use installed runtime gems with explicit load
paths because the local consumer dependency bundle is unresolved. Required CI
and native comparisons remain separate gates.

The pinned consumer baseline completed 424 examples with zero failures and 199
pending: 208 golden examples, seven round-trip examples and ten round-trip golden
checks passed. The pending cases explicitly retain existing non-byte-equal
round trips. The consumer checkout was unchanged. This local classification used
installed runtime gems outside Bundler; installed leptris 1.9.355.0 is below the
consumer requirement of 1.9.365.1, so it does not verify that dependency bundle.

### Rust framing foundation

`emf-rs` contains an independent core with checked little-endian reads, owned
source spans, EMF header decoding, bounded record framing, recoverable tail
diagnostics and exact unchanged serialization. Detection recognizes WMF containers;
WMF parsing remains unsupported. Formatting, Clippy and 28 focused integration
tests passed locally on stable Rust. The initial foundation passed the Rust CI
matrix on Linux stable, Linux Rust 1.73 and macOS stable at commit `274a257`.
Later integrations require their own matrix results.

The typed slice adds header, EOF, SETMAPMODE, POLYLINE and COMMENT models with
checked edits and ordered EMF+ payload extraction. Unchanged unknown bytes are
preserved. Comment growth and shrink rebuild DWORD alignment; EOF edits retain
palette bytes and address the final SizeLast field. The integrated core and typed-snapshot
C ABI passed 49 Rust tests locally at `b34c69b`; strict Clippy also passed. This does not complete all record families,
structured EMF+, corpus parity or full Ruby native model hydration.

### Ruby backend selection

`EMF_BACKEND` selects `auto`, `ruby` or `native` for each parse and serialization
operation. Automatic fallback applies only when native setup is unavailable;
operation errors propagate. Forced Ruby execution avoids loading native support.
Invalid selection raises `ArgumentError`, and forced unavailable native execution
raises `Emf::Native::Unavailable`.

Commit `14fb505` integrates this dispatch with 45 focused policy, API, detector,
CLI and mutable-model examples passing. The initial native adapter is available
when `EMF_NATIVE_LIBRARY` names the compiled
ABI v1 shared library. It hydrates header, EOF, SETMAPMODE, POLYLINE, COMMENT and
unknown raw records from native snapshots without invoking the Ruby parser or
wire readers. Unsupported typed families raise a format error rather than silently
changing the model. Ruby serialization preserves mutable model edits.

`bundle exec rspec spec/emf/native` passed 29 examples under Ruby 3.4 Bundler
at `a077952`, including full-wire canonical equality, forced-native fresh-process use, edits, malformed
record recovery, invalid span rejection and disposal on failures. Four existing
parser examples also passed. Hydration uses checked input spans, removing per-record
C buffer calls. This remains a bounded subset: remaining records, header variants,
full corpus parity and native edited serialization are open.

The local debug measurement consumed every wire for 20 iterations of 1,001 records
(12,128 bytes). Span hydration took 1.303 seconds versus 1.396 seconds before the
change; Ruby controls varied from 0.796 to 0.960 seconds. These noisy debug results
do not establish a Ruby speed advantage or the issue performance target.

### Initial C ABI

The `emf-ffi` crate provides versioned C layouts, owned document, buffer and error
handles, detection, raw record batches and unchanged serialization. Output-reset,
limits, lifecycle and panic-boundary tests accompany a separately compiled C11
client linked to the actual library. Six ABI tests and the C client passed locally
on macOS with stable Rust before integration. The C client is included in CI.

Snapshot v1 now exposes decoded header, EOF, SETMAPMODE, POLYLINE, COMMENT and
ordered diagnostics in an owned buffer. A malformed short EOF remains a raw record
and framing continues to later records. The independently compiled C11 smoke
client passed against the integrated shared library at `b34c69b`. Full record
coverage and C-side edits remain open. The bounded Ruby adapter now consumes these
decoded fields; it does not repeat the wire parser.

### Initial Ruby WMF slice

Commit `0a32b35` adds standard and placeable headers, checksum validation, bounded
WORD framing, EOF/MoveTo/LineTo, opaque unknown records, trailing-byte retention
and checked coordinate edits. Two synthetic fixtures cover both headers. The
integrated WMF, visitor, backend-selection and public API checks passed 41 examples
at `b34c69b`. This is a Ruby subset; native WMF, remaining WMF records, structured
EMF+ and downstream format coverage remain open.

The isolated consumer benchmark subprocess now preserves installed gem paths
when leaving Bundler. Its six focused examples passed at `b34c69b`, including a
fresh-process regression for isolated bundle installs. Current-head CI is pending.

### Serialization resource budgets

`SerializeLimits` bounds output bytes and work before allocation, including edited
point payloads. Checked cumulative parser accounting rejects overflow. The
integrated workspace passed 58 Rust tests, strict Clippy, formatting and the
compiled C smoke client at `c513178`. FFI coverage exercises real output
and work limit failures through owned error views and preserves `EMF_LIMIT_EXCEEDED`.
These checks do not complete corrupted-corpus, fuzz or platform acceptance.

### Signed coordinate native cohort

Commit `7371400` extends snapshot schema 2 (ABI version 1 unchanged) with seven
signed coordinate families: window and viewport origin/extent, brush origin,
clip offset and move-to. Ruby models hydrate directly from signed fields, retain
mutable wires, and match the Ruby canonical observations for this cohort.

`cargo test --workspace --locked` passed 69 tests; strict clippy, formatting and
`sh crates/emf-ffi/tests/run-c-smoke.sh` passed. The focused native/backend Ruby suite
passed 35 examples. These are cohort checks, not complete-corpus parity or a
performance result. The subsequent color and rectangle cohort is integrated below.


### Color, rectangle and fixed state/path cohorts

Commit `fd55d22` adds direct Ruby hydration for text/background COLORREF values,
ellipse, rectangle and rounded rectangle records. Snapshot schema 2 tags 16–20
retain all four color bytes and signed bounds/corner fields; the C ABI remains 1.
The combined workspace passed 79 Rust tests, strict Clippy, formatting and the
compiled C smoke client. The native Ruby suite passed 39 examples, including
field edits, canonical Ruby comparisons, fixed-record suffix normalization and
truncated known records retained as Raw with diagnostics.

Commit `0b6c21b` adds 14 fixed state/path families in the Rust core, including
signed RestoreDc, unsigned object/state fields, zero-payload path operations,
signed path bounds and SelectClipPath with an opaque optional suffix. All 70
core tests, core Clippy and formatting passed before integration. ABI and Ruby
adaptation landed in `b4ec24d`: snapshot tags 21–34, direct Ruby hydration,
owned C snapshots and malformed-record controls. The combined workspace passed
85 Rust tests, strict Clippy, formatting and the compiled C smoke client; the
focused native Ruby suite passed 43 examples.

Commit `05d5b3b` adds ten fixed geometry/object families in the core: LineTo,
Arc/ArcTo/Chord/Pie, clip rectangles, CreatePen, CreateBrushIndirect and SetPixelV.
All 75 core tests, strict core Clippy and formatting passed before integration.
ABI and Ruby adaptation landed in `0fb8deb`: snapshot tags 35–44 and direct
hydration of signed geometry, unsigned object fields and all COLORREF bytes.
The workspace passed 91 Rust tests, strict Clippy, formatting and the linked C
smoke client; the focused native Ruby suite passed 47 examples. Full registry,
corpus and platform acceptance remain open.

### Forced-native measurement support

Commit `87f1fde` adds explicit native selection to warm and cold benchmark
children, library identity metadata and honest public-stage descriptions.
Fourteen focused examples pass. Synthetic supported and unsupported native
inputs verify success and failure reporting; these checks establish no speedup.
The corpus inventory remains unsafe until its timeout outcomes are resolved.
