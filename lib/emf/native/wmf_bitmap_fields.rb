# frozen_string_literal: true

module Emf
  module Native
    class WmfBitmapFields
      def initialize(record, raw)
        @record = record
        @raw = raw
        @type = record.fetch(:type)
        @offset = record.fetch(:offset)
        @payload = record.fetch(:payload)
      end

      def call
        validate(@record.fetch(:family) == 11 && @raw.bytesize >= 6 && @raw.bytesize.even? &&
                 @payload.bytesize <= Wmf::Binary::MAX_INPUT_BYTES)
        validate(@raw.unpack("Vv") == [@raw.bytesize / 2, @type])
        kind = @type & 0xFF
        fields = decode_fields(kind)
        body = Wmf::BitmapCodec.encode_fields(fields, @type)
        validate(@raw.bytesize == body.bytesize + 6 && @raw.byteslice(6..) == body)
        Wmf::BitmapCodec::RECORDS.fetch(kind).new(**fields, type_id: @type, offset: @offset)
      rescue SerializeError
        validate(false)
      end

      private

      def decode_fields(kind)
        names = Wmf::BitmapCodec::FIELDS.fetch(kind)
        fixed = names.length * 4
        validate(@payload.bytesize >= fixed + 8)
        values = names.each_with_index.map do |field, index|
          format = Wmf::BitmapCodec.field_type(kind, field) == :int16 ? "l<" : "V"
          @payload.byteslice(index * 4, 4).unpack1(format)
        end
        names.zip(values).to_h.merge(image_fields(kind, fixed))
      end

      def image_fields(kind, fixed)
        presence, length = @payload.byteslice(fixed, 8).unpack("V2")
        validate([0, 1].include?(presence) && @payload.bytesize == fixed + 8 + length)
        absent = presence.zero?
        validate(absent ? Wmf::BitmapCodec.optional?(kind) && length.zero? : length.positive? && length.even?)
        prefix = Wmf::BitmapCodec.wire_fields(kind, absent).sum { |field| field == :raster_operation ? 4 : 2 }
        validate(@raw.bytesize >= 6 + prefix)
        { bitmap: absent ? nil : @payload.byteslice(fixed + 8, length),
          suffix: absent ? @raw.byteslice((6 + prefix)..) : "".b }
      end

      def validate(condition)
        return if condition

        raise ParseError.new(offset: @offset, record_code: @type, message: "invalid native WMF bitmap record at offset #{@offset}")
      end
    end
  end
end
