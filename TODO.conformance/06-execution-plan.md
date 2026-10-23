# Execution plan

## Status vocabulary

- `in progress` — assigned foundational work described by the issue owner.
- `planned` — scoped but not started; execute after the listed plan dependencies.
- `blocked` — requires the named model/native or product dependency.
- `done` — merged to `main` with its specs green.

Manifest-row statuses (a different vocabulary, see `01-contract-and-decisions.md`)
are `implemented`, `deferred`, `blocked:model` and `not_checkable`.

Owners are intentionally blank for assignment at execution time. WMF rules and
backend-parity specs remain separate work streams; model/native files remain
outside lens ownership.

## Ordered work items

| ID | Status | Owner | Work item and output | Depends on | Effort |
| --- | --- | --- | --- | --- | ---: |
| W01 | done |  | Add `Emf::Conformance.check`, `Diagnostic`, and plain-Ruby `Report` with svg_conform-compatible top-level keys plus offsets/citations. | — | 30–40m |
| W02 | done |  | Add registry and immutable strict/tolerant profile entries; reject unknown profiles and keep requirement IDs severity-independent. | W01 | 30–40m |
| W03 | done |  | Register EMF header, EOF, common framing, trailing-byte, Raw and `Metafile#errors` recovery rules with cited diagnostics. | W01–W02 | 35–40m |
| W04 | done |  | Adapt the existing EMF+ stream conformance results to the common report/registry without duplicating decoding. | W01–W02 | 20–30m |
| W05 | done |  | Freeze issue ordering, summary grouping, primitive-only context, shared timestamp injection and report serialization contract. | W01 | 20–30m |
| W06 | done |  | Build the checked-in requirement manifest for every inventory row, including section, accessor, profile severity and `blocked:model` reason; add coverage specs that fail on omissions. | W02, inventory review | 30–40m |
| W07 | done |  | Complete EMF HEADER description/pixel-format and EOF palette/`SizeLast` constraints and oracle fixtures. | W03, public buffer/location fields | 30–40m |
| W08 | done |  | Add EMF fixed state/transform enum, flag, nonzero divisor, finite matrix and RESTOREDC constraints. | W06 | 30–40m |
| W09 | done |  | Add EMF object create/select/delete, stock handle, palette and object-lifecycle constraints. | W06 | 30–40m |
| W10 | done |  | Add EMF path-bracket, clipping and DC-state sequence constraints. | W06 | 25–35m |
| W11 | done |  | Add EMF point, polygon, PolyDraw, GradientFill and region count/size constraints with real type 71–74 fixtures. | W06 | 30–40m |
| W12 | done |  | Add EMF EXTTEXTOUT/SMALLTEXTOUT/POLYTEXTOUT string, Dx, character-count and offset/length rules. | W06, public decoded text fields | 30–40m |
| W13 | done |  | Add EMF bitmap usage, BMI/bits offset/length, overlap, stride and record-end bounds; mark unexposed semantic checks blocked. | W06 | 30–40m |
| W14 | done |  | Add EMF comment, escape, OpenGL and opaque-record outer count/bounds coverage; retain semantic payload gaps in the manifest. | W06 | 30–40m |
| W15 | done |  | Add EMF+ common framing/control/reserved-type and Header/EOF placement rules with requirement IDs. | W04, W06 | 25–35m |
| W16 | done |  | Add EMF+ property, transform, flag-mask, enum, unit, range and finite-value rules. | W06 | 30–40m |
| W17 | done |  | Add EMF+ drawing geometry, point/rectangle counts, compressed-coordinate and payload-bound rules. | W06 | 30–40m |
| W18 | done |  | Translate public EMF+ object-resolution and state/container results into referring-record diagnostics without copying the resolver. | W06 | 30–40m |
| W19 | done |  | Cover EMF+ DriverString/image/SerializableObject/terminal payloads and StrokeFillPath; add blocked entries for fields still opaque. | W06, public model fields as needed | 30–40m |
| W20 | done |  | In the WMF work stream, map all 115 specified layouts and 56 rejection reasons to stable requirement IDs and public accessors/blocked reasons. | W02 | 30–40m |
| W21 | done |  | Add WMF accepted-model fixed, enum, count, array and framing rules using only public records. | W20 | 30–40m |
| W22 | done |  | Add WMF object allocation/type/select/delete/capacity and DC-state constraints over the public record sequence. | W20 | 30–40m |
| W23 | done |  | Add WMF bitmap, text, palette, region, escape and embedded-EMF buffer rules; preserve opaque subtypes. | W20 | 30–40m |
| W24 | done |  | Add WMF declared-size and all rejected-input reason diagnostics after neutral size/parse evidence is public; do not call native rejection classes. | W20, model/native dependency | 20–30m |
| W25 | done |  | Add strict/tolerant oracle specs for corrupted fixtures 1–7, including the first hard format rejection. | W02–W14 and blocked text/header fields | 30–40m |
| W26 | done |  | Add strict/tolerant oracle specs for corrupted fixtures 8–14, with a bounded test for the 1.5 MiB recovery file. | W02–W19 and blocked text/header fields | 30–40m |
| W27 | done |  | Add strict/tolerant oracle specs for corrupted fixtures 15–21 and assert continuation after Raw/ParseError recovery. | W02–W19 and blocked text/font fields | 30–40m |
| W28 | done |  | In the parity work stream, compare normalized full reports for forced Ruby/native EMF and EMF+ inputs, including Raw and recovery cases. | W05, relevant rules | 30–40m |
| W29 | done |  | Extend forced-backend full-report parity to accepted and rejected WMF cases. | W21–W24, neutral rejection result | 30–40m |
| W30 | done |  | Rust CI runs all of `spec/emf` with `EMF_TEST_NATIVE_LIBRARY` set and fails on library-missing skips (#56), so every `backend_parity*_spec.rb` runs natively there. The parity guard counts only native wire sources (#64). | W28 | 20–30m |
| W31 | done |  | Document bytes/model input, report keys, profile semantics, blocked coverage and examples without adding a runtime dependency. | W05, W27 | 20–30m |
| W32 | done |  | Final run: main at `b79254a` passed Test, Rust, the corrupted-corpus resilience run and the downstream goldens. | W07–W31 and owner corpus decision | 30–40m |
| W33 | done |  | Investigated EMF SELECTOBJECT in `2014-12-07-140817.emf`: all 28 SELECTOBJECT and 12 DELETEOBJECT records are valid (sizes, stock indices, handle lifecycle), so the corruption is not detectable from the stream. Recorded as `not_checkable` row `emf.select_object.corpus_corruption`; the corpus oracle references it. | W09, W25 | 20–30m |
| W34 | done |  | Re-count `blocked:model`: move rows whose reason says the data is readable (EOF last position, bitmap and comment checks) to `deferred` or implement them; report `blocked:model` only for fields that are truly unreadable. Finding 4. | W06 | 20–30m |
| W35 | done |  | Corpus oracle: each corrupted fixture asserts its exact expected requirement id(s) under strict and the matching warning(s) under tolerant, not a regex over ids. Finding 3. | W25–W27, W33 | 30–40m |
| W36 | blocked |  | Recovered `ParseError`s in `Metafile#errors` carry no `#evidence`, so `emf.record.*` ids still come from the message table. Needs evidence on recovered errors in the parser (issue #15 scope). `parse_recovery_spec.rb` is the tripwire that fails when it lands. | model dependency | 20–30m |
| W37 | done |  | Review overlapping rules (same constraint checked by two rules, for example EMF+ rows already `not_checkable` because another rule covers them) and record the survivor per constraint in the manifest. Finding 9. | W06 | 20–30m |
| W38 | done |  | Completeness gate: every record type of the 119 EMF, 55 EMF+ and 70 WMF RecordType entries appears in a manifest row (`manifest_completeness_spec.rb`); a type counts as covered only by an implemented, `not_checkable` or `blocked:model` row (W43 removed the interim `coverage_gaps.yml`). Finding 1. | W06 | 30–40m |
| W39 | done |  | Report issues carry `kind` and `spec_citation` at the top level (with `category` and `context.spec_citation` kept). Finding 2. | W05 | 10–15m |
| W40 | done |  | Document the tolerant policy (a `tolerant_reason` waives the rule for every input) and pin it in `profile_spec.rb`. Finding 5. | W02 | 10–15m |
| W41 | done |  | Performance bound: the largest fixture checks under strict within 2 s (`performance_spec.rb`; measured 0.19-0.31 s). Finding 9. | W26 | 10–15m |
| W42 | done |  | Plan documents corrected: path inputs, status vocabulary, `emf.parse.unparseable` ids, element format, owner decision. Finding 8. | — | 20–30m |
| W43 | done |  | Close the coverage gaps: rules for the WMF fixed-geometry and state records and EMF+ ellipse records left in `manifest/coverage_gaps.yml`; the completeness gate no longer counts `deferred` rows as coverage; WMF text-align horizontal/vertical domains; WMF rejection reasons limited by input size or shadowed by detection become `not_checkable`. | W38 | 40–60m |
| W44 | done |  | Name the remaining detectable corpus corruptions (EMF+ payload, header buffer, nHandles, null bitmap object, text/font files) in the oracle; an empty strict list must reference a `not_checkable` manifest row. | W35 | 30–40m |

## Model/native dependencies

These changes are prerequisites owned under `lib/emf/model/**` and
`lib/emf/native/**`, coordinated with PR #54 or a follow-up. They are not lens
implementation work:

1. expose full variable buffers even when a wire `body`/`trailing` field absorbed
   them, identically for Ruby and native hydration;
2. decode or expose EMF HEADER description/pixel format, EOF palette location,
   and EXTTEXTOUT string/Dx data needed by cited rules;
3. propagate the containing EMR_COMMENT file offset to public EMF+ stream
   records;
4. expose WMF declared record size on accepted records; and
5. return backend-neutral structured evidence when WMF/header parsing cannot
   produce a metafile model.

No lens rule may read lazy-wire, snapshot, native diagnostic, or WMFR packet
internals while waiting for these dependencies.

## Effort

The 32 work items total **15h 05m–20h 20m** of focused implementation and
verification time. This excludes review latency, CI queue time, and the separately
owned model/native prerequisites. Items can run in parallel after W06 by format
family; corpus and parity items integrate only after their cited rules land.

## Acceptance commands

All implementation commands below are **planned, not run** during planning:

```sh
bundle exec rspec spec/emf/conformance
bundle exec rspec spec/emf/conformance/corpus*_spec.rb
bundle exec rspec spec/emf/conformance/backend_parity*_spec.rb
bundle exec rspec
bundle exec rubocop
```

The backend-parity command is valid only with the native library forced:

```sh
EMF_TEST_NATIVE_LIBRARY="$library" bundle exec rspec \
  spec/emf/native spec/emf/native_wmf*_spec.rb spec/emf/wmf \
  spec/emf/conformance/backend_parity*_spec.rb
```

Acceptance requires:

- manifests enumerate 119 EMF, 55 defined EMF+ and the 70 MS-WMF RecordType
  entries by name or code (gated by `manifest_completeness_spec.rb`); the
  META_HEADER/META_PLACEABLE layouts and the escape subtypes of the 115 layouts
  are tracked by their own rows and are not yet part of that gate;
- every emitted issue has stable identity, severity, exact offset and citation;
- all 19 parsed/recovered corrupted fixtures are valid with named tolerant
  warnings and invalid with named strict errors;
- the two no-model fixtures follow the owner-approved validity policy and always
  return structured reports;
- forced-backend normalized reports are byte-for-byte equal; and
- no new runtime gem dependency or backend-specific lens access is introduced.
