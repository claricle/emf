# 09 — EMF+ coverage inventory

Status: **Typed decoding exists for every defined record, object and image effect inside `Emf::EmfPlus`; none of it is exposed on `Metafile`, `Model` or the CLI, and the representation gate below is still a proposal.** Package: [09-format-extension.md](09-format-extension.md) steps 1, 4, 5 and 8 (EMF+ half). Ruby status re-measured against the code 2026-10-20 on branch `feat/emf-plus-conditional-rules` at 03f356a (`origin/main` d93bf89 plus one commit). Corpus counts are from the census run at 8e3f083 and were not re-run.

Reachability: `Records.decode`, `Objects.decode` and `Effects.decode` are called only from inside `lib/emf/emf_plus/`. `lib/emf.rb:19` autoloads `Emf::EmfPlus`, but `Metafile`, `Model` and the CLI do not use it, and `Metafile#emf_plus` is still the raw concatenated String. "typed" in the tables below means a class that decodes and re-encodes in `Emf::EmfPlus`, not that a caller of `Emf.parse` gets typed records.

Sources: `reference-docs/ms-emfplus/ch02-structures.md` (normative, [MS-EMFPLUS] 240423), `ch01` section 1.3.1, `ch03` examples, `ch05` product-behavior notes. Corpus numbers come from `bundle exec ruby script/emf_plus_census --out tmp/emf-plus-census.json` at `8e3f083` (not re-run for this update; not committed: the JSON goes stale whenever the parser changes). It parses one fixture at a time and prints `[n/229]` progress to stderr; the full corpus takes about 16 minutes because some corrupt fixtures take over a minute each.

## Summary of measured facts

| Fact | Value | Source |
| --- | --- | --- |
| EMF+ record types (`RecordType`, 0x4001 to 0x403A) | 58 | ch02 2.1.1.1 |
| ... with a record section in 2.3.x | 54 | `#### EmfPlus* Record` headings |
| ... reserved, `MUST NOT be used` | 3 (0x4005 to 0x4007) | ch02 2.1.1.1 |
| ... enumerator without any record section | 1 (`EmfPlusStrokeFillPath` 0x4037) | ch02 2.1.1.1 vs 2.3 |
| Objects (2.2) | 67 = 9 graphics + 47 structure + 11 image effects | `#### ... Object` headings |
| Corpus fixtures | 229 (208 valid + 21 corrupt) | `spec/fixtures/**/*.emf` |
| Fixtures with at least one EMF+ comment | 27 (23 valid + 4 corrupt) | census |
| ... by directory | `emf` 19, `emf-corrupted` 4, `emf-ea` 3, `simple` 1 | census |
| EMF+ Dual header flag | 27 of 27 set; no EMF+ Only fixture | census (first `EmfPlusHeader`) |
| Fixtures with an EMF+ record spanning two `EMR_COMMENT`s | 0 | census |
| Fixtures with continued `EmfPlusObject` chains | 2 (`emf/test-109.emf`, `emf/test-155.emf`) | census |
| Fixtures with `Size`/`DataSize` inconsistencies | 2, both in `emf-corrupted` | census |
| Record types seen in no fixture (non-reserved) | 11 of 55: Clear, SetCompositingMode, Save, Restore, BeginContainer, BeginContainerNoParams, EndContainer, ScaleWorldTransform, StrokeFillPath, SetTSGraphics, SetTSClip | census |
| Graphics object types seen in no fixture | 1 of 9: CustomLineCap | census |
| Record types registered in `Records.registry` | 54 of 54 defined (58 enumerators minus 3 reserved minus `StrokeFillPath`) | `lib/emf/emf_plus/records.rb:81-93` |
| Record types decoded as `Records::Unknown` | 4: reserved 0x4005 to 0x4007 and `StrokeFillPath` 0x4037 | `records.rb:97` (`registry.fetch(frame.type, Unknown)`) |
| Graphics objects typed | 9 of 9 | `lib/emf/emf_plus/objects.rb:21-34` |
| Image effects typed | 11 of 11 (unknown GUID or short block falls back to `Effects::Opaque`) | `lib/emf/emf_plus/effects.rb:29-41` |
| Structure objects decoded | 47 of 47: 26 under `Records::Primitives`, 12 as named classes in `objects/*.rb`, 9 inside parent readers with no class of their own | structure table below |
| Typed records with a field still kept raw or uninterpreted | 3: `SetTSGraphics` palette, `SetTSClip` compressed rects, `DrawDriverString` `CmapLookup` glyph meaning | rows below |

How the 58 was counted: a script matched the `EmfPlus<Name> = 0x40..` enumerator lines inside the `RecordType` typedef (58 matches, values contiguous from 0x4001 to 0x403A). The 54 came from counting `#### EmfPlus<Name> Record` headings under `## EMF+ Records` (clipping 5, comment 1, control 3, drawing 21, object 2, property 8, state 5, terminal server 2, transform 7). 58 = 54 + 3 reserved + `StrokeFillPath`. Objects were counted from `#### ... Object` headings under `## EMF+ Objects` (graphics 9, structure 47, image effects 11).

## Framing (verified against ch02 and the corpus)

- Every EMF+ record is little-endian: `u16 Type`, `u16 Flags`, `u32 Size`, `u32 DataSize`, then `DataSize` bytes (ch02 2.3 category headers; ch01 1.3.2). `Size` includes the 12-byte header, so `Size = DataSize + 12`; both are 32-bit aligned (padding fields such as `AlignmentPadding` in `EmfPlusPath` and `EmfPlusDrawString` carry the remainder; value ignored on read, must be preserved for byte-identical output).
- EMF+ records live inside `EMR_COMMENT_EMFPLUS`: an EMF `EMR_COMMENT` (type 0x46) whose data starts with `u32 0x2B464D45` ("EMF+"), followed by one or more EMF+ records (ch01 1.3.1; ch03 EMR_COMMENT_EMFPLUS Example 2). Several EMF+ records may share one comment.
- `EmfPlusHeader` must be the first record of the first comment after `EMR_HEADER`; `EmfPlusEndOfFile` is in the last comment before `EMR_EOF` (ch01 1.3.1).
- Corpus check: across the 23 valid EMF+ fixtures there are zero records where `DataSize != Size - 12`, `Size` is not a multiple of 4, or `Size` exceeds the stream; no trailing bytes. The 4 corrupt EMF+ fixtures show: a `DataSize` of 4009754664 on a `Size` 52 EmfPlusObject (`bad_corrupted_2014-12-07-163010.emf`, 2033 comments like `emf/test-038.emf`), and in `bad_corrupted_2017-02-12-010400.emf` a `Size` 0 record and a 0x8888 record plus 10304 unframed trailing bytes in the EMF+ stream.
- Current Ruby: `Emr::Parser` drops the 4-byte identifier and concatenates all EMF+ comments into `Metafile#emf_plus` (`nil` when none, format `:emf_plus`). The comments themselves stay in `Metafile#records` as `WireAdapter` over `Binary::Records::Comment`, and `Emr::Serializer` writes only header + `records` + `trailing`.

