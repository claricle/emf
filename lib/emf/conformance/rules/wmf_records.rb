# frozen_string_literal: true

# WMF fixed-field, enum and point-array rules over typed public records
# (MS-WMF 2.3.3 drawing, 2.3.4 object, 2.3.5 state records). Records the model
# keeps opaque (UnknownRecord) are never judged here.
return if Emf::Conformance::Registry.loaded_elsewhere?(__FILE__)

module Emf
  module Conformance
    module WmfRecordRules
      WMF = %i[wmf].freeze
      R = Emf::Model::Wmf::Records
      IGNORED = "GDI ignores an out-of-range value instead of rejecting the record"

      # id => [record class, field, valid values (Range/Array), citation, name of the enumeration]
      ENUMS = {
        "wmf.enum.bk_mode" => [R::SetBkMode, :mode, [1, 2], "MS-WMF 2.1.1.20 MixMode Enumeration; " \
                                                            "2.3.5.15 META_SETBKMODE (BkMode)", "MixMode"],
        "wmf.enum.map_mode" => [R::SetMapMode, :mode, (1..8), "MS-WMF 2.1.1.16 MapMode Enumeration; " \
                                                              "2.3.5.17 META_SETMAPMODE (MapMode)", "MapMode"],
        "wmf.enum.poly_fill_mode" => [R::SetPolyFillMode, :mode, [1, 2], "MS-WMF 2.1.1.25 PolyFillMode Enumeration; " \
                                                                         "2.3.5.20 META_SETPOLYFILLMODE (PolyFillMode)",
                                      "PolyFillMode"],
        "wmf.enum.rop2" => [R::SetRop2, :mode, (1..16), "MS-WMF 2.1.1.2 BinaryRasterOperation Enumeration; " \
                                                        "2.3.5.22 META_SETROP2 (DrawMode)", "BinaryRasterOperation"],
        "wmf.enum.stretch_blt_mode" => [R::SetStretchBltMode, :mode, (1..4), "MS-WMF 2.1.1.30 StretchMode Enumeration; " \
                                                                             "2.3.5.23 META_SETSTRETCHBLTMODE (StretchMode)",
                                        "StretchMode"],
        "wmf.enum.ext_flood_fill_mode" => [R::ExtFloodFill, :mode, [0, 1], "MS-WMF 2.1.1.9 FloodFill Enumeration; " \
                                                                           "2.3.3.4 META_EXTFLOODFILL (Mode)", "FloodFill"],
        "wmf.enum.brush_style" => [R::CreateBrushIndirect, :brush_style, (0..9), "MS-WMF 2.1.1.4 BrushStyle Enumeration; " \
                                                                                 "2.3.4.1 META_CREATEBRUSHINDIRECT, " \
                                                                                 "2.2.2.10 LogBrush Object (BrushStyle)",
                                   "BrushStyle"]
      }.freeze

      BS_PATTERN = 3
      COLOR_USAGE = [R::DibCreatePatternBrush, R::SetDibToDev, R::StretchDib].freeze
      TEXT_ALIGN_MASK = 0x011F
      HORIZONTAL_ALIGN = [0x0, 0x2, 0x6].freeze # TA_LEFT, TA_RIGHT, TA_CENTER (bit 0x4 alone is no value)
      VERTICAL_ALIGN = [0x0, 0x8, 0x18].freeze  # TA_TOP, TA_BOTTOM, TA_BASELINE (bit 0x10 alone is no value)
      LAYOUT_MASK = 0x0009 # LAYOUT_RTL | LAYOUT_BITMAPORIENTATIONPRESERVED; LAYOUT_LTR is 0
      PEN_CAPS = [0x0000, 0x0100, 0x0200].freeze
      PEN_JOINS = [0x0000, 0x1000, 0x2000].freeze

      module_function

      def enum(context, klass, field, domain, name)
        each_of(context, klass) do |record|
          value = record.public_send(field)
          next if domain.include?(value)

          "#{klass.name.split('::').last} #{field} is #{value.inspect}, not a #{name} value"
        end
      end

      def color_usage(context)
        each_of(context, *COLOR_USAGE) do |record|
          value = record.color_usage
          # META_DIBCREATEPATTERNBRUSH: with Style BS_PATTERN, DIB_RGB_COLORS is used regardless of this field.
          next if record.is_a?(R::DibCreatePatternBrush) && record.style == BS_PATTERN
          next if [0, 1, 2].include?(value)

          "color usage is #{value.inspect}, MUST be DIB_RGB_COLORS, DIB_PAL_COLORS or DIB_PAL_INDICES"
        end
      end

      def hatch_style(context)
        each_of(context, R::CreateBrushIndirect) do |record|
          next unless record.brush_style == 2 && !(0..5).cover?(record.brush_hatch)

          "BS_HATCHED brush has HatchStyle #{record.brush_hatch.inspect}, MUST be 0..5"
        end
      end

      def pen_style(context)
        each_of(context, R::CreatePenIndirect) do |record|
          style = record.pen_style.to_i
          next if (style & 0xF) <= 8 && PEN_CAPS.include?(style & 0x0F00) && PEN_JOINS.include?(style & 0xF000)

          format("pen style 0x%04X is not a PenStyle style, end-cap and join combination", style)
        end
      end

      def text_align(context)
        each_of(context, R::SetTextAlign) do |record|
          value = record.alignment.to_i
          if value.anybits?(~TEXT_ALIGN_MASK)
            format("text alignment 0x%04X sets bits outside the TextAlignmentMode flags", value)
          elsif !HORIZONTAL_ALIGN.include?(value & 0x6)
            "text alignment 0x#{hex(value, 4)} has horizontal bits 0x#{(value & 0x6).to_s(16).upcase}, " \
              "MUST be TA_LEFT, TA_RIGHT or TA_CENTER"
          elsif !VERTICAL_ALIGN.include?(value & 0x18)
            "text alignment 0x#{hex(value, 4)} has vertical bits 0x#{hex(value & 0x18, 2)}, " \
              "MUST be TA_TOP, TA_BOTTOM or TA_BASELINE"
          end
        end
      end

      def hex(value, width) = value.to_s(16).upcase.rjust(width, "0")

      def layout(context)
        each_of(context, R::SetLayout) do |record|
          next if record.layout.to_i.nobits?(~LAYOUT_MASK)

          format("layout 0x%04X sets bits outside the Layout flags", record.layout.to_i)
        end
      end

      def point_count(context)
        each_of(context, R::Polygon, R::Polyline) do |record|
          count = record.points.size
          if count > 0x7FFF
            "#{count} points do not fit the signed 16-bit NumberOfPoints"
          elsif record.is_a?(R::Polygon) && count < 2
            "polygon has #{count} point(s), MUST have at least 2"
          end
        end
      end

      def polypolygon_counts(context)
        each_of(context, R::PolyPolygon) do |record|
          counts = record.points_per_polygon
          if counts.size > 0xFFFF
            "#{counts.size} polygons do not fit the unsigned 16-bit NumberOfPolygons"
          elsif counts.sum != record.points.size
            "PolyPolygon counts add up to #{counts.sum} points but the record holds #{record.points.size}"
          elsif counts.any? { |count| count > 0xFFFF }
            "a PolyPolygon polygon count exceeds the unsigned 16-bit range"
          end
        end
      end

      def point_range(context)
        each_of(context, R::Polygon, R::Polyline, R::PolyPolygon) do |record|
          bad = record.points.find { |point| !(-0x8000..0x7FFF).cover?(point.x) || !(-0x8000..0x7FFF).cover?(point.y) }
          "point (#{bad.x}, #{bad.y}) is outside the signed 16-bit coordinate range" if bad
        end
      end

      def each_of(context, *classes)
        context.records.each_with_index.filter_map do |record, index|
          next unless classes.any? { |klass| record.is_a?(klass) }

          message = yield record
          next unless message

          { message: message, offset: record.offset, record_index: index + 1, record_type: record.type_id.to_i }
        end
      end
    end

    registry = Registry.loading
    WmfRecordRules::ENUMS.each do |id, (klass, field, domain, citation, name)|
      registry.register(id: id, formats: WmfRecordRules::WMF, citation: citation, kind: :enum_domain,
                        tolerant_reason: WmfRecordRules::IGNORED) do |context|
        WmfRecordRules.enum(context, klass, field, domain, name)
      end
    end
    [
      ["wmf.enum.color_usage", :color_usage,
       "MS-WMF 2.1.1.6 ColorUsage Enumeration; " \
       "2.3.4.8 META_DIBCREATEPATTERNBRUSH, 2.3.1.4 META_SETDIBTODEV, 2.3.1.6 META_STRETCHDIB (ColorUsage)",
       :enum_domain, WmfRecordRules::IGNORED],
      ["wmf.enum.hatch_style", :hatch_style, "MS-WMF 2.1.1.12 HatchStyle Enumeration; " \
                                             "2.2.2.10 LogBrush Object (BrushHatch), 2.3.4.1 META_CREATEBRUSHINDIRECT", :enum_domain, WmfRecordRules::IGNORED],
      ["wmf.enum.pen_style", :pen_style, "MS-WMF 2.1.1.23 PenStyle Enumeration; " \
                                         "2.2.1.4 Pen Object (PenStyle), 2.3.4.5 META_CREATEPENINDIRECT", :enum_domain, WmfRecordRules::IGNORED],
      ["wmf.flags.text_align", :text_align, "MS-WMF 2.1.2.3 TextAlignmentMode Flags, 2.1.2.4 VerticalTextAlignmentMode Flags; " \
                                            "2.3.5.24 META_SETTEXTALIGN (TextAlignmentMode)", :flag_mask, WmfRecordRules::IGNORED],
      ["wmf.flags.layout", :layout, "MS-WMF 2.1.1.13 Layout Enumeration; " \
                                    "2.3.5.16 META_SETLAYOUT (Layout)", :flag_mask, WmfRecordRules::IGNORED],
      ["wmf.array.point_count", :point_count, "MS-WMF 2.3.3.14 META_POLYLINE, 2.3.3.15 META_POLYGON (NumberOfPoints)", :point_count, nil],
      ["wmf.array.polypolygon_counts", :polypolygon_counts, "MS-WMF 2.2.2.17 PolyPolygon Object (NumberOfPolygons, aPointsPerPolygon); " \
                                                            "2.3.3.16 META_POLYPOLYGON",
       :array_counts, nil],
      ["wmf.fixed.point_range", :point_range, "MS-WMF 2.2.2.16 PointS Object", :coordinate_range, nil]
    ].each do |id, method, citation, kind, reason|
      registry.register(id: id, formats: WmfRecordRules::WMF, citation: citation, kind: kind, tolerant_reason: reason) do |context|
        WmfRecordRules.public_send(method, context)
      end
    end
  end
end
