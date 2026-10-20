# EMF record coverage inventory

Status: bounded native slice implemented; complete registry and variant parity pending.

Source of truth: `lib/emf/emr/binary/records.rb` and its referenced wire files.
This table lists each autoloaded record class, including `Raw`; it does not claim
that every variant is implemented semantically or exercised by the fixture corpus.
Header parsing is separate in `lib/emf/emr/binary/header.rb`. The initial header
slice crosses the core, snapshot ABI and Ruby adapter; extended header variants
remain open.

The `In progress` rows distinguish typed fields from opaque compatibility bodies.
The current [native family evidence](../docs/native-record-coverage.md) links models,
hydrators and focused controls; the initial core slice remains documented in
[PR #17](https://github.com/claricle/emf/pull/17). Neither focused synthetic controls
nor an inventory match proves complete variant or corpus parity.

Run `ruby script/record_coverage` to check class names, constants, numeric collisions
and wire-source links against the registry. This checks inventory identity only;
it does not execute native adapters or certify semantic coverage.

## Execution rule

For each row, inspect its wire definition and referenced shared primitives, then
add typed decoding, bounds checks, field-level assertions, byte-preserving serialization,
and Ruby adapter parity. Record real fixture coverage or add synthetic controls for
uncovered fields/variants. Update a row with its Rust symbol, tests and implementation
PR/commit before marking it complete. Raw passthrough alone is not typed coverage.
Keep unsupported extension payloads opaque explicitly where no semantics exist today;
the format-extension inventory in [09](09-format-extension.md) defines new scope.

Implement a small mixed vertical slice first, then complete groups under
[03](03-rust-core.md). Row states track bounded implementation; no row yet claims complete variant
and corpus parity. Group names are proposed Rust modules.

| Wire class | Type-code constant | Existing source | Proposed core module | State / evidence |
| --- | --- | --- | --- | --- |
| `Raw` | `unknown types` | [`raw.rb`](../lib/emf/emr/binary/records/raw.rb) | `emf::raw` | In progress |
| `Eof` | `EOF` | [`eof.rb`](../lib/emf/emr/binary/records/eof.rb) | `emf::eof` | In progress |
| `SetTextColor` | `SETTEXTCOLOR` | [`set_text_color.rb`](../lib/emf/emr/binary/records/set_text_color.rb) | `emf::text` | In progress: typed core, snapshot-2 Ruby parity and edits; `fd55d22` |
| `SetBkColor` | `SETBKCOLOR` | [`set_bk_color.rb`](../lib/emf/emr/binary/records/set_bk_color.rb) | `emf::color_palette` | In progress: typed core, snapshot-2 Ruby parity and edits; `fd55d22` |
| `SetBkMode` | `SETBKMODE` | [`set_bk_mode.rb`](../lib/emf/emr/binary/records/set_bk_mode.rb) | `emf::state_objects` | In progress: core and snapshot-2 Ruby parity; `b7b72e6` |
| `SetMapMode` | `SETMAPMODE` | [`set_map_mode.rb`](../lib/emf/emr/binary/records/set_map_mode.rb) | `emf::state_objects` | In progress |
| `SetRop2` | `SETROP2` | [`set_rop2.rb`](../lib/emf/emr/binary/records/set_rop2.rb) | `emf::state_objects` | In progress: core and snapshot-2 Ruby parity; `b7b72e6` |
| `SetPolyFillMode` | `SETPOLYFILLMODE` | [`set_poly_fill_mode.rb`](../lib/emf/emr/binary/records/set_poly_fill_mode.rb) | `emf::state_objects` | In progress: core and snapshot-2 Ruby parity; `b7b72e6` |
| `SetTextAlign` | `SETTEXTALIGN` | [`set_text_align.rb`](../lib/emf/emr/binary/records/set_text_align.rb) | `emf::text` | In progress: typed core, snapshot-2 Ruby parity and edits; `b4ec24d` |
| `SetColorAdjustment` | `SETCOLORADJUSTMENT` | [`set_color_adjustment.rb`](../lib/emf/emr/binary/records/set_color_adjustment.rb) | `emf::color_palette` | In progress: Ruby wire exposes 12 ColorAdjustment scalar accessors over preserved `body`; native family-0 body parity is proven; [field/body controls](../spec/emf/native/set_color_adjustment_spec.rb); Rust typed snapshots, rendering, and full variant/corpus proof remain open |
| `SetStretchBltMode` | `SETSTRETCHBLTMODE` | [`set_stretch_blt_mode.rb`](../lib/emf/emr/binary/records/set_stretch_blt_mode.rb) | `emf::bitmap` | In progress: core and snapshot-2 Ruby parity; `b7b72e6` |
| `SaveDc` | `SAVEDC` | [`save_dc.rb`](../lib/emf/emr/binary/records/save_dc.rb) | `emf::state_objects` | In progress: typed core, snapshot-2 Ruby parity and edits; `b4ec24d` |
| `RestoreDc` | `RESTOREDC` | [`restore_dc.rb`](../lib/emf/emr/binary/records/restore_dc.rb) | `emf::state_objects` | In progress: typed core, snapshot-2 Ruby parity and edits; `b4ec24d` |
| `SelectObject` | `SELECTOBJECT` | [`select_object.rb`](../lib/emf/emr/binary/records/select_object.rb) | `emf::state_objects` | In progress: typed core, snapshot-2 Ruby parity and edits; `b4ec24d` |
| `DeleteObject` | `DELETEOBJECT` | [`delete_object.rb`](../lib/emf/emr/binary/records/delete_object.rb) | `emf::state_objects` | In progress: typed core, snapshot-2 Ruby parity and edits; `b4ec24d` |
| `CreatePen` | `CREATEPEN` | [`create_pen.rb`](../lib/emf/emr/binary/records/create_pen.rb) | `emf::state_objects` | In progress: typed core, snapshot-2 Ruby parity and edits; `0fb8deb` |
| `CreateBrushIndirect` | `CREATEBRUSHINDIRECT` | [`create_brush_indirect.rb`](../lib/emf/emr/binary/records/create_brush_indirect.rb) | `emf::state_objects` | In progress: typed core, snapshot-2 Ruby parity and edits; `0fb8deb` |
| `SetWindowOrgEx` | `SETWINDOWORGEX` | [`set_window_org_ex.rb`](../lib/emf/emr/binary/records/set_window_org_ex.rb) | `emf::transform` | In progress: signed core, snapshot and Ruby parity/edit controls; `7371400` |
| `SetWindowExtEx` | `SETWINDOWEXTEX` | [`set_window_ext_ex.rb`](../lib/emf/emr/binary/records/set_window_ext_ex.rb) | `emf::transform` | In progress: signed core, snapshot and Ruby parity/edit controls; `7371400` |
| `SetViewportOrgEx` | `SETVIEWPORTORGEX` | [`set_viewport_org_ex.rb`](../lib/emf/emr/binary/records/set_viewport_org_ex.rb) | `emf::transform` | In progress: signed core, snapshot and Ruby parity/edit controls; `7371400` |
| `SetViewportExtEx` | `SETVIEWPORTEXTEX` | [`set_viewport_ext_ex.rb`](../lib/emf/emr/binary/records/set_viewport_ext_ex.rb) | `emf::transform` | In progress: signed core, snapshot and Ruby parity/edit controls; `7371400` |
| `SetBrushOrgEx` | `SETBRUSHORGEX` | [`set_brush_org_ex.rb`](../lib/emf/emr/binary/records/set_brush_org_ex.rb) | `emf::transform` | In progress: signed core, snapshot and Ruby parity/edit controls; `7371400` |
| `MoveToEx` | `MOVETOEX` | [`move_to_ex.rb`](../lib/emf/emr/binary/records/move_to_ex.rb) | `emf::geometry` | In progress: signed core, snapshot and Ruby parity/edit controls; `7371400` |
| `LineTo` | `LINETO` | [`line_to.rb`](../lib/emf/emr/binary/records/line_to.rb) | `emf::geometry` | In progress: typed core, snapshot-2 Ruby parity and edits; `0fb8deb` |
| `Rectangle` | `RECTANGLE` | [`rectangle.rb`](../lib/emf/emr/binary/records/rectangle.rb) | `emf::geometry` | In progress: typed core, snapshot-2 Ruby parity and edits; `fd55d22` |
| `Ellipse` | `ELLIPSE` | [`ellipse.rb`](../lib/emf/emr/binary/records/ellipse.rb) | `emf::geometry` | In progress: typed core, snapshot-2 Ruby parity and edits; `fd55d22` |
| `RoundRect` | `ROUNDRECT` | [`round_rect.rb`](../lib/emf/emr/binary/records/round_rect.rb) | `emf::geometry` | In progress: typed core, snapshot-2 Ruby parity and edits; `fd55d22` |
| `Arc` | `ARC` | [`arc.rb`](../lib/emf/emr/binary/records/arc.rb) | `emf::geometry` | In progress: typed core, snapshot-2 Ruby parity and edits; `0fb8deb` |
| `ArcTo` | `ARCTO` | [`arc_to.rb`](../lib/emf/emr/binary/records/arc_to.rb) | `emf::geometry` | In progress: typed core, snapshot-2 Ruby parity and edits; `0fb8deb` |
| `Chord` | `CHORD` | [`chord.rb`](../lib/emf/emr/binary/records/chord.rb) | `emf::geometry` | In progress: typed core, snapshot-2 Ruby parity and edits; `0fb8deb` |
| `Pie` | `PIE` | [`pie.rb`](../lib/emf/emr/binary/records/pie.rb) | `emf::geometry` | In progress: typed core, snapshot-2 Ruby parity and edits; `0fb8deb` |
| `AngleArc` | `ANGLEARC` | [`angle_arc.rb`](../lib/emf/emr/binary/records/angle_arc.rb) | `emf::geometry` | In progress: typed core, snapshot-2 Ruby parity and edits; `e548c23` |
| `SetArcDirection` | `SETARCDIRECTION` | [`set_arc_direction.rb`](../lib/emf/emr/binary/records/set_arc_direction.rb) | `emf::geometry` | In progress: typed core, snapshot-2 Ruby parity and edits; `b4ec24d` |
| `Polygon` | `POLYGON` | [`polygon.rb`](../lib/emf/emr/binary/records/polygon.rb) | `emf::geometry` | In progress: core and snapshot-2 Ruby parity; `8c25f5d` |
| `Polyline` | `POLYLINE` | [`polyline.rb`](../lib/emf/emr/binary/records/polyline.rb) | `emf::geometry` | In progress: core and snapshot-2 Ruby parity; `8c25f5d` |
| `PolyBezier` | `POLYBEZIER` | [`poly_bezier.rb`](../lib/emf/emr/binary/records/poly_bezier.rb) | `emf::geometry` | In progress: core and snapshot-2 Ruby parity; `8c25f5d` |
| `Polygon16` | `POLYGON16` | [`polygon16.rb`](../lib/emf/emr/binary/records/polygon16.rb) | `emf::geometry` | In progress: core and snapshot-2 Ruby parity; `8c25f5d` |
| `Polyline16` | `POLYLINE16` | [`polyline16.rb`](../lib/emf/emr/binary/records/polyline16.rb) | `emf::geometry` | In progress: core and snapshot-2 Ruby parity; `8c25f5d` |
| `PolyBezier16` | `POLYBEZIER16` | [`poly_bezier16.rb`](../lib/emf/emr/binary/records/poly_bezier16.rb) | `emf::geometry` | In progress: core and snapshot-2 Ruby parity; `8c25f5d` |
| `PolyBezierTo` | `POLYBEZIERTO` | [`poly_bezier_to.rb`](../lib/emf/emr/binary/records/poly_bezier_to.rb) | `emf::geometry` | In progress: core and snapshot-2 Ruby parity; `8c25f5d` |
| `PolyBezierTo16` | `POLYBEZIERTO16` | [`poly_bezier_to16.rb`](../lib/emf/emr/binary/records/poly_bezier_to16.rb) | `emf::geometry` | In progress: core and snapshot-2 Ruby parity; `8c25f5d` |
| `PolylineTo` | `POLYLINETO` | [`polyline_to.rb`](../lib/emf/emr/binary/records/polyline_to.rb) | `emf::geometry` | In progress: core and snapshot-2 Ruby parity; `8c25f5d` |
| `PolylineTo16` | `POLYLINETO16` | [`polyline_to16.rb`](../lib/emf/emr/binary/records/polyline_to16.rb) | `emf::geometry` | In progress: core and snapshot-2 Ruby parity; `8c25f5d` |
| `PolyDraw` | `POLYDRAW` | [`poly_draw.rb`](../lib/emf/emr/binary/records/poly_draw.rb) | `emf::geometry` | In progress: core and snapshot-2 Ruby parity; `2ea1d9f` |
| `PolyDraw16` | `POLYDRAW16` | [`poly_draw16.rb`](../lib/emf/emr/binary/records/poly_draw16.rb) | `emf::geometry` | In progress: core and snapshot-2 Ruby parity; `2ea1d9f` |
| `PolyPolyline` | `POLYPOLYLINE` | [`poly_polyline.rb`](../lib/emf/emr/binary/records/poly_polyline.rb) | `emf::geometry` | In progress: core and snapshot-2 Ruby parity; `38722dd` |
| `PolyPolygon` | `POLYPOLYGON` | [`poly_polygon.rb`](../lib/emf/emr/binary/records/poly_polygon.rb) | `emf::geometry` | In progress: core and snapshot-2 Ruby parity; `38722dd` |
| `PolyPolyline16` | `POLYPOLYLINE16` | [`poly_polyline16.rb`](../lib/emf/emr/binary/records/poly_polyline16.rb) | `emf::geometry` | In progress: core and snapshot-2 Ruby parity; `38722dd` |
| `PolyPolygon16` | `POLYPOLYGON16` | [`poly_polygon16.rb`](../lib/emf/emr/binary/records/poly_polygon16.rb) | `emf::geometry` | In progress: core and snapshot-2 Ruby parity; `38722dd` |
| `Comment` | `COMMENT` | [`comment.rb`](../lib/emf/emr/binary/records/comment.rb) | `emf::opaque_extensions` | In progress |
| `SetWorldTransform` | `SETWORLDTRANSFORM` | [`set_world_transform.rb`](../lib/emf/emr/binary/records/set_world_transform.rb) | `emf::transform` | In progress: typed core, snapshot-2 Ruby parity and edits; `e548c23` |
| `ModifyWorldTransform` | `MODIFYWORLDTRANSFORM` | [`modify_world_transform.rb`](../lib/emf/emr/binary/records/modify_world_transform.rb) | `emf::transform` | In progress: typed core, snapshot-2 Ruby parity and edits; `e548c23` |
| `BeginPath` | `BEGINPATH` | [`begin_path.rb`](../lib/emf/emr/binary/records/begin_path.rb) | `emf::path_clip_region` | In progress: typed core, snapshot-2 Ruby parity and edits; `b4ec24d` |
| `EndPath` | `ENDPATH` | [`end_path.rb`](../lib/emf/emr/binary/records/end_path.rb) | `emf::path_clip_region` | In progress: typed core, snapshot-2 Ruby parity and edits; `b4ec24d` |
| `CloseFigure` | `CLOSEFIGURE` | [`close_figure.rb`](../lib/emf/emr/binary/records/close_figure.rb) | `emf::path_clip_region` | In progress: typed core, snapshot-2 Ruby parity and edits; `b4ec24d` |
| `FillPath` | `FILLPATH` | [`fill_path.rb`](../lib/emf/emr/binary/records/fill_path.rb) | `emf::path_clip_region` | In progress: typed core, snapshot-2 Ruby parity and edits; `b4ec24d` |
| `StrokePath` | `STROKEPATH` | [`stroke_path.rb`](../lib/emf/emr/binary/records/stroke_path.rb) | `emf::path_clip_region` | In progress: typed core, snapshot-2 Ruby parity and edits; `b4ec24d` |
| `StrokeAndFillPath` | `STROKEANDFILLPATH` | [`stroke_and_fill_path.rb`](../lib/emf/emr/binary/records/stroke_and_fill_path.rb) | `emf::path_clip_region` | In progress: typed core, snapshot-2 Ruby parity and edits; `b4ec24d` |
| `FlattenPath` | `FLATTENPATH` | [`flatten_path.rb`](../lib/emf/emr/binary/records/flatten_path.rb) | `emf::path_clip_region` | In progress: core `e0fa139`, native `8598911`; remaining corpus/variant checks |
| `WidenPath` | `WIDENPATH` | [`widen_path.rb`](../lib/emf/emr/binary/records/widen_path.rb) | `emf::path_clip_region` | In progress: core `e0fa139`, native `8598911`; remaining corpus/variant checks |
| `SelectClipPath` | `SELECTCLIPPATH` | [`select_clip_path.rb`](../lib/emf/emr/binary/records/select_clip_path.rb) | `emf::path_clip_region` | In progress: typed core, snapshot-2 Ruby parity and edits; `b4ec24d` |
| `AbortPath` | `ABORTPATH` | [`abort_path.rb`](../lib/emf/emr/binary/records/abort_path.rb) | `emf::path_clip_region` | In progress: typed core, snapshot-2 Ruby parity and edits; `b4ec24d` |
| `SetMiterLimit` | `SETMITERLIMIT` | [`set_miter_limit.rb`](../lib/emf/emr/binary/records/set_miter_limit.rb) | `emf::path_clip_region` | In progress: typed core, snapshot-2 Ruby parity and edits; `e548c23` |
| `ExtTextOutW` | `EXTTEXTOUTW` | [`ext_text_out_w.rb`](../lib/emf/emr/binary/records/ext_text_out_w.rb) | `emf::text` | In progress: semantic core, snapshot-2 native Ruby hydration and edited serialization; corpus parity pending |
| `ExtTextOutA` | `EXTTEXTOUTA` | [`ext_text_out_a.rb`](../lib/emf/emr/binary/records/ext_text_out_a.rb) | `emf::text` | In progress: semantic core, snapshot-2 native Ruby hydration and edited serialization; corpus parity pending |
| `CreateFontIndirectW` | `EXTCREATEFONTINDIRECTW` | [`create_font_indirect_w.rb`](../lib/emf/emr/binary/records/create_font_indirect_w.rb) | `emf::text` | In progress: typed LogFont/Panose/ExDv, snapshot family 90 and native Ruby hydration; [font variant/edit controls](../spec/emf/native/font_adapter_spec.rb); corpus parity pending |
| `ExtCreatePen` | `EXTCREATEPEN` | [`ext_create_pen.rb`](../lib/emf/emr/binary/records/ext_create_pen.rb) | `emf::state_objects` | In progress: semantic core, snapshot family 81 and direct Ruby hydration (`dff26df`); legacy body writes and Ruby count guards corrected (`be0d78f`); corpus parity open |
| `StretchDIBits` | `STRETCHDIBITS` | [`stretch_dibits.rb`](../lib/emf/emr/binary/records/stretch_dibits.rb) | `emf::bitmap` | In progress: typed metadata and native Ruby hydration; DIB/pixel buffers opaque; [parity/edit/offset controls](../spec/emf/native/bitmap_adapter_spec.rb); corpus/variant parity pending |
| `SetPixelV` | `SETPIXELV` | [`set_pixel_v.rb`](../lib/emf/emr/binary/records/set_pixel_v.rb) | `emf::state_objects` | In progress: typed core, snapshot-2 Ruby parity and edits; `0fb8deb` |
| `SetMetArgn` | `SETMETARGN` | [`set_metargn.rb`](../lib/emf/emr/binary/records/set_metargn.rb) | `emf::state_objects` | In progress: core `e0fa139`, native `8598911`; remaining corpus/variant checks |
| `OffsetClipRgn` | `OFFSETCLIPRGN` | [`offset_clip_rgn.rb`](../lib/emf/emr/binary/records/offset_clip_rgn.rb) | `emf::path_clip_region` | In progress: signed core, snapshot and Ruby parity/edit controls; `7371400` |
| `ExcludeClipRect` | `EXCLUDECLIPRECT` | [`exclude_clip_rect.rb`](../lib/emf/emr/binary/records/exclude_clip_rect.rb) | `emf::path_clip_region` | In progress: typed core, snapshot-2 Ruby parity and edits; `0fb8deb` |
| `IntersectClipRect` | `INTERSECTCLIPRECT` | [`intersect_clip_rect.rb`](../lib/emf/emr/binary/records/intersect_clip_rect.rb) | `emf::path_clip_region` | In progress: typed core, snapshot-2 Ruby parity and edits; `0fb8deb` |
| `ExtSelectClipRgn` | `EXTSELECTCLIPRGN` | [`ext_select_clip_rgn.rb`](../lib/emf/emr/binary/records/ext_select_clip_rgn.rb) | `emf::path_clip_region` | In progress: semantic core, native snapshot hydration and corrected Ruby wire layouts (`881a472`); corpus parity pending |
| `ScaleViewportExtEx` | `SCALEVIEWPORTEXTEX` | [`scale_viewport_ext_ex.rb`](../lib/emf/emr/binary/records/scale_viewport_ext_ex.rb) | `emf::transform` | In progress: typed core, snapshot-2 Ruby parity and edits; `e548c23` |
| `ScaleWindowExtEx` | `SCALEWINDOWEXTEX` | [`scale_window_ext_ex.rb`](../lib/emf/emr/binary/records/scale_window_ext_ex.rb) | `emf::transform` | In progress: typed core, snapshot-2 Ruby parity and edits; `e548c23` |
| `SetMapperFlags` | `SETMAPPERFLAGS` | [`set_mapper_flags.rb`](../lib/emf/emr/binary/records/set_mapper_flags.rb) | `emf::state_objects` | In progress: core `e0fa139`, native `8598911`; remaining corpus/variant checks |
| `RealizePalette` | `REALIZEPALETTE` | [`realize_palette.rb`](../lib/emf/emr/binary/records/realize_palette.rb) | `emf::color_palette` | In progress: typed core, native snapshot and Ruby hydration; [palette parity/edit/count controls](../spec/emf/native/palette_adapter_spec.rb); corpus/variant parity pending |
| `SelectPalette` | `SELECTPALETTE` | [`select_palette.rb`](../lib/emf/emr/binary/records/select_palette.rb) | `emf::color_palette` | In progress: typed core, native snapshot and Ruby hydration; [palette parity/edit/count controls](../spec/emf/native/palette_adapter_spec.rb); corpus/variant parity pending |
| `CreatePalette` | `CREATEPALETTE` | [`create_palette.rb`](../lib/emf/emr/binary/records/create_palette.rb) | `emf::color_palette` | In progress: typed core, native snapshot and Ruby hydration; [palette parity/edit/count controls](../spec/emf/native/palette_adapter_spec.rb); corpus/variant parity pending |
| `ResizePalette` | `RESIZEPALETTE` | [`resize_palette.rb`](../lib/emf/emr/binary/records/resize_palette.rb) | `emf::color_palette` | In progress: typed core, native snapshot and Ruby hydration; [palette parity/edit/count controls](../spec/emf/native/palette_adapter_spec.rb); corpus/variant parity pending |
| `SetPaletteEntries` | `SETPALETTEENTRIES` | [`set_palette_entries.rb`](../lib/emf/emr/binary/records/set_palette_entries.rb) | `emf::color_palette` | In progress: typed core, native snapshot and Ruby hydration; [palette parity/edit/count controls](../spec/emf/native/palette_adapter_spec.rb); corpus/variant parity pending |
| `ExtFloodFill` | `EXTFLOODFILL` | [`ext_flood_fill.rb`](../lib/emf/emr/binary/records/ext_flood_fill.rb) | `emf::state_objects` | In progress: typed core and native scalar snapshot hydration; [field/edit/suffix controls](../spec/emf/native/semantic_state_spec.rb); corpus/variant parity pending |
| `FillRgn` | `FILLRGN` | [`fill_rgn.rb`](../lib/emf/emr/binary/records/fill_rgn.rb) | `emf::path_clip_region` | In progress: semantic core, native snapshot hydration and corrected Ruby wire layouts (`881a472`); corpus parity pending |
| `FrameRgn` | `FRAMERGN` | [`frame_rgn.rb`](../lib/emf/emr/binary/records/frame_rgn.rb) | `emf::path_clip_region` | In progress: semantic core, native snapshot hydration and corrected Ruby wire layouts (`881a472`); corpus parity pending |
| `InvertRgn` | `INVERTRGN` | [`invert_rgn.rb`](../lib/emf/emr/binary/records/invert_rgn.rb) | `emf::path_clip_region` | In progress: semantic core, native snapshot hydration and corrected Ruby wire layouts (`881a472`); corpus parity pending |
| `PaintRgn` | `PAINTRGN` | [`paint_rgn.rb`](../lib/emf/emr/binary/records/paint_rgn.rb) | `emf::path_clip_region` | In progress: semantic core, native snapshot hydration and corrected Ruby wire layouts (`881a472`); corpus parity pending |
| `BitBlt` | `BITBLT` | [`bit_blt.rb`](../lib/emf/emr/binary/records/bit_blt.rb) | `emf::bitmap` | In progress: typed metadata and native Ruby hydration; DIB/pixel buffers opaque; [parity/edit/offset controls](../spec/emf/native/bitmap_adapter_spec.rb); corpus/variant parity pending |
| `StretchBlt` | `STRETCHBLT` | [`stretch_blt.rb`](../lib/emf/emr/binary/records/stretch_blt.rb) | `emf::bitmap` | In progress: typed metadata and native Ruby hydration; DIB/pixel buffers opaque; [parity/edit/offset controls](../spec/emf/native/bitmap_adapter_spec.rb); corpus/variant parity pending |
| `MaskBlt` | `MASKBLT` | [`mask_blt.rb`](../lib/emf/emr/binary/records/mask_blt.rb) | `emf::bitmap` | In progress: typed metadata and native Ruby hydration; DIB/pixel buffers opaque; [parity/edit/offset controls](../spec/emf/native/bitmap_adapter_spec.rb); corpus/variant parity pending |
| `PlgBlt` | `PLGBLT` | [`plg_blt.rb`](../lib/emf/emr/binary/records/plg_blt.rb) | `emf::bitmap` | In progress: typed metadata and native Ruby hydration; DIB/pixel buffers opaque; [parity/edit/offset controls](../spec/emf/native/bitmap_adapter_spec.rb); corpus/variant parity pending |
| `SetDibitsToDevice` | `SETDIBITSTODEVICE` | [`set_dibits_to_device.rb`](../lib/emf/emr/binary/records/set_dibits_to_device.rb) | `emf::bitmap` | In progress: typed metadata and native Ruby hydration; DIB/pixel buffers opaque; [parity/edit/offset controls](../spec/emf/native/bitmap_adapter_spec.rb); corpus/variant parity pending |
| `AlphaBlend` | `ALPHABLEND` | [`alpha_blend.rb`](../lib/emf/emr/binary/records/alpha_blend.rb) | `emf::bitmap` | In progress: typed metadata and native Ruby hydration; DIB/pixel buffers opaque; [parity/edit/offset controls](../spec/emf/native/bitmap_adapter_spec.rb); corpus/variant parity pending |
| `TransparentBlt` | `TRANSPARENTBLT` | [`transparent_blt.rb`](../lib/emf/emr/binary/records/transparent_blt.rb) | `emf::bitmap` | In progress: typed metadata and native Ruby hydration; DIB/pixel buffers opaque; [parity/edit/offset controls](../spec/emf/native/bitmap_adapter_spec.rb); corpus/variant parity pending |
| `SetLayout` | `SETLAYOUT` | [`set_layout.rb`](../lib/emf/emr/binary/records/set_layout.rb) | `emf::state_objects` | In progress: core `e0fa139`, native `8598911`; remaining corpus/variant checks |
| `SetIcmMode` | `SETICMMODE` | [`set_icm_mode.rb`](../lib/emf/emr/binary/records/set_icm_mode.rb) | `emf::color_palette` | In progress: core `e0fa139`, native `8598911`; remaining corpus/variant checks |
| `CreateMonoBrush` | `CREATEMONOBRUSH` | [`create_mono_brush.rb`](../lib/emf/emr/binary/records/create_mono_brush.rb) | `emf::bitmap` | In progress: typed metadata and native Ruby hydration; DIB/pixel buffers opaque; [parity/edit/offset controls](../spec/emf/native/bitmap_adapter_spec.rb); corpus/variant parity pending |
| `CreateDibPatternBrushPt` | `CREATEDIBPATTERNBRUSHPT` | [`create_dib_pattern_brush_pt.rb`](../lib/emf/emr/binary/records/create_dib_pattern_brush_pt.rb) | `emf::bitmap` | In progress: typed metadata and native Ruby hydration; DIB/pixel buffers opaque; [parity/edit/offset controls](../spec/emf/native/bitmap_adapter_spec.rb); corpus/variant parity pending |
| `GradientFill` | `GRADIENTFILL` | [`gradient_fill.rb`](../lib/emf/emr/binary/records/gradient_fill.rb) | `emf::bitmap` | In progress: typed core and native Ruby hydration; [mode/edit/malformed controls](../spec/emf/native/gradient_adapter_spec.rb); corpus/variant parity pending |
| `SmallTextOut` | `SMALLTEXTOUT` | [`small_text_out.rb`](../lib/emf/emr/binary/records/small_text_out.rb) | `emf::text` | In progress: fixed prefix, raw 16-byte optional block, and count/flag-dependent `text_bytes` view with same-length edits; [semantic field/body controls](../spec/emf/native/small_text_out_semantics_spec.rb); Ruby/native parity and semantic truncation errors proven; rendering, Unicode conversion, and full variant/corpus proof remain open |
| `DrawEscape` | `DRAWESCAPE` | [`draw_escape.rb`](../lib/emf/emr/binary/records/draw_escape.rb) | `emf::opaque_extensions` | In progress: body-backed unsigned `i_escape`, read-only `cj_in`, and detached exact-length `data_bytes` over the 8-byte prefix; native family-0 parity, zero/short/oversized spans, suffix and snapshot preservation proven; [semantic controls](../spec/emf/native/escape_semantics_spec.rb); full variant/corpus proof remains open |
| `ExtEscape` | `EXTESCAPE` | [`ext_escape.rb`](../lib/emf/emr/binary/records/ext_escape.rb) | `emf::opaque_extensions` | In progress: body-backed unsigned `i_escape`, read-only `cj_in`, and detached exact-length `data_bytes` over the 8-byte prefix; native family-0 parity, zero/short/oversized spans, suffix and snapshot preservation proven; [semantic controls](../spec/emf/native/escape_semantics_spec.rb); full variant/corpus proof remains open |
| `NamedEscape` | `NAMEDESCAPE` | [`named_escape.rb`](../lib/emf/emr/binary/records/named_escape.rb) | `emf::opaque_extensions` | In progress: body-backed strict unsigned `i_escape`, read-only `cj_driver`/`cj_in`, and detached exact-length `driver_name_bytes`/`data_bytes` spans over the 12-byte prefix; native family-0 parity, odd-byte names, suffix/body reassignment and snapshot preservation proven; [semantic controls](../spec/emf/native/named_escape_semantics_spec.rb); full variant/corpus proof remains open |
| `ColorCorrectPalette` | `COLORCORRECTPALETTE` | [`color_correct_palette.rb`](../lib/emf/emr/binary/records/color_correct_palette.rb) | `emf::color_palette` | In progress: Ruby wire exposes four unsigned 32-bit fields over preserved `body`; native family-0 body parity is proven; [field/body controls](../spec/emf/native/color_correct_palette_spec.rb); full variant/corpus proof remains open |
| `SetIcmProfileA` | `SETICMPROFILEA` | [`set_icm_profile_a.rb`](../lib/emf/emr/binary/records/set_icm_profile_a.rb) | `emf::color_palette` | In progress: body-backed `dw_flags` access/edit and detached `name_bytes`/`profile_bytes` views with exact-length edits; `cb_name`/`cb_data` are read-only; native family-0 parity, span guards, short-body and suffix preservation are proven; [semantic span controls](../spec/emf/native/icm_profile_semantics_spec.rb); full variant/corpus proof remains open |
| `SetIcmProfileW` | `SETICMPROFILEW` | [`set_icm_profile_w.rb`](../lib/emf/emr/binary/records/set_icm_profile_w.rb) | `emf::color_palette` | In progress: body-backed `dw_flags` access/edit and detached `name_bytes`/`profile_bytes` views with exact-length edits; `cb_name`/`cb_data` are read-only; native family-0 parity, span guards, short-body and suffix preservation are proven; [semantic span controls](../spec/emf/native/icm_profile_semantics_spec.rb); full variant/corpus proof remains open |
| `ForceUfiMapping` | `FORCEUFIMAPPING` | [`force_ufi_mapping.rb`](../lib/emf/emr/binary/records/force_ufi_mapping.rb) | `emf::color_palette` | In progress: opaque native body hydration and editable Ruby wire parity; [byte/edit controls](../spec/emf/native/adapter_spec.rb); semantic fields and corpus/variant parity remain open |
| `SetLinkedUfis` | `SETLINKEDUFIS` | [`set_linked_ufis.rb`](../lib/emf/emr/binary/records/set_linked_ufis.rb) | `emf::color_palette` | In progress: opaque native body hydration and editable Ruby wire parity; [byte/edit controls](../spec/emf/native/adapter_spec.rb); semantic fields and corpus/variant parity remain open |
| `ColorMatchToTargetW` | `COLORMATCHTOTARGETW` | [`colormatch_to_target_w.rb`](../lib/emf/emr/binary/records/colormatch_to_target_w.rb) | `emf::color_palette` | In progress: body-backed `dw_action`/`dw_flags` u32 accessors, read-only `cb_name`/`cb_data`, and detached exact-length `name_bytes`/`profile_bytes` spans over the 16-byte prefix; native family-0 parity, zero/raw-short/suffix and snapshot preservation proven; [semantic controls](../spec/emf/native/color_match_semantics_spec.rb); full variant/corpus proof remains open |
| `CreateColorspaceW` | `CREATECOLORSPACEW` | [`create_colorspace_w.rb`](../lib/emf/emr/binary/records/create_colorspace_w.rb) | `emf::color_palette` | In progress: typed LCS fields and fixed-width endpoint/filename byte views, plus W profile flags/count/span access over preserved body; exact-length span edits, short-body and suffix preservation; native family-0 parity proven; [semantic span controls](../spec/emf/native/create_colorspace_semantics_spec.rb); full variant/corpus proof remains open |
| `CreateColorspace` | `CREATECOLORSPACE` | [`create_colorspace.rb`](../lib/emf/emr/binary/records/create_colorspace.rb) | `emf::color_palette` | In progress: typed LCS fields and fixed-width endpoint/filename byte views over preserved body; exact-length span edits, short-body and suffix preservation; native family-0 parity proven; [semantic span controls](../spec/emf/native/create_colorspace_semantics_spec.rb); full variant/corpus proof remains open |
| `SetColorspace` | `SETCOLORSPACE` | [`set_colorspace.rb`](../lib/emf/emr/binary/records/set_colorspace.rb) | `emf::color_palette` | In progress: unsigned 32-bit `ih_cs` accessor over preserved body (minimum 4-byte semantic span); native family-0 body parity proven; [accessor/edit controls](../spec/emf/native/colorspace_handles_spec.rb); full variant/corpus proof remains open |
| `DeleteColorspace` | `DELETECOLORSPACE` | [`delete_colorspace.rb`](../lib/emf/emr/binary/records/delete_colorspace.rb) | `emf::color_palette` | In progress: unsigned 32-bit `ih_cs` accessor over preserved body (minimum 4-byte semantic span); native family-0 body parity proven; [accessor/edit controls](../spec/emf/native/colorspace_handles_spec.rb); full variant/corpus proof remains open |
| `GlsRecord` | `GLSRECORD` | [`gls_record.rb`](../lib/emf/emr/binary/records/gls_record.rb) | `emf::opaque_extensions` | In progress: read-only `cb_data`, detached exact-length `data_bytes`, native family-0 parity, short/oversized/suffix and snapshot/reparse preservation; [semantic body controls](../spec/emf/native/gls_semantics_spec.rb); full variant/corpus proof remains open |
| `GlsBoundedRecord` | `GLSBOUNDEDRECORD` | [`gls_bounded_record.rb`](../lib/emf/emr/binary/records/gls_bounded_record.rb) | `emf::opaque_extensions` | In progress: bounded raw 16-byte `bounds` with editable setter, read-only `cb_data`, detached exact-length `data_bytes`; native family-0 parity, short/oversized/suffix and snapshot/reparse preservation; [semantic body controls](../spec/emf/native/gls_semantics_spec.rb); full variant/corpus proof remains open |
| `PolyTextOutA` | `POLYTEXTOUTA` | [`poly_textout_a.rb`](../lib/emf/emr/binary/records/poly_textout_a.rb) | `emf::text` | In progress: raw body retained with indexed `text_bytes`, `dx_bytes`, and `entry_bounds` views and exact-span edits; read-only `c_strings`; native family-0 parity, short-body and suffix preservation proven; [semantic span controls](../spec/emf/native/poly_text_out_semantics_spec.rb); full variant/corpus proof remains open |
| `PolyTextOutW` | `POLYTEXTOUTW` | [`poly_textout_w.rb`](../lib/emf/emr/binary/records/poly_textout_w.rb) | `emf::text` | In progress: raw body retained with indexed `text_bytes`, `dx_bytes`, and `entry_bounds` views and exact-span edits; read-only `c_strings`; native family-0 parity, short-body and suffix preservation proven; [semantic span controls](../spec/emf/native/poly_text_out_semantics_spec.rb); full variant/corpus proof remains open |
| `PixelFormat` | `PIXELFORMAT` | [`pixel_format.rb`](../lib/emf/emr/binary/records/pixel_format.rb) | `emf::opaque_extensions` | In progress: body-backed `pfd_size`, `pfd_version`, `dw_flags`, and three masks plus detached 40-byte `pfd_bytes` with exact-length edits; native family-0 parity, type/range atomicity, short-body, suffix, and snapshot preservation proven; [semantic controls](../spec/emf/native/pixel_format_semantics_spec.rb); full variant/corpus proof remains open |
| `SetTextJustification` | `SETTEXTJUSTIFICATION` | [`set_text_justification.rb`](../lib/emf/emr/binary/records/set_text_justification.rb) | `emf::text` | In progress: typed core and native scalar snapshot hydration; [field/edit/suffix controls](../spec/emf/native/semantic_state_spec.rb); corpus/variant parity pending |

## Completion conditions

- Regenerate or reconcile this table when the Ruby registry changes. No recognized
  type may silently drop to raw bytes in the native implementation.
- For variable-size records, exercise zero, one and many elements, invalid counts,
  overlapping/out-of-range spans, alignment/padding, and truncated buffers.
- Exercise byte strings, signed coordinates, UTF-16 units, fixed-width integers,
  float bits, bitmap metadata and payload offsets according to the actual wire class.
- Keep unknown numeric type preservation and malformed-known-record recovery distinct.
- Count implementation completeness by covered registry entries and variants,
  not by the number of corpus files that happen to pass.
