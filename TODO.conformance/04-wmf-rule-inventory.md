# MS-WMF rule inventory

WMF rule files and their specs are a separate work stream. They still implement
the same Ruby lens contract and may read only the public metafile model.

## Complete MS-WMF record families

| Family | Count | Record specifications | Public-model coverage |
| --- | ---: | --- | --- |
| Bitmap | 6 | META_BITBLT, META_DIBBITBLT, META_DIBSTRETCHBLT, META_SETDIBTODEV, META_STRETCHBLT, META_STRETCHDIB | D for outer geometry/ROP/color-usage on typed records; B for DIB/bitmap ranges; M for declared record-size comparison and deeper bitmap semantics. |
| Control | 3 | META_EOF, META_HEADER, META_PLACEABLE | D for public header/placeable values on accepted models; rejected/truncated headers require a backend-neutral parse-result surface. |
| Drawing | 20 | META_ARC, META_CHORD, META_ELLIPSE, META_EXTFLOODFILL, META_EXTTEXTOUT, META_FILLREGION, META_FLOODFILL, META_FRAMEREGION, META_INVERTREGION, META_LINETO, META_PAINTREGION, META_PATBLT, META_PIE, META_POLYLINE, META_POLYGON, META_POLYPOLYGON, META_RECTANGLE, META_ROUNDRECT, META_SETPIXEL, META_TEXTOUT | D for fixed geometry, decoded counts, modes and references; B/M for text padding and payloads not retained semantically. |
| Object | 11 | META_CREATEBRUSHINDIRECT, META_CREATEFONTINDIRECT, META_CREATEPALETTE, META_CREATEPATTERNBRUSH, META_CREATEPENINDIRECT, META_CREATEREGION, META_DELETEOBJECT, META_DIBCREATEPATTERNBRUSH, META_SELECTCLIPREGION, META_SELECTOBJECT, META_SELECTPALETTE | D for typed public object fields and lifecycle/reference checks; B for opaque object creators; rejected object-table failures need the neutral parse-result surface. |
| State | 31 | META_ANIMATEPALETTE, META_EXCLUDECLIPRECT, META_INTERSECTCLIPRECT, META_MOVETO, META_OFFSETCLIPRGN, META_OFFSETVIEWPORTORG, META_OFFSETWINDOWORG, META_REALIZEPALETTE, META_RESIZEPALETTE, META_RESTOREDC, META_SAVEDC, META_SCALEVIEWPORTEXT, META_SCALEWINDOWEXT, META_SETBKCOLOR, META_SETBKMODE, META_SETLAYOUT, META_SETMAPMODE, META_SETMAPPERFLAGS, META_SETPALENTRIES, META_SETPOLYFILLMODE, META_SETRELABS, META_SETROP2, META_SETSTRETCHBLTMODE, META_SETTEXTALIGN, META_SETTEXTCHAREXTRA, META_SETTEXTCOLOR, META_SETTEXTJUSTIFICATION, META_SETVIEWPORTEXT, META_SETVIEWPORTORG, META_SETWINDOWEXT, META_SETWINDOWORG | D for most fixed fields/enums and state sequences; B for palette entries; M for rejected-input reasons and declared sizes. |
| Escape | 44 | META_ESCAPE plus ABORTDOC, BEGIN_PATH, CHECKJPEGFORMAT, CHECKPNGFORMAT, CLIP_TO_PATH, CLOSECHANNEL, DOWNLOADFACE, DOWNLOADHEADER, DRAWPATTERNRECT, ENCAPSULATED_POSTSCRIPT, END_PATH, ENDDOC, EPSPRINTING, EXTTEXTOUT, GETCOLORTABLE, GETDEVICEUNITS, GETEXTENDEDTEXTMETRICS, GETFACENAME, GETPAIRKERNTABLE, GETPHYSPAGESIZE, GETPRINTINGOFFSET, GET_PS_FEATURESETTING, GETSCALINGFACTOR, META_ESCAPE_ENHANCED_METAFILE, METAFILE_DRIVER, NEWFRAME, NEXTBAND, PASSTHROUGH, POSTSCRIPT_DATA, POSTSCRIPT_IDENTIFY, POSTSCRIPT_IGNORE, POSTSCRIPT_INJECTION, POSTSCRIPT_PASSTHROUGH, OPENCHANNEL, QUERYDIBSUPPORT, QUERYESCSUPPORT, SETCOLORTABLE, SETCOPYCOUNT, SETLINECAP, SETLINEJOIN, SETMITERLIMIT, SPCLPASSTHROUGH2, STARTDOC | D for the generic escape ID and outer byte count; typed public views cover selected payloads, including embedded EMF. Other subtypes remain B/M. |

