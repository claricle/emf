# Native structured EMF+ coverage

The opt-in `emf_core::emf_plus` module parses logical EMF+ bytes. The legacy
`Document::emf_plus_bytes` API and top-level format detection are unchanged.
Normative source: local MS-EMFPLUS sections 2.3 and 2.2.

`parse_segments` accepts ordered payload slices **after** each EMF+ signature.
Records may cross slices; empty slices and exact lengths are retained. The caller
owns the enclosing EMF comments, signatures and outer padding. `serialize_segments`
returns the original segmentation and rejects edits that change total length;
`serialize` permits explicit record edits and derives Size/DataSize. Empty and
headerless logical streams are accepted for editing/extraction, without claiming
to validate a complete playback document.

## Structured families

- Header, EOF and GetDC; Clear; rendering origin and flags-only rendering modes.
- Save/Restore, Begin/EndContainer, BeginContainerNoParams.
- Set/Multiply/ResetWorldTransform, Translate/Scale/RotateWorldTransform,
  SetPageTransform; Reset/SetClipRect/Path/Region and OffsetClip.
- Fill/DrawRects, Fill/DrawEllipse, Fill/DrawPie, DrawArc.
- FillPolygon, DrawLines and DrawBeziers with float, signed 16-bit or relative
  coordinates; relative values retain seven/fifteen-bit width and data padding.
- FillRegion/FillPath brush words and DrawPath pen words.
- Fill/DrawClosedCurve and DrawCurve, retaining tension bits, offsets and ranges.
- DrawImage/DrawImagePoints source fields and destination rectangles/three points.
- DrawString raw UTF-16, layout and format ID; DrawDriverString glyphs, positions,
  realized-advance layout and optional transform.
- Object fragment headers with object ID/type and optional TotalObjectSize.

Floating-point fields expose their IEEE bits. Record flags, unknown record data,
and bytes between DataSize and Size are retained exactly. Typed layout mismatches
are rejected rather than silently normalized. All parsing, object assembly and
atomic fixed-length object edits use the shared ParseLimits; serializers preflight
shared SerializeLimits before reserving output.

## Objects and continuation

Continuation chains validate identity, repeated totals, termination and exact
logical length before assembly. Both a clear-C final chunk and the observed
Windows C-set final chunk are supported. Object definitions retain their order,
including replacement definitions for the same object-table slot. Assembly is
explicit and independently budgeted. `replace_object_bytes` is atomic and retains
fragment sizes, flags, padding and comment boundaries.

Borrowed, allocation-free object views currently decode Solid/Hatch Brush, Font
(including raw UTF-16 and suffix) and ImageAttributes. Other object subtypes remain
explicitly opaque. Editing assembled bytes and replacing an object is supported;
there is no implicit object resegmentation.

## Remaining acceptance work

Deeper Pen/Path/Region/Image/StringFormat/CustomLineCap
objects, nested object structures and effects remain opaque. Playback object
reference validity, enum-domain interpretation and complete document ordering are
not validated. This checkpoint supplies reusable bounded native framing and editing;
it does not claim full native EMF+ format acceptance or add a Ruby public API.

Public regressions: `emf-rs/crates/emf-core/tests/emf_plus.rs` cover exact and mutable
roundtrips, typed values, unknown/padding and segment preservation, malformed
framing, every shared parse budget, serialization limits, continuation forms,
pre-expansion object limits and atomic edit failure.
`tests/emf_plus_drawing.rs` adds typed drawing assertions, mutable/exact roundtrips,
relative-width/sign and NaN-bit preservation, count/truncation/encoding failures and
allocation/work limit failures before counted vector expansion.
`tests/emf_plus_text.rs` covers raw UTF-16, glyph/position/matrix layouts, edits,
invalid counts and matrix flags, padding and resource budgets.
