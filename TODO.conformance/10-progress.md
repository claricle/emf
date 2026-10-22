# Issue 37 progress

Last update: 2026-10-22 (integrated branch `feat/conformance-lens`)
Baseline: `origin/main` at `f20eb0e`

## Status summary

| Area | Status | Evidence / next gate |
| --- | --- | --- |
| Entry point, diagnostic, report | Done | `Emf::Conformance.check`; issue keys incl. `kind` and `spec_citation` (`report_spec.rb`). |
| Registry, profiles, manifest | Done | Strict/tolerant with per-rule `tolerant_reason`; manifest statuses implemented / blocked:model / not_checkable / deferred; completeness gate over 119 EMF, 55 EMF+, 70 WMF types. |
| EMF rules | Done | Header/EOF/framing/recovery, state, transform, path/clip, objects, geometry, bitmap, comment/escape/OpenGL, text, header buffers. |
| EMF+ rules | Done | Framing, properties, drawing, objects/state, payloads, ellipse sizes. |
| WMF rules | Done | Framing, records, objects/DC state, buffers, fixed layouts, TernaryRasterOperation values, rejection reasons from `Error#evidence`. |
| Corrupted corpus | Done | Oracle names the corruption in 20 of 21 files; 140817 is proven undetectable and references a `not_checkable` row. |
| Backend parity | Done locally; CI selection pending | EMF, EMF+ and WMF full-report parity specs; Rust CI selection (W30) waits on PR #56. |
| Model prerequisites | Done | Header buffers, EOF palette, EXTTEXTOUT string/Dx, EMF+ comment offset, variable buffers, WMF declared size, `Error#evidence`. |
| Documentation | Done | README "Conformance lens" section and CHANGELOG entry. |

## Work items

Done: W01–W29, W31, W33–W35, W38–W44.
Planned: W30 (Rust CI selection, after PR #56), W32 (final CI run), W36 (evidence on recovered
errors, tripwire in `parse_recovery_spec.rb`), W37 (overlapping-rule review).

## Handoff order

1. Integrate and review W01–W04 against the public contract without assuming the
   in-progress branch is complete merely because files exist.
2. Freeze serialization and build the complete manifest in W05–W06.
3. Run EMF, EMF+ and accepted-model WMF rule chunks in parallel, respecting the
   file ownership in `06-execution-plan.md`.
4. Land public-model prerequisites through their owner, then enable only the
   previously blocked manifest entries whose Ruby/native accessors match.
5. Add corpus oracles, report parity and CI selection; finish with W32.

## Progress update template

For each completed item record:

- item ID and commit;
- files changed and requirement IDs enabled;
- acceptance commands actually run and their results;
- manifest entries still `blocked:model` with dependency links; and
- revised remaining low/high effort calculated from unfinished rows.

Do not convert a blocked requirement to “covered” because a parser rejected the
input or because a serializer variant round-trips.
