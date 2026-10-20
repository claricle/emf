# frozen_string_literal: true

module Emf
  module EmfPlus
    module Records
      # EmfPlusResetWorldTransform (2.3.9.2): no body; Flags are unused.
      class ResetWorldTransform < Base
        TYPE = 0x402B

        class ResetWorldTransformBody < BinData::Record
          endian :little
        end
        BODY = ResetWorldTransformBody
      end
    end
  end
end
