# frozen_string_literal: true

require_relative "wmf_text_fields"

module Emf
  module Native
    class WmfFields
      def initialize(record, raw)
        @record = record
        @raw = raw
        @type = record.fetch(:type)
        @offset = record.fetch(:offset)
        @payload = record.fetch(:payload)
        @function = @type & 0xFF
      end

      def call
        if @type.zero?
          validate(@record.fetch(:family) == 1 && @payload.empty? && @raw.bytesize == 6)
          return Model::Wmf::Records::Eof.new(offset: @offset)
        end
        return fixed(Wmf::Binary::OBJECT_RECORDS.fetch(@function), 4) if Wmf::Binary::OBJECT_RECORDS.key?(@function)
        return WmfTextFields.new(@record, @raw).call if Wmf::Binary::TEXT_FUNCTIONS.include?(@function)
        return points(Wmf::Binary::POINT_ARRAY_RECORDS.fetch(@function)) if Wmf::Binary::POINT_ARRAY_RECORDS.key?(@function)
        return fixed(Wmf::Binary::FIXED_RECORDS.fetch(@function), 2) if Wmf::Binary::FIXED_RECORDS.key?(@function)

        Model::Wmf::Records::UnknownRecord.new(type_id: @type, raw_bytes: @raw, offset: @offset)
      end

      private

      def fixed(klass, family)
        fields = klass::WIRE_FIELDS
        wire_size = family == 4 ? klass::PAYLOAD_BYTES : fields.length * 2
        validate(@record.fetch(:family) == family && @payload.bytesize == fields.length * 4 && @raw.bytesize == wire_size + 6)
        values = @payload.unpack(family == 4 ? "V*" : "l<*")
        if family == 4
          values = values.zip(klass::WIRE_TYPES).map { |value, type| type == :int16 && value >= 0x80000000 ? value - 0x100000000 : value }
        end
        klass.new(**fields.zip(values).to_h, type_id: @type, offset: @offset)
      end

      def points(klass)
        validate(@record.fetch(:family) == 3 && @payload.bytesize >= 16)
        count, polygons = @payload.unpack("Q<2")
        validate(@payload.bytesize == 16 + (polygons * 4) + (count * 8))
        counts = @payload.byteslice(16, polygons * 4).unpack("V*")
        multi = klass == Model::Wmf::Records::PolyPolygon
        if multi
          validate(@raw.bytesize == 8 + (polygons * 2) + (count * 4) && counts.sum == count)
        else
          minimum = klass == Model::Wmf::Records::Polygon ? 2 : 0
          validate(polygons.zero? && count.between?(minimum, 0x7FFF) && @raw.bytesize == 8 + (count * 4))
        end
        coordinates = @payload.byteslice((16 + (polygons * 4))..).unpack("l<*")
        points = coordinates.each_slice(2).map { |x, y| Model::Wmf::Records::PointS.new(x: x, y: y) }
        fields = { points: points, type_id: @type, offset: @offset }
        fields[:points_per_polygon] = counts if multi
        klass.new(**fields)
      end

      def validate(condition)
        return if condition

        raise ParseError.new(offset: @offset, record_code: @type, message: "invalid native WMF typed record at offset #{@offset}")
      end
    end
  end
end
