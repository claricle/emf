# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/with_bounds"

module Emf
  module Emr
    module Binary
      module Records
        class RoundRect < Emf::Emr::Binary::WithBounds
          rectl :rcl_box
          size_l :szl_corner
        end
      end
    end
  end
end
