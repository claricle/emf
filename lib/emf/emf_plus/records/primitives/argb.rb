# frozen_string_literal: true

require "bindata"

module Emf
  module EmfPlus
    module Records
      module Primitives
        # EmfPlusARGB (2.2.2.1): bytes are stored blue, green, red, alpha.
        class ARGB < BinData::Record
          endian :little
          uint8 :blue
          uint8 :green
          uint8 :red
          uint8 :alpha
        end
      end
    end
  end
end
