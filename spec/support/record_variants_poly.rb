# frozen_string_literal: true

require_relative "record_variants"

# Variants for the count-driven point records (MS-EMF 2.3.5): zero, one and
# many points, signed and extreme coordinates, PolyDraw type bytes, PolyPoly
# count arrays, and counts that disagree with the payload.
module RecordVariants
  POLY_BOUNDS = [-5, -6, 70, 80].freeze

  module PolyBuilders
    def bounds = rectl("rcl_bounds", *POLY_BOUNDS)
    def count_bounds(count, field) = bounds + u32(field, count)
  end
  Entry.include(PolyBuilders)

  POINTS_L = [[0, 0], [-1, 1], [INT_MIN, INT_MAX], [12_345, -67_890]].freeze
  POINTS_S = [[0, 0], [-1, 1], [-32_768, 32_767], [123, -456]].freeze

  { "Polygon" => 3, "Polyline" => 4, "PolyBezier" => 2, "PolyBezierTo" => 5, "PolylineTo" => 6 }.each do |name, type|
    define(name, type) do
      valid("zero points", count_bounds(0, "cptl"))
      valid("one point", count_bounds(1, "cptl"), points_l("aptl", POINTS_L.first(1)))
      valid("three points", count_bounds(3, "cptl"), points_l("aptl", POINTS_L.first(3)))
      valid("four points with extremes", count_bounds(4, "cptl"), points_l("aptl", POINTS_L))
      valid("points beyond count kept as suffix", count_bounds(1, "cptl"), points_l("aptl", POINTS_L.first(1)),
            pad("\x01\x02\x03\x04\x05\x06\x07\x08"))
      malformed("count exceeds payload", count_bounds(5, "cptl"), points_l("aptl", POINTS_L.first(1)))
      malformed("count 0xFFFFFFFF", count_bounds(UINT_MAX, "cptl"), points_l("aptl", POINTS_L.first(1)))
    end
  end

  { "Polygon16" => 86, "Polyline16" => 87, "PolyBezier16" => 85, "PolyBezierTo16" => 88, "PolylineTo16" => 89 }.each do |name, type|
    define(name, type) do
      valid("zero points", count_bounds(0, "cpts"))
      valid("one point", count_bounds(1, "cpts"), points_s("apts", POINTS_S.first(1)))
      valid("three points", count_bounds(3, "cpts"), points_s("apts", POINTS_S.first(3)))
      valid("four points with extremes", count_bounds(4, "cpts"), points_s("apts", POINTS_S))
      valid("points beyond count kept as suffix", count_bounds(1, "cpts"), points_s("apts", POINTS_S.first(1)), pad("\x01\x02\x03\x04"))
      malformed("count exceeds payload", count_bounds(5, "cpts"), points_s("apts", POINTS_S.first(1)))
      malformed("count 0xFFFFFFFF", count_bounds(UINT_MAX, "cpts"), points_s("apts", POINTS_S.first(1)))
    end
  end

  # PT_MOVETO 6, PT_LINETO 2, PT_BEZIERTO 4, PT_LINETO|PT_CLOSEFIGURE 3.
  DRAW_TYPES = [6, 2, 4, 3].freeze

  { "PolyDraw" => [56, "cptl", "aptl", :points_l],
    "PolyDraw16" => [92, "cpts", "apts", :points_s] }.each do |name, (type, count, array, builder)|
    define(name, type) do
      points = builder == :points_l ? POINTS_L : POINTS_S
      valid("zero points", count_bounds(0, count))
      valid("one point padded type byte", count_bounds(1, count), send(builder, array, points.first(1)), bytes_list("ab_types", [6]),
            pad("\0\0\0"))
      valid("three points padded", count_bounds(3, count), send(builder, array, points.first(3)),
            bytes_list("ab_types", DRAW_TYPES.first(3)), pad("\0"))
      valid("four points aligned", count_bounds(4, count), send(builder, array, points), bytes_list("ab_types", DRAW_TYPES))
      malformed("count exceeds payload", count_bounds(5, count), send(builder, array, points.first(1)), bytes_list("ab_types", [6]))
      malformed("type bytes missing", count_bounds(2, count), send(builder, array, points.first(2)))
    end
  end

  {
    "PolyPolygon" => [8, "c_ptl_total", "aptl", :points_l], "PolyPolyline" => [7, "c_ptl_total", "aptl", :points_l],
    "PolyPolygon16" => [91, "c_pts_total", "apts", :points_s], "PolyPolyline16" => [90, "c_pts_total", "apts", :points_s]
  }.each do |name, (type, total, array, builder)|
    define(name, type) do
      points = builder == :points_l ? POINTS_L : POINTS_S
      header = ->(polys, sum) { bounds + u32("n_polys", polys) + u32(total, sum) }
      valid("zero polygons", header.call(0, 0))
      valid("one polygon", header.call(1, 3), u32_list("a_poly_counts", [3]), send(builder, array, points.first(3)))
      valid("two polygons", header.call(2, 4), u32_list("a_poly_counts", [1, 3]), send(builder, array, points))
      valid("empty polygon between others", header.call(3, 2), u32_list("a_poly_counts", [1, 0, 1]), send(builder, array, points.first(2)))
      malformed("count sum disagrees with total", header.call(2, 2), u32_list("a_poly_counts", [3, 3]),
                send(builder, array, points.first(2)))
      malformed("polygon count exceeds payload", header.call(7, 1), u32_list("a_poly_counts", [1]), send(builder, array, points.first(1)))
      malformed("total exceeds payload", header.call(1, 9), u32_list("a_poly_counts", [9]), send(builder, array, points.first(1)))
    end
  end
end
