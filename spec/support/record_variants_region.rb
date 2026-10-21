# frozen_string_literal: true

require_relative "record_variants"

# Variants for region, clip and path-paint records (MS-EMF 2.2.24 RegionData,
# 2.3.5 FillRgn/FrameRgn/InvertRgn/PaintRgn/FillPath/StrokePath/StrokeAndFillPath,
# 2.3.2 SelectClipPath, 2.3.3 ExtSelectClipRgn, ExtFloodFill, SetTextJustification):
# empty, single and multi-rectangle regions, trailing region bytes, absent
# clip region data and counts that exceed the declared byte length.
module RecordVariants
  self.catalog = :region
  REGION_BOUNDS = [-8, -9, 100, 120].freeze
  REGION_RECTS = [[-8, -9, 10, 11], [20, 21, 100, 120], [0, 0, 0, 0]].freeze
  CLIP_MODE_DIAGNOSTIC = "native falls back to Raw with ParseError 108 for a clip mode outside 1..5; " \
                         "Ruby keeps the typed record with no diagnostic"
  CLIP_MODES = (1..5).to_a.freeze

  module RegionBuilders
    # RegionData bytes plus accessor checks under `path`; count_override lies about count_rects.
    def region(path, rects, trailing: "".b, count_override: nil)
      body = [32, 1, count_override || rects.size, rects.size * 16].pack("V4") + REGION_BOUNDS.pack("l<4") +
             rects.flatten.pack("l<*") + trailing
      checks = check("#{path}.count_rects", rects.size) + check("#{path}.trailing", trailing)
      checks += rects.each_index.flat_map { |i| check("#{path}.rectangles[#{i}].left", rects[i][0]) }
      [body, checks]
    end

    # Fields after the bounds of a region record: cb, extras, then the region bytes.
    def region_record(extra_before, rects, extra_after = [], **options)
      body, checks = region("rgn_data", rects, **options)
      u32("cb_rgn_data", body.bytesize) + extra_before + extra_after + pad(body) + checks
    end

    def region_cases(extra_before: [], extra_after: [])
      REGION_CASES.each do |label, rects, options|
        valid(label, rectl("rcl_bounds", -1, -2, 3, 4), region_record(extra_before, rects, extra_after, **options))
      end
      malformed("count exceeds declared bytes", rectl("rcl_bounds", 0, 0, 1, 1),
                region_record(extra_before, REGION_RECTS.first(1), extra_after, count_override: 9))
      malformed("declared bytes below region header", rectl("rcl_bounds", 0, 0, 1, 1),
                u32("cb_rgn_data", 16), extra_before, extra_after, pad("\0".b * 16))
    end
  end
  Entry.include(RegionBuilders)

  REGION_CASES = [
    ["empty region", [], {}], ["one rectangle", REGION_RECTS.first(1), {}],
    ["three rectangles", REGION_RECTS, {}], ["trailing bytes after rectangles", REGION_RECTS.first(2), { trailing: "\xAA\xBB\xCC\xDD".b }]
  ].freeze

  define("FillRgn", 71) { region_cases(extra_before: u32("ih_brush", 3)) }
  define("InvertRgn", 73) { region_cases }
  define("PaintRgn", 74) { region_cases }
  define("FrameRgn", 72) { region_cases(extra_before: u32("ih_brush", 4) + sizel("szl_stroke", -2, 7)) }

  define("ExtSelectClipRgn", 75) do
    REGION_CASES.each do |label, rects, options|
      body, checks = region("rgn_data", rects, **options)
      CLIP_MODES.each do |mode|
        next if mode != 5 && rects.size != 2

        valid("#{label}, mode #{mode}", u32("cb_rgn_data", body.bytesize), u32("dw_mode", mode), pad(body), checks)
      end
    end
    malformed("no region data, undefined mode", u32("cb_rgn_data", 0), u32("dw_mode", UINT_MAX), pending: CLIP_MODE_DIAGNOSTIC)
    valid("no region data, RGN_COPY", u32("cb_rgn_data", 0), u32("dw_mode", 5))
    bad, = region("rgn_data", REGION_RECTS.first(1), count_override: 9)
    malformed("count exceeds declared bytes", u32("cb_rgn_data", bad.bytesize), u32("dw_mode", 5), pad(bad))
    malformed("declared bytes below region header", u32("cb_rgn_data", 16), u32("dw_mode", 5), pad("\0".b * 16))
  end

  { "FillPath" => 62, "StrokePath" => 64, "StrokeAndFillPath" => 63 }.each do |name, type|
    define(name, type) do
      valid("zero bounds", rectl("rcl_bounds", 0, 0, 0, 0))
      valid("signed bounds", rectl("rcl_bounds", -10, -20, 30, 40))
      valid("inverted bounds", rectl("rcl_bounds", 30, 40, -10, -20))
      valid("extreme bounds", rectl("rcl_bounds", INT_MIN, INT_MIN, INT_MAX, INT_MAX))
    end
  end

  define("SelectClipPath", 67) do
    CLIP_MODES.each { |mode| valid("region mode #{mode}", u32("region_mode", mode)) }
    valid("undefined mode", u32("region_mode", UINT_MAX))
  end

  define("ExtFloodFill", 53) do
    valid("border fill", pointl("start", 1, 2), colorref("color", 1, 2, 3), u32("flood_fill_mode", 0))
    valid("surface fill, negative start", pointl("start", -5, INT_MIN), colorref("color", 255, 255, 255, 9), u32("flood_fill_mode", 1))
    valid("undefined mode", pointl("start", INT_MAX, 0), colorref("color", 0, 0, 0), u32("flood_fill_mode", UINT_MAX))
  end

  define("SetTextJustification", 120) do
    valid("zero", i32("n_break_extra", 0), i32("n_break_count", 0))
    valid("positive", i32("n_break_extra", 12), i32("n_break_count", 3))
    valid("negative extremes", i32("n_break_extra", INT_MIN), i32("n_break_count", INT_MAX))
  end
end
