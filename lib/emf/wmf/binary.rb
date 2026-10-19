# frozen_string_literal: true

module Emf
  module Wmf
    module Binary
      PLACEABLE_KEY = 0x9AC6CDD7
      HEADER_BYTES = 18
      PLACEABLE_BYTES = 22
      MAX_INPUT_BYTES = 200 * 1024 * 1024
      MAX_RECORDS = 1_000_000

      FIXED_RECORDS = {
        0x14 => Model::Wmf::Records::MoveTo,
        0x13 => Model::Wmf::Records::LineTo,
        0x0B => Model::Wmf::Records::SetWindowOrg,
        0x0C => Model::Wmf::Records::SetWindowExt,
        0x0D => Model::Wmf::Records::SetViewportOrg,
        0x0E => Model::Wmf::Records::SetViewportExt,
        0x18 => Model::Wmf::Records::Ellipse,
        0x1B => Model::Wmf::Records::Rectangle
      }.freeze
      FIXED_FUNCTIONS = FIXED_RECORDS.invert.freeze

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
