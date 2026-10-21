# frozen_string_literal: true

require "emf/emf_plus/records/primitives/rect_array"

module Emf
  module EmfPlus
    module Records
      # EmfPlusFillRects (2.3.4.20). S solid colour brush, C selects Rect over RectF.
      class FillRects < Base
        include ShapeFlags
        include FillBrush

        TYPE = 0x400A

        class FillRectsBody < Body
          endian :little
          mandatory_parameter :flags
          uint32 :brush_id
          uint32 :item_count
          rect_array :rect_data,
                     rect_count: :item_count,
                     compressed: -> { flags.anybits?(ShapeFlags::COMPRESSED_FLAG) }
        end
        BODY = FillRectsBody

        def count = body.item_count
        def rects = body.rect_data.rects
      end
    end
  end
end
