# 04 — C ABI and ownership

Status: **Implemented; local C ownership acceptance measured**. The standalone
client passes on aarch64 macOS against the existing clean-a release library
(2026-10-20). This is host-specific evidence; the remaining delivery, sanitizer,
and resource gates below still apply. Depends on [baseline parity](02-baseline-and-parity.md)
and [the core](03-rust-core.md); see [Ruby binding](05-ruby-binding.md),
[resilience](06-resilience.md), [delivery](08-platform-delivery.md), and
[progress](10-progress.md) for their separate acceptance gates.

## Implemented interface

`emf-rs/crates/emf-ffi` contains the `cdylib`, its public
[`include/emf.h`](../emf-rs/crates/emf-ffi/include/emf.h), and the Ruby-free
[`tests/abi.c`](../emf-rs/crates/emf-ffi/tests/abi.c) client. The header is the
authority for declarations, field offsets, constants and caller obligations;
Rust layouts, enums, strings and references do not cross the boundary.

ABI version **1** is returned by `emf_abi_version`. Versioned structs require the
exact supported `struct_size` and version. Lengths and indices are `uint64_t`,
checked for host addressability before conversion. Incompatible signatures or
layouts require a new ABI version and loader support. Snapshot schema versions
are independent of the ABI version.

| Operations | Implemented contract |
| --- | --- |
| `emf_detect` | Detect EMF, standard WMF or placeable WMF without constructing a document |
| `emf_parse`, `emf_wmf_parse` | Own input bytes and return the corresponding opaque document |
| `emf_document_info`, `emf_wmf_document_info` | Header size, format, EOF, record/diagnostic counts and tail sizes |
| `emf_record_batch`, `emf_wmf_record_batch` | Caller-owned descriptor array, with original index, offset, byte length, type and family |
| `emf_document_snapshot` | Owned outer snapshot using [snapshot v2](../emf-rs/crates/emf-ffi/snapshot-v2.md) |
| `emf_wmf_document_snapshot` | Owned [WMFS v1](../emf-rs/crates/emf-ffi/wmf-snapshot-v1.md) snapshot |
| `emf_document_emf_plus_snapshot_v1` | Owned [EPSN v1](../emf-rs/crates/emf-ffi/emf-plus-snapshot-v1.md) nested-frame snapshot; required independent options struct, optional limits |
| `emf_record_bytes`, `emf_wmf_record_bytes` | Owned copy of exact original record bytes |
| `emf_serialize`, `emf_wmf_serialize` | Owned serialized output |
| `emf_wmf_replace_record` | Replace a WMF function/payload; rejected edits preserve the document |
| `emf_buffer_view`, `emf_error_view` | Borrow bytes/message from the corresponding owned handle |
| `emf_document_free`, `emf_wmf_document_free`, `emf_buffer_free`, `emf_error_free` | Release the matching handle; NULL is a no-op |

On the measured 64-bit host, the C client asserts `emf_limits` size 48,
`emf_info` 64, `emf_record_descriptor` 40 and `emf_error_info` 48, with their
field offsets. `emf_plus_snapshot_options` is 16 bytes. These are measured target
layouts, not proof of 32-bit or Windows compatibility. The header's `sizeof` and
`offsetof` requirements govern target-specific pointer/alignment differences.

## Status and ownership contract

Return statuses are `0 OK`, `1 INVALID_ARGUMENT`, `2 FORMAT_ERROR`,
`3 LIMIT_EXCEEDED`, `4 SERIALIZE_ERROR`, `5 INTERNAL_ERROR`, and
`6 ALLOCATION_FAILED`. Recoverable record errors are document diagnostics on a
successful parse. The Ruby mapping is tracked in [05](05-ruby-binding.md).

Required output pointers must be supplied; `out_error` is optional. Handle and
count outputs are cleared on entry, including failure. Callers retain separately
owned handles when reusing an output slot: overwriting a slot does not free its
previous value. A successful call clears its error slot. Error objects have
independent lifetimes; there is no shared last-error message. Messages and binary
data use pointer/length pairs, not NUL termination.

NULL input is accepted only with zero length (which can still produce a format
error). Non-null pointers must designate valid, aligned memory for the declared
range. Arbitrary pointers, wrong-kind handles, dangling pointers and double-free
are outside the contract and must not be used as negative tests.

Input storage need survive only the call. Each returned buffer owns its bytes
independently of the input, document, other buffers and errors. Buffer views remain
valid until that buffer is freed; error message views remain valid until that
error is freed. The Ruby adapter must copy borrowed bytes before freeing their
owner.

EMF documents are immutable. WMF replacement is supported, with original source
spans retained for descriptors and record-byte access. Independent handles may be
used on independent threads; callers serialize operations on the same handle and
never free it concurrently with a call using it. No Ruby callbacks or VM objects
enter this C interface.

## Measured local acceptance

The C client checks layouts, ABI version, exact parsing/serialization, descriptor
boundaries, typed snapshot decoding, diagnostics, input ownership, and NULL frees.
The lifecycle extension additionally measures:

- NULL input with positive and unaddressable lengths is rejected for detect,
  EMF parse and WMF parse without returning handles.
- Rejected record access clears an output slot while its saved buffer remains
  usable; failed batch access clears the count.
- Rejected metadata and record operations leave the same live document usable.
- A successful snapshot clears a saved error slot without consuming that error.
- Two independently allocated errors coexist; one error remains readable after
  its peer, the document and all output buffers have been freed.
- Serialized and record-byte buffers remain exact after document release;
  freeing one buffer leaves another usable. A rejected view leaves its buffer
  usable on the next call.
- Rejected WMF payload, index, function and NULL/length edits preserve exact
  serialization, followed by a successful edit on that same document.
- An unsupported EMF+ options version is rejected on a live document, followed
  by successful snapshot generation and buffer access after document release.

Reproduce from the repository root with an existing matching library (set
`EMF_ABI_LIBRARY_DIR` to its directory):

```sh
cc -std=c11 -Wall -Wextra -Werror -I emf-rs/crates/emf-ffi/include \
  emf-rs/crates/emf-ffi/tests/abi.c -L "$EMF_ABI_LIBRARY_DIR" -lemf_ffi \
  -Wl,-rpath,"$EMF_ABI_LIBRARY_DIR" -o /tmp/emf-abi-smoke
/tmp/emf-abi-smoke
```

Measured library directory:
`/private/tmp/emf-execution/apple-repro/clean-a/aarch64-apple-darwin/release`.
Compilation passed with warnings treated as errors; execution returned
`C ABI smoke: ok` and exit 0. No Cargo build or full suite was needed for this
acceptance extension.

## Remaining acceptance gates

This local run does not establish Linux, Windows, x86_64 or 32-bit ABI support;
run the client with each packaged target's library and loader under
[08](08-platform-delivery.md). Sanitizer/leak checks, externally supervised
malformed-input testing, representative descriptor/snapshot batch-cost
measurements, and Fiddle fixed-width/layout checks retain their separate gates.

Fallible exports use `catch_unwind`; no Rust unwind may cross a C frame. This
client does not inject panics or allocation failures and does not prove panic
containment or guaranteed OOM recovery. Aborting panics, allocator aborts,
invalid pointers and process termination cannot be caught this way. Continue
checking length/work/allocation ceilings and fallible reservations under
[06](06-resilience.md); retain its resource and process-supervision evidence.
