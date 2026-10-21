# frozen_string_literal: true

require "emf/binary/float32_le"

module Emf
  module EmfPlus
    module Records
      # EmfPlusTranslateWorldTransform (2.3.9.7): translation by dx, dy.
      class TranslateWorldTransform < Base
        include PostMultiplyFlag

        TYPE = 0x402D

        class TranslateWorldTransformBody < Body
          endian :little
          float32_le :dx
          float32_le :dy
        end
        BODY = TranslateWorldTransformBody

        def dx = body.dx
        def dy = body.dy
      end
    end
  end
end
