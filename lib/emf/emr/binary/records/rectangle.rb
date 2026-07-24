# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/with_bounds"

module Emf
  module Emr
    module Binary
      module Records
        class Rectangle < Emf::Emr::Binary::WithBounds
          rectl :rcl_box
        end
      end
    end
  end
end
