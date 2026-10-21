# frozen_string_literal: true

require "emf/binary/float32_le"

module Emf
  module EmfPlus
    module Records
      # EmfPlusRotateWorldTransform (2.3.9.3): rotation by angle degrees.
      class RotateWorldTransform < Base
        include PostMultiplyFlag

        TYPE = 0x402F

        class RotateWorldTransformBody < Body
          endian :little
          float32_le :angle
        end
        BODY = RotateWorldTransformBody

        def angle = body.angle
      end
    end
  end
end
