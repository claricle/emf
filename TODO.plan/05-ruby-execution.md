# Ruby implementation and integration sequence

Status: **In progress**. This expands package 05 into executable Ruby tasks; its
effort is included in the existing **3–4 engineering days**, not added to the
[overall estimate](00-overview.md). Baseline harness work belongs to
[package 02](02-baseline-and-parity.md); packaging and new-format
implementation retain their separate estimates.

The existing Ruby parser is the initial behavioral oracle and remains the
fallback. Ruby implementation work is required even when decoding runs in Rust.
The [binding contract](05-ruby-binding.md) owns backend policy, ABI error mapping,
wire hydration and native ownership; the steps below identify where to apply it.

## Existing implementation

| Existing path | Current responsibility | Planned treatment |
| --- | --- | --- |
| `lib/emf.rb` | Public parse/file/serialize/detection dispatch, autoloads and shared BinData primitives | Add internal backend dispatch while retaining entry points and binary file semantics |
| `lib/emf/detector.rb` | EMF and standard/placeable WMF detection | Preserve detection symbols, boundaries and errors through the public API |
| `lib/emf/emr/parser.rb` | Ruby EMF decoding, recovery, record wrapping and raw EMF+ extraction | Retain as selectable fallback and parity oracle; avoid calling it to reconstruct native results |
| `lib/emf/emr/serializer.rb` | Header conversion, live wire bytes and trailing bytes | Preserve Ruby serialization and support mixed Ruby/native records through the shared model contract |
| `lib/emf/model/emr/records.rb` | `WireAdapter` identity, wire access, equality, hash and visitor entry | Make lazy native construction compatible with these existing observations |
| `lib/emf/model/emr/header.rb` | Header fields and `from_wire`/`to_wire` conversion | Construct compatible native results without losing optional layout or retained bytes |
| `lib/emf/model/metafile.rb` | Enumerable document with frozen record/error arrays and trailing bytes | Retain classes, container behavior and raw EMF+ representation |
| `lib/emf/visitors/dump.rb`, `lib/emf/visitors/stats.rb` | Human-readable and record statistics consumers | Preserve dispatch, field access and output with either backend |
| `exe/emf` | Info, dump, validate, stats and round-trip commands | Exercise existing commands against both backends, preserving output and exit status |

## Ordered work

### R1 — Capture Ruby contracts before dispatch changes

Complete package 02's manifest and `spec/support/backend_parity.rb`. Extend the
existing parser, model, visitor, detector, round-trip and CLI specs with explicit
preservation assertions where the baseline lacks them. Record binary string
encoding, parse/file equivalence, serialize-file return value and filesystem
errors. Save corruption outcomes rather than assuming all inputs parse cleanly.

Exit: the unchanged Ruby implementation supplies reproducible observations,
including scalar/nested wire mutation and manually constructed models. This step
precedes the native slice and can proceed without any Rust files.

### R2 — Add dispatch and availability policy

Introduce `lib/emf/backend.rb`, the native autoload entry and loader paths listed
in package 05. Route public parsing and serialization in `lib/emf.rb` through the
selection layer without changing format detection or file I/O contracts. Retain
the existing eager BinData primitive registration: native records still need
actual BinData compatibility objects. This plan does not remove that dependency.

Use fresh processes in proposed `spec/emf/native/backend_spec.rb` for environment
selection and loader failures. Assert that requiring `emf` with forced Ruby does
not load Fiddle or the native loader, then prove parsing and serialization still
work. Compare loaded features before/after the call. Auto selection may fall back
on availability failure; a native parse error must propagate without Ruby retry.
Use explicit native-call and Ruby-parser spies in focused tests to prove dispatch,
rather than accepting a passing fixture as evidence of native execution.

Exit: every selection row in package 05 has an asserted result, missing native
assets leave the Ruby path usable, and forced native fails clearly when absent.

### R3 — Adapt the first native result to existing Ruby objects

