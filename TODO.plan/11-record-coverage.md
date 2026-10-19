# EMF record coverage inventory

Status: bounded native slice implemented; complete registry and variant parity pending.

Source of truth: `lib/emf/emr/binary/records.rb` and its referenced wire files.
This table lists each autoloaded record class, including `Raw`; it does not claim
that every variant is implemented semantically or exercised by the fixture corpus.
Header parsing is separate in `lib/emf/emr/binary/header.rb`. The initial header
slice crosses the core, snapshot ABI and Ruby adapter; extended header variants
remain open.

The `In progress` rows have bounded typed or raw support in
[`model.rs`](../emf-rs/crates/emf-core/src/model.rs),
[`typed.rs`](../emf-rs/crates/emf-core/tests/typed.rs) and
[`adapter_spec.rb`](../spec/emf/native/adapter_spec.rb), delivered in
[PR #17](https://github.com/claricle/emf/pull/17). This evidence does not complete
every variant, malformed-input classification or corpus parity check.

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
| `SetTextAlign` | `SETTEXTALIGN` | [`set_text_align.rb`](../lib/emf/emr/binary/records/set_text_align.rb) | `emf::text` | In progress: typed core and exact edits; `0b6c21b`; native adapter pending |
| `SetStretchBltMode` | `SETSTRETCHBLTMODE` | [`set_stretch_blt_mode.rb`](../lib/emf/emr/binary/records/set_stretch_blt_mode.rb) | `emf::bitmap` | In progress: core and snapshot-2 Ruby parity; `b7b72e6` |
| `SaveDc` | `SAVEDC` | [`save_dc.rb`](../lib/emf/emr/binary/records/save_dc.rb) | `emf::state_objects` | In progress: typed core and exact edits; `0b6c21b`; native adapter pending |
| `RestoreDc` | `RESTOREDC` | [`restore_dc.rb`](../lib/emf/emr/binary/records/restore_dc.rb) | `emf::state_objects` | In progress: typed core and exact edits; `0b6c21b`; native adapter pending |
| `SelectObject` | `SELECTOBJECT` | [`select_object.rb`](../lib/emf/emr/binary/records/select_object.rb) | `emf::state_objects` | In progress: typed core and exact edits; `0b6c21b`; native adapter pending |
| `DeleteObject` | `DELETEOBJECT` | [`delete_object.rb`](../lib/emf/emr/binary/records/delete_object.rb) | `emf::state_objects` | In progress: typed core and exact edits; `0b6c21b`; native adapter pending |
| `CreatePen` | `CREATEPEN` | [`create_pen.rb`](../lib/emf/emr/binary/records/create_pen.rb) | `emf::state_objects` | Not started |
| `CreateBrushIndirect` | `CREATEBRUSHINDIRECT` | [`create_brush_indirect.rb`](../lib/emf/emr/binary/records/create_brush_indirect.rb) | `emf::state_objects` | Not started |
| `SetWindowOrgEx` | `SETWINDOWORGEX` | [`set_window_org_ex.rb`](../lib/emf/emr/binary/records/set_window_org_ex.rb) | `emf::transform` | In progress: signed core, snapshot and Ruby parity/edit controls; `7371400` |
| `SetWindowExtEx` | `SETWINDOWEXTEX` | [`set_window_ext_ex.rb`](../lib/emf/emr/binary/records/set_window_ext_ex.rb) | `emf::transform` | In progress: signed core, snapshot and Ruby parity/edit controls; `7371400` |
| `SetViewportOrgEx` | `SETVIEWPORTORGEX` | [`set_viewport_org_ex.rb`](../lib/emf/emr/binary/records/set_viewport_org_ex.rb) | `emf::transform` | In progress: signed core, snapshot and Ruby parity/edit controls; `7371400` |
| `SetViewportExtEx` | `SETVIEWPORTEXTEX` | [`set_viewport_ext_ex.rb`](../lib/emf/emr/binary/records/set_viewport_ext_ex.rb) | `emf::transform` | In progress: signed core, snapshot and Ruby parity/edit controls; `7371400` |
| `SetBrushOrgEx` | `SETBRUSHORGEX` | [`set_brush_org_ex.rb`](../lib/emf/emr/binary/records/set_brush_org_ex.rb) | `emf::transform` | In progress: signed core, snapshot and Ruby parity/edit controls; `7371400` |
| `MoveToEx` | `MOVETOEX` | [`move_to_ex.rb`](../lib/emf/emr/binary/records/move_to_ex.rb) | `emf::geometry` | In progress: signed core, snapshot and Ruby parity/edit controls; `7371400` |
| `LineTo` | `LINETO` | [`line_to.rb`](../lib/emf/emr/binary/records/line_to.rb) | `emf::geometry` | Not started |
| `Rectangle` | `RECTANGLE` | [`rectangle.rb`](../lib/emf/emr/binary/records/rectangle.rb) | `emf::geometry` | In progress: typed core, snapshot-2 Ruby parity and edits; `fd55d22` |
| `Ellipse` | `ELLIPSE` | [`ellipse.rb`](../lib/emf/emr/binary/records/ellipse.rb) | `emf::geometry` | In progress: typed core, snapshot-2 Ruby parity and edits; `fd55d22` |
| `RoundRect` | `ROUNDRECT` | [`round_rect.rb`](../lib/emf/emr/binary/records/round_rect.rb) | `emf::geometry` | In progress: typed core, snapshot-2 Ruby parity and edits; `fd55d22` |
| `Arc` | `ARC` | [`arc.rb`](../lib/emf/emr/binary/records/arc.rb) | `emf::geometry` | Not started |
| `ArcTo` | `ARCTO` | [`arc_to.rb`](../lib/emf/emr/binary/records/arc_to.rb) | `emf::geometry` | Not started |
| `Chord` | `CHORD` | [`chord.rb`](../lib/emf/emr/binary/records/chord.rb) | `emf::geometry` | Not started |
| `Pie` | `PIE` | [`pie.rb`](../lib/emf/emr/binary/records/pie.rb) | `emf::geometry` | Not started |
| `AngleArc` | `ANGLEARC` | [`angle_arc.rb`](../lib/emf/emr/binary/records/angle_arc.rb) | `emf::geometry` | Not started |
| `SetArcDirection` | `SETARCDIRECTION` | [`set_arc_direction.rb`](../lib/emf/emr/binary/records/set_arc_direction.rb) | `emf::geometry` | In progress: typed core and exact edits; `0b6c21b`; native adapter pending |
| `Polygon` | `POLYGON` | [`polygon.rb`](../lib/emf/emr/binary/records/polygon.rb) | `emf::geometry` | Not started |
| `Polyline` | `POLYLINE` | [`polyline.rb`](../lib/emf/emr/binary/records/polyline.rb) | `emf::geometry` | In progress |
| `PolyBezier` | `POLYBEZIER` | [`poly_bezier.rb`](../lib/emf/emr/binary/records/poly_bezier.rb) | `emf::geometry` | Not started |
| `Polygon16` | `POLYGON16` | [`polygon16.rb`](../lib/emf/emr/binary/records/polygon16.rb) | `emf::geometry` | Not started |
| `Polyline16` | `POLYLINE16` | [`polyline16.rb`](../lib/emf/emr/binary/records/polyline16.rb) | `emf::geometry` | Not started |
| `PolyBezier16` | `POLYBEZIER16` | [`poly_bezier16.rb`](../lib/emf/emr/binary/records/poly_bezier16.rb) | `emf::geometry` | Not started |
| `PolyBezierTo` | `POLYBEZIERTO` | [`poly_bezier_to.rb`](../lib/emf/emr/binary/records/poly_bezier_to.rb) | `emf::geometry` | Not started |
| `PolyBezierTo16` | `POLYBEZIERTO16` | [`poly_bezier_to16.rb`](../lib/emf/emr/binary/records/poly_bezier_to16.rb) | `emf::geometry` | Not started |
| `PolylineTo` | `POLYLINETO` | [`polyline_to.rb`](../lib/emf/emr/binary/records/polyline_to.rb) | `emf::geometry` | Not started |
| `PolylineTo16` | `POLYLINETO16` | [`polyline_to16.rb`](../lib/emf/emr/binary/records/polyline_to16.rb) | `emf::geometry` | Not started |
| `PolyDraw` | `POLYDRAW` | [`poly_draw.rb`](../lib/emf/emr/binary/records/poly_draw.rb) | `emf::geometry` | Not started |
| `PolyDraw16` | `POLYDRAW16` | [`poly_draw16.rb`](../lib/emf/emr/binary/records/poly_draw16.rb) | `emf::geometry` | Not started |
| `PolyPolyline` | `POLYPOLYLINE` | [`poly_polyline.rb`](../lib/emf/emr/binary/records/poly_polyline.rb) | `emf::geometry` | Not started |
| `PolyPolygon` | `POLYPOLYGON` | [`poly_polygon.rb`](../lib/emf/emr/binary/records/poly_polygon.rb) | `emf::geometry` | Not started |
| `PolyPolyline16` | `POLYPOLYLINE16` | [`poly_polyline16.rb`](../lib/emf/emr/binary/records/poly_polyline16.rb) | `emf::geometry` | Not started |
| `PolyPolygon16` | `POLYPOLYGON16` | [`poly_polygon16.rb`](../lib/emf/emr/binary/records/poly_polygon16.rb) | `emf::geometry` | Not started |
| `Comment` | `COMMENT` | [`comment.rb`](../lib/emf/emr/binary/records/comment.rb) | `emf::opaque_extensions` | In progress |
| `SetWorldTransform` | `SETWORLDTRANSFORM` | [`set_world_transform.rb`](../lib/emf/emr/binary/records/set_world_transform.rb) | `emf::transform` | Not started |
| `ModifyWorldTransform` | `MODIFYWORLDTRANSFORM` | [`modify_world_transform.rb`](../lib/emf/emr/binary/records/modify_world_transform.rb) | `emf::transform` | Not started |
| `BeginPath` | `BEGINPATH` | [`begin_path.rb`](../lib/emf/emr/binary/records/begin_path.rb) | `emf::path_clip_region` | In progress: typed core and exact edits; `0b6c21b`; native adapter pending |
| `EndPath` | `ENDPATH` | [`end_path.rb`](../lib/emf/emr/binary/records/end_path.rb) | `emf::path_clip_region` | In progress: typed core and exact edits; `0b6c21b`; native adapter pending |
| `CloseFigure` | `CLOSEFIGURE` | [`close_figure.rb`](../lib/emf/emr/binary/records/close_figure.rb) | `emf::path_clip_region` | In progress: typed core and exact edits; `0b6c21b`; native adapter pending |
| `FillPath` | `FILLPATH` | [`fill_path.rb`](../lib/emf/emr/binary/records/fill_path.rb) | `emf::path_clip_region` | In progress: typed core and exact edits; `0b6c21b`; native adapter pending |
| `StrokePath` | `STROKEPATH` | [`stroke_path.rb`](../lib/emf/emr/binary/records/stroke_path.rb) | `emf::path_clip_region` | In progress: typed core and exact edits; `0b6c21b`; native adapter pending |
| `StrokeAndFillPath` | `STROKEANDFILLPATH` | [`stroke_and_fill_path.rb`](../lib/emf/emr/binary/records/stroke_and_fill_path.rb) | `emf::path_clip_region` | In progress: typed core and exact edits; `0b6c21b`; native adapter pending |
| `FlattenPath` | `FLATTENPATH` | [`flatten_path.rb`](../lib/emf/emr/binary/records/flatten_path.rb) | `emf::path_clip_region` | Not started |
| `WidenPath` | `WIDENPATH` | [`widen_path.rb`](../lib/emf/emr/binary/records/widen_path.rb) | `emf::path_clip_region` | Not started |
| `SelectClipPath` | `SELECTCLIPPATH` | [`select_clip_path.rb`](../lib/emf/emr/binary/records/select_clip_path.rb) | `emf::path_clip_region` | In progress: typed core and exact edits; `0b6c21b`; native adapter pending |
| `AbortPath` | `ABORTPATH` | [`abort_path.rb`](../lib/emf/emr/binary/records/abort_path.rb) | `emf::path_clip_region` | In progress: typed core and exact edits; `0b6c21b`; native adapter pending |
| `SetMiterLimit` | `SETMITERLIMIT` | [`set_miter_limit.rb`](../lib/emf/emr/binary/records/set_miter_limit.rb) | `emf::path_clip_region` | Not started |
| `ExtTextOutW` | `EXTTEXTOUTW` | [`ext_text_out_w.rb`](../lib/emf/emr/binary/records/ext_text_out_w.rb) | `emf::text` | Not started |
| `ExtTextOutA` | `EXTTEXTOUTA` | [`ext_text_out_a.rb`](../lib/emf/emr/binary/records/ext_text_out_a.rb) | `emf::text` | Not started |
| `CreateFontIndirectW` | `EXTCREATEFONTINDIRECTW` | [`create_font_indirect_w.rb`](../lib/emf/emr/binary/records/create_font_indirect_w.rb) | `emf::text` | Not started |
| `ExtCreatePen` | `EXTCREATEPEN` | [`ext_create_pen.rb`](../lib/emf/emr/binary/records/ext_create_pen.rb) | `emf::state_objects` | Not started |
| `StretchDIBits` | `STRETCHDIBITS` | [`stretch_dibits.rb`](../lib/emf/emr/binary/records/stretch_dibits.rb) | `emf::bitmap` | Not started |
| `SetPixelV` | `SETPIXELV` | [`set_pixel_v.rb`](../lib/emf/emr/binary/records/set_pixel_v.rb) | `emf::state_objects` | Not started |
| `SetMetArgn` | `SETMETARGN` | [`set_metargn.rb`](../lib/emf/emr/binary/records/set_metargn.rb) | `emf::state_objects` | Not started |
| `OffsetClipRgn` | `OFFSETCLIPRGN` | [`offset_clip_rgn.rb`](../lib/emf/emr/binary/records/offset_clip_rgn.rb) | `emf::path_clip_region` | In progress: signed core, snapshot and Ruby parity/edit controls; `7371400` |
| `ExcludeClipRect` | `EXCLUDECLIPRECT` | [`exclude_clip_rect.rb`](../lib/emf/emr/binary/records/exclude_clip_rect.rb) | `emf::path_clip_region` | Not started |
| `IntersectClipRect` | `INTERSECTCLIPRECT` | [`intersect_clip_rect.rb`](../lib/emf/emr/binary/records/intersect_clip_rect.rb) | `emf::path_clip_region` | Not started |
| `ExtSelectClipRgn` | `EXTSELECTCLIPRGN` | [`ext_select_clip_rgn.rb`](../lib/emf/emr/binary/records/ext_select_clip_rgn.rb) | `emf::path_clip_region` | Not started |
| `ScaleViewportExtEx` | `SCALEVIEWPORTEXTEX` | [`scale_viewport_ext_ex.rb`](../lib/emf/emr/binary/records/scale_viewport_ext_ex.rb) | `emf::transform` | Not started |
| `ScaleWindowExtEx` | `SCALEWINDOWEXTEX` | [`scale_window_ext_ex.rb`](../lib/emf/emr/binary/records/scale_window_ext_ex.rb) | `emf::transform` | Not started |
| `SetMapperFlags` | `SETMAPPERFLAGS` | [`set_mapper_flags.rb`](../lib/emf/emr/binary/records/set_mapper_flags.rb) | `emf::state_objects` | Not started |
| `RealizePalette` | `REALIZEPALETTE` | [`realize_palette.rb`](../lib/emf/emr/binary/records/realize_palette.rb) | `emf::color_palette` | Not started |
| `SelectPalette` | `SELECTPALETTE` | [`select_palette.rb`](../lib/emf/emr/binary/records/select_palette.rb) | `emf::color_palette` | Not started |
| `CreatePalette` | `CREATEPALETTE` | [`create_palette.rb`](../lib/emf/emr/binary/records/create_palette.rb) | `emf::color_palette` | Not started |
| `ResizePalette` | `RESIZEPALETTE` | [`resize_palette.rb`](../lib/emf/emr/binary/records/resize_palette.rb) | `emf::color_palette` | Not started |
| `SetPaletteEntries` | `SETPALETTEENTRIES` | [`set_palette_entries.rb`](../lib/emf/emr/binary/records/set_palette_entries.rb) | `emf::color_palette` | Not started |
| `ExtFloodFill` | `EXTFLOODFILL` | [`ext_flood_fill.rb`](../lib/emf/emr/binary/records/ext_flood_fill.rb) | `emf::state_objects` | Not started |
| `FillRgn` | `FILLRGN` | [`fill_rgn.rb`](../lib/emf/emr/binary/records/fill_rgn.rb) | `emf::path_clip_region` | Not started |
| `FrameRgn` | `FRAMERGN` | [`frame_rgn.rb`](../lib/emf/emr/binary/records/frame_rgn.rb) | `emf::path_clip_region` | Not started |
| `InvertRgn` | `INVERTRGN` | [`invert_rgn.rb`](../lib/emf/emr/binary/records/invert_rgn.rb) | `emf::path_clip_region` | Not started |
| `PaintRgn` | `PAINTRGN` | [`paint_rgn.rb`](../lib/emf/emr/binary/records/paint_rgn.rb) | `emf::path_clip_region` | Not started |
| `BitBlt` | `BITBLT` | [`bit_blt.rb`](../lib/emf/emr/binary/records/bit_blt.rb) | `emf::bitmap` | Not started |
| `StretchBlt` | `STRETCHBLT` | [`stretch_blt.rb`](../lib/emf/emr/binary/records/stretch_blt.rb) | `emf::bitmap` | Not started |
| `MaskBlt` | `MASKBLT` | [`mask_blt.rb`](../lib/emf/emr/binary/records/mask_blt.rb) | `emf::bitmap` | Not started |
| `PlgBlt` | `PLGBLT` | [`plg_blt.rb`](../lib/emf/emr/binary/records/plg_blt.rb) | `emf::bitmap` | Not started |
| `SetDIBitsToDevice` | `SETDIBITSTODEVICE` | [`set_dibits_to_device.rb`](../lib/emf/emr/binary/records/set_dibits_to_device.rb) | `emf::bitmap` | Not started |
| `AlphaBlend` | `ALPHABLEND` | [`alpha_blend.rb`](../lib/emf/emr/binary/records/alpha_blend.rb) | `emf::bitmap` | Not started |
| `TransparentBlt` | `TRANSPARENTBLT` | [`transparent_blt.rb`](../lib/emf/emr/binary/records/transparent_blt.rb) | `emf::bitmap` | Not started |
| `SetLayout` | `SETLAYOUT` | [`set_layout.rb`](../lib/emf/emr/binary/records/set_layout.rb) | `emf::state_objects` | Not started |
| `SetIcmMode` | `SETICMMODE` | [`set_icm_mode.rb`](../lib/emf/emr/binary/records/set_icm_mode.rb) | `emf::color_palette` | Not started |
| `CreateMonoBrush` | `CREATEMONOBRUSH` | [`create_mono_brush.rb`](../lib/emf/emr/binary/records/create_mono_brush.rb) | `emf::bitmap` | Not started |
| `CreateDibPatternBrushPt` | `CREATEDIBPATTERNBRUSHPT` | [`create_dib_pattern_brush_pt.rb`](../lib/emf/emr/binary/records/create_dib_pattern_brush_pt.rb) | `emf::bitmap` | Not started |
| `GradientFill` | `GRADIENTFILL` | [`gradient_fill.rb`](../lib/emf/emr/binary/records/gradient_fill.rb) | `emf::bitmap` | Not started |
| `SmallTextOut` | `SMALLTEXTOUT` | [`small_text_out.rb`](../lib/emf/emr/binary/records/small_text_out.rb) | `emf::text` | Not started |
| `DrawEscape` | `DRAWESCAPE` | [`draw_escape.rb`](../lib/emf/emr/binary/records/draw_escape.rb) | `emf::opaque_extensions` | Not started |
| `ExtEscape` | `EXTESCAPE` | [`ext_escape.rb`](../lib/emf/emr/binary/records/ext_escape.rb) | `emf::opaque_extensions` | Not started |
| `NamedEscape` | `NAMEDESCAPE` | [`named_escape.rb`](../lib/emf/emr/binary/records/named_escape.rb) | `emf::opaque_extensions` | Not started |
| `ColorCorrectPalette` | `COLORCORRECTPALETTE` | [`color_correct_palette.rb`](../lib/emf/emr/binary/records/color_correct_palette.rb) | `emf::color_palette` | Not started |
| `SetIcmProfileA` | `SETICMPROFILEA` | [`set_icm_profile_a.rb`](../lib/emf/emr/binary/records/set_icm_profile_a.rb) | `emf::color_palette` | Not started |
| `SetIcmProfileW` | `SETICMPROFILEW` | [`set_icm_profile_w.rb`](../lib/emf/emr/binary/records/set_icm_profile_w.rb) | `emf::color_palette` | Not started |
| `ForceUfiMapping` | `FORCEUFIMAPPING` | [`force_ufi_mapping.rb`](../lib/emf/emr/binary/records/force_ufi_mapping.rb) | `emf::color_palette` | Not started |
| `SetLinkedUfis` | `SETLINKEDUFIS` | [`set_linked_ufis.rb`](../lib/emf/emr/binary/records/set_linked_ufis.rb) | `emf::color_palette` | Not started |
| `ColorMatchToTargetW` | `COLORMATCHTOTARGETW` | [`colormatch_to_target_w.rb`](../lib/emf/emr/binary/records/colormatch_to_target_w.rb) | `emf::color_palette` | Not started |
| `CreateColorspaceW` | `CREATECOLORSPACEW` | [`create_colorspace_w.rb`](../lib/emf/emr/binary/records/create_colorspace_w.rb) | `emf::color_palette` | Not started |
| `CreateColorspace` | `CREATECOLORSPACE` | [`create_colorspace.rb`](../lib/emf/emr/binary/records/create_colorspace.rb) | `emf::color_palette` | Not started |
| `SetColorspace` | `SETCOLORSPACE` | [`set_colorspace.rb`](../lib/emf/emr/binary/records/set_colorspace.rb) | `emf::color_palette` | Not started |
| `DeleteColorspace` | `DELETECOLORSPACE` | [`delete_colorspace.rb`](../lib/emf/emr/binary/records/delete_colorspace.rb) | `emf::color_palette` | Not started |
| `GlsRecord` | `GLSRECORD` | [`gls_record.rb`](../lib/emf/emr/binary/records/gls_record.rb) | `emf::opaque_extensions` | Not started |
| `GlsBoundedRecord` | `GLSBOUNDEDRECORD` | [`gls_bounded_record.rb`](../lib/emf/emr/binary/records/gls_bounded_record.rb) | `emf::opaque_extensions` | Not started |
| `PolyTextOutA` | `POLYTEXTOUTA` | [`poly_textout_a.rb`](../lib/emf/emr/binary/records/poly_textout_a.rb) | `emf::text` | Not started |
| `PolyTextOutW` | `POLYTEXTOUTW` | [`poly_textout_w.rb`](../lib/emf/emr/binary/records/poly_textout_w.rb) | `emf::text` | Not started |
| `PixelFormat` | `PIXELFORMAT` | [`pixel_format.rb`](../lib/emf/emr/binary/records/pixel_format.rb) | `emf::opaque_extensions` | Not started |
| `SetTextJustification` | `SETTEXTJUSTIFICATION` | [`set_text_justification.rb`](../lib/emf/emr/binary/records/set_text_justification.rb) | `emf::text` | Not started |

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
