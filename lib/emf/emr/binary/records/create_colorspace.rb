# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        # Logical color space fields retain their original fixed-width wire bytes.
        class CreateColorspace < Emf::Emr::Binary::Record
          rest :body

          [
            [:ih_cs, 0, "V", 4],
            [:lcs_signature, 4, "V", 332],
            [:lcs_version, 8, "V", 332],
            [:lcs_size, 12, "V", 332],
            [:color_space_type, 16, "l<", 332],
            [:intent, 20, "l<", 332],
            [:gamma_red, 60, "V", 332],
            [:gamma_green, 64, "V", 332],
            [:gamma_blue, 68, "V", 332]
          ].each do |name, offset, format, required|
            define_method(name) do
              colorspace_body(required).byteslice(offset, 4).unpack1(format)
            end

            define_method("#{name}=") do |value|
              write_colorspace_value(offset, value, format, required)
            end
          end

          def endpoints_bytes
            colorspace_body(332).byteslice(24, 36).b
          end

          def endpoints_bytes=(value)
            replace_colorspace_bytes(24, 36, value, 332)
          end

          def filename_bytes
            colorspace_body(332).byteslice(72, 260).b
          end

          def filename_bytes=(value)
            replace_colorspace_bytes(72, 260, value, 332)
          end

          private

          def colorspace_body(required)
            bytes = body.to_s
            raise ArgumentError, "truncated logical color space body" if bytes.bytesize < required

            bytes
          end

          def write_colorspace_value(offset, value, format, required)
            colorspace_body(required)
            raise ArgumentError, "color space value must be an Integer" unless value.is_a?(Integer)

            range = format == "l<" ? (-0x80000000..0x7fffffff) : (0..0xffffffff)
            raise RangeError, "color space value must fit its 32-bit field" unless range.cover?(value)

            replace_colorspace_bytes(offset, 4, [value].pack(format), required)
          end

          def replace_colorspace_bytes(offset, length, value, required)
            bytes = colorspace_body(required)
            unless value.is_a?(String) && value.bytesize == length
              raise ArgumentError, "color space value must be a String of #{length} bytes"
            end

            replacement = bytes.b
            replacement[offset, length] = value.b
            self.body = replacement
          end
        end
      end
    end
  end
end
