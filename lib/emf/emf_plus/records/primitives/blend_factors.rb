# frozen_string_literal: true

require "bindata"
require "emf/binary/float32_le"
require "emf/emf_plus/records/primitives/bounded_array"

module Emf
  module EmfPlus
    module Records
      module Primitives
        # EmfPlusBlendFactors (2.2.2.5).
        class BlendFactors < Body
          endian :little
          uint32 :position_count
          bounded_array :blend_positions, type: :float32_le, element_size: 4, initial_length: :position_count
          bounded_array :blend_factors, type: :float32_le, element_size: 4, initial_length: :position_count
        end
      end
    end
  end
end
