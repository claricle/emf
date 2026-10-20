# frozen_string_literal: true

require "bindata"

module Emf
  module EmfPlus
    module Records
      module Primitives
        # EmfPlusPointF (2.2.2.36): 32-bit floats.
        class PointF < BinData::Record
          endian :little
          float :x
          float :y
        end
      end
    end
  end
end
