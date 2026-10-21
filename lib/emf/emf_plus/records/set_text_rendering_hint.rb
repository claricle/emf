# frozen_string_literal: true

module Emf
  module EmfPlus
    module Records
      # EmfPlusSetTextRenderingHint (2.3.6.8): no body; the TextRenderingHint value is the low flag byte.
      class SetTextRenderingHint < Base
        TYPE = 0x401F

        class SetTextRenderingHintBody < Body
          endian :little
        end
        BODY = SetTextRenderingHintBody

        def flag_fields = { text_rendering_hint: 0xFF }

        def text_rendering_hint = flags & 0xFF
      end
    end
  end
end
