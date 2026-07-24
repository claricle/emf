# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      # Many drawing records start with an RECTL bounding box after the header.
      class WithBounds < Emf::Emr::Binary::Record
        rectl :rcl_bounds
      end
    end
  end
end
