# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        # Body-backed byte spans retain the driver's raw name, data and padding.
        class NamedEscape < Emf::Emr::Binary::Record
          rest :body

          def i_escape
            named_escape_body.byteslice(0, 4).unpack1("V")
          end

          def i_escape=(value)
            bytes = named_escape_body
            raise ArgumentError, "i_escape must be an Integer" unless value.is_a?(Integer)
            raise RangeError, "i_escape must fit in an unsigned 32-bit field" unless value.between?(0, 0xFFFFFFFF)

            bytes[0, 4] = [value].pack("V")
            self.body = bytes
          end

          def cj_driver
            named_escape_body.byteslice(4, 4).unpack1("V")
          end

          def cj_in
            named_escape_body.byteslice(8, 4).unpack1("V")
          end

          def driver_name_bytes
            bytes = named_escape_body
            length = bytes.byteslice(4, 4).unpack1("V")
            validate_span!(bytes, 12, length, "driver name")
            bytes.byteslice(12, length).b
          end

          def driver_name_bytes=(value)
            bytes = named_escape_body
            length = bytes.byteslice(4, 4).unpack1("V")
            validate_span!(bytes, 12, length, "driver name")
            validate_bytes!(value, length, "driver name")
            bytes[12, length] = value.b
            self.body = bytes
          end

          def data_bytes
            bytes = named_escape_body
            driver_length = bytes.byteslice(4, 4).unpack1("V")
            data_length = bytes.byteslice(8, 4).unpack1("V")
            data_offset = 12 + driver_length
            validate_span!(bytes, 12, driver_length, "driver name")
            validate_span!(bytes, data_offset, data_length, "data")
            bytes.byteslice(data_offset, data_length).b
          end

          def data_bytes=(value)
            bytes = named_escape_body
            driver_length = bytes.byteslice(4, 4).unpack1("V")
            data_length = bytes.byteslice(8, 4).unpack1("V")
            data_offset = 12 + driver_length
            validate_span!(bytes, 12, driver_length, "driver name")
            validate_span!(bytes, data_offset, data_length, "data")
            validate_bytes!(value, data_length, "data")
            bytes[data_offset, data_length] = value.b
            self.body = bytes
          end

          private

          def named_escape_body
            bytes = body.to_s.b
            raise ArgumentError, "truncated named escape prefix" if bytes.bytesize < 12

            bytes
          end

          def validate_span!(bytes, offset, length, name)
            raise ArgumentError, "truncated named escape #{name}" if length > bytes.bytesize - offset
          end

          def validate_bytes!(value, length, name)
            valid = value.is_a?(String) && value.bytesize == length
            raise ArgumentError, "#{name} must be a String of #{length} bytes" unless valid
          end
        end
      end
    end
  end
end
