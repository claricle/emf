# TODO Progress — 2026-07-24

This file summarises what's been implemented vs what remains. Each TODO
file in this directory has its own detailed scope; this is the roll-up.

## Done (foundation + working EMF MVP)

| # | Title | Status |
|---|---|---|
| 01 | Bootstrap gem skeleton | done — gem builds, specs run, rubocop clean |
| 02 | Convert MS spec .docx → GFM markdown | done — script + 4 specs, 21 chapter files generated for MS-EMF, MS-WMF, MS-EMFPLUS |
| 03 | Binary primitives & codec | done — 11 bindata primitives + codec, all round-trip specced |
| 04 | Geometry value types | done — 8 value types (Point, PointF, PointS, Size, Rect, RectS, Color, Matrix) |
| 05 | Metafile container, Record base, Visitor base | done — Metafile enumerable, Record abstract, Visitor with register_visit |
| 06 | Format detector | done — APM WMF, standard WMF, EMF, garbage, short input |
| 09 | EMF wire layer | partial — 61 of ~122 record types declared, header fully parsed, registry + Raw fallback |
| 10 | EMF domain layer | partial — Header + WireAdapter; per-record domain classes land in TODO 10 follow-up |
| 11 | EMF parser | MVP done — single-pass, per-record error trapping, EMF+ payload extraction stub; 2-pass path association lands in TODO 11 follow-up |
| 15 | Public API surface | MVP done — Emf.parse / .parse_file / .serialize / .serialize_file / .detect_format |

## Verification (against spec/fixtures/)

- 75 specs, 0 failures.
- Rubocop clean (122 files, 0 offenses).
- Byte-identical round-trip on 137/186 EMF fixtures (74%).
- All 186 EMF fixtures parse without raising.
- Simple fixture (image1.emf): 3538 records, 0 errors, byte-identical round-trip.
- Converter output verified against all three MS spec .docx.

## Remaining work

### P0 — landing the full EMF MVP

| # | Title | Why |
|---|---|---|
| 09 | EMF wire layer — finish remaining EMR_* types | ~60 more record types needed for 100% round-trip on all fixtures |
| 10 | EMF domain layer — replace WireAdapter with semantic classes | emfsvg needs typed records, not raw bindata wrappers |
| 11 | EMF parser — 2-pass path association | emfsvg needs path→renderer back-references |
| 16 | Round-trip harness — every non-corrupted fixture | strongest correctness signal |
| 17 | Corrupted-resilience spec — emf-corrupted/ corpus | proves no crashes/hangs |

### P1 — completing the formats and tooling

| # | Title | Why |
|---|---|---|
| 07 | WMF wire + domain + parser | second format |
| 08 | Source WMF fixtures | can't validate WMF without |
| 12 | EMF+ wire layer (~60 records) | third format |
| 13 | EMF+ domain layer | mirror |
| 14 | EMF+ parser (consumes EMR_COMMENT payload) | wires EMF+ into Metafile#emf_plus |
| 18 | Visitors: Dump and Stats | debugging + spec assertions |
| 19 | exe/emf CLI | user-facing tool |
| 20 | Documentation | README + architecture + format notes |
| 21 | CI | GitHub Actions matrix |

## Known issues to address in TODO 10/11 follow-ups

1. **49 EMF fixtures don't byte-round-trip yet** (21 EOFError on reparse, 28 record-count drift). Most are EMF+ carriers and records with field layouts we stubbed (`rest :body`). Fix: complete the wire classes for the remaining ~60 EMR_* types in TODO 09.
2. **EMF+ extraction stashes raw bytes**, not a parsed `Metafile`. The structured extraction lands in TODO 14.
3. **Path association (BEGINPATH..ENDPATH ↔ FILLPATH/STROKEPATH) is not built**. emfsvg's rendering of EMF paths will need this; lands in TODO 11.
4. **WireAdapter wraps the bindata record**, not a true semantic class. emfsvg gets type_id + raw fields; proper `Emf::Model::Emr::Records::Polygon` etc. land in TODO 10.
