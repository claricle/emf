# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/with_bounds"
require "emf/emr/binary/ext_text_out_fields"

module Emf
  module Emr
    module Binary
      module Records
        # EMR_EXTTEXTOUTA per MS-EMF 2.3.8.1. Same EMRTEXT layout as
        # ExtTextOutW except the string is 8-bit ANSI.
        class ExtTextOutA < Emf::Emr::Binary::WithBounds
          uint32 :i_graphics_mode
          float32_le :ex_scale
          float32_le :ey_scale
          point_l :ptl_reference
          uint32 :n_chars
          uint32 :off_string
          uint32 :f_options
          rectl :rcl, onlyif: -> { f_options.nobits?(0x100) }
          uint32 :off_dx
          rest :trailing

          include Emf::Emr::Binary::ExtTextOutFields

          private

          def char_size = 1

          # ANSI bytes read as Windows-1252; the real code page is the selected
          # font's charset, which this record does not carry.
          def decode_text(bytes)
            bytes.dup.force_encoding(Encoding::Windows_1252).encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
          end
        end
      end
    end
  end
end
