# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/with_bounds"

module Emf
  module Emr
    module Binary
      module Records
        class Arc < Emf::Emr::Binary::WithBounds
          rectl :rcl_box
          point_l :pt_start
          point_l :pt_end
        end
      end
    end
  end
end
