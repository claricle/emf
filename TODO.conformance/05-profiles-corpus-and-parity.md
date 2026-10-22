# Profiles, corpus, and backend parity

## Profile contract

`strict` reports every violated normative requirement as an error. `tolerant`
changes severity only for a rule that carries a written `tolerant_reason`; the
waiver applies to that requirement for every input, not per fixture (see
`01-contract-and-decisions.md`, "Tolerant policy"). It never hides a finding and never changes its
`requirement_id`, `kind`, citation, or offset.

The tolerant corpus suite passes when:

1. every input terminates without a crash, hang, or unbounded allocation and
   returns a structured report;
2. each of the 19 inputs that produces a parsed or recovered model has no errors,
   is `valid: true`, and contains the expected named warning(s);
3. `Raw` records, `ParseError`s and trailing bytes become warnings only where the
   fixture matrix permits recovery, and validation continues over later records;
4. every warning has a stable kind, requirement ID, citation and real record/file
   offset; and
5. per the owner decision of 2026-10-21 (`01-contract-and-decisions.md`), the two
   inputs that cannot produce a record model return `valid: false` format
   reports (`emf.parse.unparseable`) under both profiles.

Thus “pass tolerant” means the validation operation is resilient and all
documented recoveries are accepted, not that undecodable bytes are silently
declared conformant.

## Corrupted-corpus matrix

The strict expectation is an error for every documented malformation. The
tolerant column is the intended severity/result after the necessary field is
public; `blocked:model` identifies an oracle that cannot yet be implemented
without the model/native ownership stream.

| Fixture | Parser outcome | Strict named finding | Tolerant expectation | Availability |
| --- | --- | --- | --- | --- |
| `2014-12-02-215338.emf` | Format rejection | `emf.parse.unparseable` — oversized/truncated HEADER | `valid: false` (owner decision 2026-10-21) | Format exception can be wrapped now. |
| `2014-12-02-215339.emf` | Parsed | `emf.restore_dc.saved_dc` — sign/range | warning; valid | Public fixed field. |
| `2014-12-02-215358.emf` | Recovered | `emf.ext_text_out.string_bounds` and the matching `emf.record.*` recovery id | warnings; valid | Text bytes/Dx semantics blocked:model; ParseError available. |
| `2014-12-02-215400.emf` | Parsed | `emf.header.description_offset` | warning; valid | blocked:model for description buffer. |
| `2014-12-02-215425.emf` | Recovered | `emf.polyline16.point_count` and the matching `emf.record.*` recovery id | warnings; valid | Public count/array and ParseError. |
| `2014-12-02-215428.emf` | Format rejection | `emf.parse.unparseable` — unrecognised signature | `valid: false` (owner decision 2026-10-21) | Format exception can be wrapped now. |
| `2014-12-07-140817.emf` | Parsed | `emf.select_object.handle` | warning; valid | Public handle and stream object state. |
| `2014-12-07-160856.emf` | Parsed | `emf.path.begin_state` | warning; valid | Public record order. |
| `2014-12-07-163010.emf` | Parsed | `emf_plus.object.payload_size` | warning; valid | Public EMF+ payload; detailed object semantics may be blocked:model. |
| `2014-12-07-235709.emf` | Recovered | `emf.ext_text_out.dx_bounds` and the matching `emf.record.*` recovery id | warnings; valid | Text bytes/Dx blocked:model; ParseError available. |
| `2014-12-09-002112.emf` | Recovered | `emf.ext_text_out.string_bounds` and the matching `emf.record.*` recovery id | warnings; valid | Same model gap; keep this 1.5 MiB case bounded. |
| `2014-12-13-105759.emf` | Recovered | `emf.header.buffer_bounds` and the matching `emf.record.*` recovery id | warnings; valid | Header buffer detail partly blocked:model. |
| `2014-12-13-132605.emf` | Recovered | `emf.header.handle_count` and the matching `emf.record.*` recovery id | warnings; valid | Public header plus ParseError. |
| `2014-12-13-133727.emf` | Parsed | `emf.create_pen.object_index` | warning; valid | Public index and object state. |
| `2014-12-14-080539.emf` | Parsed | `emf.header.description_count` | warning; valid | blocked:model for description buffer. |
| `2016-02-02-210039.emf` | Parsed | `emf.ext_text_out.string_bounds` | warning; valid | Text bytes blocked:model. |
| `2016-02-02-220639.emf` | Recovered | `emf.bitmap.object_bounds` and the matching `emf.record.*` recovery id | warnings; valid | Outer offsets/counts and recovery public; payload semantics B. |
| `2016-02-02-225639.emf` | Recovered | `emf.bitmap.stride_bounds` and the matching `emf.record.*` recovery id | warnings; valid | Outer values and recovery public; rel4 semantics B. |
| `2017-02-11-230400.emf` | Recovered | `emf_plus.header.frame_size` and the matching `emf.record.*` recovery id | warnings; valid | Public EMF+ frame and recovery. |
| `2017-02-12-010400.emf` | Parsed | `emf_plus.record.data_size` | warning; valid | Public EMF+ frame. |
| `2017-05-12-074000.emf` | Recovered | `emf.font.name_bounds` and the matching `emf.record.*` recovery id | warnings; valid | Index/recovery public; name bytes may be blocked:model. |

The corpus README is the malformation oracle; the current parser result is not.
Each spec must assert the expected diagnostic identity, not merely `valid` or a
nonempty issue list.

## Other fixture roles

- `spec/fixtures/emf/`, `emf-ea/`, and `simple/` supply clean positive cases and
  diverse record coverage.
- `record_variants*.rb` supplies round-trip and forced-backend parity inputs,
  including intentionally nonconformant variants; it is not a validity oracle.
- WMF fuzz seeds supply bounded resilience cases. Rejection reason fixtures
  remain parser-contract inputs until rejected-input evidence is public.
- Native mutation specs identify sizes/counts/offsets worth covering, but new
  conformance specs must assert MS-* requirement IDs and citations independently.

## Forced-backend parity

Parity proves that each backend parses the same bytes into the public model and
that the one Ruby lens emits the same report:

1. force the Ruby backend, parse the bytes, and call `check(metafile, profile:)`;
2. force the native backend, parse the same bytes, and call the same method;
3. normalize only an injected/shared timestamp and source filename; and
4. compare the entire `Report#to_h`, including ordered issues and context.

No backend name belongs in a diagnostic. Parser-originated errors may differ
internally, but their public `ParseError` translation and final lens issue must be
identical. The parity suite covers clean, recovered, EMF+, Raw-record, and WMF
models; hard rejection parity is added once the neutral parse-result dependency
lands.

The dedicated spec is owned by the separate backend-parity work stream and must
be named `spec/emf/conformance/backend_parity_spec.rb` (or match
`backend_parity*_spec.rb`). Rust CI must run it explicitly with
`EMF_TEST_NATIVE_LIBRARY` set. A local run without that variable may skip native
examples; the Rust job must fail if the library variable is missing or the parity
file is not selected.
