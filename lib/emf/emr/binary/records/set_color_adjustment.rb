# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        class SetColorAdjustment < Emf::Emr::Binary::Record
          rest :body

          def adjustment_size
            read_adjustment_value(0, "v")
          end

          def adjustment_size=(value)
            write_adjustment_value(0, value)
          end

          def values
            read_adjustment_value(2, "v")
          end

          def values=(value)
            write_adjustment_value(2, value)
          end

          def illuminant_index
            read_adjustment_value(4, "v")
          end

          def illuminant_index=(value)
            write_adjustment_value(4, value)
          end

          def red_gamma
            read_adjustment_value(6, "v")
          end

          def red_gamma=(value)
            write_adjustment_value(6, value)
          end

          def green_gamma
            read_adjustment_value(8, "v")
          end

          def green_gamma=(value)
            write_adjustment_value(8, value)
          end

          def blue_gamma
            read_adjustment_value(10, "v")
          end

          def blue_gamma=(value)
            write_adjustment_value(10, value)
          end

          def reference_black
            read_adjustment_value(12, "v")
          end

          def reference_black=(value)
            write_adjustment_value(12, value)
          end

          def reference_white
            read_adjustment_value(14, "v")
          end

          def reference_white=(value)
            write_adjustment_value(14, value)
          end

          def contrast
            read_adjustment_value(16, "s<")
          end

          def contrast=(value)
            write_adjustment_value(16, value, signed: true)
          end

          def brightness
            read_adjustment_value(18, "s<")
          end

          def brightness=(value)
            write_adjustment_value(18, value, signed: true)
          end

          def colorfulness
            read_adjustment_value(20, "s<")
          end

          def colorfulness=(value)
            write_adjustment_value(20, value, signed: true)
          end

          def red_green_tint
            read_adjustment_value(22, "s<")
          end

          def red_green_tint=(value)
            write_adjustment_value(22, value, signed: true)
          end

          private

          def adjustment_body
            bytes = body.to_s
            raise ArgumentError, "invalid color adjustment body length" if bytes.bytesize < 24

            bytes
          end

          def read_adjustment_value(offset, format)
            adjustment_body.byteslice(offset, 2).unpack1(format)
          end

          def write_adjustment_value(offset, value, signed: false)
            bytes = adjustment_body.dup
            raise ArgumentError, "color adjustment value must be an Integer" unless value.is_a?(Integer)

            bounds = signed ? (-32_768..32_767) : (0..65_535)
            raise RangeError, "color adjustment value must fit its 16-bit integer field" unless bounds.cover?(value)

            bytes[offset, 2] = [value].pack(signed ? "s<" : "v")
            self.body = bytes
          end
        end
      end
    end
  end
end
