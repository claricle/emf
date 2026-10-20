# frozen_string_literal: true

require "bindata"
require "emf/emf_plus/records/primitives/argb"

module Emf
  module EmfPlus
    module Records
      module Primitives
        # EmfPlusPalette (2.2.2.28).
        class Palette < BinData::Record
          endian :little
          uint32 :palette_style_flags
          uint32 :palette_count
          array :palette_entries, type: :argb, initial_length: :palette_count
        end
      end
    end
  end
end
