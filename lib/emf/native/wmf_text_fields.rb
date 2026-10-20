# frozen_string_literal: true

module Emf
  module Native
    class WmfTextFields
      def initialize(record, raw)
        @record = record
        @raw = raw
      end

      def call
        payload = @record.fetch(:payload)
        validate(@record.fetch(:family) == 5 && payload.bytesize >= 72)
        x, y, options, has_rect, count, padding_length, dx_length, suffix_length, has_dx, reserved = payload.unpack("l<2V2Q<4V2")
        rectangle = payload.byteslice(56, 16).unpack("l<4")
        extended = @record.fetch(:type) & 0xFF == 0x32
        validate_lengths(payload, count, padding_length, dx_length, suffix_length, has_rect, has_dx, reserved)
        fields = {
          x: x, y: y, text: payload.byteslice(72, count), padding: payload.byteslice(72 + count, padding_length),
          type_id: @record.fetch(:type), offset: @record.fetch(:offset)
        }
        return text_out(fields, options, has_rect, has_dx, suffix_length) unless extended

        validate(has_rect == (options.anybits?(6) ? 1 : 0) && padding_length <= 1)
        expected = 14 + (has_rect * 8) + count + padding_length + (dx_length * 2) + suffix_length
        validate(@raw.bytesize == expected)
        fields[:rectangle] = Model::Wmf::Records::TextRectangle.new(**%i[left top right bottom].zip(rectangle).to_h) if has_rect == 1
        fields[:options] = options
        fields[:dx] = payload.byteslice(72 + count + padding_length, dx_length * 4).unpack("l<*") if has_dx == 1
        fields[:suffix] = payload.byteslice(72 + count + padding_length + (dx_length * 4), suffix_length)
        Model::Wmf::Records::ExtTextOut.new(**fields)
      end

      private

      def validate_lengths(payload, count, padding_length, dx_length, suffix_length, rectangle, spacing, reserved)
        validate(reserved.zero? && count <= 0x7FFF && [0, 1].include?(rectangle) && [0, 1].include?(spacing))
        validate(payload.bytesize == 72 + count + padding_length + (dx_length * 4) + suffix_length)
        validate(dx_length == (spacing == 1 ? count : 0))
        validate(padding_length % 2 == count % 2)
      end

      def text_out(fields, options, rectangle, spacing, suffix_length)
        validate(options.zero? && rectangle.zero? && spacing.zero? && suffix_length.zero?)
        validate(@raw.bytesize >= 12 && @raw.bytesize == 12 + fields.fetch(:text).bytesize + fields.fetch(:padding).bytesize)
        Model::Wmf::Records::TextOut.new(**fields)
      end

      def validate(condition)
        return if condition

        raise ParseError.new(offset: @record.fetch(:offset), record_code: @record.fetch(:type), message: "invalid native WMF text record")
      end
    end
  end
end
