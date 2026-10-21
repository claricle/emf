# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        # Universal font identifiers retain their original byte representation.
        class ForceUfiMapping < Emf::Emr::Binary::Record
          rest :body

          [[:ufi_checksum, 0], [:ufi_index, 4]].each do |name, offset|
            define_method(name) { ufi_body.byteslice(offset, 4).unpack1("V") }
            define_method("#{name}=") do |value|
              ufi_body
              raise ArgumentError, "UFI value must be an Integer" unless value.is_a?(Integer)
              raise RangeError, "UFI value must fit an unsigned 32-bit integer" unless (0..0xFFFFFFFF).cover?(value)

              replace_ufi_bytes(offset, 4, [value].pack("V"))
            end
          end

          def ufi_bytes
            ufi_body.byteslice(0, 8).b
          end

          def ufi_bytes=(value)
            replace_ufi_bytes(0, 8, value)
          end

          private

          def ufi_body
            bytes = body.to_s
            raise ArgumentError, "truncated universal font identifier" if bytes.bytesize < 8

            bytes
          end

          def replace_ufi_bytes(offset, length, value)
            bytes = ufi_body
            raise ArgumentError, "UFI value must be a String of #{length} bytes" unless value.is_a?(String) && value.bytesize == length

            replacement = bytes.b
            replacement[offset, length] = value.b
            self.body = replacement
          end
        end
      end
    end
  end
end
