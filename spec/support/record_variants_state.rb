# frozen_string_literal: true

require_relative "record_variants"

# Variants for fixed-layout state, transform and path-control records
# (MS-EMF 2.3.11 and 2.3.7 control/path records). Values cover zero, boundary
# and sign-sensitive cases that the corpus fixtures do not reach.
module RecordVariants
  {
    "SetBkMode" => [18, "bk_mode", [1, 2]], "SetMapMode" => [17, "map_mode", [1, 8]],
    "SetRop2" => [20, "rop2", [1, 16]], "SetPolyFillMode" => [19, "poly_fill_mode", [1, 2]],
    "SetStretchBltMode" => [21, "stretch_mode", [1, 4]], "SetTextAlign" => [22, "text_align_mode", [0, 0x1006]],
    "SetArcDirection" => [57, "arc_direction", [1, 2]], "SetIcmMode" => [98, "mode", [1, 4]],
    "SetLayout" => [115, "mode", [0, 1]], "SetMapperFlags" => [16, "flags", [0, 1]],
    "SelectObject" => [37, "ih_object", [1, 0x8000_0005]], "DeleteObject" => [40, "ih_object", [1, 255]]
  }.each do |name, (type, field, defined)|
    define(name, type) do
      defined.each { |value| valid("defined value #{value}", u32(field, value)) }
      valid("zero", u32(field, 0))
      valid("max unsigned", u32(field, UINT_MAX))
    end
  end

  define("RestoreDc", 34) do
    valid("relative -1", i32("saved_dc", -1))
    valid("absolute positive", i32("saved_dc", 3))
    valid("min signed", i32("saved_dc", INT_MIN))
    valid("max signed", i32("saved_dc", INT_MAX))
  end

  define("SetMiterLimit", 58) do
    valid("default 10", f32("miter_limit", 10.0))
    valid("zero", f32("miter_limit", 0.0))
    valid("fractional", f32("miter_limit", 1.5))
    valid("infinity", f32("miter_limit", Float::INFINITY))
  end

  { "SetTextColor" => 24, "SetBkColor" => 25 }.each do |name, type|
    define(name, type) do
      valid("black", colorref("color", 0, 0, 0))
      valid("channels distinct", colorref("color", 1, 2, 3))
      valid("white with reserved byte", colorref("color", 255, 255, 255, 0x7F))
    end
  end

  {
    "SaveDc" => 33, "BeginPath" => 59, "EndPath" => 60, "CloseFigure" => 61, "FlattenPath" => 65,
    "WidenPath" => 66, "AbortPath" => 68, "SetMetArgn" => 28
  }.each do |name, type|
    define(name, type) { valid("header only (8 bytes)") }
  end

  {
    "SetWindowOrgEx" => [10, "origin"], "SetViewportOrgEx" => [12, "origin"], "SetBrushOrgEx" => [13, "ptl_origin"],
    "MoveToEx" => [27, "origin"], "LineTo" => [54, "origin"], "OffsetClipRgn" => [26, "ptl_offset"]
  }.each do |name, (type, field)|
    define(name, type) do
      valid("origin zero", pointl(field, 0, 0))
      valid("negative coordinates", pointl(field, -1, INT_MIN))
      valid("max coordinates", pointl(field, INT_MAX, 7))
    end
  end

  { "SetWindowExtEx" => 9, "SetViewportExtEx" => 11 }.each do |name, type|
    define(name, type) do
      valid("extent zero", sizel("extent", 0, 0))
      valid("negative extent", sizel("extent", -640, INT_MIN))
      valid("max extent", sizel("extent", INT_MAX, 480))
    end
  end

  define("SetPixelV", 15) do
    valid("origin pixel", pointl("ptl_pixel", 0, 0), colorref("cr_color", 9, 8, 7))
    valid("negative pixel", pointl("ptl_pixel", -5, -6), colorref("cr_color", 255, 0, 128, 3))
  end

  { "Rectangle" => 43, "Ellipse" => 42 }.each do |name, type|
    define(name, type) do
      valid("empty box", rectl("rcl_box", 0, 0, 0, 0))
      valid("signed box", rectl("rcl_box", -10, -20, 30, 40))
      valid("inverted box", rectl("rcl_box", 30, 40, -10, -20))
      valid("extreme box", rectl("rcl_box", INT_MIN, INT_MIN, INT_MAX, INT_MAX))
    end
  end

  define("RoundRect", 44) do
    valid("zero corner", rectl("rcl_box", 1, 2, 3, 4), sizel("szl_corner", 0, 0))
    valid("signed corner", rectl("rcl_box", -10, -20, 30, 40), sizel("szl_corner", -4, 8))
  end

  { "Arc" => 45, "ArcTo" => 55, "Chord" => 46, "Pie" => 47 }.each do |name, type|
    define(name, type) do
      valid("coincident points", rectl("rcl_box", 0, 0, 10, 10), pointl("ptl_start", 5, 0), pointl("ptl_end", 5, 0))
      valid("signed points", rectl("rcl_box", -10, -10, 10, 10), pointl("ptl_start", -10, 0), pointl("ptl_end", INT_MAX, INT_MIN))
    end
  end

  define("AngleArc", 41) do
    valid("zero radius and sweep", pointl("ptl_center", 0, 0), u32("n_radius", 0), f32("start_angle", 0.0), f32("sweep_angle", 0.0))
    valid("full sweep", pointl("ptl_center", -3, 4), u32("n_radius", UINT_MAX), f32("start_angle", 45.5), f32("sweep_angle", -360.0))
  end

  { "ExcludeClipRect" => 29, "IntersectClipRect" => 30 }.each do |name, type|
    define(name, type) do
      valid("empty clip", rectl("rcl_clip", 0, 0, 0, 0))
      valid("signed clip", rectl("rcl_clip", -1, -2, 3, 4))
    end
  end

  { "ScaleViewportExtEx" => 31, "ScaleWindowExtEx" => 32 }.each do |name, type|
    define(name, type) do
      valid("identity ratios", i32("x_num", 1), i32("x_denom", 1), i32("y_num", 1), i32("y_denom", 1))
      valid("negative ratios", i32("x_num", -3), i32("x_denom", 2), i32("y_num", INT_MIN), i32("y_denom", INT_MAX))
      valid("zero denominators", i32("x_num", 1), i32("x_denom", 0), i32("y_num", 1), i32("y_denom", 0))
    end
  end

  define("SetWorldTransform", 35) do
    valid("identity", xform("xform", 1.0, 0.0, 0.0, 1.0, 0.0, 0.0))
    valid("scale rotate translate", xform("xform", 0.5, -2.0, 4.25, 8.0, -16.5, 1024.0))
    valid("non-finite", xform("xform", Float::INFINITY, -Float::INFINITY, 0.0, 0.0, 0.0, 0.0))
  end

  define("ModifyWorldTransform", 36) do
    [[1, "identity"], [2, "left multiply"], [3, "right multiply"], [4, "set"]].each do |mode, label|
      valid("#{label} mode", xform("xform", 1.0, 0.0, 0.0, 1.0, 2.5, -2.5), u32("modify_mode", mode))
    end
    valid("undefined mode", xform("xform", 1.0, 0.0, 0.0, 1.0, 0.0, 0.0), u32("modify_mode", UINT_MAX))
  end

  define("CreatePen", 38) do
    valid("solid width 1", u32("ih_pen", 1), u32("pen_style", 0), pointl("width", 1, 0), colorref("color", 0, 0, 0))
    valid("dash with ignored y", u32("ih_pen", 7), u32("pen_style", 1), pointl("width", 3, 99), colorref("color", 1, 2, 3, 4))
    valid("max handle null style", u32("ih_pen", UINT_MAX), u32("pen_style", 5), pointl("width", 0, 0), colorref("color", 255, 255, 255))
  end

  define("CreateBrushIndirect", 39) do
    valid("solid", u32("ih_brush", 1), u32("brush_style", 0), colorref("color", 10, 20, 30), u32("brush_hatch", 0))
    valid("hatched", u32("ih_brush", 2), u32("brush_style", 2), colorref("color", 255, 0, 0), u32("brush_hatch", 3))
    valid("hollow max values", u32("ih_brush", UINT_MAX), u32("brush_style", 1), colorref("color", 0, 0, 0, 255),
          u32("brush_hatch", UINT_MAX))
  end
end
