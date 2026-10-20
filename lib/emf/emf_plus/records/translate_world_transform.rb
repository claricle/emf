# frozen_string_literal: true

module Emf
  module EmfPlus
    module Records
      # EmfPlusTranslateWorldTransform (2.3.9.7): translation by dx, dy.
      class TranslateWorldTransform < Base
        include PostMultiplyFlag

        TYPE = 0x402D

        class TranslateWorldTransformBody < BinData::Record
          endian :little
          float :dx
          float :dy
        end
        BODY = TranslateWorldTransformBody

        def dx = body.dx
        def dy = body.dy
      end
    end
  end
end
