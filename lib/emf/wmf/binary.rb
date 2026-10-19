# frozen_string_literal: true

module Emf
  module Wmf
    module Binary
      PLACEABLE_KEY = 0x9AC6CDD7
      HEADER_BYTES = 18
      PLACEABLE_BYTES = 22
      MAX_INPUT_BYTES = 200 * 1024 * 1024
      MAX_RECORDS = 1_000_000

      module_function

      def checksum(bytes)
        bytes.unpack("v10").reduce(0, :^)
      end

      def integer(value, range, name)
        return value if value.is_a?(Integer) && range.cover?(value)

        raise SerializeError, "WMF #{name} out of range: #{value.inspect}"
      end

      def uint16(value, name)
        integer(value, 0..0xFFFF, name)
      end

      def int16(value, name)
        integer(value, -0x8000..0x7FFF, name)
      end
    end
  end
end
