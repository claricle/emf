# WMFR version 1: first rejection under the Ruby WMF contract

`emf_wmf_rejection(data, length, max_input_bytes, max_records, out_buffer, out_error)` answers which phase of the
Ruby WMF contract rejects an input first, as data. It is additive:
`EMF_ABI_VERSION` and WMFS (version 1) are unchanged, and hydrating an accepted
document does not need it. It takes raw bytes, not a document handle, so it also
answers when `emf_wmf_parse` itself failed. It allocates only the 48-byte answer
plus an object table of at most 65,535 slots, and reads each byte a bounded number
of times. Free the buffer with `emf_buffer_free`.

Why a separate walk: `emf_wmf_parse` recovers past malformed records and keeps
going, so its diagnostics cannot say what Ruby would have raised first. The walk
in `emf_core::wmf::contract` follows Ruby's order: placeable, standard header,
records in stream order (framing, then that record's payload), the object table,
then the largest-record check. It reports the failure; it carries no wording.

The two limits are the contract's own ceilings (Ruby: 200 MiB and 1,000,000 records,
read from `Wmf::Binary` on each call), passed in so the answer never drifts from the
caller's contract.

## Layout

`WMFR`, then little-endian u32 version (1), present, codec, reason, has-offset,
has-function, function, then u64 offset and detail. 48 bytes.

- present 0: the contract accepts the input; every other field is zero.
- offset / function: what the contract reports; each is zero unless its has-flag
  is 1. Header and whole-input reasons carry neither.
- detail: the declared length in words for 403, the referenced index for 1702-1707,
  otherwise zero.

## Reasons

A reason is `codec * 100 + n`. Codes are append-only. Codecs: 1 input, 2 placeable,
3 standard header, 4 record framing, 5 fixed record, 6 state, 7 font, 8 object
record, 9 point array, 10 text, 11 palette, 12 region, 13 brush, 14 bitmap,
15 geometry, 16 DC/escape, 17 object table, 18 largest record.

Whole-input reasons (a Ruby `FormatError`, no offset): 101, 201-203, 301-306, 1801.
Every other reason is a record failure (a Ruby `ParseError` with offset and record
code). `lib/emf/native/wmf_rejection.rb` owns the wording; the exact set is the
`Reason` enum in `emf-core/src/wmf/contract.rs`.
