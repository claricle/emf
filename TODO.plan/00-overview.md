# Metafile parser, Ruby integration and native delivery

Status: proposed; implementation not started. Baseline: `a549346` on `main`.
Requirement: [issue #15](https://github.com/claricle/emf/issues/15).

## Existing implementation and intended changes

The repository already contains a working Ruby EMF parser and serializer, BinData
record definitions, Ruby domain models, error recovery, visitors, CLI commands and
fixture tests. The native core builds on this behavior and its tests. The Ruby
work changes the existing API dispatch, model adaptation and serialization path,
adds backend selection and native loading, and retains the Ruby implementation.
WMF and structured EMF+ need new implementation because their current parsers and
serializers are placeholders.

## Goal

Implement a reusable Rust parser and serializer for EMF, EMF+, and WMF, expose it
through a versioned C ABI, and use it from the existing `emf` Ruby gem. Preserve
the Ruby API and record behavior, retain the BinData implementation as a fallback,
and ship native platform gems that install without a compiler. Demonstrate the
speed improvement through the Ruby API and downstream consumers as well as Rust
microbenchmarks.

The first delivery migrates the existing EMF behavior. Full issue completion also
requires the WMF and structured EMF+ work in [09](09-format-extension.md). Their
current implementations are stubs; this is additional format development rather
than an existing implementation that can simply be translated.

This directory is an execution plan. Proposed code paths, commands, acceptance
checks, and performance targets describe future work, not results already obtained.
The planning PR contains no parser or packaging implementation.

## Repository layout

Keep the Ruby gem at the repository root. Add a Rust workspace as a self-contained
subtree so the core remains usable without Ruby and can be distributed separately
without redesigning its contracts:

```text
emf-rs/
  Cargo.toml, Cargo.lock, rust-toolchain.toml
  crates/emf-core/           # owned bytes, typed records, validation, serialization
  crates/emf-ffi/            # C ABI and generated/checked public header
  fuzz/                     # fuzz targets and seed manifest for existing fixtures
lib/emf/
  backend.rb                # availability and explicit selection
  native/                   # library loading, ABI calls, model adaptation
  emr/, wmf/, emf_plus/     # existing Ruby implementation retained
spec/
  fixtures/manifest.json    # common fixture identity and expected outcomes
  support/                  # parity and subprocess helpers
  emf/                      # backend, model, round-trip, safety regression checks
bench/                      # Ruby API and consumer benchmark drivers
TODO.plan/                  # requirements, execution tasks, acceptance and progress
```

These are proposed paths. Detailed work items define their contents; reconcile
renames in the same PR that introduces them. Do not move the existing fixture
directories and break their RSpec paths. Corpus seeds and Rust tests resolve the
same fixture manifest. The workspace's test dependency on repository fixtures must
be documented separately from its runtime independence.

The parsanol Rust/Ruby pair and leptris provide architecture and shipping examples.
This work does not require integrating a parsing-combinator engine or adding
`parsanol-rs` as a dependency. A future repository extraction is outside this plan.

## Plan navigation

Start with this overview and [requirements](01-requirements.md). The
[Ruby execution plan](05-ruby-execution.md) maps the existing Ruby files to
ordered implementation tasks. Its [binding contract](05-ruby-binding.md)
is the detailed interface specification. The Rust, format and delivery documents
in the table below own their respective contracts; each requirement has one
canonical description. Package IDs remain stable so progress
and acceptance references continue to identify the same work.

## Work packages and dependencies

| ID | Deliverable | Depends on | Initial effort |
| --- | --- | --- | --- |
| [01](01-requirements.md) | Compatibility contract and completion matrix | Source/issue baseline | Included in 02 |
| [02](02-baseline-and-parity.md) | Fixture manifest, canonical comparison, downstream and timing baseline | 01 | 2–3 days |
| [03](03-rust-core.md) | Bounded typed EMF parser and exact serializer | 02; [11](11-record-coverage.md) inventory | 6–8 days |
| [04](04-c-abi.md) | Versioned ABI, ownership, errors and lifecycle checks | 02; small 03 slice | 2–3 days |
| [05](05-ruby-binding.md) | Native selection, compatible models and Ruby fallback | 03 slice + 04 | 3–4 days |
| [06](06-resilience.md) | Corrupt-input bounds, subprocess checks and fuzzing | 02; starts with 03/04 | 2–3 days |
| [07](07-performance.md) | Measured Ruby and downstream speedup | 02 baseline + 05 | 1–2 days |
| [08](08-platform-delivery.md) | Platform gems, install smoke checks, CI and release integration | 04/05; platform probe starts after 02 | 3–4 days |
| [09](09-format-extension.md) | Standard/placeable WMF and structured EMF+ | 02 contract + 03–06 foundations | Additional 15–25 days, provisional |
| [10](10-progress.md) | Acceptance evidence and implementation handoff | Updated with each work package | Included above |

The EMF/native subtotal is **19–27 engineering days**. Allow **20–30 days
(approximately 4–6 weeks for one engineer)** for integration and corrections.
Including new-format work gives an initial **35–55 engineering days (7–11 weeks)**.
These are planning ranges, not measured throughput or calendar commitments. They
include investigation, implementation, review corrections, and validation; CI
queue time, access delays, and maintainer response time can extend elapsed time.

Confidence is lower for new formats, mutable wire compatibility, downstream
hydration costs, and Windows ARM64 delivery. Re-estimate after 02 and again after
the first native vertical slice. Missing fixtures or a platform that cannot meet
the no-compiler requirement must remain a visible delivery gap, not disappear
from the supported-target list.

## First executable milestone

1. Complete the fixture manifest and current API/model snapshots in 02.
2. Pin an `emfsvg` revision, run its existing golden/round-trip suites with the
   current gem, and identify the reported slow fixture and its timing boundaries.
3. Build one Rust slice covering header, a fixed record, a variable record, an
   unknown record, EOF, and trailing bytes. Pass it through the C ABI and Ruby model.
4. Exercise `.wire` reading and mutation, dump/visitor behavior, serialization,
   cleanup, and a corrupt input. Measure complete Ruby consumption of this slice.
5. Freeze the model-adaptation and binding contracts only if compatibility and
   measured costs are acceptable. Then expand the record families in 11.

Once 02 establishes the oracle, Rust record-family work, corrupted-input test
preparation, and platform/toolchain probes have independent outputs. Integrate
them through the ABI and Ruby slice before scaling the implementation.

## Completion

Every requirement in [01](01-requirements.md) must link to concrete passing
evidence in [10](10-progress.md). A Rust-only speed result, raw record passthrough,
or a native library built on one platform does not establish completion of the
Ruby integration, typed coverage, or distribution requirements. The fallback and
native paths must both remain covered. No gem publication is part of the planning
deliverable.