After the header/fixed/variable/raw/EOF/trailing core and ABI slice exists, add
`lib/emf/native/backend.rb` and `lib/emf/native/model.rb`. Construct existing
metafile/header/record objects and ordered error objects. Refactor direct `@wire`
reads in `WireAdapter` coherently with lazy access; retain repeated wire identity,
class, equality/hash, inspect, visitors and offsets. Keep record ownership alive
when callers retain a record after releasing the metafile.

Add assertions in `spec/emf/backend_parity_spec.rb` and existing model/visitor
specs for retained records, repeated traversal, GC stress and exceptions during
construction. Assert cleanup exactly once and ensure temporary handles are freed
on failed conversion. Measure full wire traversal before expanding record groups.

Exit: the native slice is usable by existing Ruby consumers with no alternate
public model, and its complete consumption cost supports the chosen adaptation.

### R4 — Preserve serialization after edits

Apply the hybrid serialization policy from package 05 to `Emf.serialize` and the
native backend. Exposed wires serialize from their current cached BinData object;
unexposed records may reuse preserved native bytes. Keep existing Ruby models and
mixed record collections serializable. Retain the unsupported-model error and
header/trailing-byte behavior of `lib/emf/emr/serializer.rb`.

Assert scalar edits, nested-array edits, unchanged sibling bytes, header
conversion, unknown records and reparsed output in the parity harness. Include
multiple serialize calls after successive edits: reading a wire once must not
freeze later output. Do not update length/header fields differently from the Ruby
baseline without an explicit compatibility decision and regression.

Exit: unchanged fixtures round-trip byte-for-byte and supported edits have the
same observable result through Ruby and native backends.

### R5 — Verify consumer behavior and document use

Run existing CLI, visitor and round-trip checks in each forced backend, then the
pinned `emfsvg` golden suites from package 02. Extend `README.adoc` with backend
selection, fallback behavior and supported platform/capability information only
after those behaviors exist. Coordinate the gemspec and clean-install checks with
[platform delivery](08-platform-delivery.md). New WMF/EMF+
fallback models/parsers remain tracked in [format extension](09-format-extension.md),
not implied complete by the EMF integration.

Exit: public documentation matches tested behavior, existing consumers retain
their results, and required platform/backend evidence is linked in
[progress](10-progress.md).

## Planned verification

After proposed specs and the native library exist, run from the repository root:

```sh
EMF_BACKEND=ruby bundle exec rspec spec/emf/backend_parity_spec.rb spec/emf/native/backend_spec.rb spec/emf/model spec/emf/detector_spec.rb spec/emf/visitors_spec.rb spec/emf/cli_spec.rb spec/emf/round_trip_spec.rb
EMF_BACKEND=native bundle exec rspec spec/emf/backend_parity_spec.rb spec/emf/native/backend_spec.rb spec/emf/model spec/emf/detector_spec.rb spec/emf/visitors_spec.rb spec/emf/cli_spec.rb spec/emf/round_trip_spec.rb
EMF_BACKEND=auto bundle exec rspec spec/emf/native/backend_spec.rb
```

The selection spec sets each case's subprocess environment explicitly, independent
of the suite's parent override. Native-dependent integration cases require a
usable library and must fail clearly if it is absent. Ruby availability tests
must pass with the native assets removed. These are future acceptance commands;
this planning PR has not implemented or run them.

## Implemented checkpoints and remaining acceptance

Backend selection, setup-only fallback, direct native model hydration and lazy
mutable wires are implemented. Preservation controls in
`spec/emf/backend_parity_spec.rb`, `spec/emf/native/backend_spec.rb`,
`spec/emf/native/adapter_spec.rb` and `spec/emf/native/lazy_wire_spec.rb` exercise
these contracts. They do not establish every R1–R5 exit condition.

PR #33 adds compatible classes for the remaining registered opaque record
families without parsing their bodies again through the Ruby parser. Its composed
adapter/EMF+ stream/object-table/link check passed 132 examples with zero failures
(seed 47027), using an actual release native library. Standalone Rust corpus
identity is recorded in [03](03-rust-core.md). Complete Ruby/native valid-corpus
observations, visitor/CLI parity, corrupted-input equivalence and the pinned
downstream native golden suite remain acceptance work; do not infer them from
the adapter examples or unchanged Rust serialization alone.
