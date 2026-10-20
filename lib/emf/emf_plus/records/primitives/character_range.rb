# frozen_string_literal: true

require "bindata"

module Emf
  module EmfPlus
    module Records
      module Primitives
        # EmfPlusCharacterRange (2.2.2.8).
        # BinData reserves `first` and `length`, so the spec names First and
        # Length are first_position and range_length here.
        class CharacterRange < Body
          endian :little
          int32 :first_position
          int32 :range_length
        end
      end
    end
  end
end
