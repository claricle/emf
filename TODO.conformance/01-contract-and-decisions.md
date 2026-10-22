# Contract and technical decisions

## Entry point

The public entry point is:

```ruby
Emf::Conformance.check(input, profile: :strict)
```

`input` is a binary string, a path (a `Pathname`, or a `String` that names an
existing file and has no NUL byte and under 4096 bytes), or an already parsed
`Emf::Model::Metafile`. A path is read with `File.binread` and becomes the
report's `filename`; any other string is treated as bytes (`filename` is `nil`).
A string that happens to name an existing file is read as that file; callers
holding bytes for which that could be ambiguous parse them first and pass the
model. Bytes are
parsed once through the selected backend, then the resulting public model is
evaluated. Accepting a model lets callers prove the lens validates the parser's
model without decoding again.
Unknown profile IDs raise `ArgumentError`. A supported input that cannot produce
a model returns a structured format diagnostic rather than leaking an
unstructured parser exception; the validity policy for the two hard-rejection
corpus files was decided by the owner (see below).

## Report shape

`Report#to_h` mirrors the useful `svg_conform` keys in plain Ruby:

| Key | Contract |
| --- | --- |
| `filename` | Source label when known; `nil` for unlabeled bytes/models. |
| `profile` | Stable profile ID, `strict` or `tolerant`. |
| `tool` | Stable lens name. |
| `version` | `Emf::VERSION`. |
| `timestamp` | UTC ISO-8601 report creation time. Exclude this key from forced-backend equality or inject one timestamp into both runs. |
| `valid` | `true` exactly when `errors.total_count == 0`. |
| `errors` | Summary with `total_count`, `by_requirement`, and ordered `issues`. |
| `warnings` | The same summary shape for non-invalidating findings. |

Each issue retains the common issue keys used by `svg_conform` where applicable
and adds metafile-specific location data:

| Key | Contract |
| --- | --- |
| `type` | `error` or `warning`, after the profile is applied. |
| `requirement_id` | Stable rule identity, independent of profile severity. |
| `message` | Human-readable explanation including expected and observed values when available. |
| `element` | `<format>:<name>` when the issue belongs to a record: for EMF the `TypeCodes` constant name without the `EMR_` prefix (`emf:RESTOREDC`, `emf:COMMENT`); `emf:0x0045` for a code with no name; EMF+ and WMF records use `<format>:0xNNNN` (the record type or function code). `nil` otherwise. |
| `attribute`, `value` | The offending field and its observed value, when one field is at fault. |
| `offset` | Absolute byte offset in the containing metafile; replaces svg_conform's `line`. |
| `severity` | Same value as `type`; kept for svg_conform compatibility. |
| `kind` | Stable machine-readable diagnostic kind; never derived from prose. Issue #37 AC2 names this key. |
| `category` | Same value as `kind`; kept for svg_conform shape compatibility. |
| `spec_citation` | The cited section (for example `MS-EMF 2.3.11.6`). Issue #37 AC2 names this key at the top level of the issue. |
| `remediation_available` | Always `false`; the lens does not repair files. |
| `context` | Primitive values only: `spec_citation` (same value as the top-level key; kept for compatibility), `format`, `record_index`, `record_type` (numeric code), and `waiver` when the tolerant profile downgraded the rule. |

svg_conform's `line`, `column` and `xpath` are omitted: they have no meaning for a
binary record stream.

Ordering is deterministic: record offset ascending (issues without an offset
first), then requirement ID, then the order the rule emitted them. EMF+ issues use
the absolute offset of the containing comment record. `by_requirement` is keyed by
requirement ID and ordered lexically. `Report#to_h(timestamp: false)` omits the
timestamp for comparisons; passing one `now:` to both runs pins it instead.

## Requirements and profiles

Requirement IDs are lowercase, dot-separated and format-qualified:
`<format>.<record or scope>.<constraint>`, for example `emf.restoredc.saved_dc`,
`emfplus.header.placement`, `wmf.record.size_minimum`. The specification section
lives in `context.spec_citation` and in the manifest, not in the ID, so a citation
correction never renames a rule. Parser recovery rules use `emf.parse.*`; parity
fixtures use test case names, never requirement IDs.

Profiles are immutable registry entries in plain Ruby. Each requirement declares
its default strict severity and, when justified by the documented real-world
corpus, its tolerant severity. Tolerant mode does not suppress findings: accepted
recoveries remain named warnings. Rules without a documented tolerant exception
retain their strict severity.

This mirrors `svg_conform`'s profile-owned, ID-addressable requirements and
requirement-grouped report summaries without adopting its `lutaml-model`
serialization dependency or SVG-specific element fields.

## Technical decisions

### One Ruby lens over the public model

There is one rule implementation in Ruby. Forced-Ruby and forced-native backends
must produce identical normalized reports from the same input. The native backend
already hydrates the Ruby record model; copying rules into Rust would create the
second validation/decode path prohibited by the issue.

### Public API only

