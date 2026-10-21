# frozen_string_literal: true

require "emf/emf_plus/records/primitives/rect_array"

module Emf
  module EmfPlus
    module Records
      # EmfPlusDrawEllipse (2.3.4.7). C selects Rect over RectF; ObjectID is the pen.
      class DrawEllipse < Base
        include ShapeFlags

        TYPE = 0x400F

        class DrawEllipseBody < Body
          endian :little
          mandatory_parameter :flags
          rect_array :rect_data,
                     rect_count: 1,
                     compressed: -> { flags.anybits?(ShapeFlags::COMPRESSED_FLAG) }
        end
        BODY = DrawEllipseBody

        def pen_id = emf_object_id
        def rect = body.rect_data.rects.first
      end
    end
  end
end
