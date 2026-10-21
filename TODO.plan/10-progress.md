# Delivery progress and handoff

Status: implementation and qualification in progress. Passing source-level checks
do not close native, performance or installed-platform acceptance.

## Current acceptance checkpoint

- **Ruby corpus:** exact source `0f63318655f49dcdc65756d780b94fda0e1602c0`
  completed all 231 fixture captures: 219 parsed, 10 recovered and two explicit
  format errors. Canonical controls verified 229 byte-exact round trips,
  reparse/file equality and unchanged input identities, with zero safety failures.
  See [the revision-bound evidence](02-baseline-and-parity.md). Later parser
  changes require affected qualification; this result does not certify them.
- **Ruby API:** source `7be55ce3f6d75d52c269071508330ef8fabaf0c7` passed
  64 forced-Ruby public API, backend-selection, model, detector and visitor
  examples. Native execution is a separate remaining criterion in
  [05](05-ruby-execution.md).
- **Performance harness:** bounded benchmark-series deadlines are implemented
  in `9b4f0e6b225ef25f3c56dc9ac52e94d2c304a39f`; its affected benchmark
  checks passed 38 examples. Ordinary deadlines retain their 60-second ceiling;
  explicit series deadlines permit up to 1,200 seconds with resource and cleanup
  controls retained. This enables the measurement policy in
  [07](07-performance.md); it is not evidence that the speed target is met.
- **Native and distribution:** the earlier workspace run at `7165bf2` stopped
  on obsolete unknown-record test controls. The source correction is integrated,
  but a passing final-source workspace run, linked ABI/public Ruby checks and
  real installed/platform rows remain open. See [03](03-rust-core.md),
  [04](04-c-abi.md) and [08](08-platform-delivery.md).

The detailed records below retain earlier observations. Their revisions and
limits apply; they do not override this checkpoint or certify later source.

## Work record

| Package | State | Evidence / remaining work |
| --- | --- | --- |
| 01 Requirements | Baseline documented | Validate contracts through executable oracle in 02 |
| 02 Baseline/parity | In progress | Fixture inventory, API/mutation controls, canonical observation/comparison harness and parser/consumer timing drivers added; reported slow workload and native comparisons pending |
| 03 Rust core | In progress | Checked reader, bounded framing and exact unchanged serialization added; typed header/EOF, scalar state, signed coordinates, color, rectangle, simple/multi point arrays, PolyDraw, scale/world transforms, fixed state/path completion and comment cohorts added; remaining record families and corpus parity pending |
| 04 C ABI | In progress | Versioned interface, owned typed snapshots, boundary tests and linked C client verified locally; full model/edit and platform checks pending |
| 05 Ruby binding | In progress | [R1–R5](05-ruby-execution.md): contracts, dispatch, model adaptation, edited serialization, consumers |
| 06 Resilience | In progress | Ruby subprocess supervisor and Rust budget regressions underway; forced-native corpus and fuzz budgets pending |
| 07 Performance | In progress | Ruby/native parser and consumer measurement drivers verified; comparable end-to-end results, issue target and regression budget remain open |
| 08 Platform delivery | In progress | Feasibility probe underway; artifacts, clean installs and complete CI/release integration pending |
| 09 Format extensions | In progress | Bounded Ruby standard/placeable WMF headers, mapping, fixed geometry, point arrays, arcs, origin offsets and raw unknown preservation verified; full WMF and structured EMF+ pending |
| 11 Record coverage | In progress | Header and bounded scalar/coordinate/variable cohorts cross core, ABI and Ruby; color/rectangle, fixed state/path, simple/multi point arrays, PolyDraw and transform parity verified; remaining registry entries and variants pending |

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

Complete the remaining end-to-end qualification rather than repeat the historical
baseline discovery:

1. Validate the corrected Rust workspace and linked ABI/Ruby public path at one
   recorded source revision; retain failures and qualify the actual library used.
2. Refresh affected corpus/parity controls for that source after parser changes,
   including forced-native execution, edits, recovery and downstream golden output.
3. Use the bounded series harness to collect the required comparable distributions
   for the named slow workload. The sub-second target remains unmet; record any
   remaining gap instead of treating source optimizations as measured acceptance.
4. Complete real source/native installed-platform rows and required CI. Keep
   missing evidence open in the corresponding package, then perform the final
   whole-issue implementation review once the implementation is finalized.

See [02](02-baseline-and-parity.md), [05](05-ruby-execution.md),
[07](07-performance.md) and [08](08-platform-delivery.md) for exact contracts.
A run certifies only its recorded source, artifact and workload identities.

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