Rules may read only public metafile records, record offsets and wire fields,
`Metafile#errors`, and `emf_plus_stream`. They must not inspect native snapshots,
`Emf::Native::Diagnostics`, `Emf::Native::WmfRejection`, lazy-wire internals, or
backend-specific classes. This keeps report behavior backend independent.

`lib/emf/native/diagnostics.rb` and `header_errors.rb` are useful parser-parity
assets because they translate native failures into the same public `ParseError`
shape. The lens reuses only that public result through `Metafile#errors`; it does
not invoke either native translator directly.

### Parser recovery is evidence, not conformance

A `Raw` record, `ParseError`, or trailing bytes must produce a named diagnostic.
Strict mode treats it as an error. Tolerant mode may downgrade a documented corpus
recovery to a warning, but it never treats missing validation coverage as proof of
conformance. The lens continues over all model records after recoverable errors.

### Existing variants are parity inputs

`spec/support/record_variants*.rb` exercises serialization and backend parity.
Its `valid` labels do not mean spec-conformant: for example, SELECTOBJECT handle
zero and positive RESTOREDC `SavedDC` values contradict normative clauses. New
conformance expectations require independent oracle cases with citations.

### No new runtime serializer dependency

The report mirrors svg_conform's stable keys with Ruby value objects instead of
adding `lutaml-model`. EMF currently has only `bindata` as a runtime dependency;
duplicating a small data shape is lower risk than enlarging every parser user's
runtime graph for validation serialization.

### Model gaps are explicit dependencies

A rule manifest row's `status` is one of:

| Status | Meaning | `reason` |
| --- | --- | --- |
| `implemented` | A registered rule with this id exists. | must be absent |
| `deferred` | The data is readable from the public model today; no rule is written yet. | required |
| `blocked:model` | The check needs a public model field that does not exist yet. | required: the missing field |
| `not_checkable` | No input can violate it, or the bytes are ignored on receipt. | required |

(`planned` was an earlier name for `deferred` and is no longer accepted.) A
`blocked:model` row is only honest when the data really is unreadable; a row
whose reason says the bytes are readable is `deferred`. Every record type of the
three inventories must appear in at least one row (by name or numeric code);
`spec/emf/conformance/manifest_completeness_spec.rb` enforces it. A row with
`record_types: []` is a generic rule and counts toward no type. Blocked entries
remain visible in coverage tests. Model/native changes land under
the PR #54 ownership stream or a follow-up, then expose the same public data from
both backends before the rule is enabled.

### WMF rejection data is not reusable by the lens

Rust `first_rejection` and `Emf::Native::WmfRejection` provide 56 stable reason
codes for native/parser parity. The Ruby table consumes a native WMFR packet and
therefore cannot be a lens dependency. A backend-neutral parse-result/model
surface is required before rejected-input WMF diagnostics can be evaluated by the
same Ruby lens. Messages and stable reason meanings may inform requirement IDs,
but the lens must not call the table.

## Compatibility and preservation

- No runtime gem dependency is added; `bindata` remains the sole runtime
  dependency.
- Parsing and serialization results do not change merely because conformance is
  available.
- Unknown EMF/WMF records remain preserved and serialized as today; the lens may
  report that their normative payload could not be evaluated.
- All report values are Ruby primitives/value objects and do not expose mutable
  wire or native objects.
- The public model contract must remain identical under Ruby and native parsing.

## Tolerant policy

A rule that carries a `tolerant_reason` is downgraded from error to warning under
`tolerant` for **every input** that triggers it, not only for the fixture that
motivated the reason. The waiver is per requirement, never per file: there is no
fixture allowlist. The downgrade never hides a finding (the warning keeps its
`requirement_id`, `kind`, citation and offset) and the written reason appears as
`context.waiver`. Consequences: a waiver is a statement about what real producers
do and must stay narrow; a rule with no `tolerant_reason` (for example
`emf.parse.unparseable`) is an error under both profiles. Pinned by
`spec/emf/conformance/profile_spec.rb`.

## Parse-recovery ids

`Metafile#errors` entries (recovered `ParseError`s) carry no `#evidence` on
either backend, so the `emf.record.*` recovery ids are chosen from the error
message. Only a `FormatError`/`ParseError` raised for an input that yields no
metafile carries `ParseEvidence`. When recovered errors gain evidence, the rule
classifies from `evidence.check` first and keeps the message table as the
fallback; `spec/emf/conformance/parse_recovery_spec.rb` fails on that day.

## Product decision (resolved 2026-10-21)

The corruption corpus contains two files for which the parser cannot construct a
model: one truncated EMR_HEADER and one input with an unrecognized first word.
The phrase “the corpus must pass tolerant” has two plausible meanings:

1. **Recommended:** every file returns a report without crashing; the 19 parsed or
   recovered models are `valid: true` with tolerant warnings, while the two files
   with no record model remain invalid format reports.
2. Downgrade even a no-model format rejection to a warning so all 21 reports are
   `valid: true`.

The owner chose the first: the two files with no record model report
`valid: false` under both profiles with the named format error
`emf.parse.unparseable` (an `emf.parse.unparseable` finding, or the specific
`wmf.reject.rNNNN` finding when the input is a rejected WMF).
