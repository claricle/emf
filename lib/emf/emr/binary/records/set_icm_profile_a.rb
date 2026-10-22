# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/variable_buffers"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        # MS-EMF 2.3.11.15: name and profile lengths are byte counts.
        class SetIcmProfileA < Emf::Emr::Binary::Record
          include Emf::Emr::Binary::VariableBuffers

          fixed_layout 20
          variable_buffer :icm_name_bytes, offset: 20, length: -> { u32_at(12) }
          variable_buffer :icm_profile_bytes, offset: -> { 20 + u32_at(12) }, length: -> { u32_at(16) }

          # Byte counts and opaque spans retain the original body layout.
          rest :body

          def dw_flags
            profile_prefix.unpack1("V")
          end

          def dw_flags=(value)
            raise ArgumentError, "color profile flags must be an Integer" unless value.is_a?(Integer)
            raise RangeError, "color profile flags must fit an unsigned 32-bit integer" unless (0..0xFFFFFFFF).cover?(value)

            write_profile_bytes(0, 4, [value].pack("V"))
          end

          def cb_name
            profile_prefix.byteslice(4, 4).unpack1("V")
          end

          def cb_data
            profile_prefix.byteslice(8, 4).unpack1("V")
          end

          def name_bytes
            read_profile_bytes(12, cb_name)
          end

          def name_bytes=(value)
            write_profile_bytes(12, cb_name, value)
          end

          def profile_bytes
            read_profile_bytes(12 + cb_name, cb_data)
          end

          def profile_bytes=(value)
            write_profile_bytes(12 + cb_name, cb_data, value)
          end

          private

          def profile_prefix
            bytes = body.to_s
            raise ArgumentError, "truncated color profile prefix" if bytes.bytesize < 12

            bytes
          end

          def read_profile_bytes(offset, length)
            bytes = profile_prefix
            raise ArgumentError, "truncated color profile span" if offset + length > bytes.bytesize

            bytes.byteslice(offset, length).b
          end

          def write_profile_bytes(offset, length, value)
            read_profile_bytes(offset, length)
            unless value.is_a?(String) && value.bytesize == length
              raise ArgumentError, "color profile value must be a String of #{length} bytes"
            end

            bytes = body.to_s.b
            bytes[offset, length] = value.b
            self.body = bytes
          end
        end
      end
    end
  end
end
