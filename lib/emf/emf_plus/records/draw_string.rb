# frozen_string_literal: true

require "emf/emf_plus/records/primitives/rect_f"

module Emf
  module EmfPlus
    module Records
      # EmfPlusDrawString (2.3.4.14). AlignmentPadding (up to 3 bytes, ignored on
      # read) stays in `trailing`.
      class DrawString < Base
        TYPE = 0x401C
        SOLID_COLOR_FLAG = 0x8000
        OBJECT_ID_MASK = 0x00FF

        class DrawStringBody < Body
          endian :little
          uint32 :brush_id
          uint32 :format_id
          uint32 :char_count
          rect_f :layout_rect
          string :string_data, read_length: -> { char_count * 2 }
        end
        BODY = DrawStringBody

        def flag_fields = { solid_color: SOLID_COLOR_FLAG, font_object_id: OBJECT_ID_MASK }

        def solid_color? = flags.anybits?(SOLID_COLOR_FLAG)
        def font_object_id = flags & OBJECT_ID_MASK
        def brush_id = body.brush_id
        def format_id = body.format_id
        def length = body.char_count
        def layout_rect = body.layout_rect.then { |r| [r.x, r.y, r.width, r.height] }

        def text
          body.string_data.to_s.dup.force_encoding(Encoding::UTF_16LE)
              .encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
        end
      end
    end
  end
end