## Record inventory

Counted from `RecordType` (ch02 section 2.1.1.1): **58 enumerators** (0x4001 to 0x403A, contiguous). Of those, 54 have a dedicated record section in 2.3.x (counted from `#### EmfPlus* Record` headings), 3 are reserved (`MUST NOT be used`), and 1 has an enumerator but no record section (`EmfPlusStrokeFillPath`). Section 2.3 names the text record `EmfPlusDrawDriverString`; the enumerator is spelled `EmfPlusDrawDriverstring`.

Columns: Variable data = the record has a variable-length field beyond the 12-byte header (yes/no, from the `(variable)` fields in its section). Ruby status: `typed, byte-identical round-trip` means a class in `Emf::EmfPlus::Records` decodes every spec field and re-encodes the original bytes (synthetic specs plus every corpus record of that type); `kept raw as Records::Unknown` rows have no class of their own and round-trip as raw frames. `Records::Object` keeps the object bytes; `Objects.decode` types them from an `ObjectChain` logical object (see Object inventory). `Metafile#emf_plus` is unchanged. Fixtures = number of the 27 EMF+-bearing corpus fixtures containing the type, from the census run above. Class = class under `Emf::EmfPlus::Records` (file `lib/emf/emf_plus/records/<snake_case>.rb`).

### Control (6)

| Type | Value | Spec | Flags (bit masks over the u16 Flags) | Variable data | Ruby status | Fixtures | Class |
| --- | --- | --- | --- | --- | --- | --- | --- |
| EmfPlusHeader | 0x4001 | 2.3.3.3 | Flags D=0x0001 (EMF+ Dual); EmfPlusFlags V=0x00000001 (video reference DC) | no | typed, byte-identical round-trip | 27 | `Records::Header` |
| EmfPlusEndOfFile | 0x4002 | 2.3.3.1 | unused | no | typed, byte-identical round-trip | 24 | `Records::EndOfFile` |
| EmfPlusGetDC | 0x4004 | 2.3.3.2 | unused | no | typed, byte-identical round-trip | 27 | `Records::GetDC` |
| EmfPlusMultiFormatStart (reserved, MUST NOT be used; keep as raw) | 0x4005 | 2.1.1.1 (enum only) | reserved | n/a | kept raw as `Records::Unknown` (`records.rb:97`); no conformance report | 0 | none |
| EmfPlusMultiFormatSection (reserved, MUST NOT be used; keep as raw) | 0x4006 | 2.1.1.1 (enum only) | reserved | n/a | kept raw as `Records::Unknown` (`records.rb:97`); no conformance report | 0 | none |
| EmfPlusMultiFormatEnd (reserved, MUST NOT be used; keep as raw) | 0x4007 | 2.1.1.1 (enum only) | reserved | n/a | kept raw as `Records::Unknown` (`records.rb:97`); no conformance report | 0 | none |

### Comment (1)

| Type | Value | Spec | Flags (bit masks over the u16 Flags) | Variable data | Ruby status | Fixtures | Class |
| --- | --- | --- | --- | --- | --- | --- | --- |
| EmfPlusComment | 0x4003 | 2.3.2.1 | unused (Windows writes 0-3) | yes | typed, byte-identical round-trip | 3 | `Records::Comment` |

### Object (1)

| Type | Value | Spec | Flags (bit masks over the u16 Flags) | Variable data | Ruby status | Fixtures | Class |
| --- | --- | --- | --- | --- | --- | --- | --- |
| EmfPlusObject | 0x4008 | 2.3.5.1 | C=0x8000 (continued), ObjectType=0x7F00, ObjectID=0x00FF | yes | typed, byte-identical round-trip | 22 | `Records::Object` |

### Drawing (11)

| Type | Value | Spec | Flags (bit masks over the u16 Flags) | Variable data | Ruby status | Fixtures | Class |
| --- | --- | --- | --- | --- | --- | --- | --- |
| EmfPlusClear | 0x4009 | 2.3.4.1 | unused | no | typed, byte-identical round-trip | 0 | `Records::Clear` |
| EmfPlusDrawRects | 0x400B | 2.3.4.13 | C=0x4000, ObjectID=0x00FF (pen) | yes | typed, byte-identical round-trip | 4 | `Records::DrawRects` |
| EmfPlusDrawLines | 0x400D | 2.3.4.10 | C=0x4000, L=0x2000 (close shape), P=0x0800, ObjectID=0x00FF (pen) | yes | typed, byte-identical round-trip | 2 | `Records::DrawLines` |
| EmfPlusDrawEllipse | 0x400F | 2.3.4.7 | C=0x4000, ObjectID=0x00FF (pen) | yes | typed, byte-identical round-trip | 2 | `Records::DrawEllipse` |
| EmfPlusDrawPie | 0x4011 | 2.3.4.12 | C=0x4000, ObjectID=0x00FF (pen) | yes | typed, byte-identical round-trip | 2 | `Records::DrawPie` |
| EmfPlusDrawArc | 0x4012 | 2.3.4.2 | C=0x4000, ObjectID=0x00FF (pen) | yes | typed, byte-identical round-trip | 2 | `Records::DrawArc` |
| EmfPlusDrawPath | 0x4015 | 2.3.4.11 | ObjectID=0x00FF (path) | no | typed, byte-identical round-trip | 15 | `Records::DrawPath` |
| EmfPlusDrawClosedCurve | 0x4017 | 2.3.4.4 | C=0x4000, P=0x0800, ObjectID=0x00FF (pen) | yes | typed, byte-identical round-trip | 2 | `Records::DrawClosedCurve` |
| EmfPlusDrawCurve | 0x4018 | 2.3.4.5 | C=0x4000, ObjectID=0x00FF (pen) | yes | typed, byte-identical round-trip | 2 | `Records::DrawCurve` |
| EmfPlusDrawBeziers | 0x4019 | 2.3.4.3 | C=0x4000, P=0x0800, ObjectID=0x00FF (pen) | yes | typed, byte-identical round-trip | 2 | `Records::DrawBeziers` |
| EmfPlusStrokeFillPath (enum only; payload undefined in ch02; keep as raw) | 0x4037 | 2.1.1.1 (enum only) | see section | n/a | kept raw as `Records::Unknown` (`records.rb:97`) | 0 | none |

### Fill (7)

