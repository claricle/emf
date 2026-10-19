# Delivery progress and handoff

Status: execution plan proposed; all implementation work pending.

## Work record

| Package | State | Evidence / remaining work |
| --- | --- | --- |
| 01 Requirements | Baseline documented | Validate contracts through executable oracle in 02 |
| 02 Baseline/parity | Not started | Manifest, field snapshots, mutation controls, downstream revision and timings |
| 03 Rust core | Not started | Vertical slice, every inventory group, serializer |
| 04 C ABI | Not started | Binding contract, ownership/lifecycle and failure checks |
| 05 Ruby binding | Not started | [R1–R5](05-ruby-execution.md): contracts, dispatch, model adaptation, edited serialization, consumers |
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

Start [02](02-baseline-and-parity.md): enumerate the current corpus into the shared
manifest, capture API/model/serialization snapshots, and establish the downstream
baseline. No Rust files need to be introduced before this oracle is available.
The initial estimates in [00](00-overview.md) should be revised after this milestone
and after the integrated native slice.
