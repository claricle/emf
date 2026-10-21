# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        # Pixel format fields retain their original fixed-width descriptor bytes.
        class PixelFormat < Emf::Emr::Binary::Record
          rest :body

          [
            [:pfd_size, 0, "v", 2],
            [:pfd_version, 2, "v", 2],
            [:dw_flags, 4, "V", 4],
            [:i_pixel_type, 8, "C", 1],
            [:c_color_bits, 9, "C", 1],
            [:c_red_bits, 10, "C", 1],
            [:c_red_shift, 11, "C", 1],
            [:c_green_bits, 12, "C", 1],
            [:c_green_shift, 13, "C", 1],
            [:c_blue_bits, 14, "C", 1],
            [:c_blue_shift, 15, "C", 1],
            [:c_alpha_bits, 16, "C", 1],
            [:c_alpha_shift, 17, "C", 1],
            [:c_accum_bits, 18, "C", 1],
            [:c_accum_red_bits, 19, "C", 1],
            [:c_accum_green_bits, 20, "C", 1],
            [:c_accum_blue_bits, 21, "C", 1],
            [:c_accum_alpha_bits, 22, "C", 1],
            [:c_depth_bits, 23, "C", 1],
            [:c_stencil_bits, 24, "C", 1],
            [:c_aux_buffers, 25, "C", 1],
            [:i_layer_type, 26, "C", 1],
            [:b_reserved, 27, "C", 1],
            [:dw_layer_mask, 28, "V", 4],
            [:dw_visible_mask, 32, "V", 4],
            [:dw_damage_mask, 36, "V", 4]
          ].each do |name, offset, format, width|
            define_method(name) do
              pixel_format_body.byteslice(offset, width).unpack1(format)
            end

            define_method("#{name}=") do |value|
              write_pixel_format_value(offset, value, format, width)
            end
          end

          def pfd_bytes
            pixel_format_body.byteslice(0, 40).b
          end

          def pfd_bytes=(value)
            replace_pixel_format_bytes(0, 40, value)
          end

          private

          def pixel_format_body
            bytes = body.to_s
            raise ArgumentError, "truncated pixel format descriptor" if bytes.bytesize < 40

            bytes
          end

          def write_pixel_format_value(offset, value, format, width)
            pixel_format_body
            raise ArgumentError, "pixel format value must be an Integer" unless value.is_a?(Integer)

            range = 0...(1 << (width * 8))
            raise RangeError, "pixel format value must fit its #{width * 8}-bit field" unless range.cover?(value)

            replace_pixel_format_bytes(offset, width, [value].pack(format))
          end

          def replace_pixel_format_bytes(offset, length, value)
            bytes = pixel_format_body
            unless value.is_a?(String) && value.bytesize == length
              raise ArgumentError, "pixel format value must be a String of #{length} bytes"
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
