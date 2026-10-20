# frozen_string_literal: true

require "bindata"

module Emf
  module EmfPlus
    module Records
      module Primitives
        # EmfPlusRectF (2.2.2.40): 32-bit floats.
        class RectF < BinData::Record
          endian :little
          float :x
          float :y
          float :width
          float :height
        end
      end
    end
  end
end
