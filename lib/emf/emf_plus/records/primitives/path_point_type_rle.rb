# frozen_string_literal: true

require "bindata"
require "emf/emf_plus/records/primitives/path_point_type"

module Emf
  module EmfPlus
    module Records
      module Primitives
        # EmfPlusPathPointTypeRLE (2.2.2.32): a Bezier bit, a reserved bit and
        # a 6-bit run count, then the type shared by that many points.
        class PathPointTypeRLE < BinData::Record
          endian :little
          uint8 :header
          path_point_type :point_type

          def bezier? = header.anybits?(0x80)
          def run_count = header & 0x3F
        end
      end
    end
  end
end
