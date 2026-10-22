# MS-EMFPLUS rule inventory

## Coverage notation

- **D** — fixed fields, flags, enums, counts, handles, or payload lengths are
  decoded on the public EMF+ record.
- **B** — public `body`/`trailing` bytes support framing and bounds checks, while
  nested semantics remain opaque.
- **M** — a cited requirement needs a public model addition before it can be
  evaluated identically for both backends.

All records receive common checks for a defined type, minimum and aligned
`Size`, `DataSize <= Size - 12`, and a payload that ends within the EMF+ stream.
Reserved type values `0x4005`–`0x4007` and unknown values receive explicit
diagnostics rather than being treated as conformant.

## All 55 defined record types

| Family | Count | Record types | Rule/model status |
| --- | ---: | --- | --- |
| Clipping | 5 | ResetClip, SetClipRect, SetClipPath, SetClipRegion, OffsetClip | D for combine mode, compressed-coordinate flags, rectangles and object handles; object-kind checks use the public stream resolver. |
| Comment | 1 | Comment | D for outer size/data size; B for application-defined payload semantics. |
| Control | 3 | EndOfFile, GetDC, Header | D for sizes, version/signature, flags, DPI, and required stream placement. |
| Drawing | 22 | Clear, DrawArc, DrawBeziers, DrawClosedCurve, DrawCurve, DrawDriverString, DrawEllipse, DrawImage, DrawImagePoints, DrawLines, DrawPath, DrawPie, DrawRects, DrawString, FillClosedCurve, FillEllipse, FillPath, FillPie, FillPolygon, FillRects, FillRegion, StrokeFillPath | D for decoded flags, enum values, object handles, and most counts/geometry; B for DriverString and image payload internals; M for any StrokeFillPath layout that remains unimplemented. |
| Object | 2 | Object, SerializableObject | D for object ID/type/continuation and outer payload lengths; B/M for type-specific object payloads not represented by public object classes. |
| Property | 8 | SetAntiAliasMode, SetTextRenderingHint, SetTextContrast, SetInterpolationMode, SetPixelOffsetMode, SetCompositingMode, SetCompositingQuality, SetRenderingOrigin | D for reserved bits, enum domains, contrast range, and coordinates. |
| State | 5 | Save, Restore, BeginContainer, BeginContainerNoParams, EndContainer | D for state/container IDs and fixed fields; stream-state matching is checkable in the lens. |
| Terminal server | 2 | SetTSGraphics, SetTSClip | D for outer flags/counts; B for palette/compressed bytes; M where compressed payload length cannot be derived without a public decoded view. |
| Transform | 7 | SetWorldTransform, ResetWorldTransform, MultiplyWorldTransform, TranslateWorldTransform, ScaleWorldTransform, RotateWorldTransform, SetPageTransform | D for matrices, order/unit enums, fixed sizes, and finite numeric values. |

The family counts sum to 55. The present implementation has typed classes for
54: `StrokeFillPath` (`0x4037`) is specified but has no typed layout. The manifest
must retain it as `blocked:model`, not omit it from coverage.

## Constraint inventory and rule files

| Proposed rule file | Constraint groups | Current status |
| --- | --- | --- |
| `lib/emf/conformance/rules/emf_plus_framing.rb` | frame size/alignment, data size, stream bounds, Header/EOF placement, unknown/reserved types | Existing stream checks are being adapted; add requirement IDs and common report issues. |
| `lib/emf/conformance/rules/emf_plus_properties.rb` | flag masks, enum domains, modes, units, contrast and transform values | Planned; current public fields are sufficient. |
| `lib/emf/conformance/rules/emf_plus_drawing.rb` | point/rectangle counts, compressed coordinate sizes, brush/pen/image/string handles, geometry | Planned; DriverString/image substructures remain buffer-level. |
| `lib/emf/conformance/rules/emf_plus_objects.rb` | object ID/type, continuation chains, object construction errors, expected object kind | Planned; use the public stream resolver rather than reimplementing an object table. |
| `lib/emf/conformance/rules/emf_plus_state.rb` | saved-state/container lifecycle, clip and transform constraints | Planned. |
| `lib/emf/conformance/rules/emf_plus_terminal.rb` | terminal-server flags, palette/count and compressed payload bounds | Planned; some semantic payload checks are blocked. |

## Object-reference validation

`ObjectTable#resolve`, exposed through the public EMF+ stream, already classifies
empty, out-of-range, wrong-kind and construction-failed references for pens,
brushes, fonts, string formats, images, image attributes, paths, regions and
clips. Rules should translate those results into requirement-specific issues at
the referring record; they must not copy the object-table algorithm or call its
Rust twin.

The public stream record offset is relative to the EMF+ comment payload. The
common report requires an absolute metafile offset. Propagating the containing
EMR_COMMENT offset into the public stream/record location is therefore a model
dependency owned outside lens rule files. Until it lands, issues may retain both
`comment_index` and stream-relative context internally, but the requirement is
`blocked:model` and must not emit a misleading absolute offset.

## Completion rule

Each of the 55 types needs a manifest row with its MS-EMFPLUS section, stable
requirement IDs, decoded accessor or `blocked:model` reason, strict/tolerant
severity, and positive/negative/bounds cases. A framing `ParseError` is a named
diagnostic, not evidence that the unseen type-specific requirements passed.
