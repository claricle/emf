# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/variable_buffers"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        class ColorCorrectPalette < Emf::Emr::Binary::Record
          include Emf::Emr::Binary::VariableBuffers

          fixed_layout 24

          rest :body

          def ih_palette
            palette_body.byteslice(0, 4).unpack1("V")
          end

          def ih_palette=(value)
            write_palette_value(0, value)
          end

          def first_entry
            palette_body.byteslice(4, 4).unpack1("V")
          end

          def first_entry=(value)
            write_palette_value(4, value)
          end

          def entry_count
            palette_body.byteslice(8, 4).unpack1("V")
          end

          def entry_count=(value)
            write_palette_value(8, value)
          end

          def reserved
            palette_body.byteslice(12, 4).unpack1("V")
          end

          def reserved=(value)
            write_palette_value(12, value)
          end

          private

          def palette_body
            bytes = body.to_s
            raise ArgumentError, "invalid color correct palette body length" if bytes.bytesize < 16

            bytes
          end

          def write_palette_value(offset, value)
            bytes = palette_body.dup
            raise ArgumentError, "palette value must be an Integer" unless value.is_a?(Integer)
            raise RangeError, "palette value must fit an unsigned 32-bit integer" unless (0..0xffffffff).cover?(value)

            bytes[offset, 4] = [value].pack("V")
            self.body = bytes
          end
        end
      end
    end
  end
end
