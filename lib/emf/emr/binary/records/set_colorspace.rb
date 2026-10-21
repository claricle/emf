# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        class SetColorspace < Emf::Emr::Binary::Record
          rest :body

          def ih_cs
            colorspace_body.byteslice(0, 4).unpack1("V")
          end

          def ih_cs=(value)
            bytes = colorspace_body.dup
            raise ArgumentError, "colorspace handle must be an Integer" unless value.is_a?(Integer)
            raise RangeError, "colorspace handle must fit an unsigned 32-bit integer" unless (0..0xffffffff).cover?(value)

            bytes[0, 4] = [value].pack("V")
            self.body = bytes
          end

          private

          def colorspace_body
            bytes = body.to_s
            raise ArgumentError, "invalid colorspace body length" if bytes.bytesize < 4

            bytes
          end
        end
      end
    end
  end
end
