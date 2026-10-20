# frozen_string_literal: true

require "bindata"

module Emf
  module EmfPlus
    module Records
      module Primitives
        # EmfPlusPathPointType (2.2.2.31): flags in the high nibble, the
        # PathPointType enumeration in the low nibble.
        class PathPointType < Body
          endian :little
          uint8 :raw

          def flags = raw >> 4
          def type = raw & 0x0F
        end
      end
    end
  end
end
