# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        # Linked identifiers preserve the declared count and ignored reserved bytes.
        class SetLinkedUfis < Emf::Emr::Binary::Record
          rest :body

          def u_num_linked_ufi
            bytes = body.to_s
            raise ArgumentError, "truncated linked UFI count" if bytes.bytesize < 4

            bytes.unpack1("V")
          end

          [[:ufi_checksum, 0], [:ufi_index, 4]].each do |name, offset|
            define_method(name) do |index|
              position = ufi_position(index)
              body.to_s.byteslice(position + offset, 4).unpack1("V")
            end

            define_method("set_#{name}") do |index, value|
              position = ufi_position(index)
              raise ArgumentError, "UFI value must be an Integer" unless value.is_a?(Integer)
              raise RangeError, "UFI value must fit an unsigned 32-bit integer" unless (0..0xFFFFFFFF).cover?(value)

              replace_ufi_bytes(position + offset, 4, [value].pack("V"))
            end
          end

          def ufi_bytes(index)
            body.to_s.byteslice(ufi_position(index), 8).b
          end

          def set_ufi_bytes(index, value)
            replace_ufi_bytes(ufi_position(index), 8, value)
          end

          private

          def ufi_position(index)
            count = u_num_linked_ufi
            raise ArgumentError, "truncated linked UFI array or reserved bytes" if 12 + (count * 8) > body.to_s.bytesize
            raise ArgumentError, "UFI index must identify a declared entry" unless index.is_a?(Integer) && index >= 0 && index < count

            4 + (index * 8)
          end

          def replace_ufi_bytes(offset, length, value)
            raise ArgumentError, "UFI value must be a String of #{length} bytes" unless value.is_a?(String) && value.bytesize == length

            replacement = body.to_s.b
            replacement[offset, length] = value.b
            self.body = replacement
          end
        end
      end
    end
  end
end
