# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/with_bounds"

module Emf
  module Emr
    module Binary
      module Records
        class ExtTextOutA < Emf::Emr::Binary::WithBounds
          uint32 :i_graphics_mode
          float :ex_scale
          float :ey_scale
          rest :body
        end
      end
    end
  end
end
