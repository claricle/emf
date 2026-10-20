# frozen_string_literal: true

require_relative "palette_fields"
require_relative "legacy_state_fields"

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
        72 => [Emr::Binary::Records::SetLayout, [:mode, nil, "V", 4]],
        91 => [Emr::Binary::Records::ExtFloodFill, [:start, %i[x y], "l<2", 8],
               [:color, %i[red green blue reserved], "C4", 4], [:flood_fill_mode, nil, "V", 4]],
        92 => [Emr::Binary::Records::SetTextJustification, [:n_break_extra, nil, "l<", 4], [:n_break_count, nil, "l<", 4]]
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

      def self.ext_text(payload, family, raw)
        raise FormatError, "invalid native text payload length" if payload.bytesize < 104

        count, dx_present, dx_count, dx_first, string_present, string_length, dx_length = payload.byteslice(60, 44).unpack("Q<VQ<V2Q<2")
        width = family == 74 ? 1 : 2
        expected = 104 + (count * width) + (dx_count * 4) + string_length + dx_length
        raise FormatError, "invalid native text payload length" unless payload.bytesize == expected

        options, rectangle_present = payload.byteslice(36, 8).unpack("V2")
        text_layout!(options, rectangle_present, count, dx_present, dx_count, dx_first, string_present, string_length, dx_length)

        buffers = text_parts(payload, count, width, dx_count, string_length, dx_length, string_present, dx_present)
        buffers.reverse! if dx_first == 1
        offsets, trailing = text_buffers(buffers, rectangle_present == 1 ? 76 : 60, raw)
        fields = text_scalars(payload)
        fields.merge!(n_chars: count, off_string: offsets.fetch(false, 0), f_options: options,
                      off_dx: offsets.fetch(true, 0), trailing: trailing)
        fields[:rcl] = %i[left top right bottom].zip(payload.byteslice(44, 16).unpack("l<4")).to_h if rectangle_present == 1
        klass = family == 74 ? Emr::Binary::Records::ExtTextOutA : Emr::Binary::Records::ExtTextOutW
        [klass, fields]
      end

      def self.text_scalars(payload)
        {
          rcl_bounds: %i[left top right bottom].zip(payload.unpack("l<4")).to_h,
          i_graphics_mode: payload.byteslice(16, 4).unpack1("V"),
          ex_scale: payload.byteslice(20, 4).unpack1("e"), ey_scale: payload.byteslice(24, 4).unpack1("e"),
          ptl_reference: %i[x y].zip(payload.byteslice(28, 8).unpack("l<2")).to_h
        }
      end

      def self.text_layout!(options, rectangle, count, dx_present, dx_count, dx_first, string_present, string_length, dx_length)
        flags = [rectangle, dx_present, dx_first, string_present]
        valid = flags.all? { |flag| (0..1).cover?(flag) } && rectangle == (options.nobits?(0x100) ? 1 : 0)
        expected_dx = count * (options.nobits?(0x2000) ? 1 : 2)
        valid &&= text_dx_valid?(dx_present, dx_count, expected_dx, dx_length, dx_first)
        valid &&= string_present == 1 || (count.zero? && string_length.zero?)
        raise FormatError, "invalid native text layout" unless valid
      end

      def self.text_dx_valid?(present, count, expected, padding, first)
        present == 1 ? count == expected : [count, padding, first].all?(&:zero?)
      end

      def self.text_parts(payload, count, width, dx_count, string_length, dx_length, string_present, dx_present)
        text_end = 104 + (count * width)
        dx_end = text_end + (dx_count * 4)
        [[false, string_present, payload.byteslice(104...text_end), payload.byteslice(dx_end, string_length), width],
         [true, dx_present, payload.byteslice(text_end...dx_end), payload.byteslice(dx_end + string_length, dx_length), 4]]
      end

      # Ruby canonicalizes NaN payloads when converting to Float. Keep the transport
      # bytes until the caller assigns a new value to that existing BinData field.
      module TextScaleBits
        attr_writer :native_bits

        def assign(value)
          @native_bits = nil
          super
        end

        private

        def value_to_binary_string(value)
          @native_bits || super
        end
      end

      def self.preserve_text_scales(wire, payload)
        [wire.ex_scale, wire.ey_scale].each_with_index do |scale, index|
          scale.extend(TextScaleBits)
          scale.native_bits = payload.byteslice(20 + (index * 4), 4)
        end
      end

      def self.preserve_small_text_scales(wire, raw)
        [wire.ex_scale, wire.ey_scale].each_with_index do |scale, index|
          scale.extend(TextScaleBits)
          scale.native_bits = raw.byteslice(28 + (index * 4), 4)
        end
      end

      def self.text_buffers(buffers, fixed, raw)
        offsets = {}
        trailing = "".b
        buffers.each do |is_dx, present, bytes, padding, alignment|
          next if present.zero?

          trailing << padding
          offset = fixed + trailing.bytesize
          raise FormatError, "invalid native text buffer alignment" unless (offset % alignment).zero?

          offsets[is_dx] = offset
          trailing << bytes
        end
        consumed = fixed + trailing.bytesize
        raise FormatError, "invalid native text record span" if consumed > raw.bytesize

        [offsets, trailing + raw.byteslice(consumed..)]
      end

      def self.extended_pen(payload, raw)
        raise FormatError, "invalid native extended pen payload" if payload.bytesize < 76

        count = payload.byteslice(24, 8).unpack1("Q<")
        info, bits, first = payload.byteslice(32, 12).unpack("V3")
        lengths = payload.byteslice(44, 32).unpack("Q<4")
        raise FormatError, "invalid native extended pen length" unless payload.bytesize == 76 + (count * 4) + lengths.sum
        raise FormatError, "native extended pen exceeds Ruby model limit" if count > 1_000_000 || payload.bytesize > 0xFFFFFFFF

        pen_layout!([info, bits, first], lengths)

        cursor = 76 + (count * 4)
        parts = lengths.map do |length|
          bytes = payload.byteslice(cursor, length)
          cursor += length
          bytes
        end
        offsets, buffers = pen_buffers(parts, [info, bits], first, 52 + (count * 4), raw)
        values = payload.unpack("V6")
        [Emr::Binary::Records::ExtCreatePen,
         { ih_pen: values[0], pen_style: values[1], width: values[2], brush_style: values[3],
           color: %i[red green blue reserved].zip(payload.byteslice(16, 4).unpack("C4")).to_h,
           brush_hatch: values[5], num_style_entries: count, style_entries: payload.byteslice(76, count * 4).unpack("V*"),
           off_bmi: offsets[0], cb_bmi: lengths[0], off_bits: offsets[1], cb_bits: lengths[1], buffers: buffers }]
      end

      def self.pen_layout!(flags, lengths)
        valid = flags.all? { |flag| (0..1).cover?(flag) }
        valid &&= flags[0] == 1 || [lengths[0], lengths[2]].all?(&:zero?)
        valid &&= flags[1] == 1 || [lengths[1], lengths[3], flags[2]].all?(&:zero?)
        raise FormatError, "invalid native extended pen layout" unless valid
      end

      def self.pen_buffers(parts, presence, first, fixed, raw)
        offsets = [0, 0]
        buffers = {}
        cursor = fixed
        (first == 1 || presence == [0, 1] ? [1, 0] : [0, 1]).each_with_index do |kind, index|
          prefix = index.zero? ? "first" : "second"
          padding, bytes = parts.values_at(kind + 2, kind)
          cursor += padding.bytesize
          if presence[kind] == 1
            raise FormatError, "invalid native extended pen alignment" unless (cursor % 4).zero?

            # Empty buffers can retain offsets into fixed fields without consuming bytes.
            original = raw.byteslice(12 + (kind * 8), 4).unpack1("V")
            offsets[kind] = bytes.empty? && (8...fixed).cover?(original) ? original : cursor
          end
          buffers[:"#{prefix}_padding"] = padding
          buffers[:"#{prefix}_bitmap"] = bytes
          cursor += bytes.bytesize
        end
        raise FormatError, "invalid native extended pen span" if cursor > raw.bytesize

        buffers[:trailing] = raw.byteslice(cursor..)
        [offsets, buffers]
      end

      def self.region(payload, family, raw)
        klass = [Emr::Binary::Records::FillRgn, Emr::Binary::Records::FrameRgn,
                 Emr::Binary::Records::InvertRgn, Emr::Binary::Records::PaintRgn,
                 Emr::Binary::Records::ExtSelectClipRgn].fetch(family - 76)
        fixed = { 76 => 20, 77 => 28, 78 => 16, 79 => 16, 80 => 8 }.fetch(family)
        raise FormatError, "invalid native region payload" if payload.bytesize < fixed

        fields = region_scalars(payload, family)
        data = optional_region_data(payload, family, fixed, fields)
        count = data ? 32 + (data.fetch(:count_rects) * 16) + data.fetch(:trailing).bytesize : 0
        wire_fixed = family == 80 ? 16 : fixed + 12
        raise FormatError, "invalid native region span" if raw.bytesize < wire_fixed + count

        fields[:cb_rgn_data] = count
        fields[:body] = raw.byteslice((wire_fixed + count)..)
        fields[:rgn_data] = data if data
        [klass, fields]
      end

      def self.optional_region_data(payload, family, fixed, fields)
        present = family == 80 ? payload.byteslice(4, 4).unpack1("V") : 1
        raise FormatError, "invalid native region presence" unless (0..1).cover?(present)
        return region_data(payload.byteslice(fixed..)) if present == 1

        raise FormatError, "invalid native clip reset" unless fields.fetch(:dw_mode) == 5 && payload.bytesize == fixed

        nil
      end

      def self.region_scalars(payload, family)
        return { dw_mode: payload.unpack1("V") } if family == 80

        fields = { rcl_bounds: %i[left top right bottom].zip(payload.unpack("l<4")).to_h }
        fields[:ih_brush] = payload.byteslice(16, 4).unpack1("V") if [76, 77].include?(family)
        fields[:szl_stroke] = %i[cx cy].zip(payload.byteslice(20, 8).unpack("l<2")).to_h if family == 77
        fields
      end

      def self.region_data(payload)
        raise FormatError, "invalid native region data" if payload.bytesize < 36

        count, extra = payload.byteslice(20, 16).unpack("Q<2")
        expected = 36 + (count * 16) + extra
        raise FormatError, "invalid native region data length" unless payload.bytesize == expected
        raise FormatError, "invalid native region count" if count > 1_000_000 || 32 + (count * 16) + extra > 0xFFFFFFFF

        axes = %i[left top right bottom]
        rectangles = payload.byteslice(36, count * 16).unpack("l<*").each_slice(4).map { |values| axes.zip(values).to_h }
        { header_size: 32, region_type: payload.unpack1("V"), count_rects: count, rgn_size: count * 16,
          bounds: axes.zip(payload.byteslice(4, 16).unpack("l<4")).to_h,
          rectangles: rectangles, trailing: payload.byteslice(36 + (count * 16), extra) }
      end

      def self.call(payload, family)
        return LegacyStateFields.call(payload, family) if [68, 73].include?(family)

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
