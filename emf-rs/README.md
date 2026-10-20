# Rust EMF core

`emf-core` is a standalone, dependency-free EMF header and record parsing crate.
It detects EMF, Aldus placeable WMF and standard WMF signatures; parsing WMF
returns `UnsupportedFormat`.

```sh
cargo test --manifest-path emf-rs/Cargo.toml -p emf-core
cargo fmt --manifest-path emf-rs/Cargo.toml --all -- --check
cargo clippy --manifest-path emf-rs/Cargo.toml --workspace --all-targets -- -D warnings
```

`parse` owns a copy of the input. Records expose raw spans; `serialize` preserves
all original bytes, including unknown payloads, reserved fields, padding and bytes
after the first EOF. Invalid record extents stop framing with a diagnostic and
retain the unframed tail. Missing EOF alone is accepted. Header damage and exceeded
budgets are fatal. Header counts and lengths are decoded without reconciliation.

`ParseLimits` bounds input bytes (default 200 MiB), individual records (128 MiB),
record count including the header (4,194,304), cumulative requested buffer bytes
(640 MiB), and work units (67,108,864). Buffer accounting charges the source copy
and each full vector capacity request before fallible reservation, including
record and diagnostic vectors. Allocator metadata and stack storage are outside
this accounting. Work charges one unit per framed record, one per 16 record bytes
rounded up, and one per 16 source-copy bytes rounded up. Source-copy work includes
trailing and malformed bytes. Limits apply separately to each parse.

Typed decoding and checked edits cover the header, EOF, SETMAPMODE, POLYLINE and
COMMENT records. Comment payloads expose EMF+ identification and bytes; inner
EMF+ records remain opaque. Edits refresh header byte and record counts, rebuild
comment alignment and retain unknown records and opaque suffixes. Invalid edit
layouts fail without mutating the document. Unchanged malformed payloads retain
their original bytes.

The remaining record families, structured EMF+, Ruby binding and full fixture
parity remain open in `TODO.plan/03-rust-core.md`. An initial owned C ABI is
provided by `emf-ffi`; see its README and public header for the raw-framing scope
and pointer contracts. One existing fixture and synthetic typed cases are
exercised here; the complete valid corpus is not an acceptance claim.
