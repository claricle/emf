# frozen_string_literal: true

require "emf/binary/float32_le"
require "emf/emf_plus/records/primitives/rect_array"

module Emf
  module EmfPlus
    module Records
      # EmfPlusDrawPie (2.3.4.12). C selects Rect over RectF; ObjectID is the pen.
      class DrawPie < Base
        include ShapeFlags

        TYPE = 0x4011

        class DrawPieBody < Body
          endian :little
          mandatory_parameter :flags
          float32_le :start_angle
          float32_le :sweep_angle
          rect_array :rect_data,
                     rect_count: 1,
                     compressed: -> { flags.anybits?(ShapeFlags::COMPRESSED_FLAG) }
        end
        BODY = DrawPieBody

        def pen_id = emf_object_id
        def start_angle = body.start_angle
        def sweep_angle = body.sweep_angle
        def rect = body.rect_data.rects.first
      end
    end
  end
end