| Type | Value | Spec | Flags (bit masks over the u16 Flags) | Variable data | Ruby status | Fixtures | Class |
| --- | --- | --- | --- | --- | --- | --- | --- |
| EmfPlusFillRects | 0x400A | 2.3.4.20 | S=0x8000, C=0x4000 | yes | typed, byte-identical round-trip | 19 | `Records::FillRects` |
| EmfPlusFillPolygon | 0x400C | 2.3.4.19 | S=0x8000, C=0x4000, P=0x0800 | yes | typed, byte-identical round-trip | 2 | `Records::FillPolygon` |
| EmfPlusFillEllipse | 0x400E | 2.3.4.16 | S=0x8000, C=0x4000 | yes | typed, byte-identical round-trip | 2 | `Records::FillEllipse` |
| EmfPlusFillPie | 0x4010 | 2.3.4.18 | S=0x8000, C=0x4000 | yes | typed, byte-identical round-trip | 2 | `Records::FillPie` |
| EmfPlusFillRegion | 0x4013 | 2.3.4.21 | S=0x8000, ObjectID=0x00FF (region) | no | typed, byte-identical round-trip | 2 | `Records::FillRegion` |
| EmfPlusFillPath | 0x4014 | 2.3.4.17 | S=0x8000, ObjectID=0x00FF (path) | no | typed, byte-identical round-trip | 10 | `Records::FillPath` |
| EmfPlusFillClosedCurve | 0x4016 | 2.3.4.15 | S=0x8000, C=0x4000, W=0x2000 (winding), P=0x0800 | yes | typed, byte-identical round-trip | 2 | `Records::FillClosedCurve` |

### Text (2)

| Type | Value | Spec | Flags (bit masks over the u16 Flags) | Variable data | Ruby status | Fixtures | Class |
| --- | --- | --- | --- | --- | --- | --- | --- |
| EmfPlusDrawString | 0x401C | 2.3.4.14 | S=0x8000 (BrushId is ARGB), ObjectID=0x00FF (font) | yes | typed, byte-identical round-trip | 3 | `Records::DrawString` |
| EmfPlusDrawDriverString | 0x4036 | 2.3.4.6 | S=0x8000 (BrushId is ARGB), ObjectID=0x00FF (font) | yes | typed, byte-identical round-trip; option predicates (`cmap_lookup?`, `vertical?`, `realized_advance?`, `limit_subpixel?`) and `#text` (UTF-16 code units under `CmapLookup`, per GDI+/Wine behaviour; nil for glyph indices) | 1 | `Records::DrawDriverString` |

### Image (3)

| Type | Value | Spec | Flags (bit masks over the u16 Flags) | Variable data | Ruby status | Fixtures | Class |
| --- | --- | --- | --- | --- | --- | --- | --- |
| EmfPlusDrawImage | 0x401A | 2.3.4.8 | C=0x4000, ObjectID=0x00FF (image) | yes | typed, byte-identical round-trip | 2 | `Records::DrawImage` |
| EmfPlusDrawImagePoints | 0x401B | 2.3.4.9 | C=0x4000, E=0x2000 (effect), P=0x0800, ObjectID=0x00FF (image) | yes | typed, byte-identical round-trip | 11 | `Records::DrawImagePoints` |
| EmfPlusSerializableObject | 0x4038 | 2.3.5.2 | unused | yes | typed, byte-identical round-trip | 2 | `Records::SerializableObject` |

### State (14)

| Type | Value | Spec | Flags (bit masks over the u16 Flags) | Variable data | Ruby status | Fixtures | Class |
| --- | --- | --- | --- | --- | --- | --- | --- |
| EmfPlusSetRenderingOrigin | 0x401D | 2.3.6.6 | unused | no | typed, byte-identical round-trip | 2 | `Records::SetRenderingOrigin` |
| EmfPlusSetAntiAliasMode | 0x401E | 2.3.6.1 | SmoothingMode=0x00FE, A=0x0001 | no | typed, byte-identical round-trip | 27 | `Records::SetAntiAliasMode` |
| EmfPlusSetTextRenderingHint | 0x401F | 2.3.6.8 | TextRenderingHint=0x00FF | no | typed, byte-identical round-trip | 15 | `Records::SetTextRenderingHint` |
| EmfPlusSetTextContrast | 0x4020 | 2.3.6.7 | TextContrast=0x0FFF (gamma x 1000) | no | typed, byte-identical round-trip | 3 | `Records::SetTextContrast` |
| EmfPlusSetInterpolationMode | 0x4021 | 2.3.6.4 | InterpolationMode=0x00FF | no | typed, byte-identical round-trip | 23 | `Records::SetInterpolationMode` |
| EmfPlusSetPixelOffsetMode | 0x4022 | 2.3.6.5 | PixelOffsetMode=0x00FF | no | typed, byte-identical round-trip | 23 | `Records::SetPixelOffsetMode` |
| EmfPlusSetCompositingMode | 0x4023 | 2.3.6.2 | CompositingMode=0x00FF | no | typed, byte-identical round-trip | 0 | `Records::SetCompositingMode` |
| EmfPlusSetCompositingQuality | 0x4024 | 2.3.6.3 | CompositingQuality=0x00FF | no | typed, byte-identical round-trip | 19 | `Records::SetCompositingQuality` |
| EmfPlusSave | 0x4025 | 2.3.7.5 | unused | no | typed, byte-identical round-trip | 0 | `Records::Save` |
| EmfPlusRestore | 0x4026 | 2.3.7.4 | unused | no | typed, byte-identical round-trip | 0 | `Records::Restore` |
| EmfPlusBeginContainer | 0x4027 | 2.3.7.1 | PageUnit=0x00FF (UnitType) | no | typed, byte-identical round-trip | 0 | `Records::BeginContainer` |
| EmfPlusBeginContainerNoParams | 0x4028 | 2.3.7.2 | unused | no | typed, byte-identical round-trip | 0 | `Records::BeginContainerNoParams` |
| EmfPlusEndContainer | 0x4029 | 2.3.7.3 | unused | no | typed, byte-identical round-trip | 0 | `Records::EndContainer` |
| EmfPlusSetTSGraphics | 0x4039 | 2.3.8.2 | V=0x0002 (VGA palette), T=0x0001 (Palette present) | yes | typed, byte-identical round-trip; `#palette` decodes `Records::Primitives::Palette` when `T` is set, raw bytes kept in `palette_bytes` (short or over-long palettes stay raw) | 0 | `Records::SetTSGraphics` |

### Clipping (6)

| Type | Value | Spec | Flags (bit masks over the u16 Flags) | Variable data | Ruby status | Fixtures | Class |
| --- | --- | --- | --- | --- | --- | --- | --- |
| EmfPlusResetClip | 0x4031 | 2.3.1.2 | reserved | no | typed, byte-identical round-trip | 2 | `Records::ResetClip` |
| EmfPlusSetClipRect | 0x4032 | 2.3.1.4 | CM=0x0F00 (CombineMode) | no | typed, byte-identical round-trip | 8 | `Records::SetClipRect` |
| EmfPlusSetClipPath | 0x4033 | 2.3.1.3 | CM=0x0F00, ObjectID=0x00FF (path) | no | typed, byte-identical round-trip | 7 | `Records::SetClipPath` |
| EmfPlusSetClipRegion | 0x4034 | 2.3.1.5 | CM=0x0F00, ObjectID=0x00FF (region) | no | typed, byte-identical round-trip | 11 | `Records::SetClipRegion` |
| EmfPlusOffsetClip | 0x4035 | 2.3.1.1 | reserved | no | typed, byte-identical round-trip | 2 | `Records::OffsetClip` |
| EmfPlusSetTSClip | 0x403A | 2.3.8.1 | C=0x8000 (4-byte rects), NumRects=0x7FFF | yes | typed, byte-identical round-trip; uncompressed rects decoded by `#rects`, compressed rects stay raw in `rect_data` because 2.3.8.1 leaves their layout undefined (`records/set_ts_clip.rb:19`, `:30`) | 0 | `Records::SetTSClip` |

