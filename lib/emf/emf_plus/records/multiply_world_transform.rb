# frozen_string_literal: true

require "emf/emf_plus/records/primitives/transform_matrix"

module Emf
  module EmfPlus
    module Records
      # EmfPlusMultiplyWorldTransform (2.3.9.1): multiplies the world transform by MatrixData.
      class MultiplyWorldTransform < Base
        include PostMultiplyFlag

        TYPE = 0x402C

        class MultiplyWorldTransformBody < BinData::Record
          endian :little
          transform_matrix :matrix
        end
        BODY = MultiplyWorldTransformBody

        def matrix = body.matrix
      end
    end
  end
end
