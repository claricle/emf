The `fixture_parity` target runs with Rust alone and no Cargo dependencies:

```sh
cargo test --manifest-path emf-rs/Cargo.toml --locked --offline -p emf-core --test fixture_parity
```

It checks the manifest fingerprint, duplicate paths, fixed cohort counts, complete
on-disk EMF/WMF inventory, byte counts and SHA-256 for all 231 fixtures. It also
parses and serializes the 208 valid EMF fixtures (`emf`, `emf-ea`, `simple`) using
default core limits and requires exact unchanged bytes. The 21 `emf-corrupted`
fixtures and two WMF fixtures receive integrity checks only. A saved Ruby `parsed`
observation does not promote a corrupted fixture into the valid cohort.

This target proves unchanged-byte preservation. Dedicated record-family tests,
the typed coverage inventory and malformed-input tests remain necessary to prove
typed decoding/edit parity and recovery behavior. It does not refresh or verify
the Ruby parser-source fingerprint or reproduce Ruby observations.

The committed TSV is derived from `spec/fixtures/manifest.json`. Its exact SHA-256
fingerprint binds the index to that JSON, so a manifest change fails the Rust test
until the index is regenerated. The Rust tests also detect unlisted, removed,
duplicated or changed fixture files. SHA-256 is test-only and has NIST vectors for
empty, short, padding-boundary and multiblock inputs.

After an intentional manifest update, regenerate and verify with Python's standard
library (Python is needed only for maintenance, never by the Rust test):

```sh
python3 emf-rs/crates/emf-core/tests/support/generate_fixture_index.py
python3 emf-rs/crates/emf-core/tests/support/generate_fixture_index.py --check
```

Regeneration only reads JSON metadata; it does not invoke Ruby or scan binary
fixtures. Review changes to the manifest and generated index together.
