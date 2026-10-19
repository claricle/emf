# 05 — Ruby binding and backend compatibility

Status: **Not started**. Estimate: **3–4 engineering days**, contingent on the
[baseline](../TODO.plan/02-baseline-and-parity.md) and the [core](../TODO.rust/03-rust-core.md)/
[ABI](../TODO.rust/04-c-abi.md) vertical slice. Resolve wire hydration cost before scaling the
port. See [performance](../TODO.delivery/07-performance.md), [platform delivery](../TODO.delivery/08-platform-delivery.md),
and [progress](../TODO.plan/10-progress.md) for the remaining gates.

See [Ruby execution sequence](00-execution.md) for the existing-file change map,
require-path checks, CLI verification and ordered integration steps.

## Planned files and dispatch

| Path | Planned responsibility |
| --- | --- |
| `lib/emf/backend.rb` | Internal backend selection and availability policy |
| `lib/emf/native.rb` | Lazy native entry point |
| `lib/emf/native/loader.rb` | Lazy Fiddle load, platform library lookup, ABI validation |
| `lib/emf/native/platforms.json` | Packaged platform/library map coordinated with gem builds |
| `lib/emf/native/backend.rb` | Buffer/handle calls, status mapping, cleanup and batching |
| `lib/emf/native/model.rb` | Existing Ruby model construction and lazy BinData hydration |
| `spec/emf/native/backend_spec.rb` | Loader, forced backend and cleanup regressions |
| `spec/emf/backend_parity_spec.rb` | Public behavioral and mutation parity |

Route the existing `Emf.parse`, `parse_file`, `serialize`, `serialize_file` and
`detect_format` entry points through the internal selection layer. Preserve
signatures, file modes, return values and existing public model classes. Keep
BinData available: it remains the Ruby backend and the native wire compatibility
representation. No `from_*` aliases, public backend-query method or separate
native public model are proposed. Tests can inspect the internal backend through
test support and process environment.

Propose **Fiddle**, loaded lazily only when native use is attempted. Do not add a
binding dependency that triggers compilation during installation. Check Fiddle
availability and type mapping on the existing Ruby 3.1–3.4 Linux/macOS matrix;
retain the gem's `>= 3.1.0` requirement. Research Fiddle distribution on later
Ruby releases before declaring support there. If it becomes an explicit dependency,
prove that installation and its transitive dependencies still need no compiler
on every advertised platform. Availability must not be inferred from a Ruby
version string alone.

## Planned selection policy

`EMF_BACKEND` is the sole proposed override, read consistently at backend setup:

| Value | Planned behavior |
| --- | --- |
| unset or `auto` | Prefer a usable packaged native library; use Ruby if Fiddle/library/compatible ABI is unavailable |
| `ruby` | Select the existing Ruby parser/serializer without loading Fiddle or a shared library |
| `native` | Require Fiddle and a compatible native library; fail clearly if unavailable |
| anything else | Raise a clear configuration error (`ArgumentError`) |

Resolve libraries only from the installed gem's declared platform-specific asset
location, proposed as `lib/emf/native/<platform>/libemf_ffi.so` on Linux or
`lib/emf/native/<platform>/libemf_ffi.dylib` on macOS, selected through
`lib/emf/native/platforms.json`. A later supported Windows build uses
`emf_ffi.dll` in that platform directory; packaging must use the same paths. A missing binary, load failure, unsupported platform or ABI
mismatch permits `auto` availability fallback before parsing. Forced native raises
an `Emf::Error` with the availability reason. Default fallback should not add noisy
per-file warnings; test reports explicitly record the selected backend and reason.

Once native work starts for an input, a format error, limit error, serialization
failure or internal native failure is returned as an error. Do not retry the
input in Ruby, hide a crash, or silently change the selected backend. Malformed
input and unsupported structured formats are not library availability failures.
EMF/WMF/EMF+ capabilities and their staged behavior must follow
[format extension](../TODO.formats/09-format-extension.md), with explicit errors for unimplemented
parsing rather than a successful empty model. Native becomes the default preferred
path only after the delivery acceptance gates pass.

