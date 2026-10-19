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
        20 => [Emr::Binary::Records::RoundRect, [:rcl_box, %i[left top right bottom], "l<4", 16], [:szl_corner, %i[cx cy], "l<2", 8]]
      }.freeze

      def self.call(payload, family)
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