### Transform (7)

| Type | Value | Spec | Flags (bit masks over the u16 Flags) | Variable data | Ruby status | Fixtures | Class |
| --- | --- | --- | --- | --- | --- | --- | --- |
| EmfPlusSetWorldTransform | 0x402A | 2.3.9.6 | unused | no | typed, byte-identical round-trip | 27 | `Records::SetWorldTransform` |
| EmfPlusResetWorldTransform | 0x402B | 2.3.9.2 | unused | no | typed, byte-identical round-trip | 14 | `Records::ResetWorldTransform` |
| EmfPlusMultiplyWorldTransform | 0x402C | 2.3.9.1 | A=0x2000 (post-multiply) | no | typed, byte-identical round-trip | 7 | `Records::MultiplyWorldTransform` |
| EmfPlusTranslateWorldTransform | 0x402D | 2.3.9.7 | A=0x2000 | no | typed, byte-identical round-trip | 2 | `Records::TranslateWorldTransform` |
| EmfPlusScaleWorldTransform | 0x402E | 2.3.9.4 | A=0x2000 | no | typed, byte-identical round-trip | 0 | `Records::ScaleWorldTransform` |
| EmfPlusRotateWorldTransform | 0x402F | 2.3.9.3 | A=0x2000 | no | typed, byte-identical round-trip | 2 | `Records::RotateWorldTransform` |
| EmfPlusSetPageTransform | 0x4030 | 2.3.9.5 | PageUnit=0x00FF (UnitType) | no | typed, byte-identical round-trip | 25 | `Records::SetPageTransform` |

## Object inventory

Variable data is derived from `(variable)` / array / optional fields in each object section and is a heuristic, not a spec statement. Counted from `#### EmfPlus*/*Effect Object` headings in ch02 section 2.2: **67 objects** = 9 graphics objects (2.2.1) + 47 structure objects (2.2.2) + 11 image effects (2.2.3). Only the 9 graphics objects have a type value (`ObjectType` enum, 2.1.1.21, plus `ObjectTypeInvalid` = 0); structure objects are nested inside them and have no type value; the 11 effects are identified by GUID (2.1.3.1) and carried by `EmfPlusSerializableObject`. Fixture counts are measured only for the 9 graphics objects (via the `EmfPlusObject` Flags); nested structure objects and effects are not visible to a framing census and are marked `not measured`.

### Graphics object (ObjectType) (9)

| Object | ObjectType | Spec | Variable data | Optional/conditional fields | Ruby status | Fixtures | Class |
| --- | --- | --- | --- | --- | --- | --- | --- |
| EmfPlusBrush | 1 | 2.2.1.1 | yes | Type (BrushType) selects BrushData: solid, hatch, texture, path gradient, linear gradient | typed, byte-identical round-trip | 5 | `Objects::Brush` |
| EmfPlusCustomLineCap | 9 | 2.2.1.2 | yes | Type (CustomLineCapDataType) selects default vs arrow data | typed, byte-identical round-trip | 0 | `Objects::CustomLineCap` |
| EmfPlusFont | 6 | 2.2.1.3 | yes | - | typed, byte-identical round-trip | 4 | `Objects::Font` |
| EmfPlusImage | 5 | 2.2.1.4 | yes | Type (ImageDataType) selects EmfPlusBitmap vs EmfPlusMetafile | typed, byte-identical round-trip | 11 | `Objects::Image` |
| EmfPlusImageAttributes | 8 | 2.2.1.5 | no | - | typed, byte-identical round-trip | 11 | `Objects::ImageAttributes` |
| EmfPlusPath | 3 | 2.2.1.6 | yes | PathPointFlags R: relative points + RLE point types; else C: int16 vs float points | typed, byte-identical round-trip | 19 | `Objects::Path` |
| EmfPlusPen | 2 | 2.2.1.7 | yes | PenData then brush object; optional data selected by PenDataFlags | typed, byte-identical round-trip | 15 | `Objects::Pen` |
| EmfPlusRegion | 4 | 2.2.1.8 | yes | RegionNodeCount + 1 nodes in a binary tree | typed, byte-identical round-trip | 11 | `Objects::Region` |
| EmfPlusStringFormat | 7 | 2.2.1.9 | yes | StringFormatData holds TabStopCount floats then RangeCount ranges | typed, byte-identical round-trip | 3 | `Objects::StringFormat` |

### Structure object (47)

Class column = where the structure is decoded today: `Records::Primitives::*` (files under `lib/emf/emf_plus/records/primitives/`), a named class inside `lib/emf/emf_plus/objects/*.rb`, or "inline" for a structure read by a parent object's reader with no class of its own. The earlier `Structures::*` names were a proposal; no such module exists.

