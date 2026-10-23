# Issue 37 progress

Last update: 2026-10-23. Delivered on `main` at `b79254a`.

## Status summary

| Area | Status | Evidence / next gate |
| --- | --- | --- |
| Entry point, diagnostic, report | Done | `Emf::Conformance.check`; issue keys incl. `kind` and `spec_citation` (`report_spec.rb`). |
| Registry, profiles, manifest | Done | Strict/tolerant with per-rule `tolerant_reason`; manifest statuses implemented / blocked:model / not_checkable / deferred; completeness gate over 119 EMF, 55 EMF+, 70 WMF types. |
| EMF rules | Done | Header/EOF/framing/recovery, state, transform, path/clip, objects, geometry, bitmap, comment/escape/OpenGL, text, header buffers. |
| EMF+ rules | Done | Framing, properties, drawing, objects/state, payloads, ellipse sizes. |
| WMF rules | Done | Framing, records, objects/DC state, buffers, fixed layouts, TernaryRasterOperation values, rejection reasons from `Error#evidence`. |
| Corrupted corpus | Done | Oracle names the corruption in 20 of 21 files; 140817 is proven undetectable and references a `not_checkable` row. |
| Backend parity | Done | EMF, EMF+ and WMF full-report parity specs run natively in the Rust CI job (#56, #64). |
| Model prerequisites | Done | Header buffers, EOF palette, EXTTEXTOUT string/Dx, EMF+ comment offset, variable buffers, WMF declared size, `Error#evidence`. |
| Documentation | Done | README "Conformance lens" section and CHANGELOG entry. |

## Work items

Done: W01–W35 and W37–W44. Blocked: W36 (evidence on recovered parse errors needs a parser
change; `parse_recovery_spec.rb` fails when it lands).

## Delivered

| PR | Content |
| --- | --- |
| #60 | Public record fields the lens reads: header buffers, EOF palette, EXTTEXTOUT string/Dx, EMF+ comment offset, variable buffers, WMF declared size, `Error#evidence`. |
| #61 | The conformance lens: rules for EMF, EMF+ and WMF, report, profiles, manifest, corpus oracle, parity specs, README section. |
| #62 | EMF+ count fields bounded by the bytes left in a record (parser, issue #15), closing the memory exhaustion the lens fuzz found. |
| #64 | Parity guard distinguishes backends by native-only wire sources after the Ruby parser gained its own byte-backed records. |

## Open items

- W36 (above).
- 1 of 21 corrupted fixtures (`bad_corrupted_2014-12-07-140817.emf`) has no detectable corruption in its
  record stream; it is recorded as `not_checkable` (`emf.select_object.corpus_corruption`).
