# Native structured EMF+ coverage

The opt-in `emf_core::emf_plus` module parses logical EMF+ bytes. The legacy
`Document::emf_plus_chunks` API and top-level format detection are unchanged.
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
- SetTSGraphics raw rendering state and transform bits, with optional bounded palette.
- SerializableObject image effects: all eleven standard GUID parameter layouts,
  retaining ignored record flags, raw float/Boolean/enum words and signed fields.

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
explicitly opaque. Independently budgeted `ObjectDefinition::decode` additionally
returns editable `ObjectData` for those four bodies, StringFormat (all header
fields, counted tab stops and character ranges), Path, Region, CustomLineCap, Pen, LinearGradient/PathGradient/Texture Brushes, and Image bitmap/metafile
metadata. Path retains raw floating-point, signed integer and relative coordinate
encodings, compressed point-type runs and alignment bytes. Relative coordinate
widths and ignored flag bits survive typed edits; coordinate/type counts, run
totals and alignment are validated before serialization. Region retains a flat preorder
node sequence for binary operations, raw rectangle bits, nested Path, empty and
infinite nodes. Counts, complete binary-tree shape and nested Path lengths are
validated without recursive parsing or destruction; nested allocations share the
object budget. Unknown node types retain the complete object as opaque because
their payload has no generic length. CustomLineCap retains both default and adjustable-arrow
fields, raw Boolean/float/enum words and optional fill/outline Paths. Nested signed
Path lengths are checked on decode and derived on edit; both Paths share the
object allocation and work budgets. Unknown cap types or optional-data flags
retain the complete opaque body. Known flags must agree with optional Path presence
on serialization. Pen retains all flag-selected fixed fields, counted dash/compound
arrays, ordered optional custom caps and Solid/Hatch/LinearGradient/PathGradient/Texture nested brushes. Unknown Pen
types, flags, nested cap types or brush types preserve the complete opaque body.
Custom cap lengths and array counts are derived on edit; option presence must
match flags and all nested allocations share the object budget. Floating-point
and enum fields retain raw bits without rendering-domain validation. Bitmap bytes and nested
metafiles remain raw, without decompression or recursive parsing. Unknown object/brush/image types remain opaque. ObjectData
serialization derives edited counts under shared SerializeLimits.
Editing assembled bytes and replacing an object is supported;
there is no implicit object resegmentation.

## Remaining acceptance work

Image pixel/palette structures and remaining nested
object structures remain opaque. Playback object
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
`tests/emf_plus_objects.rs` covers typed object fields, exact/mutable roundtrips,
StringFormat count validation, all independent resource limits, unexpanded image
payloads and typed edits through continuation/comment boundary preservation.
`tests/emf_plus_path.rs` covers all Path coordinate encodings, raw bit/width and
RLE preservation, counted edits, malformed layouts, shared budgets and typed
continuation edits with exact fragment, padding and segment preservation.

`tests/emf_plus_region.rs` covers typed preorder nodes, all binary operators, raw
rectangle bits, nested Path edits, derived node counts/lengths, unknown-node opaque
preservation, malformed trees, shared budgets and a 20,000-level tree without
recursive parsing, writing or destruction. Continuation edits retain exact
fragment headers, unknown records, padding and comment segment boundaries.

## Enclosing native Document API

`Document::structured_emf_plus(&ParseLimits)` extracts a detached
`emf_plus::EmbeddedStream` with an editable `stream`. It selects decoded EMR_COMMENT
records whose data starts with `EMF+`, strips only that signature, and retains every
segment (including empty ones and boundaries inside a record). Extraction shares
one parse budget across comment scanning, exact source snapshots and logical
stream decoding. Malformed EMF+ is an error only when this optional API is called;
the enclosing EMF parser and raw `emf_plus_chunks()` behavior remain unchanged.
The Ruby raw `emf_plus` representation and existing FFI are unchanged by this API.

`Document::apply_structured_emf_plus(&snapshot, &SerializeLimits)` validates the
current selected comment indices and exact payload bytes against extraction.
A raw edit that changes that selection or its data returns `EmbedError::StaleSource`;
unrelated comment edits can coexist. Re-extract after a successful typed edit.
There is no typed cache and neither representation silently wins a conflict.
A snapshot may be used with an equivalent document having the same selected
indices and payloads; it is a content snapshot, not a document identity token.

Apply retains the existing selected comment set. Earlier comments retain their
original logical capacities, clamped to the remaining bytes on shrink; the final
selected comment receives the remainder, including growth. Empty comments retain
their `EMF+` signature. Same-length streams keep their exact original segmentation.
This is an enclosing-container policy: standalone `serialize_segments` remains
strict, and callers requiring different boundaries can explicitly edit raw
comments. Unlike Ruby's per-origin-frame grouping, Rust also retains boundaries
inside records. A nonempty stream with no original selected comments is rejected;
this API does not insert EMR records.
Every layout check and allocation completes before mutation. Only segments with
changed bytes are marked edited; untouched comments retain their exact original
wire representation, including noncanonical suffixes. Changed comments require
the same canonical padding layout as `edit_record`; original padding bytes are
preserved by the enclosing serializer. Unknown records, unrelated comments,
header opaque bytes and tails follow the existing EMF serialization contract
(including header count refresh after any edit). Serialization limits cover the
logical stream, all comment signatures and additional comparison/staging work; this operation does not
serialize the whole enclosing EMF, whose output has its own limits.

