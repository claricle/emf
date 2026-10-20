# frozen_string_literal: true

require "bindata"
require "emf/emf_plus/records/primitives/argb"

module Emf
  module EmfPlus
    module Records
      module Primitives
        # EmfPlusBlendColors (2.2.2.4).
        class BlendColors < BinData::Record
          endian :little
          uint32 :position_count
          array :blend_positions, type: :float_le, initial_length: :position_count
          array :blend_colors, type: :argb, initial_length: :position_count
        end
      end
    end
  end
end
