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
        0x0F => Model::Wmf::Records::OffsetWindowOrg,
        0x11 => Model::Wmf::Records::OffsetViewportOrg,
        0x17 => Model::Wmf::Records::Arc,
        0x18 => Model::Wmf::Records::Ellipse,
        0x1A => Model::Wmf::Records::Pie,
        0x1B => Model::Wmf::Records::Rectangle,
        0x1C => Model::Wmf::Records::RoundRect,
        0x30 => Model::Wmf::Records::Chord
      }.freeze
      FIXED_FUNCTIONS = FIXED_RECORDS.invert.freeze

      POINT_ARRAY_RECORDS = {
        0x24 => Model::Wmf::Records::Polygon,
        0x25 => Model::Wmf::Records::Polyline,
        0x38 => Model::Wmf::Records::PolyPolygon
      }.freeze
      POINT_ARRAY_FUNCTIONS = POINT_ARRAY_RECORDS.invert.freeze

      OBJECT_RECORDS = {
        0xFA => Model::Wmf::Records::CreatePenIndirect,
        0xFC => Model::Wmf::Records::CreateBrushIndirect,
        0x2D => Model::Wmf::Records::SelectObject,
        0xF0 => Model::Wmf::Records::DeleteObject
      }.freeze
      OBJECT_FUNCTIONS = OBJECT_RECORDS.invert.freeze
      # Opaque creators still consume the lowest available object-table slot.
      OBJECT_CREATORS = [0xFA, 0xFC, 0xFB, 0xF7, 0xF9, 0xFF, 0x42].freeze

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

      def uint32(value, name)
        integer(value, 0..0xFFFFFFFF, name)
      end

      def validate_objects(records, capacity)
        slots = Array.new(capacity, false)
        records.each do |record|
          function = record.type_id & 0xFF
          if OBJECT_CREATORS.include?(function)
            index = slots.index(false)
            yield record, "object table capacity exceeded" unless index
            slots[index] = true
          elsif record.is_a?(Model::Wmf::Records::ObjectReference)
            index = record.object_index
            # Preserve high-bit stock selectors without interpreting their numeric ID.
            next if record.is_a?(Model::Wmf::Records::SelectObject) && index.anybits?(0x8000)

            yield record, "invalid object reference #{index}" unless index < capacity && slots[index]
            slots[index] = false if record.is_a?(Model::Wmf::Records::DeleteObject)
          end
        end
      end

      def int16(value, name)
        integer(value, -0x8000..0x7FFF, name)
      end
    end
  end
end