Counting every escape subtype separately gives 115 specified record layouts
(6 + 3 + 20 + 11 + 31 + 44). Unknown WMF functions remain preservable opaque
records; they receive framing/coverage diagnostics but are not rejected merely
for being unknown.

## Existing rejection catalog

The Rust `first_rejection` walk covers 18 codec families and 56 stable reason
codes:

| Codec family | Reason codes |
| --- | --- |
| Input limit | 101 |
| Placeable header | 201–203 |
| WMF header | 301–306 |
| Record framing/termination | 401–406 |
| Fixed records | 501 |
| State records | 601 |
| Font records | 701 |
| Object records | 801 |
| Point-array records | 901–904 |
| Text records | 1001–1005 |
| Palette records | 1101–1102 |
| Region/clipping records | 1201–1206 |
| Brush records | 1301–1304 |
| Bitmap records | 1401–1402 |
| Geometry records | 1501–1502 |
| DC/escape records | 1601–1603 |
| Object-table validation | 1701–1707 |
| Declared maximum record | 1801 |

`lib/emf/native/wmf_rejection.rb` maps the reason codes to messages, but its
input is a native WMFR diagnostic packet. The public lens cannot reuse that
class without creating a backend-specific path. The reason definitions may be
used as a review checklist and stable vocabulary only.

The shared rejection-case asset covers 54 of 56 reasons; the 200 MiB input-limit
case (101) and million-record limit case (401) remain bounded Rust tests and
should not be materialized in ordinary Ruby specs.

## Rule and dependency split

| Proposed rule file | Constraint groups | Status |
| --- | --- | --- |
| `lib/emf/conformance/rules/wmf_framing.rb` | accepted-model header/placeable/EOF, public record order and outer bounds | Planned in WMF work stream; declared record size is M. |
| `lib/emf/conformance/rules/wmf_records.rb` | fixed fields, enum domains, point/text/palette/region/bitmap counts and bounds | Planned; implement D/B requirements and register blocked ones. |
| `lib/emf/conformance/rules/wmf_objects.rb` | object allocation, expected type, select/delete and capacity lifecycle | Planned from the public record sequence. |
| `lib/emf/conformance/rules/wmf_escape.rb` | escape ID, byte count, typed payload validation, embedded EMF bounds | Planned; most subtype semantics remain B/M. |
| Public model/parse result | declared record size and rejected-input structured evidence | Dependency owned by the model/native stream after or alongside PR #54, never by lens files. |

The present parser drops each WMF record's declared size and raises before a
metafile model exists for structural rejection. Until both facts are exposed by
a backend-neutral public result, the corresponding 56 reason-level lens checks
remain `blocked:model`. Accepted-record rules can ship independently, but must
not claim complete WMF coverage.

## W20 requirement map: record layouts (stable IDs)

Layout ID = `wmf.layout.<lowercase META_ name>`; escape subtypes are `wmf.layout.escape.<name>`.
Function codes are the WMF RecordFunction word. `W22`/`W23` marks rules not yet written; `none` means
the specification states no constraint checkable on public values (framing and declared size are
`wmf.record.declared_size`, blocked). Section numbers follow the family order above and were not
re-checked against the published MS-WMF text (it was unreachable from this session).

### Bitmap

