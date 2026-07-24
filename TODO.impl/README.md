# TODO Index

The `emf` gem is a pure-Ruby parser for WMF / EMF / EMF+ formats, producing
an OOP domain model that `emfsvg` consumes for SVG transformation. See
`../PLAN` (in `~/.claude/plans/we-are-to-write-glimmering-unicorn.md`) for the
full architecture.

## Roadmap

| # | Title | Priority | Status |
|---|---|---|---|
| [01](01-bootstrap-gem-skeleton.md) | Bootstrap gem skeleton | P0 | pending |
| [02](02-convert-reference-docs.md) | Convert MS spec .docx → GFM markdown | P0 | pending |
| [03](03-binary-primitives.md) | Binary primitives & codec (shared Bindata types) | P0 | pending |
| [04](04-geometry-value-types.md) | Geometry value types (Point/Size/Rect/Color/Matrix) | P0 | pending |
| [05](05-metafile-record-visitor-base.md) | Metafile container, Record base, Visitor base | P0 | pending |
| [06](06-format-detector.md) | Format detector (WMF vs EMF vs EMF+ container) | P0 | pending |
| [07](07-wmf-wire-domain-parser.md) | WMF wire + domain + parser | P1 | pending |
| [08](08-source-wmf-fixtures.md) | Source WMF fixtures | P1 | pending |
| [09](09-emf-wire-layer.md) | EMF wire layer (header + all EMR_* records) | P0 | pending |
| [10](10-emf-domain-layer.md) | EMF domain layer | P0 | pending |
| [11](11-emf-parser.md) | EMF parser (2-pass path assoc, EMF+ extraction) | P0 | pending |
| [12](12-emfplus-wire-layer.md) | EMF+ wire layer (~60 EMF+ records) | P1 | pending |
| [13](13-emfplus-domain-layer.md) | EMF+ domain layer | P1 | pending |
| [14](14-emfplus-parser.md) | EMF+ parser (consumes EMR_COMMENT payload) | P1 | pending |
| [15](15-public-api.md) | Public API surface | P0 | pending |
| [16](16-round-trip-harness.md) | Round-trip serialization test harness | P0 | pending |
| [17](17-corrupted-resilience.md) | Corrupted-resilience spec | P0 | pending |
| [18](18-visitors-dump-stats.md) | Visitors: Dump and Stats | P1 | pending |
| [19](19-cli.md) | exe/emf CLI | P1 | pending |
| [20](20-documentation.md) | Documentation | P1 | pending |
| [21](21-ci.md) | CI: GitHub Actions matrix | P1 | pending |

## Dependency graph

```
01 ─┬─ 02
    │
    ├─ 03 ─┬─ 04 ── 05 ── 06 ── 15 ── 16
    │      │              │      │
    │      ├─ 09 ── 10 ── 11 ────┤
    │      │              │      │
    │      │              ├─ 17  │
    │      │              │      │
    │      ├─ 12 ── 13 ── 14 ────┤
    │      │                     │
    │      └─ 07 ────────────────┤
    │              │             │
    └─ 08 ─────────┴─────────────┴── 18 ── 19 ── 20 ── 21
```

## MVP scope (P0)

01, 02, 03, 04, 05, 06, 09, 10, 11, 15, 16, 17 — full EMF parse/serialize with
resilience and round-trip verification, plus the foundation that EMF+ and WMF
build on. Once these are merged, the gem is usable for emfsvg's EMF→SVG path.

## Full scope (P0 + P1)

Adds WMF support (07, 08), EMF+ (12, 13, 14), visitors and CLI (18, 19),
documentation (20), CI (21). After all 21 TODOs, the gem is production-ready.

## Conventions (every TODO honors)

- **No `require_relative`** in `lib/`. No `require` of internal paths. Use Ruby
  `autoload` defined in the immediate parent namespace's file.
- **No doubles** in specs (`RSpec.describe` with real instances only).
- **No `send` to private methods**, **no `instance_variable_set/get`**,
  **no `respond_to?` for type checking** (use `is_a?` or design away the check).
- **No AI attribution** in any commit message or PR description.
- **No commits to `main`**, **no tag pushes**. All work via PRs on feature branches.
- **BSD-2-Clause** license, clean-room reimplementation, no GPL taint.
- **bindata for wire, PORO for domain, `from_wire`/`to_wire` to translate.**
- **Registry + autoload** for OCP. Adding a record touches the record's own file
  plus three lines in the format's `records.rb`.
- **Visitor pattern** for consumers. `emf` itself stays closed for modification.
