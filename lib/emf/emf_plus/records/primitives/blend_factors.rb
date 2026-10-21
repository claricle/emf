# frozen_string_literal: true

require "bindata"
require "emf/binary/float32_le"

module Emf
  module EmfPlus
    module Records
      module Primitives
        # EmfPlusBlendFactors (2.2.2.5).
        class BlendFactors < Body
          endian :little
          uint32 :position_count
          array :blend_positions, type: :float32_le, initial_length: :position_count
          array :blend_factors, type: :float32_le, initial_length: :position_count
        end
      end
    end
  end
end
