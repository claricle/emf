# frozen_string_literal: true

module Emf
  module EmfPlus
    module Records
      # EmfPlusScaleWorldTransform (2.3.9.4): scaling by sx, sy.
      class ScaleWorldTransform < Base
        include PostMultiplyFlag

        TYPE = 0x402E

        class ScaleWorldTransformBody < BinData::Record
          endian :little
          float :sx
          float :sy
        end
        BODY = ScaleWorldTransformBody

        def sx = body.sx
        def sy = body.sy
      end
    end
  end
end
