# Initial C ABI

Build `emf-ffi` as a shared library with `cargo build -p emf-ffi` from `emf-rs`.
The public contract is [include/emf.h](include/emf.h). Run the Rust boundary
tests with `cargo test -p emf-ffi` and the independent C client with
`sh crates/emf-ffi/tests/run-c-smoke.sh`.

ABI version 1 provides format detection, immutable parsed EMF documents, document
counts, record descriptor batches, owned raw record buffers, byte-preserving
serialization, and owned errors. Detection recognizes WMF signatures; parsing
supports EMF only. [Snapshot v2](snapshot-v2.md) exposes decoded headers, EOF,
SETMAPMODE, POLYLINE, COMMENT, SETBKMODE, SETPOLYFILLMODE, SETROP2,
SETSTRETCHBLTMODE, diagnostics and preserved header/tail bytes in one
owned buffer. Snapshot schema 2 is independent of C ABI version 1. Other records
remain raw. Edits, Ruby hydration, and a complete
package 04 milestone are not provided by this subset.

Input bytes may be released after parsing returns. Each returned buffer owns its
bytes and survives freeing the document. A buffer view borrows from its buffer;
an error view borrows from its error. Free each handle once using its matching
free function. Independent handles may be used concurrently; serialize access to
the same handle and never free it during a call. Passing NULL to free is safe.

Initialize structure sizes and versions as directed in the header. NULL parse
limits select core defaults; explicit zero limits mean zero. Byte/count limit
ceilings must fit the platform's `usize`; work units use `u64`. Record counts and
indices exclude the header and include EOF. Batches expose source offsets and
full record sizes, including record headers. Parsing preserves malformed tails
as diagnostics when the core can recover, and serialization retains their bytes.

Fallible exports contain Rust unwinding panics and return `EMF_INTERNAL_ERROR`.
Valid aligned caller memory and live handles remain caller responsibilities;
invalid pointers, double frees, allocator aborts, and builds using `panic=abort`
cannot be recovered. Error messages are UTF-8, capped at 512 bytes, and need not
have a terminating NUL. Error handles are optional; a failed message allocation
can leave an error with an empty message. Large byte buffers use fallible
reservations; allocating the small owning handles can still abort on exhaustion.
