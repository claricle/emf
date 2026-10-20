# frozen_string_literal: true

module Emf
  module EmfPlus
    module Records
      # EmfPlusSetInterpolationMode (2.3.6.4): no body; the InterpolationMode value is the low flag byte.
      class SetInterpolationMode < Base
        TYPE = 0x4021

        class SetInterpolationModeBody < BinData::Record
          endian :little
        end
        BODY = SetInterpolationModeBody

        def flag_fields = { interpolation_mode: 0xFF }

        def interpolation_mode = flags & 0xFF
      end
    end
  end
end
