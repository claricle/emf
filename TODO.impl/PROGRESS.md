# TODO Progress — 2026-07-24 (second pass)

This file summarises what's been implemented vs what remains. Each TODO
file in this directory has its own detailed scope; this is the roll-up.

## Done

### Foundation (TODOs 01–06) — fully complete
- Gem scaffold, error hierarchy, bindata primitives, geometry value
  types, Metafile container, Record base, Visitor base, format detector.

### TODO 02 — Reference doc converter — fully complete
- `scripts/convert_docs.rb` (rubyzip + nokogiri).
- 21 chapter files generated across MS-WMF, MS-EMF, MS-EMFPLUS.
- 4 specs including a synthetic-docx end-to-end test.

### TODO 09 — EMF wire layer — substantially complete
- 117 of ~122 EMR_* types declared as bindata wire classes.
- Header wire class supports 88/100/108-byte variants + trailing bytes.
- Registry + autoload + Raw fallback for the few remaining types.
- TypeCodes module documents the canonical numeric constants.

### TODO 10 — EMF domain layer — MVP complete
- `Emf::Model::Emr::Header` preserves all 18 wire fields + trailing.
- `Emf::Model::Emr::Records::WireAdapter` wraps every other wire class.
- Per-record semantic classes deferred (WireAdapter carries type_id and
  the underlying wire for emfsvg to dispatch on).

### TODO 11 — EMF parser — MVP complete
- Reads variable-length header, walks records, dispatches via registry.
- Per-record error trapping via `Emf::ParseError`.
- Variable-array sanity check (prevents pathological hangs).
- EMF+ payload extraction (raw bytes on `Metafile#emf_plus`).
- Post-EOF trailing bytes captured on `Metafile#trailing`.
- 2-pass path association deferred (TODO 11 follow-up).

### TODO 15 — Public API — fully complete
- `Emf.parse`, `parse_file`, `serialize`, `serialize_file`,
  `detect_format`. Auto-dispatches WMF vs EMF.

### TODO 16 — Round-trip harness — fully complete
- `spec/emf/round_trip_spec.rb` walks every non-corrupted fixture
  (186 + 21 + 1 = 208) and asserts byte-identical round-trip.

### TODO 17 — Corrupted-resilience spec — fully complete
- `spec/emf/corrupted_resilience_spec.rb` walks all 21 `emf-corrupted/`
  files. Asserts no crash, no hang (5s timeout). All 21 pass.

### TODO 18 — Visitors — fully complete
- `Emf::Visitors::Stats` produces record-class histogram.
- `Emf::Visitors::Dump` produces human-readable dump.
- Both override `visit_emr_wire_record` for the catch-all adapter.

### TODO 19 — CLI — fully complete
- `exe/emf` with subcommands: `version`, `info`, `dump`, `validate`,
  `stats`, `round-trip`, `help`.
- Tested end-to-end against `spec/fixtures/simple/image1.emf`.

### TODO 20 — Documentation — fully complete
- `README.adoc` rewritten with synopsis, CLI usage, architecture,
  constraints, roadmap.
- `docs/architecture.adoc` — three-layer design + MECE table.
- `docs/format_notes.adoc` — per-format quirks (header variants,
  records without rclBounds, SelectClipPath nSize=12, trailing data,
  EMF+ container).
- `CONTRIBUTING.adoc` — branch policy, code style, constraints,
  how-to-add-a-record.
- `CHANGELOG.adoc` — Keep-a-Changelog format starting at 0.1.0.

### TODO 21 — CI — fully complete
- `.github/workflows/test.yml`: matrix on Ruby 3.1/3.2/3.3/3.4 across
  Ubuntu and macOS. Runs specs, rubocop, gem build.
- `.github/workflows/release.yml`: tag-triggered (`v*`) release to
  rubygems.org + GitHub release. Gated on tag push, not on main commits.
- No AI attribution anywhere.

## Verification (against spec/fixtures/)

- **306 specs, 0 failures** (up from 75 in the first pass).
- Rubocop clean (179 files).
- Gem builds.
- **Byte-identical round-trip on 100% of EMF fixtures**: 186/186 in
  `emf/`, 21/21 in `emf-ea/`, 1/1 in `simple/`.
- All 21 `emf-corrupted/` files parse without crashing or hanging.

## Remaining work

### P0 — semantic refinements

| # | Title | Why |
|---|---|---|
| 10 | Replace `WireAdapter` with semantic per-record domain classes | emfsvg gets `Polygon#points` instead of `wire.aptl` |
| 11 | 2-pass path association (BEGINPATH ↔ FILLPATH/STROKEPATH) | emfsvg's path rendering needs the back-reference |

### P1 — additional formats and tooling

| # | Title | Why |
|---|---|---|
| 07 | WMF wire + domain + parser | second format |
| 08 | Source WMF fixtures | can't validate WMF without |
| 12 | EMF+ wire layer (~58 records) | third format |
| 13 | EMF+ domain layer | mirror |
| 14 | EMF+ parser (consumes EMR_COMMENT payload) | wires EMF+ into `Metafile#emf_plus` |

## Known improvements for a future PR

1. **SelectClipPath wire class** is currently spec-form (28 bytes) but
   real-world files often have nSize=12 (header + regionMode only, no
   rclBounds). Non-conforming files fall through to Raw. Fix: make the
   rclBounds field conditional on nSize, or split into two classes.
2. **`Stats#visit_emr_wire_record`** tallies by underlying wire class
   (e.g. `WireAdapter(Comment)`). Once TODO 10 lands semantic classes,
   the histogram will show `Polygon`, `Polyline`, etc. directly.
3. **Header to_wire** preserves `trailing` bytes verbatim but doesn't
   semantically model the optional description string or pixel format
   data. A future refactor could parse them properly.
