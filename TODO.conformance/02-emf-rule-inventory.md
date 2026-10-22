# MS-EMF rule inventory

## Coverage notation

- **D** — the present public record/wire model exposes the fields required for
  record framing, fixed fields, counts, handles, or enums.
- **B** — public `body`/`trailing` bytes allow bounds or byte-length checks, but
  not every semantic subfield is decoded.
- **M** — a normative check needs a public model addition from the model/native
  ownership stream. A rule remains `blocked:model` until both backends expose it.

Every record also receives the common record checks when applicable: known type,
minimum/fixed size, four-byte alignment, declared size within the stream, and
serialized byte length equal to `nSize`. Required-field presence is represented
by successful typed hydration; a recovered `Raw` record receives a parse-recovery
diagnostic instead of being marked conformant.

## All 119 record types

| Family | Count | Record types | Rule/model status |
| --- | ---: | --- | --- |
| Bitmap | 8 | ALPHABLEND, BITBLT, MASKBLT, PLGBLT, SETDIBITSTODEVICE, STRETCHBLT, STRETCHDIBITS, TRANSPARENTBLT | D for fixed geometry, usage enums, offsets and byte counts; B for referenced BMI/bits ranges; M only for semantic bitmap payload checks not exposed by the public buffer view. |
| Clipping | 6 | EXCLUDECLIPRECT, EXTSELECTCLIPRGN, INTERSECTCLIPRECT, OFFSETCLIPRGN, SELECTCLIPPATH, SETMETARGN | D for rectangles, offsets, modes, and fixed sizes; B/M for region payload internals where the wire object retains bytes rather than decoded scans. |
| Comment | 1 | COMMENT | D for `cbData` and record size; B for comment bounds/type dispatch; M for semantic payloads not represented by `emf_plus_stream`. |
| Control | 2 | EOF, HEADER | D for fixed header fields, signature/version/counts and fixed EOF fields; B/M for HEADER description/pixel-format buffers and EOF palette entries; M for locating EOF `SizeLast` at the actual last four bytes when a palette is present. |
| Drawing | 39 | ANGLEARC, ARC, ARCTO, CHORD, ELLIPSE, EXTFLOODFILL, EXTTEXTOUTA, EXTTEXTOUTW, FILLPATH, FILLRGN, FRAMERGN, GRADIENTFILL, LINETO, PAINTRGN, PIE, POLYBEZIER, POLYBEZIER16, POLYBEZIERTO, POLYBEZIERTO16, POLYDRAW, POLYDRAW16, POLYGON, POLYGON16, POLYLINE, POLYLINE16, POLYLINETO, POLYLINETO16, POLYPOLYGON, POLYPOLYGON16, POLYPOLYLINE, POLYPOLYLINE16, POLYTEXTOUTA, POLYTEXTOUTW, RECTANGLE, ROUNDRECT, SETPIXELV, SMALLTEXTOUT, STROKEANDFILLPATH, STROKEPATH | D for fixed geometry/enums and decoded point/count arrays; B for derived variable arrays; M for EXTTEXTOUT strings/Dx arrays, SMALLTEXTOUT text semantics, and POLYTEXTOUT text arrays that are currently opaque. |
| Escape | 3 | DRAWESCAPE, EXTESCAPE, NAMEDESCAPE | D for fixed identifiers/counts where present; B for payload bounds; M for payload-specific semantics. |
| Object creation | 9 | CREATEBRUSHINDIRECT, CREATECOLORSPACE, CREATECOLORSPACEW, CREATEDIBPATTERNBRUSHPT, CREATEMONOBRUSH, CREATEPALETTE, CREATEPEN, EXTCREATEFONTINDIRECTW, EXTCREATEPEN | D for exposed indices, styles, enums and counts; B for palette/font/brush buffers; M for CREATECOLORSPACE/CREATECOLORSPACEW and any unexposed variable object fields. |
| Object manipulation | 8 | COLORCORRECTPALETTE, DELETECOLORSPACE, DELETEOBJECT, RESIZEPALETTE, SELECTOBJECT, SELECTPALETTE, SETCOLORSPACE, SETPALETTEENTRIES | D for exposed handles/indices/counts and stock-object rules; B for palette entries; M for the currently opaque color-space records. |
| OpenGL | 2 | GLSBOUNDEDRECORD, GLSRECORD | D for outer framing; B for payload bounds; M for OpenGL payload semantics. |
| Path bracket | 6 | ABORTPATH, BEGINPATH, CLOSEFIGURE, ENDPATH, FLATTENPATH, WIDENPATH | D for record size and stream/state ordering rules. |
| State | 33 | COLORMATCHTOTARGETW, FORCEUFIMAPPING, INVERTRGN, MOVETOEX, PIXELFORMAT, REALIZEPALETTE, RESTOREDC, SAVEDC, SCALEVIEWPORTEXTEX, SCALEWINDOWEXTEX, SETARCDIRECTION, SETBKCOLOR, SETBKMODE, SETBRUSHORGEX, SETCOLORADJUSTMENT, SETICMMODE, SETICMPROFILEA, SETICMPROFILEW, SETLAYOUT, SETLINKEDUFIS, SETMAPMODE, SETMAPPERFLAGS, SETMITERLIMIT, SETPOLYFILLMODE, SETROP2, SETSTRETCHBLTMODE, SETTEXTALIGN, SETTEXTCOLOR, SETTEXTJUSTIFICATION, SETVIEWPORTEXTEX, SETVIEWPORTORGEX, SETWINDOWEXTEX, SETWINDOWORGEX | D for most fixed fields/enums and RESTOREDC sign/range; B for variable profile/UFI/region data; M for SETCOLORADJUSTMENT, PIXELFORMAT, FORCEUFIMAPPING, COLORCORRECTPALETTE, SETICMPROFILEA/W, SETLINKEDUFIS and COLORMATCHTOTARGETW semantic fields that are currently opaque. |
| Transform | 2 | MODIFYWORLDTRANSFORM, SETWORLDTRANSFORM | D for matrices, mode enum, fixed size, and finite-value checks required by the cited clauses. |