| Layout ID | Function | MS-WMF | Public accessor | Covered by |
| --- | --- | --- | --- | --- |
| `wmf.layout.bitblt` | 0x0922 | 2.3.1.1 | `BitBlt` | W23 |
| `wmf.layout.dibbitblt` | 0x0940 | 2.3.1.2 | `DibBitBlt` | W23 |
| `wmf.layout.dibstretchblt` | 0x0B41 | 2.3.1.3 | `DibStretchBlt` | W23 |
| `wmf.layout.setdibtodev` | 0x0D32 | 2.3.1.4 | `SetDibToDev` | wmf.enum.color_usage |
| `wmf.layout.stretchblt` | 0x0B23 | 2.3.1.5 | `StretchBlt` | W23 |
| `wmf.layout.stretchdib` | 0x0F43 | 2.3.1.6 | `StretchDib` | wmf.enum.color_usage |
### Control

| Layout ID | Function | MS-WMF | Public accessor | Covered by |
| --- | --- | --- | --- | --- |
| `wmf.layout.eof` | 0x0000 | 2.3.2.1 | `Eof` | wmf.eof.missing, wmf.eof.not_last |
| `wmf.layout.header` | - | 2.3.2.2 | `Header` | wmf.header.* |
| `wmf.layout.placeable` | - | 2.3.2.3 | `PlaceableHeader` | wmf.placeable.* |

### Drawing

| Layout ID | Function | MS-WMF | Public accessor | Covered by |
| --- | --- | --- | --- | --- |
| `wmf.layout.arc` | 0x0817 | 2.3.3.1 | `Arc` | none (no public-value constraint) |
| `wmf.layout.chord` | 0x0830 | 2.3.3.2 | `Chord` | none |
| `wmf.layout.ellipse` | 0x0418 | 2.3.3.3 | `Ellipse` | none |
| `wmf.layout.extfloodfill` | 0x0548 | 2.3.3.4 | `ExtFloodFill` | wmf.enum.ext_flood_fill_mode |
| `wmf.layout.exttextout` | 0x0A32 | 2.3.3.5 | `ExtTextOut` | W23 |
| `wmf.layout.fillregion` | 0x0228 | 2.3.3.6 | `FillRegion` | W22 |
| `wmf.layout.floodfill` | 0x0419 | 2.3.3.7 | `FloodFill` | none |
| `wmf.layout.frameregion` | 0x0429 | 2.3.3.8 | `FrameRegion` | W22 |
| `wmf.layout.invertregion` | 0x012A | 2.3.3.9 | `InvertRegion` | W22 |
| `wmf.layout.lineto` | 0x0213 | 2.3.3.10 | `LineTo` | none |
| `wmf.layout.paintregion` | 0x012B | 2.3.3.11 | `PaintRegion` | W22 |
| `wmf.layout.patblt` | 0x061D | 2.3.3.12 | `PatBlt` | W23 |
| `wmf.layout.pie` | 0x081A | 2.3.3.13 | `Pie` | none |
| `wmf.layout.polyline` | 0x0325 | 2.3.3.14 | `Polyline` | wmf.array.point_count, wmf.fixed.point_range |
| `wmf.layout.polygon` | 0x0324 | 2.3.3.15 | `Polygon` | wmf.array.point_count, wmf.fixed.point_range |
| `wmf.layout.polypolygon` | 0x0538 | 2.3.3.16 | `PolyPolygon` | wmf.array.polypolygon_counts, wmf.fixed.point_range |
| `wmf.layout.rectangle` | 0x041B | 2.3.3.17 | `Rectangle` | none |
| `wmf.layout.roundrect` | 0x061C | 2.3.3.18 | `RoundRect` | none |
| `wmf.layout.setpixel` | 0x041F | 2.3.3.19 | `SetPixel` | none |
| `wmf.layout.textout` | 0x0521 | 2.3.3.20 | `TextOut` | W23 |
### Object

