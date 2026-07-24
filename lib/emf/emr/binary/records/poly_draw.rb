# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/with_bounds"

module Emf
  module Emr
    module Binary
      module Records
        class PolyDraw < Emf::Emr::Binary::WithBounds
          uint32 :cptl
          array :aptl, type: :point_l, initial_length: :cptl
          array :ab_types, type: :uint8, initial_length: :cptl
        end
      end
    end
  end
end