Map ABI `FORMAT_ERROR` and `LIMIT_EXCEEDED` to `Emf::FormatError`, and
`SERIALIZE_ERROR` to `Emf::SerializeError`; map internal or allocation failures to
`Emf::Error` with bounded detail. Convert successful parse diagnostics into ordered
`Emf::ParseError` instances with offset and record code. Treat invalid arguments
from binding-owned calls as an adapter defect. Diagnostic compatibility and
reviewed safety changes follow [02](../TODO.plan/02-baseline-and-parity.md).

## Planned native model and mutable wire behavior

Build the existing `Emf::Model::Metafile` and `Emf::Model::Emr::Header` shapes from
batched native data. Retain record order, model classes, offsets, errors, opaque
EMF+ bytes, trailing bytes, enumeration and frozen-container behavior. Each native
record adapter must remain compatible with `WireAdapter` checks and visitor
registration. The current adapter uses `@wire` directly in `type_id`, `inspect`,
equality and hash; change these internal methods coherently so lazy records do
not read an uninitialized instance variable.

Propose lazy **actual BinData records**: retain bounded per-record bytes and the
existing lookup class, then call that class's `read` on first `.wire` access.
Cache and return the same object thereafter. Construct raw records for the same
recovery cases as the baseline. Materialization must preserve exact class names,
field access, nested arrays, visitor dispatch and dump text. Never run the entire
file through `Emr::Parser` merely to construct a native result.

Wire mutation has no reliable universal dirty callback. Once a wire is exposed,
serialization must use that cached object's `to_binary_s`, even if no explicit
setter was intercepted. Unexposed records can copy native-preserved bytes. This
hybrid must serialize manually built Ruby models, existing headers and mixed
native/Ruby adapters with the same supported-record behavior. Equality/hash and
inspect must observe current wire values as before; they may trigger hydration.
Document that mutation can change hashes exactly as it can today. Do not introduce
an immutable proxy to avoid this requirement.

Choose and test native lifetime ownership explicitly. A proposed owner object
keeps the native document alive for all lazy records, serializes same-handle calls,
and frees it exactly once after all references are unreachable. Every temporary
buffer/error handle uses `ensure` cleanup. Finalizers are a last-resort owner
cleanup, must not capture the object they finalize, and cannot be the only cleanup
for temporary allocations. Test retained records after their metafile is dropped,
GC stress, exceptions during model build and repeated parse/serialize loops.

## Planned verification and exit gate

```sh
EMF_BACKEND=ruby bundle exec rspec
EMF_BACKEND=native bundle exec rspec
EMF_BACKEND=auto bundle exec rspec spec/emf/native/backend_spec.rb spec/emf/backend_parity_spec.rb
bundle exec rubocop lib/emf/backend.rb lib/emf/native.rb lib/emf/native spec/emf/native spec/emf/backend_parity_spec.rb spec/support/backend_parity.rb
bundle exec ruby bench/parser.rb --manifest spec/fixtures/manifest.json --backend native --output tmp/bench/native.json
EMFSVG_PATH=/path/to/emfsvg bundle exec ruby bench/emfsvg.rb --backend native --output tmp/bench/emfsvg-native.json
```

All commands are planned for files not yet implemented. Run missing-Fiddle,
missing-library, bad-version, unsupported-platform and invalid-override cases in
fresh subprocesses; native suites must prove native was selected. Require exact
valid-fixture bytes, public API and mutation parity, downstream golden parity,
cleanup checks and wire-heavy timings on supported Ruby versions. `auto` tests
must also prove Ruby availability fallback. Parser-only speed does not establish
the downstream target, and a successful fallback run is not native test evidence.
