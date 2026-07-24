# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/with_bounds"

module Emf
  module Emr
    module Binary
      module Records
        # EMR_EXTTEXTOUTA per MS-EMF 2.3.8.1. Same EMRTEXT layout as
        # ExtTextOutW except the string is 8-bit ANSI.
        class ExtTextOutA < Emf::Emr::Binary::WithBounds
          uint32 :i_graphics_mode
          float :ex_scale
          float :ey_scale
          point_l :ptl_reference
          uint32 :n_chars
          uint32 :off_string
          uint32 :f_options
          rectl :rcl
          uint32 :off_dx
          rest :trailing
        end
      end
    end
  end
end