The historical pre-qualification 231-fixture capture was **not an accepted baseline**: 221 parsed,
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

### Point arrays and PolyDraw

Commit `8c25f5d` extends the bounded native slice to the simple point-array
families, including signed 16-bit and 32-bit points. The integrated workspace
passed 99 Rust tests and 51 native Ruby examples. Commit `38722dd` extends this
to PolyPolyline/PolyPolygon and their 16-bit counterparts: independent array
counts, signed fields, direct Ruby hydration and editable serialization. The
workspace passed 106 Rust tests and 55 native Ruby examples.

Commit `252b4b7` adds core PolyDraw/PolyDraw16 models and serialization; native
snapshot and Ruby mapping landed in `2ea1d9f`. Shared point/type counts, opaque
u8 type values, signed extrema, empty arrays, edits, unknown siblings and
malformed Raw recovery are covered. `cargo test --workspace --locked` passed
113 tests and `bundle exec rspec spec/emf/native` passed 59 examples with the
compiled debug library. Strict Clippy, formatting, the linked C smoke client
and changed-file Ruby lint passed. These results do not establish full registry,
fixture-corpus, performance or platform acceptance.

### Ruby WMF geometry and point arrays

Commit `7219f6e` adds Rectangle/Ellipse and window/viewport origins and extents.
Commit `d72ead5` adds Polygon/Polyline/PolyPolygon with signed points, checked
counts, edited record framing and byte preservation. The bounded WMF suite
passed 30 examples; changed-file lint passed. Other WMF families, native mapping
and structured EMF+ acceptance remain open.

### Scale and world transforms

Commit `920174a` adds typed ScaleViewportExtEx, ScaleWindowExtEx,
SetWorldTransform, ModifyWorldTransform, AngleArc and SetMiterLimit.
Float fields retain their IEEE 754 bits, including NaNs and signed zero.
The core worker passed 101 tests, strict Clippy and formatting checks.
Commit `e548c23` adds snapshot-2 transport and direct Ruby hydration for all
six families. The workspace passed 121 Rust tests and the compiled debug library
passed 62 native Ruby examples. Strict Clippy, formatting, the linked C smoke
client and changed-file Ruby lint passed. C/Rust retain exact float transport
bits; Ruby serialization matches the existing BinData behavior, including NaN
normalization. Full registry and corpus parity remain open.

### CI manifest schema controls

Commit `6dad910` repairs six reproduced CI failures by generating temporary
current-schema manifests for inventory and consumer validation tests. Legacy
schema rejection remains explicit. The 16 focused examples pass and changed-file
lint passes. This test repair does not recapture or approve the tracked corpus
inventory; production baseline acceptance remains open.

### Remaining fixed state and compatibility records

Core commit `e0fa139` and native commit `8598911` add SetMapperFlags,
SetMetaRgn (Ruby `SetMetArgn`), ExtFloodFill, FlattenPath, WidenPath,
SetIcmMode, SetLayout and SetTextJustification. Snapshot schema 2 gains tags
66–73; ABI version 1 is unchanged. ExtFloodFill and SetTextJustification
retain the current Ruby opaque-body contract; semantic fields remain open.

`cargo test --workspace` passed 128 tests. Strict workspace Clippy, formatting
and the linked C smoke client passed. The compiled native library passed
65 examples with `bundle exec rspec spec/emf/native`; changed Ruby lint passed.
Checks cover direct hydration, edits, malformed Raw recovery, owned snapshot
lifetimes and opaque-body length validation. Full corpus parity remains open.

### Ruby WMF arcs and offsets

Commit `1735620` adds typed Arc/Pie/Chord/RoundRect and window/viewport offsets,
including checked signed coordinates and edited serialization. The bounded WMF
suite passed 36 examples. The integrated WMF, fixture-manifest and consumer
benchmark checks passed 52 examples at that commit. These results do not
establish complete WMF, native WMF or performance acceptance.

### Extended text output core

Commit `b61f7cd` adds semantic Rust models for `ExtTextOutA` and `ExtTextOutW`.
The model retains raw A bytes, UTF-16 code units, float bit patterns, optional
clipping rectangles, per-character advances, both buffer orders and padding.
Edits regenerate checked counts and offsets. Invalid spans, overlaps and
alignments retain the complete Raw record with diagnostics.

The native bridge adds checked snapshot payloads and direct Ruby hydration for
both families, including empty buffers, ETO_NO_RECT, per-character advances and
float bit preservation until reassignment. ABI 1 and snapshot schema 2 remain
unchanged. Commit `86bf701` supplies the bridge. The integrated checkpoint passed 141 Rust
tests, 70 native Ruby examples, strict workspace Clippy, formatting and linked
C ABI smoke.
Full corpus parity and performance acceptance remain open.