| Layout ID | Function | MS-WMF | Public accessor | Covered by |
| --- | --- | --- | --- | --- |
| `wmf.layout.createbrushindirect` | 0x02FC | 2.3.4.1 | `CreateBrushIndirect` | wmf.enum.brush_style, wmf.enum.hatch_style |
| `wmf.layout.createfontindirect` | 0x02FB | 2.3.4.2 | `CreateFontIndirect` | W23 |
| `wmf.layout.createpalette` | 0x00F7 | 2.3.4.3 | `CreatePalette` | W23 |
| `wmf.layout.createpatternbrush` | 0x01F9 | 2.3.4.4 | `CreatePatternBrush` | W23 |
| `wmf.layout.createpenindirect` | 0x02FA | 2.3.4.5 | `CreatePenIndirect` | wmf.enum.pen_style |
| `wmf.layout.createregion` | 0x06FF | 2.3.4.6 | `CreateRegion` | W23 |
| `wmf.layout.deleteobject` | 0x01F0 | 2.3.4.7 | `DeleteObject` | W22 |
| `wmf.layout.dibcreatepatternbrush` | 0x0142 | 2.3.4.8 | `DibCreatePatternBrush` | wmf.enum.color_usage |
| `wmf.layout.selectclipregion` | 0x012C | 2.3.4.9 | `SelectClipRegion` | W22 |
| `wmf.layout.selectobject` | 0x012D | 2.3.4.10 | `SelectObject` | W22 |
| `wmf.layout.selectpalette` | 0x0234 | 2.3.4.11 | `SelectPalette` | W22 |
### State

| Layout ID | Function | MS-WMF | Public accessor | Covered by |
| --- | --- | --- | --- | --- |
| `wmf.layout.animatepalette` | 0x0436 | 2.3.5.1 | `AnimatePalette` | W23 |
| `wmf.layout.excludecliprect` | 0x0415 | 2.3.5.2 | `ExcludeClipRect` | none |
| `wmf.layout.intersectcliprect` | 0x0416 | 2.3.5.3 | `IntersectClipRect` | none |
| `wmf.layout.moveto` | 0x0214 | 2.3.5.4 | `MoveTo` | none |
| `wmf.layout.offsetcliprgn` | 0x0220 | 2.3.5.5 | `OffsetClipRgn` | none |
| `wmf.layout.offsetviewportorg` | 0x0211 | 2.3.5.6 | `OffsetViewportOrg` | none |
| `wmf.layout.offsetwindoworg` | 0x020F | 2.3.5.7 | `OffsetWindowOrg` | none |
| `wmf.layout.realizepalette` | 0x0035 | 2.3.5.8 | `RealizePalette` | none |
| `wmf.layout.resizepalette` | 0x0139 | 2.3.5.9 | `ResizePalette` | W23 |
| `wmf.layout.restoredc` | 0x0127 | 2.3.5.10 | `RestoreDc` | W22 |
| `wmf.layout.savedc` | 0x001E | 2.3.5.11 | `SaveDc` | W22 |
| `wmf.layout.scaleviewportext` | 0x0412 | 2.3.5.12 | `ScaleViewportExt` | none (divisor semantics: W22) |
| `wmf.layout.scalewindowext` | 0x0410 | 2.3.5.13 | `ScaleWindowExt` | none (divisor semantics: W22) |
| `wmf.layout.setbkcolor` | 0x0201 | 2.3.5.14 | `SetBkColor` | none |
| `wmf.layout.setbkmode` | 0x0102 | 2.3.5.15 | `SetBkMode` | wmf.enum.bk_mode |
| `wmf.layout.setlayout` | 0x0149 | 2.3.5.16 | `SetLayout` | wmf.flags.layout, wmf.fixed.layout_reserved |
| `wmf.layout.setmapmode` | 0x0103 | 2.3.5.17 | `SetMapMode` | wmf.enum.map_mode |
| `wmf.layout.setmapperflags` | 0x0231 | 2.3.5.18 | `SetMapperFlags` | none |
| `wmf.layout.setpalentries` | 0x0037 | 2.3.5.19 | `SetPalEntries` | W23 |
| `wmf.layout.setpolyfillmode` | 0x0106 | 2.3.5.20 | `SetPolyFillMode` | wmf.enum.poly_fill_mode |
| `wmf.layout.setrelabs` | 0x0105 | 2.3.5.21 | `SetRelAbs` | none |
| `wmf.layout.setrop2` | 0x0104 | 2.3.5.22 | `SetRop2` | wmf.enum.rop2 |
| `wmf.layout.setstretchbltmode` | 0x0107 | 2.3.5.23 | `SetStretchBltMode` | wmf.enum.stretch_blt_mode |
| `wmf.layout.settextalign` | 0x012E | 2.3.5.24 | `SetTextAlign` | wmf.flags.text_align |
| `wmf.layout.settextcharextra` | 0x0108 | 2.3.5.25 | `SetTextCharExtra` | none |
| `wmf.layout.settextcolor` | 0x0209 | 2.3.5.26 | `SetTextColor` | none |
| `wmf.layout.settextjustification` | 0x020A | 2.3.5.27 | `SetTextJustification` | none |
| `wmf.layout.setviewportext` | 0x020E | 2.3.5.28 | `SetViewportExt` | none |
| `wmf.layout.setviewportorg` | 0x020D | 2.3.5.29 | `SetViewportOrg` | none |
| `wmf.layout.setwindowext` | 0x020C | 2.3.5.30 | `SetWindowExt` | none |
| `wmf.layout.setwindoworg` | 0x020B | 2.3.5.31 | `SetWindowOrg` | none |

