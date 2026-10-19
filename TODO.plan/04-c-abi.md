# 04 — C ABI and ownership

Status: **Not started**. Estimate: **2–3 engineering days**, after the
[core vertical slice](03-rust-core.md). Complete the slice with
[the Ruby binding](05-ruby-binding.md) before extending all record families.
Depends on [baseline parity](02-baseline-and-parity.md). Safety gates are in
[resilience](06-resilience.md), packaging in [delivery](08-platform-delivery.md),
and completion in [progress](10-progress.md).

## Planned files and versioned surface

Create `emf-rs/crates/emf-ffi/Cargo.toml`, `src/lib.rs`,
`include/emf.h`, and `tests/abi.c`. Build a `cdylib`; expose only fixed C-compatible
types and opaque handles. The public header is the authority for both the Ruby
loader and a standalone C smoke client. Rust layouts, enum discriminants, `Vec`,
strings, references and Rust errors never cross this boundary.

The proposed ABI version is **1**. `uint32_t emf_abi_version(void)` returns `1`;
the loader checks it before calling any other function. Incompatible signatures
or layouts require a new version and loader support. Structs include `struct_size`
and a version field; reserved members are zero. Fixed-width integer fields and
explicit byte order apply to exported batch payloads. Use `uint64_t` lengths and
indices, checked against host `size_t`/Rust `usize` before conversion. Confirm
Fiddle's fixed-width mappings on each supported target before freezing the header.

Planned operations (freeze these declarations and the referenced struct layouts
in the header before binding implementation):

| Operation | Proposed contract |
| --- | --- |
| `emf_detect(data, len, out_format, out_error)` | Detect format without constructing a document |
| `emf_parse(data, len, limits, out_document, out_error)` | Copy/own required bytes, parse and return an opaque document |
| `emf_document_info(document, out_info)` | Format, header summary, record count and diagnostic count |
| `emf_record_batch(document, start, capacity, out_descriptors, out_count)` | Fill caller-owned descriptor array for many records in one call |
| `emf_document_snapshot(document, out_buffer, out_error)` | Versioned bulk header/typed-field/diagnostic payload for model construction |
| `emf_record_bytes(document, index, out_buffer, out_error)` | Copy exact record bytes for on-demand wire hydration |
| `emf_serialize(document, out_buffer, out_error)` | Serialize the core document to an owned output buffer |
| `emf_buffer_view(buffer, out_data, out_len)` | Read-only pointer and length valid until buffer free |
| `emf_error_view(error, out_info)` | Status, category, optional offset/code, and message pointer/length |
| `emf_document_free`, `emf_buffer_free`, `emf_error_free` | Release each owned handle exactly once |

The proposed declarations make handle and output ownership explicit:

```c
typedef struct emf_document emf_document;
typedef struct emf_buffer emf_buffer;
typedef struct emf_error emf_error;
uint32_t emf_abi_version(void);
int32_t emf_detect(const uint8_t *, uint64_t, uint32_t *, emf_error **);
int32_t emf_parse(const uint8_t *, uint64_t, const emf_limits *, emf_document **, emf_error **);
int32_t emf_document_info(const emf_document *, emf_info *);
int32_t emf_record_batch(const emf_document *, uint64_t, uint64_t, emf_record_descriptor *, uint64_t *);
int32_t emf_document_snapshot(const emf_document *, emf_buffer **, emf_error **);
int32_t emf_record_bytes(const emf_document *, uint64_t, emf_buffer **, emf_error **);
int32_t emf_serialize(const emf_document *, emf_buffer **, emf_error **);
int32_t emf_buffer_view(const emf_buffer *, const uint8_t **, uint64_t *);
int32_t emf_error_view(const emf_error *, emf_error_info *);
void emf_document_free(emf_document *);
void emf_buffer_free(emf_buffer *);
void emf_error_free(emf_error *);
```

`emf_limits`, `emf_info`, `emf_record_descriptor` and `emf_error_info` are
versioned fixed-layout structs, not opaque types. Before freezing v1, define their
field offsets and sizes in the header and assert them in Rust and C. The null
limits pointer selects documented defaults; non-null limits require a supported
version and size. This declaration block is a planned interface, not an existing
compilable header.

