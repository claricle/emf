# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        # Body-backed fields retain driver-specific bytes and trailing padding.
        class ExtEscape < Emf::Emr::Binary::Record
          rest :body

          def i_escape
            escape_body.byteslice(0, 4).unpack1("V")
          end

          def i_escape=(value)
            bytes = escape_body
            valid = value.is_a?(Integer) && value.between?(0, 0xFFFFFFFF)
            raise ArgumentError, "i_escape must be an unsigned 32-bit Integer" unless valid

            bytes[0, 4] = [value].pack("V")
            self.body = bytes
          end

          def cj_in
            escape_body.byteslice(4, 4).unpack1("V")
          end

          def data_bytes
            bytes = escape_body
            length = bytes.byteslice(4, 4).unpack1("V")
            raise ArgumentError, "truncated escape data" if length > bytes.bytesize - 8

            bytes.byteslice(8, length).b
          end

          def data_bytes=(value)
            length = data_bytes.bytesize
            valid = value.is_a?(String) && value.bytesize == length
            raise ArgumentError, "escape data must be a String of #{length} bytes" unless valid

            bytes = escape_body
            bytes[8, length] = value.b
            self.body = bytes
          end

          private

          def escape_body
            bytes = body.to_s.b
            raise ArgumentError, "truncated escape record prefix" if bytes.bytesize < 8

            bytes
          end
        end
      end
    end
  end
end