### Escape

| Layout ID | Function | MS-WMF | Public accessor | Covered by |
| --- | --- | --- | --- | --- |
| `wmf.layout.meta_escape` | 0x0626 | 2.3.6 | `Escape` (escape_function, data, padding) | W23 |
| `wmf.layout.escape.abortdoc` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.begin_path` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.checkjpegformat` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.checkpngformat` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.clip_to_path` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.closechannel` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.downloadface` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.downloadheader` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.drawpatternrect` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.encapsulated_postscript` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.end_path` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.enddoc` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.epsprinting` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.exttextout` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.getcolortable` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.getdeviceunits` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.getextendedtextmetrics` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.getfacename` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.getpairkerntable` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.getphyspagesize` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.getprintingoffset` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.get_ps_featuresetting` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.getscalingfactor` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.meta_escape_enhanced_metafile` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.metafile_driver` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.newframe` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.nextband` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.passthrough` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.postscript_data` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.postscript_identify` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.postscript_ignore` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.postscript_injection` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.postscript_passthrough` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.openchannel` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.querydibsupport` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.queryescsupport` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.setcolortable` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.setcopycount` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.setlinecap` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.setlinejoin` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.setmiterlimit` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.spclpassthrough2` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |
| `wmf.layout.escape.startdoc` | 0x0626 | 2.3.6 | `Escape#data` typed views where present, else opaque | W23 (payload semantics blocked:model unless a typed view exists) |

Total layouts mapped: 115.

## W20 requirement map: rejection reasons

All 56 reasons are `wmf.reject.rNNNN` rows (NNNN = the stable reason code, zero padded) with status
`blocked:model` in `lib/emf/conformance/manifest/wmf.yml`: the parser raises before a Metafile exists, and
the lens then reports only `emf.parse.unparseable`. Enabling them is W24.

## W21 implemented rules

`wmf.header.{type,version,size,number_of_members}`, `wmf.placeable.{handle,checksum}`, `wmf.eof.{missing,not_last,trailing_bytes}`,
`wmf.record.unknown_function`, `wmf.enum.{bk_mode,map_mode,poly_fill_mode,rop2,stretch_blt_mode,ext_flood_fill_mode,brush_style,color_usage,hatch_style,pen_style}`,
`wmf.flags.{text_align,layout}`, `wmf.fixed.{layout_reserved,point_range}`, `wmf.array.{point_count,polypolygon_counts}`.
The parser already rejects most of these shapes, so they fire in practice on hand-built or mutated public models.
