# frozen_string_literal: true

require_relative "wmf_text_fields"
require_relative "wmf_palette_fields"
require_relative "wmf_region_fields"
require_relative "wmf_brush_fields"
require_relative "wmf_bitmap_fields"
require_relative "wmf_remaining_fields"

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
        return prefix_record if Wmf::Binary::PREFIX_FUNCTIONS.include?(@function)
        return fixed(Wmf::Binary::OBJECT_RECORDS.fetch(@function), 4) if Wmf::Binary::OBJECT_RECORDS.key?(@function)
        return WmfTextFields.new(@record, @raw).call if Wmf::Binary::TEXT_FUNCTIONS.include?(@function)
        return points(Wmf::Binary::POINT_ARRAY_RECORDS.fetch(@function)) if Wmf::Binary::POINT_ARRAY_RECORDS.key?(@function)
        return fixed(Wmf::Binary::FIXED_RECORDS.fetch(@function), 2) if Wmf::Binary::FIXED_RECORDS.key?(@function)

        Model::Wmf::Records::UnknownRecord.new(type_id: @type, raw_bytes: @raw, offset: @offset)
      end

      private

      def prefix_record
        if Wmf::GeometryCodec::RECORDS.key?(@function) || Wmf::DcEscapeCodec::RECORDS.key?(@function)
          return WmfRemainingFields.new(@record, @raw).call
        end
        return WmfBitmapFields.new(@record, @raw).call if Wmf::BitmapCodec::RECORDS.key?(@function)

        return WmfBrushFields.new(@record, @raw).call if Wmf::BrushCodec::RECORDS.key?(@function)
        return font if @function == 0xFB
        return state(Wmf::Binary::STATE_RECORDS.fetch(@function)) if Wmf::Binary::STATE_RECORDS.key?(@function)

        if Wmf::RegionCodec::RECORDS.key?(@function)
          WmfRegionFields.new(@record, @raw).call
        else
          WmfPaletteFields.new(@record, @raw).call
        end
      end

      def font
        klass = Model::Wmf::Records::CreateFontIndirect
        prefix_size = 6 + klass::PAYLOAD_BYTES
        validate(@record.fetch(:family) == 7 && @payload.bytesize == 84 &&
                 @raw.bytesize >= prefix_size && @raw.bytesize.even?)
        signed = @payload.byteslice(0, 20).unpack("l<5")
        bytes = @payload.byteslice(20, 32).unpack("V8")
        validate(signed.all? { |value| value.between?(-0x8000, 0x7FFF) } && bytes.all? { |value| value <= 0xFF })
        values = signed + bytes + [@payload.byteslice(52, 32)]
        fields = klass::WIRE_FIELDS.zip(values).to_h
        klass.new(**fields, type_id: @type, offset: @offset, suffix: @raw.byteslice(prefix_size..))
      end

      def state(klass)
        fields = klass::WIRE_FIELDS
        prefix_size = 6 + klass::PAYLOAD_BYTES
        validate(@record.fetch(:family) == 6 && @payload.bytesize == fields.length * 4 &&
                 @raw.bytesize >= prefix_size && @raw.bytesize.even?)
        values = @payload.unpack("V*")
        values.zip(klass::WIRE_TYPES).each do |value, type|
          validate(type != :uint16 || value <= 0xFFFF)
        end
        klass.new(**fields.zip(values).to_h, type_id: @type, offset: @offset, suffix: @raw.byteslice(prefix_size..))
      end

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
