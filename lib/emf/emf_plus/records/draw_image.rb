# frozen_string_literal: true

require "emf/emf_plus/records/primitives/rect_f"
require "emf/emf_plus/records/primitives/rect"

module Emf
  module EmfPlus
    module Records
      # EmfPlusDrawImage (2.3.4.8). The C flag selects EmfPlusRect over
      # EmfPlusRectF for RectData.
      class DrawImage < Base
        TYPE = 0x401A
        COMPRESSED_FLAG = 0x4000
        OBJECT_ID_MASK = 0x00FF

        class DrawImageBody < Body
          endian :little
          mandatory_parameter :flags
          uint32 :image_attributes_id
          int32 :src_unit
          rect_f :src_rect
          rect :compressed_rect, onlyif: -> { flags.anybits?(COMPRESSED_FLAG) }
          rect_f :rect_data, onlyif: -> { !flags.anybits?(COMPRESSED_FLAG) }
        end
        BODY = DrawImageBody

        def flag_fields = { compressed: COMPRESSED_FLAG, image_object_id: OBJECT_ID_MASK }

        def compressed? = flags.anybits?(COMPRESSED_FLAG)
        def image_object_id = flags & OBJECT_ID_MASK
        def image_attributes_id = body.image_attributes_id
        def src_unit = body.src_unit
        def src_rect = rect_values(body.src_rect)
        def dest_rect = rect_values(compressed? ? body.compressed_rect : body.rect_data)

        private

        def rect_values(rect) = [rect.x, rect.y, rect.width, rect.height]
      end
    end
  end
end