### Region records and benchmark diagnostics

Commit `6a9b2fc` adds semantic Rust models and checked edited serialization for
FillRgn, FrameRgn, InvertRgn, PaintRgn and ExtSelectClipRgn. Four new region tests
and 32 existing focused compatibility/framing checks passed.
Commit `881a472` adds snapshot families 76–80 and direct native hydration,
with corrected Ruby wire layouts and typed region data. The focused checkpoint
passed 75 native Ruby examples, workspace Rust tests, strict Clippy, formatting,
the linked C smoke client and changed-file Ruby lint. Full corpus parity remains
open. InvertRgn/PaintRgn no longer expose a nonexistent brush field;
ExtSelectClipRgn exposes typed region data. Scalar and nested edits serialize
directly; structural array edits require the corresponding explicit wire counts
and sizes, consistent with existing counted Ruby wire records.

Commit `8a9c7d5` adds bounded Ruby/Gem/Bundler diagnostics to benchmark dependency
load errors. Its seven focused examples pass locally. This does not establish
a fix for the two Ruby 3.2 CI failures; the next CI run must expose their cause.

### Extended pen core and Ruby 3.2 benchmark startup

Commit `39fd569` adds semantic ExtCreatePen parsing and checked edited
serialization. Style entries, optional bitmap buffers, buffer order, padding,
unknown scalar bits and record suffixes are retained. The core checkpoint
passed 52 focused tests, strict core Clippy and formatting. The native bridge
is in progress; this core-only checkpoint does not establish a passing FFI
workspace or complete Ruby support.

Commit `aa6a077` clears inherited `BUNDLER_SETUP` in benchmark child processes.
An inherited setup path reproduced dependency-loading failure with Ruby 3.2.3
and Bundler 2.4.19; the regression passed all seven benchmark examples after
the fix. A Ruby 3.4 control and changed-file lint also passed. Current-head CI
remains required before the Ruby 3.2 CI failure can be reported as resolved.

### Extended pen bridge and WMF object lifecycle

Commit `dff26df` adds extended-pen snapshot family 81 and direct Ruby hydration,
including typed unsigned fields, styles, bitmap spans, buffer ordering and padding.
Commit `54e2f44` fixes the adapter spec's standalone native-fields dependency.
Commit `be0d78f` restores legacy `body=`/`body.assign` mutation through typed
fields and guards Ruby style counts before allocation. Malformed records retain
their bytes and preserve subsequent records; invalid body writes are atomic.
Complete extended-pen corpus acceptance remains open.

Commit `3ce96d6` adds Ruby WMF CreatePenIndirect, CreateBrushIndirect,
SelectObject and DeleteObject models with editable serialization and bounded
object-table allocation, reference validation, deletion and slot reuse. Known
opaque object creators reserve slots while retaining their bytes. High-bit stock
selectors remain opaque. Other object payloads, drawing-state semantics and
native WMF remain open.

The integrated checkpoint passed 130 affected Ruby examples (seed 13541),
`cargo test --workspace`, strict workspace Clippy, formatting and the linked C
smoke client. The WMF worker's seven changed Ruby files lint clean; eight new
regressions failed against the previous implementation. Current-head CI, complete
registry/corpus parity and performance/platform acceptance remain open.

### Standalone corpus and public EMF+ stream checkpoint

PR #33 (`1d34087`, dependent on PR #32) integrates the remaining opaque native
Ruby class mappings, standalone Rust fixture checks and public Ruby EMF+ stream
representation. The stream provides lazy access, immutable edits that rebuild
only changed comments, a time-indexed 64-slot object table and GetDC spans.
Effect association currently handles only an immediately preceding
SerializableObject; ambiguous associations remain diagnostic. Records spanning
comments remain raw with a stream error. These boundaries remain open format
acceptance gaps.

The composed native adapter/stream/object-table/link command passed 132 examples,
zero failures (seed 47027). The standalone core fixture target passed three tests,
including exact serialization of 208 valid EMF fixtures and integrity of all 231
fixture files. The EMF+ implementation checks separately passed 1,146 examples;
model checks passed 22. These results verify their stated scopes only.

Whole-issue acceptance remains incomplete: full native/Ruby canonical corpus
comparison, current corrupted-input resource outcomes, downstream native golden
acceptance, end-to-end performance target and the complete platform distribution
matrix must still be evidenced. PR #32/#33 required final-head CI and dependency
integration remain delivery requirements.
