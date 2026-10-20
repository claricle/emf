# frozen_string_literal: true

require "bindata"
require "emf/binary/float32_le"

module Emf
  module EmfPlus
    module Records
      module Primitives
        # EmfPlusPointF (2.2.2.36): 32-bit floats.
        class PointF < Body
          endian :little
          float32_le :x
          float32_le :y
        end
      end
    end
  end
end
