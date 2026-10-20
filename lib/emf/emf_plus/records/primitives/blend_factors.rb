# frozen_string_literal: true

require "bindata"

module Emf
  module EmfPlus
    module Records
      module Primitives
        # EmfPlusBlendFactors (2.2.2.5).
        class BlendFactors < Body
          endian :little
          uint32 :position_count
          array :blend_positions, type: :float_le, initial_length: :position_count
          array :blend_factors, type: :float_le, initial_length: :position_count
        end
      end
    end
  end
end
