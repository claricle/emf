# frozen_string_literal: true

require "bindata"
require "emf/emf_plus/records/primitives/relative_coordinate"

module Emf
  module EmfPlus
    module Records
      module Primitives
        # EmfPlusPointR (2.2.2.37): relative location, each axis 7 or 15 bits.
        class PointR < BinData::Record
          endian :little
          relative_coordinate :x
          relative_coordinate :y
        end
      end
    end
  end
end
