# frozen_string_literal: true

module Emf
  module EmfPlus
    module Records
      # EmfPlusRotateWorldTransform (2.3.9.3): rotation by angle degrees.
      class RotateWorldTransform < Base
        include PostMultiplyFlag

        TYPE = 0x402F

        class RotateWorldTransformBody < Body
          endian :little
          float :angle
        end
        BODY = RotateWorldTransformBody

        def angle = body.angle
      end
    end
  end
end
