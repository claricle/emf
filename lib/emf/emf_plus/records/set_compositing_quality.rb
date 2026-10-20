# frozen_string_literal: true

module Emf
  module EmfPlus
    module Records
      # EmfPlusSetCompositingQuality (2.3.6.3): no body; the CompositingQuality value is the low flag byte.
      class SetCompositingQuality < Base
        TYPE = 0x4024

        class SetCompositingQualityBody < BinData::Record
          endian :little
        end
        BODY = SetCompositingQualityBody

        def flag_fields = { compositing_quality: 0xFF }

        def compositing_quality = flags & 0xFF
      end
    end
  end
end
