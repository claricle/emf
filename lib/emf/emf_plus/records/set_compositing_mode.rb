# frozen_string_literal: true

module Emf
  module EmfPlus
    module Records
      # EmfPlusSetCompositingMode (2.3.6.2): no body; the CompositingMode value is the low flag byte.
      class SetCompositingMode < Base
        TYPE = 0x4023

        class SetCompositingModeBody < BinData::Record
          endian :little
        end
        BODY = SetCompositingModeBody

        def flag_fields = { compositing_mode: 0xFF }

        def compositing_mode = flags & 0xFF
      end
    end
  end
end
