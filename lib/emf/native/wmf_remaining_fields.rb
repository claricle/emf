# frozen_string_literal: true

module Emf
  module Native
    class WmfRemainingFields
      def initialize(record, raw)
        @record = record
        @raw = raw
        @type = record.fetch(:type)
        @offset = record.fetch(:offset)
        @payload = record.fetch(:payload)
      end

      def call
        validate(@raw.bytesize >= 6 && @raw.bytesize.even? && @payload.bytesize <= Wmf::Binary::MAX_INPUT_BYTES)
        validate(@raw.unpack("Vv") == [@raw.bytesize / 2, @type])
        geometry = Wmf::GeometryCodec::RECORDS.key?(@type & 0xFF)
        codec = geometry ? Wmf::GeometryCodec : Wmf::DcEscapeCodec
        validate(@record.fetch(:family) == (geometry ? 12 : 13))
        klass = codec::RECORDS.fetch(@type & 0xFF)
        fields = if geometry
                   scalar_fields(klass)
                 elsif @type & 0xFF == 0x26
                   escape_fields
                 else
                   dc_fields
                 end
        model = klass.new(**fields, type_id: @type, offset: @offset)
        validate(codec.encode(model) == @raw)
        model
      rescue SerializeError
        validate(false)
      end

      private

      def scalar_fields(klass)
        validate(@payload.bytesize == klass::WIRE_FIELDS.length * 4 && @raw.bytesize >= 6 + klass::PAYLOAD_BYTES)
        values = klass::WIRE_TYPES.each_with_index.map do |type, index|
          @payload.byteslice(index * 4, 4).unpack1(type == :int16 ? "l<" : "V")
        end
        klass::WIRE_FIELDS.zip(values).to_h.merge(suffix: @raw.byteslice((6 + klass::PAYLOAD_BYTES)..))
      end

      def dc_fields
        restore = @type & 0xFF == 0x27
        validate(@payload.bytesize == (restore ? 4 : 0) && @raw.bytesize >= (restore ? 8 : 6))
        fields = { suffix: @raw.byteslice((restore ? 8 : 6)..) }
        fields[:saved_dc] = @payload.unpack1("l<") if restore
        fields
      end

      def escape_fields
        validate(@payload.bytesize >= 12)
        function, length = @payload.unpack("VQ<")
        validate(length <= 0xFFFF && @payload.bytesize == 12 + length)
        prefix = 10 + length + (length % 2)
        validate(@raw.bytesize >= prefix)
        { escape_function: function, data: @payload.byteslice(12, length),
          padding: length.odd? ? @raw.getbyte(10 + length) : nil, suffix: @raw.byteslice(prefix..) }
      end

      def validate(condition)
        return if condition

        raise ParseError.new(offset: @offset, record_code: @type, message: "invalid native WMF typed record at offset #{@offset}")
      end
    end
  end
end
