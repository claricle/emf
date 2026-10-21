# frozen_string_literal: true

require "bindata"
require "emf/binary/float32_le"

module Emf
  module EmfPlus
    module Records
      module Primitives
        # EmfPlusRectF (2.2.2.40): 32-bit floats.
        class RectF < Body
          endian :little
          float32_le :x
          float32_le :y
          float32_le :width
          float32_le :height
        end
      end
    end
  end
end
