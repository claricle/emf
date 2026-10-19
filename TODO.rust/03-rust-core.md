# 03 — Ruby-independent Rust core

Status: **Not started**. Estimate: **6–8 engineering days** for current EMF
compatibility after [baseline gates](02-baseline-and-parity.md). Re-estimate if
the record inventory or wire-heavy vertical slice reveals missing work. Full
WMF and structured EMF+ implementation belongs to [format extension](09-format-extension.md)
and is not included in this estimate.

Depends on [requirements](01-requirements.md) and baseline observations. Delivers
input to [the C ABI](04-c-abi.md) and [Ruby binding](05-ruby-binding.md), with
cross-cutting [resilience](06-resilience.md), [performance](07-performance.md),
and [record coverage](11-record-coverage.md) gates. See [progress](10-progress.md).

## Planned workspace and contracts

| Path | Planned responsibility |
| --- | --- |
| `emf-rs/Cargo.toml` | Workspace containing `crates/emf-core` and `crates/emf-ffi` |
| `emf-rs/Cargo.lock` | Locked build dependencies |
| `emf-rs/crates/emf-core/src/lib.rs` | Rust parse, detect and serialize entry points |
| `emf-rs/crates/emf-core/src/model.rs` | Owned document, header, typed record, raw record and diagnostic types |
| `emf-rs/crates/emf-core/src/limits.rs` | Input, allocation and work budgets shared by readers |
| `emf-rs/crates/emf-core/src/reader.rs` | Checked little-endian reads, slicing and budget accounting |
| `emf-rs/crates/emf-core/src/emf/` | EMF header, record-family parsers and serialization |
| `emf-rs/crates/emf-core/tests/fixture_parity.rs` | Shared manifest-driven integration tests |

`emf-core` must contain no Ruby, BinData, Fiddle or C ABI types and must build and
test without a Ruby runtime. `emf-ffi` depends on it; the reverse dependency is
forbidden. Proposed Rust entry points are `detect_format(&[u8])`,
`parse(&[u8], &ParseLimits) -> Result<Document, ParseFailure>`, and
`serialize(&Document) -> Result<Vec<u8>, SerializeFailure>`. Exact exported Rust
type names can settle with the first implementation; observable semantics are
fixed by parity fixtures. Owned documents must outlive the caller's input buffer;
borrowing input across the C boundary is not part of this design.

A document stores header data, ordered typed records, raw record spans, ordered
diagnostics, opaque extracted EMF+ bytes and bytes after EOF. Retain original
record bytes and padding even when decoded fields are available. Track unchanged
versus edited records explicitly: unedited serialization copies original bytes;
edited typed records rebuild checked fields while retaining unrelated opaque
bytes. Do not normalize NaNs, signed zero, reserved fields, unknown payloads or
header metadata during an unchanged round trip. This representation must support
standalone Rust use; Ruby's mutable BinData edits are reconciled at the binding
boundary described in [05](05-ruby-binding.md).

## Planned implementation sequence

1. **Reader and framing.** Add checked addition/multiplication, explicit endian
   reads, bounded ranges and a single record cursor. Detect the existing EMF/WMF
   signatures without prematurely claiming WMF parsing support. Decode the EMF
   header, enforce forward progress and record extents, stop at EOF and retain
   trailing bytes. Return a structured failure for unrecoverable header damage.
2. **Measured vertical slice.** Implement header, EOF, one common fixed record,
   one variable-array record, comment extraction and unknown/raw records, together
   with byte serialization. Connect this slice through the ABI and binding before
   expanding record coverage. Use a synthetic fixture containing only supported
   families; a production fixture with missing families is not a passing slice.
3. **Record families.** Port the existing lookup inventory family by family:
   state/transforms, object creation and selection, geometry and paths, text and
   fonts, regions/clipping, raster/bitmap data, comments and remaining records.
   Each family needs field decoding, bounds checks, byte preservation, diagnostics
   and fixtures before its coverage row is complete. Supported Ruby record types
   must remain typed on the native path; treating all records as raw does not
   satisfy model or wire parity.
4. **Serialization and corpus completion.** Exercise untouched documents, edited
   typed records and raw records. Match current stop/recovery boundaries where
   safe, then run all valid fixtures and classified malformed cases. Keep EMF+
   comment extraction compatible while structured EMF+ parsing remains a separate
   tracked deliverable.

The vertical slice must include real `emfsvg` conversion, dump and repeated
`.wire` traversal. If compatibility hydration consumes the performance budget,
measure batched model extraction or revise the adapter before scaling the port.
Reparsing the entire input through `Emr::Parser` after a Rust validation pass is
not a native parser implementation.

## Planned safety and parity rules

Validate declared lengths/counts against available record bytes before allocating
or iterating. A malformed record must consume bytes, return a bounded raw recovery,
or stop; no branch may retry the same offset indefinitely. Preserve the current
variable-array recovery behavior and distinguish a recoverable record diagnostic
from a fatal header error. Establish explicit input, record, array, recursion (if
introduced), total allocation and work limits under [06](06-resilience.md).

The Ruby parser currently has a 200 MiB input cap and a 1,000,000-entry sanity
limit for selected arrays. These are compatibility evidence, not proof that all
other allocations are safe. Native limits must be documented and regression
covered, including the reported corrupt fixture. Use fallible reservations for
large buffers after validating sizes. Memory limits reduce risk; they do not
make allocator aborts or process-wide exhaustion catchable.

## Planned checks and exit gate

```sh
cargo fmt --manifest-path emf-rs/Cargo.toml --all -- --check
cargo clippy --manifest-path emf-rs/Cargo.toml --workspace --all-targets -- -D warnings
cargo test --manifest-path emf-rs/Cargo.toml -p emf-core
cargo test --manifest-path emf-rs/Cargo.toml -p emf-core --test fixture_parity
```

These commands are planned and require the workspace and tests to be created.
Acceptance requires all 208 valid fixtures to retain exact bytes, complete typed
coverage against the inventory, reviewed malformed-input differences, passing
standalone core tests, and a measured vertical slice that includes compatibility
costs. A fast raw scanner alone cannot close this phase. Release/platform checks
are defined in [delivery](08-platform-delivery.md).
