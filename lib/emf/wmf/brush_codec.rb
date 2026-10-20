# frozen_string_literal: true

module Emf
  module Wmf
    module BrushCodec
      RECORDS = { 0xF9 => Model::Wmf::Records::CreatePatternBrush, 0x42 => Model::Wmf::Records::DibCreatePatternBrush }.freeze
      FUNCTIONS = RECORDS.invert.freeze
      SIGNED_FIELDS = %i[bitmap_type width height width_bytes].freeze
      BYTE_FIELDS = %i[planes bits_pixel].freeze

      module_function

      def decode(raw, function, offset)
        fields = { type_id: function, offset: offset }
        if function & 0xFF == 0xF9
          yield "truncated pattern brush prefix" if raw.bytesize < 38
          values = raw.byteslice(6, 10).unpack("s<4C2")
          fields.merge!((SIGNED_FIELDS + BYTE_FIELDS).zip(values).to_h)
          length = pattern_length(fields[:width], fields[:height], fields[:planes], fields[:bits_pixel])
          yield "invalid pattern brush extent" unless length && length <= raw.bytesize - 38
          fields.merge!(bits: raw.byteslice(16, 4), reserved: raw.byteslice(20, 18),
                        pattern: raw.byteslice(38, length), suffix: raw.byteslice((38 + length)..))
        else
          yield "truncated DIB brush prefix" if raw.bytesize < 12
          style, usage = raw.byteslice(6, 4).unpack("v2")
          yield "invalid DIB brush color usage" unless style == 3 || usage <= 2
          fields.merge!(style: style, color_usage: usage, target: raw.byteslice(10..))
        end
        RECORDS.fetch(function & 0xFF).new(**fields)
      end

      def pattern_length(width, height, planes, bits_pixel)
        return unless width.positive? && height.positive? && planes == 1 && bits_pixel.positive?

        (((width * bits_pixel) + 15) / 16) * 2 * height
      end

      def byte_size(record)
        if record.is_a?(Model::Wmf::Records::CreatePatternBrush)
          38 + record.pattern.bytesize + record.suffix.bytesize
        else
          10 + record.target.bytesize
        end
      end

      def encode(record)
        function = Binary.uint16(record.type_id, "RecordFunction")
        raise SerializeError, "WMF brush RecordFunction mismatch" unless function & 0xFF == FUNCTIONS[record.class]

        payload = encode_payload(record)
        if record.is_a?(Model::Wmf::Records::CreatePatternBrush)
          validate_string(record.suffix, "suffix", even: true)
          validate_size(payload.bytesize + record.suffix.bytesize)
          payload += record.suffix.b
        end
        validate_size(payload.bytesize)

        [3 + (payload.bytesize / 2), function].pack("Vv") + payload
      end

      def encode_payload(record)
        if record.is_a?(Model::Wmf::Records::CreatePatternBrush)
          pattern_payload(record)
        else
          style = Binary.uint16(record.style, "style")
          usage = Binary.uint16(record.color_usage, "color_usage")
          raise SerializeError, "invalid WMF DIB brush color usage" unless style == 3 || usage <= 2

          validate_string(record.target, "target", even: true)
          raise SerializeError, "empty WMF DIB brush target" if record.target.empty?

          validate_size(4 + record.target.bytesize)
          [style, usage].pack("v2") + record.target.b
        end
      end

      def pattern_payload(record)
        signed = SIGNED_FIELDS.map { |field| Binary.int16(record.public_send(field), field) }
        bytes = BYTE_FIELDS.map { |field| Binary.uint8(record.public_send(field), field) }
        length = pattern_length(record.width, record.height, record.planes, record.bits_pixel)
        validate_string(record.bits, "bits", length: 4)
        validate_string(record.reserved, "reserved", length: 18)
        validate_string(record.pattern, "pattern", even: true)
        raise SerializeError, "invalid WMF pattern brush extent" unless length && length == record.pattern.bytesize

        validate_size(32 + record.pattern.bytesize)
        [*signed, *bytes].pack("s<4C2") + record.bits.b + record.reserved.b + record.pattern.b
      end

      def validate_size(size)
        raise SerializeError, "WMF brush too large" if size > Binary::MAX_INPUT_BYTES - 6
      end

      def validate_string(value, name, length: nil, even: false)
        return if value.is_a?(String) && (!length || value.bytesize == length) && (!even || value.bytesize.even?) &&
                  value.bytesize <= Binary::MAX_INPUT_BYTES - 6

        raise SerializeError, "invalid WMF brush #{name} bytes"
      end
    end
  end
end
