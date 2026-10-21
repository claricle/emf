# frozen_string_literal: true

module Emf
  module EmfPlus
    module Records
      # EmfPlusSetTextContrast (2.3.6.7): no body. The low 12 flag bits hold
      # the text gamma multiplied by 1000.
      class SetTextContrast < Base
        TYPE = 0x4020
        CONTRAST_MASK = 0x0FFF

        class SetTextContrastBody < Body
          endian :little
        end
        BODY = SetTextContrastBody

        def flag_fields = { text_contrast: CONTRAST_MASK }

        def text_contrast = flags & CONTRAST_MASK
        def gamma = text_contrast / 1000.0
      end
    end
  end
end