| Object | Spec | Variable data | Presence conditions | Ruby status | Fixtures | Class |
| --- | --- | --- | --- | --- | --- | --- |
| EmfPlusARGB | 2.2.2.1 | no | - | typed, byte-identical round-trip | not measured | `Records::Primitives::ARGB` (`primitives/argb.rb:10`) |
| EmfPlusBitmap | 2.2.2.2 | yes | Type: raw pixel data (BitmapData) vs EmfPlusCompressedImage | typed, byte-identical round-trip | not measured | `Records::Primitives::Bitmap` (`primitives/bitmap.rb:13`) |
| EmfPlusBitmapData | 2.2.2.3 | yes | Colors (palette) MUST be present when PixelFormat I flag is set | typed, byte-identical round-trip | not measured | `Records::Primitives::BitmapData` (`primitives/bitmap_data.rb:12`) |
| EmfPlusBlendColors | 2.2.2.4 | yes | - | typed, byte-identical round-trip | not measured | `Records::Primitives::BlendColors` (`primitives/blend_colors.rb:11`) |
| EmfPlusBlendFactors | 2.2.2.5 | yes | - | typed, byte-identical round-trip | not measured | `Records::Primitives::BlendFactors` (`primitives/blend_factors.rb:10`) |
| EmfPlusBoundaryPathData | 2.2.2.6 | yes | - | typed, byte-identical round-trip (nested EmfPlusPath decoded as Objects::Path; raw bytes if it does not parse; corpus: 37 of 37 path boundaries decode) | not measured | `Objects::Brush::BoundaryPathData` (`objects/brush.rb:95`) |
| EmfPlusBoundaryPointData | 2.2.2.7 | yes | - | typed, byte-identical round-trip | not measured | `Objects::Brush::BoundaryPointData` (`objects/brush.rb:102`) |
| EmfPlusCharacterRange | 2.2.2.8 | no | - | typed, byte-identical round-trip | not measured | `Records::Primitives::CharacterRange` |
| EmfPlusCompoundLineData | 2.2.2.9 | yes | - | typed, byte-identical round-trip | not measured | `Objects::Pen::CompoundLineData` (`objects/pen.rb:48`) |
| EmfPlusCompressedImage | 2.2.2.10 | yes | - | typed, byte-identical round-trip | not measured | `Records::Primitives::CompressedImage` (`primitives/compressed_image.rb:10`) |
| EmfPlusCustomEndCapData | 2.2.2.11 | yes | - | typed, byte-identical round-trip | not measured | inline: `Objects::Pen#custom_end_cap` (`objects/pen.rb:115`) |
| EmfPlusCustomLineCapArrowData | 2.2.2.12 | no | - | typed, byte-identical round-trip | not measured | `Objects::CustomLineCap::CustomLineCapArrowData` (`objects/custom_line_cap.rb:41`) |
| EmfPlusCustomLineCapData | 2.2.2.13 | yes | OptionalData selected by CustomLineCapDataFlags | typed, byte-identical round-trip | not measured | `Objects::CustomLineCap::CustomLineCapDefaultData` (`objects/custom_line_cap.rb:26`) |
| EmfPlusCustomLineCapOptionalData | 2.2.2.14 | yes | FillData if FillPath flag; OutlineData if LinePath flag | typed, byte-identical round-trip | not measured | inline: `Objects::CustomLineCap#fill_path`, `#line_path` (`objects/custom_line_cap.rb:91-92`) |
| EmfPlusCustomStartCapData | 2.2.2.15 | yes | - | typed, byte-identical round-trip | not measured | inline: `Objects::Pen#custom_start_cap` (`objects/pen.rb:114`) |
| EmfPlusDashedLineData | 2.2.2.16 | yes | - | typed, byte-identical round-trip | not measured | `Objects::Pen::DashedLineData` (`objects/pen.rb:41`) |
| EmfPlusFillPath | 2.2.2.17 | yes | - | typed, byte-identical round-trip | not measured | inline: `Objects::CustomLineCap#fill_path` (`objects/custom_line_cap.rb:91`) |
| EmfPlusFocusScaleData | 2.2.2.18 | no | - | typed, byte-identical round-trip | not measured | `Records::Primitives::FocusScaleData` (`primitives/focus_scale_data.rb:10`) |
| EmfPlusGraphicsVersion | 2.2.2.19 | no | - | typed, byte-identical round-trip | not measured | `Records::Primitives::GraphicsVersion` |
| EmfPlusHatchBrushData | 2.2.2.20 | no | - | typed, byte-identical round-trip | not measured | `Objects::Brush::HatchBrushData` (`objects/brush.rb:53`) |
| EmfPlusInteger7 | 2.2.2.21 | no | - | typed, byte-identical round-trip | not measured | `Records::Primitives::RelativeCoordinate` (`primitives/relative_coordinate.rb:12`) |
| EmfPlusInteger15 | 2.2.2.22 | no | - | typed, byte-identical round-trip | not measured | `Records::Primitives::RelativeCoordinate` (`primitives/relative_coordinate.rb:12`) |
| EmfPlusLanguageIdentifier | 2.2.2.23 | no | - | typed, byte-identical round-trip | not measured | `Records::Primitives::LanguageIdentifier` |
| EmfPlusLinearGradientBrushData | 2.2.2.24 | yes | OptionalData selected by BrushDataFlags | typed, byte-identical round-trip | not measured | `Objects::Brush::LinearGradientBrushData` (`objects/brush.rb:68`) |
| EmfPlusLinearGradientBrushOptionalData | 2.2.2.25 | yes | Transform if BrushDataTransform; blend colors (PresetColors) xor blend factors (H and/or V) | typed, byte-identical round-trip | not measured | inline: `Objects::Brush::Reader#read_linear_gradient` (`objects/brush.rb:205`) |
| EmfPlusLinePath | 2.2.2.26 | yes | - | typed, byte-identical round-trip | not measured | inline: `Objects::CustomLineCap#line_path` (`objects/custom_line_cap.rb:92`) |
| EmfPlusMetafile | 2.2.2.27 | yes | Type (MetafileDataType) selects EMF/WMF/EMF+ payload; MetafileDataSize | typed, byte-identical round-trip | not measured | `Records::Primitives::Metafile` (`primitives/metafile.rb:10`) |
| EmfPlusPalette | 2.2.2.28 | yes | - | typed, byte-identical round-trip | not measured | `Records::Primitives::Palette` (`primitives/palette.rb:11`) |
| EmfPlusPathGradientBrushData | 2.2.2.29 | yes | BoundaryData is path if BrushDataPath else point list; OptionalData by BrushDataFlags | typed, byte-identical round-trip | not measured | `Objects::Brush::PathGradientBrushData` (`objects/brush.rb:80`) |
| EmfPlusPathGradientBrushOptionalData | 2.2.2.30 | yes | Transform; blend colors xor blend factors H; FocusScaleData if BrushDataFocusScales | typed, byte-identical round-trip | not measured | inline: `Objects::Brush::Reader#read_path_gradient_optional` (`objects/brush.rb:229`) |
| EmfPlusPathPointType | 2.2.2.31 | no | - | typed, byte-identical round-trip | not measured | `Records::Primitives::PathPointType` |
| EmfPlusPathPointTypeRLE | 2.2.2.32 | no | used instead of EmfPlusPathPointType when Path R flag set | typed, byte-identical round-trip | not measured | `Records::Primitives::PathPointTypeRLE` |
| EmfPlusPenData | 2.2.2.33 | yes | OptionalData selected by PenDataFlags | typed, byte-identical round-trip | not measured | `Objects::Pen::PenHeader` (`objects/pen.rb:31`) |
| EmfPlusPenOptionalData | 2.2.2.34 | yes | each field present iff its PenData flag is set (Transform, StartCap, EndCap, Join, MiterLimit, LineStyle, DashedLineCap, DashOffset, DashedLine, NonCenter, CompoundLine, CustomStartCap, CustomEndCap) | typed, byte-identical round-trip | not measured | inline: `Objects::Pen::Reader#read_optional` (`objects/pen.rb:82`) |
| EmfPlusPoint | 2.2.2.35 | no | - | typed, byte-identical round-trip | not measured | `Records::Primitives::Point` (`primitives/point.rb:10`) |
| EmfPlusPointF | 2.2.2.36 | no | - | typed, byte-identical round-trip | not measured | `Records::Primitives::PointF` (`primitives/point_f.rb:10`) |
| EmfPlusPointR | 2.2.2.37 | yes | used instead of Point/PointF when R/P flag set (relative coordinates, Integer7/Integer15 encoding) | typed, byte-identical round-trip | not measured | `Records::Primitives::PointR` (`primitives/point_r.rb:11`) |
| EmfPlusRect | 2.2.2.38 | no | - | typed, byte-identical round-trip | not measured | `Records::Primitives::Rect` (`primitives/rect.rb:10`) |
| EmfPlusRectF | 2.2.2.39 | no | - | typed, byte-identical round-trip | not measured | `Records::Primitives::RectF` (`primitives/rect_f.rb:10`) |
| EmfPlusRegionNode | 2.2.2.40 | yes | RegionNodeData absent for Empty/Infinite; children for combine types; path for Path type | typed, byte-identical round-trip | not measured | `Records::Primitives::RegionNode` |
| EmfPlusRegionNodeChildNodes | 2.2.2.41 | yes | - | typed, byte-identical round-trip | not measured | `Records::Primitives::RegionNodeChildNodes` |
| EmfPlusRegionNodePath | 2.2.2.42 | yes | - | typed, byte-identical round-trip | not measured | `Records::Primitives::RegionNodePath` |
| EmfPlusSolidBrushData | 2.2.2.43 | no | - | typed, byte-identical round-trip | not measured | `Objects::Brush::SolidBrushData` (`objects/brush.rb:47`) |
| EmfPlusStringFormatData | 2.2.2.44 | yes | both arrays optional; sizes from TabStopCount/RangeCount in the parent | typed, byte-identical round-trip | not measured | `Records::Primitives::StringFormatData` |
| EmfPlusTextureBrushData | 2.2.2.45 | yes | OptionalData selected by BrushDataFlags | typed, byte-identical round-trip | not measured | `Objects::Brush::TextureBrushData` (`objects/brush.rb:61`) |
| EmfPlusTextureBrushOptionalData | 2.2.2.46 | yes | Transform if BrushDataTransform; ImageObject present iff the record is large enough to hold it | typed, byte-identical round-trip (nested EmfPlusImage decoded as Objects::Image; raw bytes if it does not parse; corpus: 1 texture brush, decoded) | not measured | inline: `Objects::Brush::Reader#read_texture` (`objects/brush.rb:191`) |
| EmfPlusTransformMatrix | 2.2.2.47 | no | - | typed, byte-identical round-trip | not measured | `Records::Primitives::TransformMatrix` (`primitives/transform_matrix.rb:10`) |

