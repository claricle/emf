# Delivery progress and handoff

Status: execution plan merged; baseline, Rust core and Ruby integration work in progress.

## Work record

| Package | State | Evidence / remaining work |
| --- | --- | --- |
| 01 Requirements | Baseline documented | Validate contracts through executable oracle in 02 |
| 02 Baseline/parity | In progress | Fixture inventory, API/mutation controls, canonical observation/comparison harness and parser/consumer timing drivers added; reported slow workload and native comparisons pending |
| 03 Rust core | In progress | Checked reader, bounded framing and exact unchanged serialization added; typed vertical slice and record families pending |
| 04 C ABI | In progress | Initial interface and C client implementation underway; ownership/lifecycle and full model checks pending |
| 05 Ruby binding | In progress | [R1–R5](05-ruby-execution.md): contracts, dispatch, model adaptation, edited serialization, consumers |
| 06 Resilience | Not started | Outcome manifest, subprocess limits, fuzz regressions |
| 07 Performance | Not started | Comparable measured end-to-end target and regression budget |
| 08 Platform delivery | Not started | Target probes, artifacts, clean installs, CI/release integration |
| 09 Format extensions | Not started | WMF/EMF+ inventory, fixtures, typed parsing and serialization |
| 11 Record coverage | Baseline inventory | Per-record implementation and field-level evidence pending |

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
then connect it through [04](04-c-abi.md) and [05](05-ruby-binding.md).
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

`bundle exec ruby script/fixture_manifest` captures every `.emf` fixture in
`spec/fixtures/manifest.json`, including source fingerprints, input hashes,
detected format and Ruby parse outcome. Each parse runs in a child with a
five-second deadline and a 16 KiB output limit. Timeout, process failure and
unexpected backend exceptions are recorded separately from format rejection.

The initial capture contains 229 fixtures: 220 parsed without diagnostics, seven
recovered with diagnostics and two rejected with `Emf::FormatError`. No child
safety failures or unexpected backend exceptions were observed. These counts
describe Ruby outcomes, not a classification of valid versus corrupt input.

`bundle exec ruby script/fixture_manifest --check` validates fixture metadata and
the parser source fingerprint against the saved capture without parsing again.
Regenerate and review the capture after intentional fixture or parser changes.
After Ruby backend dispatch was added, a fresh capture preserved all 229 outcomes.
One fixture exceeded the same five-second limit during the full run and parsed
successfully on a bounded retry; the refreshed manifest passed its metadata and
source-fingerprint check. The reported performance workload remains unidentified.

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
tests passed locally on stable Rust. The declared Rust 1.73 minimum and Linux/macOS
checks are included in the Rust CI matrix; their results remain pending.

This foundation does not complete typed record decoding, edited serialization,
corpus parity, the C ABI or Ruby native model hydration. The next core slice adds
header/EOF, fixed and variable record models with checked edits while preserving
unknown bytes.

### Ruby backend selection

`EMF_BACKEND` selects `auto`, `ruby` or `native` for each parse and serialization
operation. Automatic fallback applies only when native setup is unavailable;
operation errors propagate. Forced Ruby execution avoids loading native support.
Invalid selection raises `ArgumentError`, and forced unavailable native execution
raises `Emf::Native::Unavailable`.

Commit `14fb505` integrates this dispatch with 45 focused policy, API, detector,
CLI and mutable-model examples passing. The native backend currently reports
unavailability; the actual loader, ABI ownership and model hydration remain open.

### Initial C ABI

The `emf-ffi` crate provides versioned C layouts, owned document, buffer and error
handles, detection, raw record batches and unchanged serialization. Output-reset,
limits, lifecycle and panic-boundary tests accompany a separately compiled C11
client linked to the actual library. Six ABI tests and the C client passed locally
on macOS with stable Rust before integration. The C client is included in CI.

This is a raw-framing subset. Typed snapshots, edits, diagnostic enumeration and
Ruby hydration remain acceptance gaps; header and payload decoding must not be
repeated in Ruby to substitute for a native model adapter.