A batch descriptor contains record index, type ID, offset, original byte length
and typed-family tag, with checked fixed widths. The snapshot payload includes a
schema version, bounded counts and explicit lengths; document its exact encoding
in `include/emf.h` or an adjacent `snapshot-v1.md`, and validate it on both sides.
Avoid a separate FFI call per point, glyph or scalar field. Descriptor batches and
the bulk snapshot must be benchmarked against a representative large fixture.
Serialization of changed Ruby BinData objects is handled by the compatibility
adapter; this ABI does not require a call per Ruby field mutation.

## Planned status and lifetime rules

Functions return an `int32_t` status: `0 OK`, `1 INVALID_ARGUMENT`,
`2 FORMAT_ERROR`, `3 LIMIT_EXCEEDED`, `4 SERIALIZE_ERROR`, `5 INTERNAL_ERROR`,
`6 ALLOCATION_FAILED`. These numbers are proposed ABI constants, not Rust enum
casts. Recoverable record errors are document diagnostics on a successful parse,
not a failing function status. Map fatal statuses to existing public Ruby error
classes in [05](05-ruby-binding.md); do not add new top-level API aliases.

Initialize output handles to null and counts to zero on entry. On success the
caller owns returned handles; on failure no document/buffer escapes, and an
optional owned error provides detail. A nonzero status remains meaningful if
error allocation fails. Messages use UTF-8 pointer/length pairs and binary data
uses byte pointer/length pairs, never NUL-terminated strings. A null data pointer
is valid only for zero length. Invalid non-null pointers and use-after-free cannot
be made safe by a C API; the caller must supply valid memory for each declared
range and valid handles of the required kind.

Input bytes need remain valid only until the call returns. Output buffer views
remain valid until that buffer is freed, independent of the document lifetime.
Ruby copies bytes into its own String before freeing a buffer. No pointer into a
movable Ruby object is stored by Rust. Free functions accept null as a no-op;
double-free is invalid. No global last-error pointer or error-message lifetime
shared across calls is permitted. Tests must cover early failures, empty buffers,
repeated parse/free and each allocation ownership path.

## Planned panic, resource and thread policy

Wrap every fallible exported operation in `catch_unwind` with unwinding enabled
for the FFI build; translate a caught panic to `INTERNAL_ERROR` and release partial
results. No panic or Rust unwind may cross a C frame. This does not catch
allocator aborts, aborting panics, invalid pointers or process termination. Validate
lengths and budgets before allocation, apply `try_reserve` to large allocations,
and return `ALLOCATION_FAILED` when a fallible reservation fails. Bound aggregate
allocations and work under [06](06-resilience.md); never claim guaranteed OOM
recovery from `catch_unwind`.

ABI v1 documents are immutable for FFI access. Independent documents may be used
on independent threads. Callers serialize operations on the same document and
must never free a handle concurrently with a call using it. Output buffers and
errors have the same no-concurrent-free rule. No Ruby callbacks, Ruby VM access,
mutable process-wide parser state or cross-thread Ruby objects enter the core.
The Ruby adapter protects same-handle access and copies results before releasing
its lock. Measure Fiddle scheduling behavior rather than promising GVL release.

## Planned verification and exit gate

```sh
cargo test --manifest-path emf-rs/Cargo.toml -p emf-ffi
mkdir -p tmp
cargo build --manifest-path emf-rs/Cargo.toml -p emf-ffi --release
cc -std=c11 -Wall -Wextra -Werror -I emf-rs/crates/emf-ffi/include emf-rs/crates/emf-ffi/tests/abi.c -L emf-rs/target/release -lemf_ffi -o tmp/emf-abi-smoke
```

Run the compiled client against the same built library, from the repository
root (Linux and macOS respectively):

```sh
LD_LIBRARY_PATH="$PWD/emf-rs/target/release${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" ./tmp/emf-abi-smoke
DYLD_LIBRARY_PATH="$PWD/emf-rs/target/release${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}" ./tmp/emf-abi-smoke
```

The client must exercise its vertical-slice fixture and exit nonzero on assertion
failure; a successful compile alone is insufficient. These host commands assume
the workspace's default target directory. [08](08-platform-delivery.md) must adapt
the library path and executable invocation to each target's staging directory and
loader, including Windows, and run on that target. These commands are planned,
not run.
Tests must independently verify ABI version rejection, structure sizes, status
mapping, null/zero-length arguments, truncated input, batches, exact bytes,
diagnostic positions and all free paths. Use sanitizer/leak checks on supported
build targets and an externally supervised malformed-input subprocess. Acceptance
requires a Ruby-free C client to parse and serialize the vertical-slice fixture,
no unwind across the boundary, and measured batch costs. Passing Rust unit tests
alone does not establish ABI compatibility.
