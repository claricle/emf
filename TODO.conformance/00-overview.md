# Issue 37: EMF/EMF+/WMF conformance lens

Status: planned; foundational work is in progress and unmerged
Baseline: `origin/main` at `da21ae2`
Issue: [claricle/emf#37](https://github.com/claricle/emf/issues/37)

## Goal

Add `Emf::Conformance.check(input, profile:)`, a Ruby conformance lens over the
same public record model returned by the parser. It validates EMF, embedded EMF+,
and WMF record streams and returns deterministic, structured diagnostics using
the `svg_conform` report shape plus a record offset and specification citation.

Completion requires:

1. Per-record required-field, size/count, enumeration, and offset/length checks,
   each tied to a stable requirement ID and an MS-EMF, MS-EMFPLUS, or MS-WMF
   section.
2. A report with stable error/warning summaries and diagnostics containing at
   least `kind`, `severity`, `requirement_id`, `offset`, and `spec_citation`.
3. `strict` and `tolerant` profiles with explicit behavior for every file in
   `spec/fixtures/emf-corrupted/`.
4. Identical reports when the Ruby and native backends parse the same input.
5. Full rule manifests for 119 EMF record types, 55 defined EMF+ record types,
   and the MS-WMF record families, with unavailable model data recorded rather
   than silently skipped.

## Acceptance trace

| Issue criterion | Plan evidence | Execution gate |
| --- | --- | --- |
| Record-level required fields, size/counts, enums and bounds with citations | Format inventories in documents 02–04 and the complete requirement manifest | W06–W24, then the manifest completeness check in W32 |
| Structured diagnostics in the common lens shape | Public issue/report contract in document 01 | W01, W05 and report contract specs |
| Strict/tolerant corpus behavior | Per-file matrix and recovery definition in document 05 | W25–W27 after blocked model fields land |
| Same parser model and emf-rs parity | One-lens decision in document 01 and forced-backend equality in document 05 | W28–W30 in Rust CI |

## Scope

In scope:

- One Ruby lens over `Emf::Model::Metafile`, its public `records`, record
  `offset`/`wire` data, `Metafile#errors`, and `Metafile#emf_plus_stream`.
- Plain Ruby report/profile/requirement objects; no new runtime dependency.
- Structural and semantic rules that can be evaluated from the public model.
- Explicit blocked-rule metadata for requirements that need public model data.
- Corpus profile expectations and forced-backend report parity in Rust CI.
- Small public-model prerequisites delivered through the model/native ownership
  stream, not through conformance-rule files.

Out of scope:

- A second decoder or rules implementation in Rust.
- Reading native snapshots, native diagnostic packets, or backend-specific
  classes from the lens.
- Treating parser survival or `record_variants` examples as proof of conformance.
- Reworking parser recovery, native hydration, or model classes inside lens work.
- Rendering, repair, or automatic mutation of malformed metafiles.

## Current behavior and evidence

- EMF parsing produces one public metafile model with record offsets, public wire
  objects, `Raw` recovery records, `ParseError`s, trailing bytes, and an embedded
  EMF+ stream.
- The native backend hydrates the same public model. A model-capability probe over
  the available fixture corpus found record and serialization parity, but also
  found fields that neither backend exposes semantically.
- `lib/emf/emf_plus/stream/conformance.rb` provides a small existing EMF+ check
  that should be adapted into the common registry.
- WMF parsing currently rejects structural failures before a model exists. The
  native `first_rejection` catalog and `lib/emf/native/wmf_rejection.rb` are
  backend-contract assets, not APIs the lens may call.
- The corruption manifest records 9 parsed inputs, 10 recovered inputs, and 2
  format rejections. The profile contract is specified in
  [05-profiles-corpus-and-parity.md](05-profiles-corpus-and-parity.md).

## Documents

- [01-contract-and-decisions.md](01-contract-and-decisions.md) — public API,
  report/profile contracts, and controlling decisions.
- [02-emf-rule-inventory.md](02-emf-rule-inventory.md) — all 119 EMF types and
  public-model coverage.
- [03-emf-plus-rule-inventory.md](03-emf-plus-rule-inventory.md) — all defined
  EMF+ types and object-reference coverage.
- [04-wmf-rule-inventory.md](04-wmf-rule-inventory.md) — MS-WMF families,
  rejection catalog, and model dependency.
- [05-profiles-corpus-and-parity.md](05-profiles-corpus-and-parity.md) — profiles,
  all 21 corrupted fixtures, and backend parity.
- [06-execution-plan.md](06-execution-plan.md) — ordered 20–40 minute work items,
  dependencies, effort, and checks.
- [10-progress.md](10-progress.md) — status and handoff record.

## Delivery boundaries

The conformance work must remain compatible with open PRs #52 and #54. PR #52
touches the WMF contract and existing plan documents. PR #54 owns
`lib/emf/native/**` and `lib/emf/model/**`; any new public model data required by
this plan is a dependency on that ownership stream or a follow-up after it lands.