### Image effect parameter block (11)

| Object | GUID | Spec | Ruby status | Fixtures | Class |
| --- | --- | --- | --- | --- | --- |
| BlurEffect | {633C80A4-1843-482B-9EF2-BE2834C5FDD4} | 2.2.3.1 | typed, byte-identical round-trip | not measured | `Effects::Blur` |
| BrightnessContrastEffect | {D3A1DBE1-8EC4-4C17-9F4C-EA97AD1C343D} | 2.2.3.2 | typed, byte-identical round-trip | not measured | `Effects::BrightnessContrast` |
| ColorBalanceEffect | {537E597D-251E-48DA-9664-29CA496B70F8} | 2.2.3.3 | typed, byte-identical round-trip | not measured | `Effects::ColorBalance` |
| ColorCurveEffect | {DD6A0022-58E4-4A67-9D9B-D48EB881A53D} | 2.2.3.4 | typed, byte-identical round-trip | not measured | `Effects::ColorCurve` |
| ColorLookupTableEffect | {A7CE72A9-0F7F-40D7-B3CC-D0C02D5C3212} | 2.2.3.5 | typed, byte-identical round-trip | not measured | `Effects::ColorLookupTable` |
| ColorMatrixEffect | {718F2615-7933-40E3-A511-5F68FE14DD74} | 2.2.3.6 | typed, byte-identical round-trip | not measured | `Effects::ColorMatrix` |
| HueSaturationLightnessEffect | {8B2DD6C3-EB07-4D87-A5F0-7108E26A9C5F} | 2.2.3.7 | typed, byte-identical round-trip | not measured | `Effects::HueSaturationLightness` |
| LevelsEffect | {99C354EC-2A31-4F3A-8C34-17A803B33A25} | 2.2.3.8 | typed, byte-identical round-trip | not measured | `Effects::Levels` |
| RedEyeCorrectionEffect | {74D29D05-69A4-4266-9549-3CC52836B632} | 2.2.3.9 | typed, byte-identical round-trip | not measured | `Effects::RedEyeCorrection` |
| SharpenEffect | {63CBF3EE-C526-402C-8F71-62C540BF5142} | 2.2.3.10 | typed, byte-identical round-trip | not measured | `Effects::Sharpen` |
| TintEffect | {1077AF00-2848-4441-9489-44AD4C2D7A2C} | 2.2.3.11 | typed, byte-identical round-trip | not measured | `Effects::Tint` |

## Conditional and version rules

Each rule needs a stated outcome before step 8 can close. "Outcome" is the intended Ruby behavior; "Tested outcome" is the spec that proves it today, or the gap or blocker (checked 2026-10-20 at 03f356a).

