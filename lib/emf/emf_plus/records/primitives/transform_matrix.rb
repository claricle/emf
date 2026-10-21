# frozen_string_literal: true

require "bindata"
require "emf/binary/float32_le"

module Emf
  module EmfPlus
    module Records
      module Primitives
        # EmfPlusTransformMatrix (2.2.2.47): m11, m12, m21, m22, dx, dy.
        class TransformMatrix < Body
          endian :little
          float32_le :m11
          float32_le :m12
          float32_le :m21
          float32_le :m22
          float32_le :dx
          float32_le :dy
        end
      end
    end
  end
end
