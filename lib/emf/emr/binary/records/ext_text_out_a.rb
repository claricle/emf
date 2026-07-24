# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/with_bounds"

module Emf
  module Emr
    module Binary
      module Records
        # EMR_EXTTEXTOUTA per MS-EMF 2.3.8.1. Same layout as ExtTextOutW
        # except the string is 8-bit ANSI (codepage-dependent) rather
        # than UTF-16LE.
        class ExtTextOutA < Emf::Emr::Binary::WithBounds
          uint32 :i_graphics_mode
          float :ex_scale
          float :ey_scale
          int16 :wmf_rect_left
          int16 :wmf_rect_top
          int16 :wmf_rect_right
          int16 :wmf_rect_bottom
          uint32 :n_chars
          uint32 :off_string
          uint32 :f_options
          int16 :wmf_rect2_left
          int16 :wmf_rect2_top
          int16 :wmf_rect2_right
          int16 :wmf_rect2_bottom
          uint32 :off_dx
          rest :trailing
        end
      end
    end
  end
end