Public regressions: `emf_plus_container.rs` covers typed edits across split/empty
segments, exact unchanged output, unknowns and nonzero inner/outer padding,
coexisting unrelated raw edits, stale selection/data rejection, malformed opt-in
data, late atomic layout failure, growth/shrink across comments (including an
empty logical stream), typed continuation-object edits and parse/serialize
budgets. Growth and shrink preserve unrelated wire records, retain original outer
padding prefixes where they fit and zero new padding via the existing EMF writer.
Custom segment policies, new EMR insertion, FFI/Ruby mapping, licensed embedded
rendering fixtures and the remaining typed families above remain open.

`emf_plus_linecap.rs` covers both cap types, every optional Path combination, raw
field/padding identity, derived edited lengths, unknown opaque fallback, malformed
signed lengths/truncation/suffixes, inconsistent edits, shared parse/serialize
budgets and continuation/segment/unknown-record preservation.

`emf_plus_pen.rs` covers every optional flag and both supported nested brushes,
raw bits, edited array/cap lengths, unknown opaque fallback, malformed nested
boundaries/counts, inconsistent flags, shared budgets and continuation/segment
byte preservation.

LinearGradient brushes expose flags, wrap mode, rectangle/color/reserved words,
optional transform and counted blend arrays, both standalone and inside Pen.
`LinearGradient::blends` stores pairs of position bits and ARGB/factor bits;
wire ordering is preset colors, or vertical then horizontal factors as selected.
Counts derive from edits. Known conflicting blend flags, fewer than two factor
samples, inconsistent optional fields, truncated arrays and suffixes fail.
Unknown flags preserve the complete enclosing object as opaque. Floating-point
bits and enum words are retained without rendering-domain validation.
`emf_plus_linear_brush.rs` covers all optional combinations, wire order,
standalone/nested growth and shrink, malformed and unknown data, shared budgets,
and exact continuation/segment/unknown-record/padding preservation.

PathGradient brushes expose center/color words, surrounding colors, a typed Path
or raw floating-point boundary points, optional transform, blend and focus scales,
both standalone and inside Pen. Boundary lengths, point/color/blend counts and
the fixed focus count derive on edit. Nested Path alignment bytes and all float
bits survive unchanged. Signed boundary lengths/counts, conflicting blend flags,
optional-field presence and factor counts are validated with shared resource
budgets; unknown flags preserve the entire enclosing object as opaque.
`emf_plus_path_brush.rs` covers all 48 optional combinations, typed boundary and
nested Pen growth/shrink, malformed lengths/counts/truncations, inconsistent edits,
shared budgets and exact continuation/segment/unknown-record/padding preservation.

Texture brushes expose flags, wrap mode and an optional transform and image,
both standalone and inside Pen. `TextureImage` retains bitmap metadata and raw
pixel/compressed bytes, or metafile metadata, counted bytes and suffix. Nested
image data shares the object budget and is never decompressed or recursively
parsed. Unknown brush flags or image types preserve the entire enclosing object
as opaque; malformed known headers/counts and inconsistent transforms fail.
`emf_plus_texture.rs` covers all eight flag combinations and three image forms,
image growth/shrink/removal, nested Pen edits, unknown preservation, malformed
headers/counts/suffixes, exact allocation thresholds, shared resource limits and
continuation/segment/unknown-record/padding identity.

SerializableObject records expose `RecordData::Effect` with Blur, BrightnessContrast,
ColorBalance, ColorCurve, ColorLookupTable, ColorMatrix, HueSaturationLightness,
Levels, RedEyeCorrection, Sharpen and Tint parameters. Lookup tables retain blue,
green, red, alpha wire order; matrix words retain column wire order. RedEye areas
retain signed RectL coordinates and derive the signed count on edit. GUID and
BufferSize derive from the selected variant. Known layouts require exact lengths;
unknown GUIDs expose their exact aligned buffer without interpreting it. Raw
numeric fields do not validate rendering ranges. Effect allocations and element
work share the enclosing parse/serialize limits, with counted wire availability
checked before reserve. `emf_plus_effects.rs` covers all GUIDs/fields, mutable and
exact roundtrips, malformed counts/lengths, unknown buffers, split segments,
ignored flags/padding preservation, growth/shrink and resource limits.

SetTSGraphics exposes `RecordData::TSGraphics` and an optional `Palette` with raw
style flags and ARGB entries. All rendering enums, ignored flags, V, signed render
origins, text contrast and transform float bits survive unchanged. The T flag must
agree with palette presence; edited palette counts and record sizes derive from
the entries. Known layouts require exact lengths and count availability before
allocation, with palette entries charged to shared allocation/work limits. Public
`emf_plus_tsgraphics.rs` tests cover all flag combinations, exact fields/bytes,
mutable state and palette growth/shrink/removal, malformed layouts, budget
thresholds and Document repacking with atomic failures/stale-source protection.
SetTSClip's compressed delta rectangles remain opaque pending interpretation.
