# Document snapshot v4 — the render contract

Schema 4 is the RENDER direction of the binding program: the EMF → VIM → SVG
conversion crosses the C ABI the same way the parse snapshots do — plain
`int32` statuses, caller-allocated output buffers, copy-then-free ownership —
so the parse lane (snapshot v1→v3) and the render lane are one binding style.

Where snapshot v1→v3 transport the EMF MODEL out of `emf-ffi`, schema 4
transports the TRANSFORMER OUTPUT in: EMF metafile bytes go in, the emfsvg
renderer's SVG bytes come out. The conversion itself lives in the
conversion-hub workspace (claricle/vectory, `vectory-rs/crates/eikogram-ffi`),
which composes the landed pipeline — `emf-core` (the EMF model) →
`emf-to-eikogram` (the VIM) → `eikogram-to-svg` (the SVG model through the
`EmfsvgSvgBuilder` serialize profile) → bytes. This crate adds no rendering
semantics; this document specifies the ABI surface it must keep.

The C ABI remains version 1. Status, output reset and lifetime rules are
those of `emf_document_snapshot`: the native side owns the output bytes until
the explicit free; the caller copies them out first and always frees.

## The ABI

```c
typedef struct EikogramBuf { uint8_t *ptr; size_t len; } EikogramBuf;

int32_t eikogram_v1_abi_version(void);
int32_t eikogram_v1_render_emf(const uint8_t *emf, size_t emf_len,
                               EikogramBuf *out);
void    eikogram_v1_free(EikogramBuf *out);
```

| Entry | Contract |
| --- | --- |
| `eikogram_v1_abi_version` | Returns 1. The loader verifies it before its first call and refuses the library on mismatch. |
| `eikogram_v1_render_emf` | Reads `emf_len` bytes at `emf` (binary — no encoding gate; a null pointer with a zero length reads as the empty input), runs the full pipeline, and records the result in `*out`. Returns a status below. |
| `eikogram_v1_free` | Releases the buffer recorded in `out` and resets it to the zeroed state. Safe on the zeroed buffer the caller starts from, and on a null pointer. |

## Buffers and ownership

`EikogramBuf` is the caller-allocated descriptor (svgpng's shape): `ptr` and
`len` are written by the native side and read once by the caller. On success
`out` holds the SVG bytes; the native side owns them until
`eikogram_v1_free`. The caller copies before freeing; an empty body records
the zeroed buffer, which the free releases harmlessly. One call owns its
allocations until the copy completes: input pointers and the output
descriptor are released on every exit path, native buffer first.

## Statuses and the error body

On any nonzero status `out` holds a JSON body
`{"class": <Ruby error class name>, "message": ...}`; the loader maps
`class` to its own error classes and never falls back silently. A class the
Ruby side raises with keyword arguments (`ResourceLimitError`) carries its
fields as additional body keys (`resource`, `limit`, `actual`); the loader
constructs the named error from them.

| Status | Meaning | Body `class` |
| --- | --- | --- |
| 0 | success | — |
| 1 | bad call (unreadable input pointer) | `ArgumentError` |
| 2 | the emf-core parse failed | `ParseError` |
| 3 | the transformer raised | `RenderError`, `ResourceLimitError` |
| 4 | the SVG model refused serialization | `RenderError` |

The status and the class are kept distinct so the loader raises named errors
without string-matching; an unrecognized `class` raises the loader's native
error rather than passing silently.

## Versioning evolution

Evolution follows the snapshot v1→v3 pattern: new capability means a NEW
suffixed entry point (old ones keep their bytes and statuses), never an
in-place change. Planned on that pattern: options transport (the renderer's
width/height/namespace overrides — v1 renders default options only) and the
reverse SVG → EMF direction (claricle/emf#90), which will carry the
transformed EMF model bytes with the same buffer, status and versioning
discipline.
