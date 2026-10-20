# frozen_string_literal: true

require "emf/emf_plus/records/primitives/rect_array"

module Emf
  module EmfPlus
    module Records
      # EmfPlusDrawArc (2.3.4.2). C selects Rect over RectF; ObjectID is the pen.
      class DrawArc < Base
        include ShapeFlags

        TYPE = 0x4012

        class DrawArcBody < Body
          endian :little
          mandatory_parameter :flags
          float :start_angle
          float :sweep_angle
          rect_array :rect_data,
                     rect_count: 1,
                     compressed: -> { flags.anybits?(ShapeFlags::COMPRESSED_FLAG) }
        end
        BODY = DrawArcBody

        def pen_id = emf_object_id
        def start_angle = body.start_angle
        def sweep_angle = body.sweep_angle
        def rect = body.rect_data.rects.first
      end
    end
  end
end
