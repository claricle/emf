# frozen_string_literal: true

require "bindata"
require "emf/binary/float32_le"
require "emf/emf_plus/records/primitives/argb"

module Emf
  module EmfPlus
    module Records
      module Primitives
        # EmfPlusBlendColors (2.2.2.4).
        class BlendColors < Body
          endian :little
          uint32 :position_count
          array :blend_positions, type: :float32_le, initial_length: :position_count
          array :blend_colors, type: :argb, initial_length: :position_count
        end
      end
    end
  end
end
