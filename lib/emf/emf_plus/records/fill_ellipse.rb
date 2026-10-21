# frozen_string_literal: true

require "emf/emf_plus/records/primitives/rect_array"

module Emf
  module EmfPlus
    module Records
      # EmfPlusFillEllipse (2.3.4.16). S solid colour brush, C selects Rect over RectF.
      class FillEllipse < Base
        include ShapeFlags
        include FillBrush

        TYPE = 0x400E

        class FillEllipseBody < Body
          endian :little
          mandatory_parameter :flags
          uint32 :brush_id
          rect_array :rect_data,
                     rect_count: 1,
                     compressed: -> { flags.anybits?(ShapeFlags::COMPRESSED_FLAG) }
        end
        BODY = FillEllipseBody

        def rect = body.rect_data.rects.first
      end
    end
  end
end
