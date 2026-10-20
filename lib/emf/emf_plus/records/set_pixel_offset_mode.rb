# frozen_string_literal: true

module Emf
  module EmfPlus
    module Records
      # EmfPlusSetPixelOffsetMode (2.3.6.5): no body; the PixelOffsetMode value is the low flag byte.
      class SetPixelOffsetMode < Base
        TYPE = 0x4022

        class SetPixelOffsetModeBody < BinData::Record
          endian :little
        end
        BODY = SetPixelOffsetModeBody

        def flag_fields = { pixel_offset_mode: 0xFF }

        def pixel_offset_mode = flags & 0xFF
      end
    end
  end
end
