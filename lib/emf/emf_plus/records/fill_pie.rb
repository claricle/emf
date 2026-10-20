# frozen_string_literal: true

require "emf/emf_plus/records/primitives/rect_array"

module Emf
  module EmfPlus
    module Records
      # EmfPlusFillPie (2.3.4.18). S solid colour brush, C selects Rect over RectF.
      class FillPie < Base
        include ShapeFlags
        include FillBrush

        TYPE = 0x4010

        class FillPieBody < BinData::Record
          endian :little
          mandatory_parameter :flags
          uint32 :brush_id
          float :start_angle
          float :sweep_angle
          rect_array :rect_data,
                     rect_count: 1,
                     compressed: -> { flags.anybits?(ShapeFlags::COMPRESSED_FLAG) }
        end
        BODY = FillPieBody

        def start_angle = body.start_angle
        def sweep_angle = body.sweep_angle
        def rect = body.rect_data.rects.first
      end
    end
  end
end
