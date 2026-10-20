# frozen_string_literal: true

module Emf
  module Native
    class WmfBrushFields
      def initialize(record, raw)
        @record = record
        @raw = raw
        @type = record.fetch(:type)
        @offset = record.fetch(:offset)
        @payload = record.fetch(:payload)
      end

      def call
        validate(@record.fetch(:family) == 10 && @raw.bytesize >= 6 && @raw.bytesize.even? &&
                 @payload.bytesize <= Wmf::Binary::MAX_INPUT_BYTES)
        fields = @type & 0xFF == 0xF9 ? pattern : dib
        record = Wmf::BrushCodec::RECORDS.fetch(@type & 0xFF).new(**fields, type_id: @type, offset: @offset)
        prefix = Wmf::BrushCodec.encode_payload(record)
        validate(@raw.bytesize >= prefix.bytesize + 6 && @raw.byteslice(6, prefix.bytesize) == prefix)
        if record.is_a?(Model::Wmf::Records::CreatePatternBrush)
          record.suffix = @raw.byteslice((6 + prefix.bytesize)..)
        else
          validate(@raw.bytesize == prefix.bytesize + 6)
        end
        record
      rescue SerializeError
        validate(false)
      end

      private

      def pattern
        validate(@payload.bytesize >= 50)
        signed = @payload.unpack("l<4")
        planes, bits_pixel = @payload.byteslice(16, 8).unpack("V2")
        length = @payload.byteslice(46, 4).unpack1("V")
        validate(signed.all? { |value| value.between?(-0x8000, 0x7FFF) } && planes <= 0xFF && bits_pixel <= 0xFF)
        expected = Wmf::BrushCodec.pattern_length(signed[1], signed[2], planes, bits_pixel)
        validate(expected && expected == length && @payload.bytesize == 50 + length && @raw.bytesize >= 38 + length)
        Wmf::BrushCodec::SIGNED_FIELDS.zip(signed).to_h.merge(
          planes: planes, bits_pixel: bits_pixel, bits: @payload.byteslice(24, 4), reserved: @payload.byteslice(28, 18),
          pattern: @payload.byteslice(50, length)
        )
      end

      def dib
        validate(@payload.bytesize >= 14)
        style, usage, length = @payload.unpack("V3")
        validate(style <= 0xFFFF && usage <= 0xFFFF && (style == 3 || usage <= 2) && length.positive? && length.even? &&
                 @payload.bytesize == 12 + length && @raw.bytesize == 10 + length)
        { style: style, color_usage: usage, target: @payload.byteslice(12, length) }
      end

      def validate(condition)
        return if condition

        raise ParseError.new(offset: @offset, record_code: @type, message: "invalid native WMF brush record at offset #{@offset}")
      end
    end
  end
end
