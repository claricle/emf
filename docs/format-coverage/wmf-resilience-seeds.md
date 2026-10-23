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
unchanged; `recovered` inputs (`file-size`, `max-record`) must parse, record the
header drift in `Metafile#errors` and serialize to a header-corrected file whose
reparse has no errors; `rejected` inputs must raise a format or parse error. Native checks
cover exact round trips of all valid inputs and checksum rejection. Rust can
report diagnostics and recover other malformed inputs, so the Ruby outcome is
not a universal native rejection oracle. Bitmap mutations exercise record framing;
they do not establish nested DIB validation.

All 16 inputs are committed under `emf-rs/fuzz/seeds/wmf-resilience/` and
registered in `emf-rs/fuzz/seeds.json`, alongside the unchanged original corpus.
Each entry records its actual SHA-256, size, synthetic provenance and generation
recipe, `wmf` kind, and all three targets (`parse`, `serialize`, `ffi`). The script
spec verifies that the committed bytes and registrations match fresh generation.
The generated `seeds-manifest.json` remains a separate recipe inventory; it is
not copied into the harness corpus.

Validate and materialize all 253 seeds for each target without a Rust build:

```sh
python3 emf-rs/fuzz/seeds.py --corpus /tmp/emf-fuzz-corpus
```

End-to-end fuzz validation remains a separate step. This inventory supplies
reproducible test inputs, without claiming a fuzz run or completion of the
[resilience plan](../../TODO.plan/06-resilience.md).
