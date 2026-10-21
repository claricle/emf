# frozen_string_literal: true

require "bindata"

module Emf
  module Binary
    # Little-endian IEEE 754 single that writes back the exact bits it read.
    # Ruby widens a float32 to a double on read but `pack("e")` canonicalises
    # every NaN to 0x7fc00000, so NaN payloads (and signalling NaNs) would
    # otherwise change on a parse -> serialize round trip. Only NaNs carry
    # their bits; every other value re-encodes exactly through the Float.
    # Assigning a value drops the retained bits.
    class Float32Le < BinData::BasePrimitive
      def initialize_instance
        super
        @nan_bits = nil
      end

      def assign(val)
        @nan_bits = nil
        super
      end

      def assign_bits(bits)
        @value = [bits].pack("V").unpack1("e")
        @nan_bits = @value.nan? ? bits : nil
        bits
      end

      def do_num_bytes
        4
      end

      private

      def sensible_default
        0.0
      end

      def read_and_return_value(io)
        raw = io.readbytes(4)
        value = raw.unpack1("e")
        @nan_bits = value.nan? ? raw.unpack1("V") : nil
        value
      end

      def value_to_binary_string(val)
        return [@nan_bits].pack("V") if @nan_bits

        [val].pack("e")
      end
    end
  end
end
