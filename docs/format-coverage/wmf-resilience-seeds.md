# Synthetic WMF resilience seeds

Generate a deterministic inventory in a temporary directory:

```sh
bundle exec ruby script/wmf_resilience_seeds --output-dir /tmp/emf-wmf-resilience-seeds
```

The command prints the absolute path to `seeds-manifest.json`. It writes eight
valid inputs and eight malformed controls. Valid inputs cover geometry, text,
bitmap and unknown records in standard and Aldus placeable containers, using one
repetition of the [WMF workloads](../../bench/wmf-workloads.md).

| Malformed seed | Mutation |
| --- | --- |
| `header-size` | Standard HeaderSize is eight words instead of nine |
| `file-size` | Declared file size is below the nine-word header minimum |
| `max-record` | Declared maximum record size is zero |
| `zero-record` | First record declares zero words |
| `missing-eof` | EOF is removed and the declared file size is repaired |
| `negative-text-count` | TextOut character count is negative |
| `placeable-checksum` | One checksum bit is inverted |
| `bitmap-short-record` | Bitmap record declares only its three-word header |

The manifest has `schema_version: 1` and a `seeds` array. Each entry includes its
name, relative path, family, placeable flag, recipe, expected outcome, SHA-256,
byte size and `synthetic` provenance. Resolve paths relative to the manifest.
Repeated generation produces identical bytes and manifest content. Keep generated
output outside the checked-in fixture inventory.

`expected_outcome` describes the Ruby parser: `parsed` inputs must serialize
unchanged; `rejected` inputs must raise a format or parse error. Native checks
cover exact round trips of all valid inputs and checksum rejection. Rust can
report diagnostics and recover other malformed inputs, so the Ruby outcome is
not a universal native rejection oracle. Bitmap mutations exercise record framing;
they do not establish nested DIB validation.

This generated manifest is separate from `emf-rs/fuzz/seeds.json`. It does not
register inputs with the fuzz harness. Integration requires the harness owner to
retain chosen files at repository-relative paths and add their actual hashes,
sizes, synthetic provenance, `wmf` kind and `parse`, `serialize`, `ffi` targets to
that existing manifest. Its lightweight validator is
`python3 emf-rs/fuzz/seeds.py`; end-to-end fuzz validation remains a separate step.
This inventory supplies reproducible test inputs, without claiming a fuzz run or
completion of the [resilience plan](../../TODO.plan/06-resilience.md).
