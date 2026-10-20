# frozen_string_literal: true

require "emf/wmf/text_codec"
require "emf/wmf/palette_codec"

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

      STATE_RECORDS = {
        0x01 => Model::Wmf::Records::SetBkColor,
        0x02 => Model::Wmf::Records::SetBkMode,
        0x03 => Model::Wmf::Records::SetMapMode,
        0x31 => Model::Wmf::Records::SetMapperFlags,
        0x06 => Model::Wmf::Records::SetPolyFillMode,
        0x04 => Model::Wmf::Records::SetRop2,
        0x07 => Model::Wmf::Records::SetStretchBltMode,
        0x2E => Model::Wmf::Records::SetTextAlign,
        0x08 => Model::Wmf::Records::SetTextCharExtra,
        0x09 => Model::Wmf::Records::SetTextColor,
        0x0A => Model::Wmf::Records::SetTextJustification,
        0x49 => Model::Wmf::Records::SetLayout
      }.freeze
      STATE_FUNCTIONS = STATE_RECORDS.invert.freeze
      PREFIX_FUNCTIONS = ([0xFB] + STATE_RECORDS.keys + PaletteCodec::RECORDS.keys).freeze

      OBJECT_RECORDS = {
        0xFA => Model::Wmf::Records::CreatePenIndirect,
        0xFC => Model::Wmf::Records::CreateBrushIndirect,
        0x2D => Model::Wmf::Records::SelectObject,
        0xF0 => Model::Wmf::Records::DeleteObject
      }.freeze
      OBJECT_FUNCTIONS = OBJECT_RECORDS.invert.freeze
      # Opaque creators still consume the lowest available object-table slot.
      OBJECT_CREATORS = [0xFA, 0xFC, 0xFB, 0xF7, 0xF9, 0xFF, 0x42].freeze
      TEXT_FUNCTIONS = [0x21, 0x32].freeze
      TYPED_FUNCTIONS = (FIXED_RECORDS.keys + POINT_ARRAY_RECORDS.keys + OBJECT_RECORDS.keys + STATE_RECORDS.keys +
                         TEXT_FUNCTIONS + PaletteCodec::RECORDS.keys + [0xFB]).freeze

      module_function

      def checksum(bytes)
        bytes.unpack("v10").reduce(0, :^)
      end

      def integer(value, range, name)
        return value if value.is_a?(Integer) && range.cover?(value)

        raise SerializeError, "WMF #{name} out of range: #{value.inspect}"
      end

      def uint8(value, name)
        integer(value, 0..0xFF, name)
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
            slots[index] = function
          elsif record.is_a?(Model::Wmf::Records::ObjectReference)
            validate_object_reference(record, capacity, slots) { |message| yield record, message }
          end
        end
      end

      def validate_object_reference(record, capacity, slots)
        index = record.object_index
        # Preserve high-bit stock selectors without interpreting their numeric ID.
        return if record.is_a?(Model::Wmf::Records::SelectObject) && index.anybits?(0x8000)

        yield "invalid object reference #{index}" unless index < capacity && slots[index]
        yield "object reference #{index} is not a palette" if record.is_a?(Model::Wmf::Records::SelectPalette) && slots[index] != 0xF7
        slots[index] = false if record.is_a?(Model::Wmf::Records::DeleteObject)
      end

      def int16(value, name)
        integer(value, -0x8000..0x7FFF, name)
      end
    end
  end
end
