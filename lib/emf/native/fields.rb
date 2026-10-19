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
               [:ptl_start, %i[x y], "l<2", 8], [:ptl_end, %i[x y], "l<2", 8]]
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
