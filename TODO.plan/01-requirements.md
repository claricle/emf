# Requirements and compatibility contract

Status: baseline documented; implementation not started.
Depends on: [overview](00-overview.md). Execution starts with [02](02-baseline-and-parity.md).

## Source baseline and issue interpretation

At `a549346`, `lib/emf.rb` routes parsing and serialization to Ruby implementations.
EMF parsing uses BinData wire records wrapped in `Model::Emr::Records::WireAdapter`.
WMF detection exists, but its parser and serializer raise an unimplemented error.
EMF+ comments expose raw payloads; standalone typed parsing is unimplemented.

The issue's `from_file`, `from_bytes`, and `from_svg` examples do not name the
current public entry points. Preserve the implemented API below; adding those
aliases or SVG generation is not required by this migration. Likewise, the issue's
assumption that consumers never see BinData needs verification: records expose
`.wire`, visitors inspect its class and fields, and serialization uses its current
bytes. Compatibility includes these reachable behaviors until a downstream audit
demonstrates a narrower contract and a separate API change is specified.

The proposed `emf-rs/` subtree is a workspace within this repository. The issue's
schematic names are not evidence of an existing Rust implementation. The Ruby gem
does not need another nested `emf/` directory.

## Existing contract to preserve

| Surface | Current behavior / preservation check | Work package |
| --- | --- | --- |
| `Emf.parse(bytes)` | Format detection, EMF parsing, same model shape; invalid format/header raises `FormatError` | 02, 03, 05 |
| `Emf.parse_file(path)` | Binary file input, same result/error behavior as parsing its bytes; preserve filesystem errors | 02, 05 |
| `Emf.serialize(metafile)` | Format dispatch, current wire mutations respected, binary string returned; unsupported format/model errors preserved | 02, 03, 05 |
| `Emf.serialize_file(metafile, path)` | Binary write and existing return/error semantics | 02, 05 |
| `Emf.detect_format(bytes)` | Preserve detection boundaries and symbols: EMF+ input is detected as `:emf`, while a parsed metafile can be `:emf_plus` | 02, 03, 05 |
| `Model::Metafile` | `format`, `header`, `records`, `errors`, `emf_plus`, `trailing`, enumeration, `ok?`, `errors?` | 02, 05 |
| Header | Existing semantic fields, wire conversion, retained bytes and original optional header layout | 02, 03, 05 |
| Records | Order, type IDs, offsets, concrete wire class behavior and fields, equality/hash, visitors, dump and writable wire data | 02, 03, 05 |
| Errors | `Emf::Error`, `FormatError`, `ParseError` with offset/record code, `SerializeError`; raised versus recovered outcome | 02, 04, 05, 06 |
| Unknown/recovered records | Raw bytes retained where recovery currently permits; original offsets and diagnostic association | 02, 03, 06 |
| Binary fidelity | Unknown fields, padding, string encodings, float bit patterns, EOF and trailing data survive unchanged round trips | 02, 03, 05 |
| Native availability | Automatic native selection when compatible artifact is available; pure Ruby remains usable without it | 05, 08 |

Parity means field values and observable behavior **and** binary fidelity. Comparing
only the input to serialized output can miss an incorrectly decoded model.
Comparing only a JSON dump can lose binary strings, signedness, float payloads,
or wire mutations. The canonical oracle in 02 must cover both.

Malformed files do not all have a successful byte-preserving round trip today.
Classify each as a raised format error, a recoverable model with diagnostics, or
another observed outcome before defining its expected native result. Do not copy
unsafe Ruby allocations to obtain negative parity. Any deliberate tighter native
rejection needs a documented input condition, stable error mapping and regression
test; unexplained differences remain failures.

## Current fixtures and implementation boundaries

| Directory / source | Baseline | Required treatment |
| --- | --- | --- |
| `spec/fixtures/emf/` | 186 EMF files | Model, bytes and downstream comparison |
| `spec/fixtures/emf-ea/` | 21 EMF files | Same; retain existing downstream-specific behavior |
| `spec/fixtures/simple/` | 1 EMF file | First integration controls and full parity |
| `spec/fixtures/emf-corrupted/` | 21 `.emf` files; README is not a fixture | Bounded execution, explicit outcome manifest |
| WMF fixtures | None in current corpus | Add licensed or synthetic standard/placeable examples in 09 |
| `lib/emf/emr/binary/records.rb` | Wire-class dispatch registry and Raw fallback | Complete item inventory in [11](11-record-coverage.md) |
| `lib/emf/emf_plus/` | Stub typed implementation; raw extraction occurs in EMR parser | Preserve extraction; add typed coverage in 09 |

The existing round-trip spec covers 208 valid files. These counts are a baseline,
not a permanent hardcoded test expectation. A shared manifest must detect missing
or newly added files and include source identity/hash so both implementations test
the same bytes. Current fixtures cannot prove every record variant is correct;
the registry inventory needs synthetic field-level tests for absent variants.

## Issue acceptance and delivery map

| Requirement | Observable completion evidence | Package |
| --- | --- | --- |
| Typed Rust EMF/EMF+/WMF parser and reusable model | Each supported record/variant has decoding assertions, serialization checks and declared opaque boundaries | 03, 09, 11 |
| Same Ruby API and record model | Forced Ruby/native comparison across manifest, mutation and visitor/dump checks; existing specs green | 02, 05 |
| Record/model and byte parity over valid fixtures | All 208 baseline files plus later additions compared; no unexplained divergence | 02, 03, 05 |
| `emfsvg` golden/round-trip suites | Pinned consumer revision runs against both backends of this checkout with unchanged golden expectations | 02, 05, 07 |
| Corrupt corpus safely inside 60-second guard | Every seed terminates in a subprocess within agreed tighter wall-time and memory budgets; no crash or hang, named slow seed included | 06 |
| Round-trip suite stays green | Valid fixture bytes identical, edits serialize correctly, unknown/trailing bytes retained | 02, 03, 05 |
| Reported approximately 12-second fixture becomes sub-second | Identify input/hardware/operation first; comparable Ruby end-to-end measurements demonstrate target or document unresolved shortfall | 02, 07 |
| Ruby fallback remains | Explicit fallback checks with no native artifact, forced Ruby and library-load/ABI failure cases | 05, 08 |
| Precompiled platform gems, no compiler at install | Every requested architecture/OS/libc combination has built artifact and clean install/parse/serialize evidence | 08 |

## Scope boundaries and open gates

The work does not include a new rendering engine, SVG generation, unrelated
downstream coordinate fixes, removing BinData, a repository move, or a gem release
from the planning PR. Dependency/version changes must be justified by the eventual
binding and package implementation rather than copied from an example project.

Before scaling implementation, resolve these gates and record evidence in 10:

1. Identify the slow fixture, benchmark machine and measured operation boundaries;
   establish the `emfsvg` revision and its existing runnable suites.
2. Audit downstream `.wire` access and validate lazy compatibility hydration with
   reads, mutations, lifetime checks and complete consumer timing.
3. Validate the proposed Fiddle loader on the existing Ruby support range and all
   target platforms, including environments where Fiddle is unavailable. Automatic
   fallback must remain installable without building a dependency.
4. Prove each native target can be built and tested, especially Windows ARM64;
   define platform names, minimum OS/libc and toolchain requirements from those probes.
5. Complete the new-format record/variant and fixture inventory. Until then,
   WMF/structured EMF+ estimates and full-format completion remain provisional.
