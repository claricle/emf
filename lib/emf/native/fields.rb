# frozen_string_literal: true

module Emf
  module Native
    module Fields
      LAYOUTS = {
        2 => [Emr::Binary::Records::SetMapMode, [:map_mode, nil, "V", 4]],
        5 => [Emr::Binary::Records::SetBkMode, [:bk_mode, nil, "V", 4]],
        6 => [Emr::Binary::Records::SetPolyFillMode, [:poly_fill_mode, nil, "V", 4]],
        7 => [Emr::Binary::Records::SetRop2, [:rop2, nil, "V", 4]],
        8 => [Emr::Binary::Records::SetStretchBltMode, [:stretch_mode, nil, "V", 4]],
        9 => [Emr::Binary::Records::SetWindowExtEx, [:extent, %i[cx cy], "l<2", 8]],
        10 => [Emr::Binary::Records::SetWindowOrgEx, [:origin, %i[x y], "l<2", 8]],
        11 => [Emr::Binary::Records::SetViewportExtEx, [:extent, %i[cx cy], "l<2", 8]],
        12 => [Emr::Binary::Records::SetViewportOrgEx, [:origin, %i[x y], "l<2", 8]],
        13 => [Emr::Binary::Records::SetBrushOrgEx, [:ptl_origin, %i[x y], "l<2", 8]],
        14 => [Emr::Binary::Records::OffsetClipRgn, [:ptl_offset, %i[x y], "l<2", 8]],
        15 => [Emr::Binary::Records::MoveToEx, [:origin, %i[x y], "l<2", 8]],
        16 => [Emr::Binary::Records::SetTextColor, [:color, %i[red green blue reserved], "C4", 4]],
        17 => [Emr::Binary::Records::SetBkColor, [:color, %i[red green blue reserved], "C4", 4]],
        18 => [Emr::Binary::Records::Ellipse, [:rcl_box, %i[left top right bottom], "l<4", 16]],
        19 => [Emr::Binary::Records::Rectangle, [:rcl_box, %i[left top right bottom], "l<4", 16]],
        20 => [Emr::Binary::Records::RoundRect, [:rcl_box, %i[left top right bottom], "l<4", 16], [:szl_corner, %i[cx cy], "l<2", 8]],
        21 => [Emr::Binary::Records::SetTextAlign, [:text_align_mode, nil, "V", 4]],
        22 => [Emr::Binary::Records::SaveDc],
        23 => [Emr::Binary::Records::RestoreDc, [:saved_dc, nil, "l<", 4]],
        24 => [Emr::Binary::Records::SelectObject, [:ih_object, nil, "V", 4]],
        25 => [Emr::Binary::Records::DeleteObject, [:ih_object, nil, "V", 4]],
        26 => [Emr::Binary::Records::SetArcDirection, [:arc_direction, nil, "V", 4]],
        27 => [Emr::Binary::Records::BeginPath],
        28 => [Emr::Binary::Records::EndPath],
        29 => [Emr::Binary::Records::CloseFigure],
        30 => [Emr::Binary::Records::FillPath, [:rcl_bounds, %i[left top right bottom], "l<4", 16]],
        31 => [Emr::Binary::Records::StrokeAndFillPath, [:rcl_bounds, %i[left top right bottom], "l<4", 16]],
        32 => [Emr::Binary::Records::StrokePath, [:rcl_bounds, %i[left top right bottom], "l<4", 16]],
        33 => [Emr::Binary::Records::SelectClipPath, [:region_mode, nil, "V", 4]],
        34 => [Emr::Binary::Records::AbortPath],
        35 => [Emr::Binary::Records::SetPixelV, [:ptl_pixel, %i[x y], "l<2", 8], [:cr_color, %i[red green blue reserved], "C4", 4]],
        36 => [Emr::Binary::Records::ExcludeClipRect, [:rcl_clip, %i[left top right bottom], "l<4", 16]],
        37 => [Emr::Binary::Records::IntersectClipRect, [:rcl_clip, %i[left top right bottom], "l<4", 16]],
        38 => [Emr::Binary::Records::CreatePen, [:ih_pen, nil, "V", 4], [:pen_style, nil, "V", 4],
               [:width, %i[x y], "l<2", 8], [:color, %i[red green blue reserved], "C4", 4]],
        39 => [Emr::Binary::Records::CreateBrushIndirect, [:ih_brush, nil, "V", 4], [:brush_style, nil, "V", 4],
               [:color, %i[red green blue reserved], "C4", 4], [:brush_hatch, nil, "V", 4]],
        40 => [Emr::Binary::Records::Arc, [:rcl_box, %i[left top right bottom], "l<4", 16],
               [:ptl_start, %i[x y], "l<2", 8], [:ptl_end, %i[x y], "l<2", 8]],
        41 => [Emr::Binary::Records::Chord, [:rcl_box, %i[left top right bottom], "l<4", 16],
               [:ptl_start, %i[x y], "l<2", 8], [:ptl_end, %i[x y], "l<2", 8]],
        42 => [Emr::Binary::Records::Pie, [:rcl_box, %i[left top right bottom], "l<4", 16],
               [:ptl_start, %i[x y], "l<2", 8], [:ptl_end, %i[x y], "l<2", 8]],
        43 => [Emr::Binary::Records::LineTo, [:origin, %i[x y], "l<2", 8]],
        44 => [Emr::Binary::Records::ArcTo, [:rcl_box, %i[left top right bottom], "l<4", 16],
               [:ptl_start, %i[x y], "l<2", 8], [:ptl_end, %i[x y], "l<2", 8]],
        60 => [Emr::Binary::Records::ScaleViewportExtEx, [:x_num, nil, "l<", 4], [:x_denom, nil, "l<", 4],
               [:y_num, nil, "l<", 4], [:y_denom, nil, "l<", 4]],
        61 => [Emr::Binary::Records::ScaleWindowExtEx, [:x_num, nil, "l<", 4], [:x_denom, nil, "l<", 4],
               [:y_num, nil, "l<", 4], [:y_denom, nil, "l<", 4]],
        62 => [Emr::Binary::Records::SetWorldTransform, [:xform, %i[m11 m12 m21 m22 dx dy], "e6", 24]],
        63 => [Emr::Binary::Records::ModifyWorldTransform, [:xform, %i[m11 m12 m21 m22 dx dy], "e6", 24], [:modify_mode, nil, "V", 4]],
        64 => [Emr::Binary::Records::AngleArc, [:ptl_center, %i[x y], "l<2", 8], [:n_radius, nil, "V", 4],
               [:start_angle, nil, "e", 4], [:sweep_angle, nil, "e", 4]],
        65 => [Emr::Binary::Records::SetMiterLimit, [:miter_limit, nil, "e", 4]],
        66 => [Emr::Binary::Records::SetMapperFlags, [:flags, nil, "V", 4]],
        67 => [Emr::Binary::Records::SetMetArgn],
        69 => [Emr::Binary::Records::FlattenPath],
        70 => [Emr::Binary::Records::WidenPath],
        71 => [Emr::Binary::Records::SetIcmMode, [:mode, nil, "V", 4]],
        72 => [Emr::Binary::Records::SetLayout, [:mode, nil, "V", 4]]
      }.freeze

      POINT_ARRAYS = {
        3 => [Emr::Binary::Records::Polyline, 8, :cptl, :aptl],
        45 => [Emr::Binary::Records::PolyBezier, 8, :cptl, :aptl],
        46 => [Emr::Binary::Records::Polygon, 8, :cptl, :aptl],
        47 => [Emr::Binary::Records::PolyBezierTo, 8, :cptl, :aptl],
        48 => [Emr::Binary::Records::PolylineTo, 8, :cptl, :aptl],
        49 => [Emr::Binary::Records::PolyBezier16, 4, :cpts, :apts],
        50 => [Emr::Binary::Records::Polygon16, 4, :cpts, :apts],
        51 => [Emr::Binary::Records::Polyline16, 4, :cpts, :apts],
        52 => [Emr::Binary::Records::PolyBezierTo16, 4, :cpts, :apts],
        53 => [Emr::Binary::Records::PolylineTo16, 4, :cpts, :apts]
      }.freeze

      def self.point_array(payload, family)
        klass, width, count_field, points_field = POINT_ARRAYS.fetch(family)
        raise FormatError, "invalid native point array payload" if payload.bytesize < 24

        count = payload.byteslice(16, 8).unpack1("Q<")
        raise FormatError, "invalid native typed payload length" unless payload.bytesize == 24 + (count * width)
        raise FormatError, "native point array exceeds Ruby model array limit" if count > 1_000_000

        bounds = %i[left top right bottom].zip(payload.unpack("l<4")).to_h
        format = width == 8 ? "l<*" : "s<*"
        points = payload.byteslice(24..).unpack(format).each_slice(2).map { |x, y| { x: x, y: y } }
        [klass, { rcl_bounds: bounds, count_field => count, points_field => points }]
      end

      MULTI_POINT_ARRAYS = {
        54 => [Emr::Binary::Records::PolyPolyline, 8, :c_ptl_total, :aptl],
        55 => [Emr::Binary::Records::PolyPolygon, 8, :c_ptl_total, :aptl],
        56 => [Emr::Binary::Records::PolyPolyline16, 4, :c_pts_total, :apts],
        57 => [Emr::Binary::Records::PolyPolygon16, 4, :c_pts_total, :apts]
      }.freeze

      def self.multi_point_array(payload, family)
        klass, width, total_field, points_field = MULTI_POINT_ARRAYS.fetch(family)
        raise FormatError, "invalid native multi array payload" if payload.bytesize < 32

        poly_count, point_count = payload.byteslice(16, 16).unpack("Q<2")
        counts_size = poly_count * 4
        raise FormatError, "invalid native typed payload length" unless payload.bytesize == 32 + counts_size + (point_count * width)
        raise FormatError, "native multi array exceeds Ruby model array limit" if poly_count > 1_000_000 || point_count > 1_000_000

        bounds = %i[left top right bottom].zip(payload.unpack("l<4")).to_h
        counts = payload.byteslice(32, counts_size).unpack("V*")
        format = width == 8 ? "l<*" : "s<*"
        points = payload.byteslice((32 + counts_size)..).unpack(format).each_slice(2).map { |x, y| { x: x, y: y } }
        [klass, { rcl_bounds: bounds, n_polys: poly_count, a_poly_counts: counts,
                  total_field => point_count, points_field => points }]
      end

      POLY_DRAW = {
        58 => [Emr::Binary::Records::PolyDraw, 8, :cptl, :aptl],
        59 => [Emr::Binary::Records::PolyDraw16, 4, :cpts, :apts]
      }.freeze

      def self.poly_draw(payload, family)
        klass, width, count_field, points_field = POLY_DRAW.fetch(family)
        raise FormatError, "invalid native PolyDraw payload" if payload.bytesize < 24

        count = payload.byteslice(16, 8).unpack1("Q<")
        raise FormatError, "invalid native typed payload length" unless payload.bytesize == 24 + (count * (width + 1))
        raise FormatError, "native PolyDraw exceeds Ruby model array limit" if count > 1_000_000

        bounds = %i[left top right bottom].zip(payload.unpack("l<4")).to_h
        format = width == 8 ? "l<*" : "s<*"
        points = payload.byteslice(24, count * width).unpack(format).each_slice(2).map { |x, y| { x: x, y: y } }
        types = payload.byteslice((24 + (count * width))..).unpack("C*")
        [klass, { rcl_bounds: bounds, count_field => count, points_field => points, ab_types: types }]
      end

      OPAQUE = {
        68 => Emr::Binary::Records::ExtFloodFill,
        73 => Emr::Binary::Records::SetTextJustification
      }.freeze

      def self.opaque(payload, family)
        raise FormatError, "invalid native opaque payload length" if payload.bytesize < 8

        count = payload.unpack1("Q<")
        raise FormatError, "invalid native opaque payload length" unless payload.bytesize == 8 + count

        [OPAQUE.fetch(family), { body: payload.byteslice(8..) }]
      end

      def self.call(payload, family)
        return opaque(payload, family) if OPAQUE.key?(family)

        klass, *layouts = LAYOUTS.fetch(family)
        raise FormatError, "invalid native typed payload length" unless payload.bytesize == layouts.sum { |_, _, _, length| length }

        offset = 0
        fields = layouts.to_h do |field, axes, format, length|
          values = payload.byteslice(offset, length).unpack(format)
          offset += length
          [field, axes ? axes.zip(values).to_h : values.first]
        end
        [klass, fields]
      end
    end
  end
end
