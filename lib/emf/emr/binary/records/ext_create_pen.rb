# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"
require "emf/emr/binary/extended_pen_buffers"

module Emf
  module Emr
    module Binary
      module Records
        class ExtCreatePen < Emf::Emr::Binary::Record
          uint32 :ih_pen
          uint32 :off_bmi
          uint32 :cb_bmi
          uint32 :off_bits
          uint32 :cb_bits
          uint32 :pen_style
          uint32 :width
          uint32 :brush_style
          color_ref :color
          uint32 :brush_hatch
          uint32 :num_style_entries
          array :style_entries, type: :uint32, initial_length: :num_style_entries
          extended_pen_buffers :buffers,
                               fixed_size: -> { 52 + (num_style_entries * 4) },
                               first_offset: -> { bits_first? ? off_bits : off_bmi },
                               first_length: -> { bits_first? ? cb_bits : cb_bmi },
                               second_offset: -> { bits_first? ? off_bmi : off_bits },
                               second_length: -> { bits_first? ? cb_bmi : cb_bits }

          def bits_first?
            off_bits.positive? && (off_bmi.zero? || off_bits < off_bmi || (off_bits == off_bmi && cb_bits.zero?))
          end

          def bitmap_info
            return if off_bmi.zero?

            bits_first? ? buffers.second_bitmap : buffers.first_bitmap
          end

          def bitmap_bits
            return if off_bits.zero?

            bits_first? ? buffers.first_bitmap : buffers.second_bitmap
          end

          def info_padding
            bits_first? ? buffers.second_padding : buffers.first_padding
          end

          def bits_padding
            bits_first? ? buffers.first_padding : buffers.second_padding
          end

          def trailing
            buffers.trailing
          end

          # Sizes, counts and offsets are explicit, as in the text wire records.
          # Update them when changing the lengths of styles or bitmap buffers.
          def body
            to_binary_s.byteslice(12..)
          end
        end
      end
    end
  end
end