Family counts sum to 119. The known fully opaque wire classes by type code are
23, 96, 97, 99–106, 109–113, 119, 121, and 122. Some of those record types still
permit common framing checks; “opaque” refers to their type-specific payload.

## Constraint inventory and rule files

| Proposed rule file | Constraint groups | Current status |
| --- | --- | --- |
| `lib/emf/conformance/rules/emf_framing.rb` | type/size/alignment, record bounds, EOF position, trailing bytes | In progress. |
| `lib/emf/conformance/rules/emf_control.rb` | HEADER signature/version/counts/offsets; EOF palette and `SizeLast` | Header/EOF base rules in progress; buffer rules partly blocked. |
| `lib/emf/conformance/rules/emf_geometry.rb` | primitive geometry, point counts, polygon count sums, PolyDraw type/count agreement | Planned; current arrays are mostly checkable. |
| `lib/emf/conformance/rules/emf_text.rb` | character count, string and Dx offset/length bounds, text option enums | Planned; core string/Dx checks blocked on public decoding. |
| `lib/emf/conformance/rules/emf_bitmap.rb` | usage enums, BMI/bits offsets and lengths, overlap/end bounds | Planned; byte bounds checkable, semantic buffers conditional. |
| `lib/emf/conformance/rules/emf_objects.rb` | handle ranges, stock handles, create/delete/select lifecycle, palette counts | Planned; opaque color-space types blocked. |
| `lib/emf/conformance/rules/emf_state.rb` | enum domains, nonzero divisors, RESTOREDC, path/DC state | Planned. |
| `lib/emf/conformance/rules/emf_regions.rb` | region header/scan sizes, region/brush references | Planned; add real fixtures for types 71–74. |
| `lib/emf/conformance/rules/emf_opaque.rb` | outer counts/bounds for comments, escapes, OpenGL, profiles and UFI data | Planned; semantic requirements stay blocked until exposed. |

## Existing catalog and completion rule

The partial catalog covers 18 of 119 record types and 36 candidate constraints.
It establishes 26 checks that can be expressed from current public data and 10
informational/behavioral statements; it is not full normative coverage. Five
variable buffer groups are not exposed: EOF palette data, HEADER description,
HEADER pixel format, EXTTEXTOUT string data, and EXTTEXTOUT Dx data.

The manifest is complete only when every one of the 119 rows has:

- exact MS-EMF section and normative sentence category;
- stable requirement ID and applicable profile severity;
- accessor expression or `blocked:model` reason;
- positive, negative, bounds, and backend-parity cases as applicable; and
- no use of a `record_variants` label as a conformance oracle.
