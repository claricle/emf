# frozen_string_literal: true

require "bindata"
require "emf/binary/float32_le"
require "emf/emf_plus/records/primitives/bounded_array"
require "emf/emf_plus/records/primitives/argb"

module Emf
  module EmfPlus
    module Records
      module Primitives
        # EmfPlusBlendColors (2.2.2.4).
        class BlendColors < Body
          endian :little
          uint32 :position_count
          bounded_array :blend_positions, type: :float32_le, element_size: 4, initial_length: :position_count
          bounded_array :blend_colors, type: :argb, element_size: 4, initial_length: :position_count
        end
      end
    end
  end
end
