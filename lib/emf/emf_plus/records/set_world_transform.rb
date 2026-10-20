# frozen_string_literal: true

require "emf/emf_plus/records/primitives/transform_matrix"

module Emf
  module EmfPlus
    module Records
      # EmfPlusSetWorldTransform (2.3.9.6): replaces the world transform; Flags are unused.
      class SetWorldTransform < Base
        TYPE = 0x402A

        class SetWorldTransformBody < BinData::Record
          endian :little
          transform_matrix :matrix
        end
        BODY = SetWorldTransformBody

        def matrix = body.matrix
      end
    end
  end
end
