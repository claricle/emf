# frozen_string_literal: true

require "emf/binary/float32_le"

module Emf
  module EmfPlus
    module Records
      # EmfPlusScaleWorldTransform (2.3.9.4): scaling by sx, sy.
      class ScaleWorldTransform < Base
        include PostMultiplyFlag

        TYPE = 0x402E

        class ScaleWorldTransformBody < Body
          endian :little
          float32_le :sx
          float32_le :sy
        end
        BODY = ScaleWorldTransformBody

        def sx = body.sx
        def sy = body.sy
      end
    end
  end
end
