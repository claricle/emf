# TODO 20 — Documentation

**Priority:** P1
**Depends on:** 19
**Status:** pending

## Context

The gem ships with only a one-line `README.adoc`. Bring it up to production quality so users (and emfsvg contributors) know what `emf` does, how to use it, and where the architecture lives.

## Outcomes

- `README.adoc` rewritten with:
  - Title, summary, license.
  - Installation (`gem install emf` or Gemfile).
  - Synopsis: parse, walk, serialize.
  - CLI usage.
  - Architecture overview (one paragraph + a link to `docs/architecture.adoc`).
  - Development setup (clone, `bundle install`, `bundle exec rspec`).
  - Contributing pointer.
- `docs/architecture.adoc` — 1–2 page deep dive on the bindata-wire / domain / visitor split. Diagrams as ASCII.
- `docs/format_notes.adoc` — quirks of each format (EMF two-pass, EMF+ in comments, WMF APM vs standard) that future maintainers must know.
- `CONTRIBUTING.adoc` — branch naming, PR rules, no AI attribution, no `require_relative`.
- `CHANGELOG.adoc` — Keep-a-changelog format, starting at 0.1.0.
- `CODE_OF_CONDUCT.md` (already in TODO 01).

## Files

```
README.adoc                                  # full rewrite
docs/architecture.adoc                       # wire/domain/visitor split
docs/format_notes.adoc                       # EMF/WMF/EMF+ quirks
CONTRIBUTING.adoc
CHANGELOG.adoc
```

## Done when

- [ ] README synopsis runs (verify by copy-pasting into `bin/console`).
- [ ] Architecture doc has a diagram.
- [ ] Format notes cover the 3 known quirks from the C library (two-pass paths, EMF+ container, WMF APM).
- [ ] CHANGELOG has 0.1.0 entry.
