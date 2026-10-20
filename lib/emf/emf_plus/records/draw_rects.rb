# frozen_string_literal: true

require "emf/emf_plus/records/primitives/rect_array"

module Emf
  module EmfPlus
    module Records
      # EmfPlusDrawRects (2.3.4.13). C selects Rect over RectF; ObjectID is the pen.
      class DrawRects < Base
        include ShapeFlags

        TYPE = 0x400B

        class DrawRectsBody < Body
          endian :little
          mandatory_parameter :flags
          uint32 :item_count
          rect_array :rect_data,
                     rect_count: :item_count,
                     compressed: -> { flags.anybits?(ShapeFlags::COMPRESSED_FLAG) }
        end
        BODY = DrawRectsBody

        def pen_id = emf_object_id
        def count = body.item_count
        def rects = body.rect_data.rects
      end
    end
  end
end