| Rule | Spec | Outcome | Tested outcome |
| --- | --- | --- | --- |
| `EmfPlusGraphicsVersion`: 20-bit signature 0xDBC01 + 12-bit version; 1 = GDI+ 1.0, 2 = GDI+ 1.1; "vendor-extensible" | 2.2.2.19, 2.1.1.12, ch05 note 12 | Decode both known values; keep unknown versions as an integer and do not reject. Wrong signature: report, keep raw. | Tested: `spec/emf/emf_plus/conditional_rules_spec.rb:15` (versions 0, 1, 2, 3, 0xFFF kept as integers behind a valid signature, none rejected), `spec/emf/emf_plus_records_spec.rb:38` (known value 2), `:43` (known value 1), `:51` (wrong signature reported by `valid_signature?`, kept raw). Object-level `GraphicsVersion` fields are read as an opaque dword and never validated. |
| Header `D` flag (EMF+ Dual) and `V` flag in `EmfPlusFlags`; EMF+ Only vs Dual playback differs by Windows version | 2.3.3.3, ch01 1.3.1, ch05 note 1 | Expose both flags. No semantic playback decision in the parser. Corpus has Dual only; EMF+ Only is a fixture gap. | Tested: `spec/emf/emf_plus_records_spec.rb:38` (D and V set), `:43` (both clear). No playback decision in the parser. Gap: no EMF+ Only fixture in the corpus (synthetic bytes only). |
| `EmfPlusGetDC` makes following EMF records drawable until the next EMF+ record | 2.3.3.2, ch01 1.3.1 | Record is order-significant; typed stream must keep its position relative to EMF records (see Representation gate). | Blocked: representation gate. `Records::GetDC` decodes (`spec/emf/emf_plus_records_spec.rb:74`) but nothing yet links it to the EMF records that follow. |
| Reserved records 0x4005 to 0x4007 | 2.1.1.1 | Preserve as unknown raw record; report as non-conformant. | Partly tested: kept as `Records::Unknown` and re-encoded (`spec/emf/emf_plus_records_spec.rb:22`). Gap: not reported as non-conformant (the registry has no entry for 0x4005 to 0x4007, so they take the `Unknown` fallback at `records.rb:97`); the parser has no conformance diagnostic list (its `errors:` array collects `ParseError` and stops framing, which would drop the rest of the stream). |
| `EmfPlusStrokeFillPath` 0x4037 has an enumerator but no record layout | 2.1.1.1, absent from 2.3 | Preserve as unknown raw record; layout is an open spec gap. | Tested: kept as `Records::Unknown` (`spec/emf/emf_plus/draw_fill_records_spec.rb:50`). Layout stays an open spec gap, as stated. |
| Unknown record type | 2.3 | Preserve bytes (`Size` governs skipping). | Tested: `spec/emf/emf_plus_spec.rb:14` (unknown type framed by `Size`, next offset correct), `spec/emf/emf_plus_records_spec.rb:14` (re-encoded identically). |
| Object IDs 0 to 63; a new object with an existing ID replaces it | 2.3.5.1, ch03 3.1.2 | Object table of 64 slots; out-of-range IDs are errors at the boundary. | Gap: no object table exists. `Records::Object#emf_object_id` is the raw 8-bit field (0 to 255), so IDs above 63 are accepted without error and a re-used ID does not replace anything. Needs the object table from the representation gate. |
| `C` (compressed int16 vs float), `P` (relative `EmfPlusPointR`), `S` (BrushId is ARGB vs object index), `L`, `W`, `E` flags change the layout and the expected `Size`/`DataSize` | 2.3.4.x | Per-record rules in the tables; Windows clears `C` when `P` is set (ch05 notes 20 to 25) but readers must handle both. | Tested: C `spec/emf/emf_plus/text_image_records_spec.rb:99` and `:149`; P `:170` and `:187`, `spec/emf/emf_plus/unproven_layouts_spec.rb:15`; S `text_image_records_spec.rb:47`; E `:161`; `SetTSClip` C `unproven_layouts_spec.rb:104` and `:113`. Readers handle P and C together (`text_image_records_spec.rb:170`, C ignored). |
| `DrawImagePoints` `E` flag: an `EmfPlusSerializableObject` effect precedes the draw | 2.3.4.9, 2.1.3.1 | Link effect to the following draw in the typed stream. | Partly tested: `DrawImagePoints#effect?` reports the flag (`spec/emf/emf_plus/text_image_records_spec.rb:161`). Blocked: representation gate for linking the effect to the following draw. |
| `DrawDriverString`: `MatrixPresent` gates `TransformMatrix`; `DriverStringOptionsCmapLookup` changes the meaning of `Glyphs` | 2.3.4.6, 2.1.2.3 | Conditional fields in the typed record. | Tested: `MatrixPresent` `spec/emf/emf_plus/text_image_records_spec.rb:69` and `:77`; odd glyph count `spec/emf/emf_plus/unproven_layouts_spec.rb:62`; `cmap_lookup?` is exposed (`text_image_records_spec.rb:74`, `:82`). Under `CmapLookup` `#text` decodes `Glyphs` as UTF-16 (incl. surrogate pairs); option predicates exposed (`text_image_records_spec.rb`, context "with DriverStringOptions"). |
| `SetTSGraphics` `T` gates `Palette`; `SetTSClip` `C` selects 4 vs 8 byte rects | 2.3.8 | Conditional fields. Windows never writes these records (ch05 notes 29, 30). | Tested: `SetTSGraphics` `T` `spec/emf/emf_plus/state_records_spec.rb:134` (absent) and `:143` (present); `SetTSClip` `C` `spec/emf/emf_plus/unproven_layouts_spec.rb:104` and `:113`, flip at `:121`. Palette typed (`state_records_spec.rb`, typed decode / short / trailing / edit examples); compressed rects stay raw because 2.3.8.1 leaves the layout undefined. |
| GDI+ 1.1 only: image effects, `SerializableObject`, `SetTSClip`, `SetTSGraphics` | 2.2.3, 2.3.5.2, 2.3.8, ch05 notes 17, 26, 31, 32 | Decode regardless of header version; do not reject on version. | Tested: `spec/emf/emf_plus/conditional_rules_spec.rb:27` (SerializableObject, SetTSClip and SetTSGraphics decode typed and re-encode after a GDI+ 1.0 header). Image effects decode from the record's own GUID, not the header (`spec/emf/emf_plus/objects_image_spec.rb:142`). |
| Brush, pen, custom line cap, path, bitmap, region, string format optional data selected by flags/counts | 2.1.2.x, 2.2.1.x, 2.2.2.x (see object tables) | Presence rule per object, tested positive and negative. | Tested per object, positive and negative: Pen `spec/emf/emf_plus/objects_pen_spec.rb:43` to `:185`; Brush `objects_brush_spec.rb:44` to `:253`; Path `objects_path_region_spec.rb:31` to `:113`; Region `:115` to `:218`; Image `objects_image_spec.rb:30` to `:140`; StringFormat `objects_spec.rb:62` to `:93`. Custom line cap and ImageAttributes optional data covered in `objects_pen_spec.rb` and `objects_spec.rb:95`. |
| `ColorCurveEffect` records written by Windows are corrupt | ch05 note 10 | Preserve bytes; typed decode must tolerate failure. | Tested: short block falls back to `Effects::Opaque` with the bytes kept (`spec/emf/emf_plus/objects_image_spec.rb:184`). Gap: only the short-block form is pinned; the actual Windows corruption is not characterised. |
| Texture brush `ImageObject` present iff the record is large enough | 2.2.2.46 | Size-dependent presence; needs a boundary fixture. | Tested: no remaining bytes means no image, remaining bytes mean an image (`Brush::Reader#read_texture`, `objects/brush.rb:191`, takes the rest after the optional transform): `spec/emf/emf_plus/objects_brush_spec.rb:61` to `:85`; nested bitmap and metafile image decode, edit and raw fallback `spec/emf/emf_plus/objects_brush_nested_spec.rb:61` to `:90` (PR #30, merged in d93bf89). Gap: the corpus has 1 texture brush; no fixture sits on the boundary. |

## Continuation (multi-record object) rule

- `EmfPlusObject` (2.3.5.1) Flags: `C` = 0x8000 (the definition continues in the next `EmfPlusObject`), `ObjectType` = 0x7F00, `ObjectID` = 0x00FF. The ch03 example 0x0300 decodes as type 3 (Path), id 0.
- When `C` is set the record carries a `TotalObjectSize` (the spec text calls the chain "EmfPlusContineudObjectRecord" and defines no such record). The object ends when `TotalObjectSize` bytes of `ObjectData` have been accumulated; the next EMF+ record is then not part of the object.
- Corpus evidence (`emf/test-109.emf`, `emf/test-155.emf`, image objects, Flags 0x8500): the layout is `Type, Flags, Size, DataSize, TotalObjectSize, ObjectData`, with `TotalObjectSize` counted inside `DataSize` and repeated in every chunk. For test-109: chunk 1 `Size` 65020 / `DataSize` 65008, chunk 2 `Size` 57120 / `DataSize` 57108, `TotalObjectSize` 122108 = 65004 + 57104. For test-155: three chunks of 65004 plus one of 45408 = 240420 = `TotalObjectSize`.
- Two places where ch02 and the corpus disagree, both to be settled with a second independent source before they are treated as normative: (1) the ch02 layout diagram puts `TotalObjectSize` before `DataSize`; the corpus puts it after. (2) ch02 says `C` is "never set in the final record"; in both corpus chains the final chunk also has `C` set. A decoder must therefore end a chain by `TotalObjectSize`, not by a clear `C`.
- Typed model implication: a reassembled object spans several records and possibly several comments. The typed object must keep each chunk's record boundary so that unchanged output is byte-identical.

## Representation gate — PROPOSAL, needs Hassan's decision on public API names

This section proposes; nothing here is decided or implemented. Constraint from package 09 step 5: `Metafile#emf_plus` (raw String) and the CLI/dump byte representation stay unchanged.

Measured starting point:

1. `Emr::Parser` already keeps every `EMR_COMMENT` as a `WireAdapter` in `Metafile#records`; each holds the full comment bytes (including the "EMF+" identifier and the comment boundary). `Emr::Serializer` serializes only `header`, `records` and `trailing`; it never reads `emf_plus`. So today comment segmentation and unchanged-output bytes are carried by `records`, and `emf_plus` is a derived, boundary-free, identifier-free concatenation used only for presence/size output (`exe/emf` prints its bytesize).
2. `Model::Visitor.visit_all` has a branch for `metafile.emf_plus.is_a?(Metafile)`; it is never true today and must not be made true without a decision, because that would change the return type.
3. The corpus has no EMF+ record spanning two comments (0 of 27), but the spec does not forbid it, so the model must not assume it.

Proposed shape (names illustrative only):

- **Alongside, not replacing.** Keep `Metafile#emf_plus` as is. Add an optional typed view built on demand from the comment records, for example a `Metafile#emf_plus_stream` accessor (or a module function `Emf::EmfPlus::Parser.call(metafile)`), returning an `Emf::EmfPlus::Stream`. The constructor, `format`, `errors` and dump output do not change.
- **Segmentation.** The stream is a list of segments, one per EMF+-bearing comment, each remembering its index in `Metafile#records` and the byte range of its EMF+ payload. Each typed record keeps `segment_index`, `offset` and its original bytes (including `AlignmentPadding` and unknown trailing bytes). A record that spans segments lists the segments it touches. Logical parsing runs over the concatenation, but boundaries are never discarded. EMF records between comments (for `EmfPlusGetDC`) stay in `records` and are referenced by index, not copied.
- **Which source wins.** The comment wires in `records` are the serialization source of truth until a typed edit is applied. A typed edit marks only the affected segments dirty and re-encodes just those; clean segments re-emit their original bytes. Typed objects that were not modified re-emit original bytes (byte-identical unedited round trip, per step 3 of package 09). `emf_plus` stays a read-only snapshot and is never an input to serialization.
- **Invalidation.** The stream captures a digest (or object identity) of the comment wires it was built from. If the raw comment records or `emf_plus` source were changed after the stream was built, the stream is stale and refuses to serialize or be edited (raises), instead of silently merging. If both the typed view and the raw wires were edited, that is a conflict error, not last-writer-wins. Rebuilding the view is the only recovery.
- **Native parity.** The Rust core (package 03/04) must return the same segment table across the C ABI so native and Ruby backends expose identical segmentation. Ruby fallback must not advertise EMF+ typing until it passes the same tests (package 09 step 7).
- **Open decisions for Hassan**: public accessor and class names; lazy vs eager build; raise vs overwrite on stale/conflict; whether the view lives on `Metafile` or only behind a function; how the ABI exposes segments.

Compatibility tests to write with the implementation (not written yet): `emf_plus` bytes identical to the pre-change parse for all 27 EMF+ fixtures; unedited `Emf.serialize` byte-identical for all 208 valid fixtures; `exe/emf` info output unchanged; format stays `:emf_plus`; stale-view and conflict cases raise; segmentation table equals the census `comment_bytes` for every fixture.

## Step 8 close criteria (not met)

The inventory may close only when each item below is done. Measured 2026-10-20 at 03f356a.

Already met in code (typed class, round-trip spec; corpus and census figures not re-run):

- All 54 defined record types are registered (`records.rb:81-93`); the 3 reserved types and `StrokeFillPath` are kept raw as `Records::Unknown`.
- All 9 graphics objects (`objects.rb:21-34`), all 47 structure objects and all 11 image effects are decoded.

Still open:

1. Representation gate decided and implemented (Representation gate section): `EmfPlusGetDC` ordering against the following EMF records, linking a `DrawImagePoints` `E`-flag effect to its draw, and the 64-slot object table (IDs above 63 are accepted today; a re-used ID replaces nothing).
2. A conformance-diagnostic channel, so reserved records 0x4005 to 0x4007 can be reported as non-conformant without dropping the rest of the stream.
3. `SetTSClip` compressed rects stay raw in `rect_data`: 2.3.8.1 describes a 1-or-2-byte delta scheme but does not name the four values per rectangle, the sign rule, the first rectangle's reference, or how the variable encoding fits its fixed `NumRects*4` size formula (`records/set_ts_clip.rb` comment). No reader (LibreOffice, Wine) implements it and the corpus has no `SetTSClip` record.
4. Fixtures: an EMF+ Only (`D` clear) file — the corpus has none (2026-10-20 scan: 229 files, 27 with EMF+, 32 headers, all Dual: 16 v2 with V clear, 14 v2 with V set, 2 v1 with V set; two real headers pinned in `spec/emf/emf_plus/header_fixture_spec.rb`); a record spanning two comments; and a licensed or generated example for each of the 11 record types and 1 graphics object (CustomLineCap) seen in no fixture.
5. `ColorCurveEffect` as Windows writes it: ch05 note 10 (`reference-docs/ms-emfplus/ch05-appendix-a-product-behavior.md:77`) only says Windows "produces corrupt records" and gives no shape. The decoder keeps any block shorter than the documented 12 bytes as `Effects::Opaque` and decodes longer blocks with the rest in `trailing`; out-of-range enum/intensity values decode without error (`spec/emf/emf_plus/color_curve_spec.rb`). Real Windows bytes are needed to go further; no fixture contains a ColorCurve effect.
6. The two spec/corpus disagreements in the continuation section settled with a second independent source.
7. `Metafile` / `Model` / CLI exposure of the typed view, which is the representation gate's public API decision (Hassan).
