# frozen_string_literal: true

module Emf
  module Native
    class WmfPaletteFields
      def initialize(record, raw)
        @record = record
        @raw = raw
        @type = record.fetch(:type)
        @offset = record.fetch(:offset)
        @payload = record.fetch(:payload)
      end

      def call
        klass = Wmf::PaletteCodec::RECORDS.fetch(@type & 0xFF)
        validate(@record.fetch(:family) == 8 && @raw.bytesize.even?)
        fields, prefix = if klass <= Model::Wmf::Records::PaletteRecord
                           entries
                         elsif klass == Model::Wmf::Records::RealizePalette
                           validate(@payload.empty?)
                           [{}, 6]
                         else
                           scalar(klass)
                         end
        validate(@raw.bytesize >= prefix)
        klass.new(**fields, type_id: @type, offset: @offset, suffix: @raw.byteslice(prefix..))
      end

      private

      def entries
        validate(@payload.bytesize >= 8)
        start, count = @payload.unpack("V2")
        validate(start <= 0xFFFF && count <= 0xFFFF && @payload.bytesize == 8 + (count * 16))
        prefix = 10 + (count * 4)
        validate(@raw.bytesize >= prefix)
        values = @payload.byteslice(8..).unpack("V*")
        validate(values.all? { |value| value <= 0xFF })
        palette = values.each_slice(4).map do |entry|
          Model::Wmf::Records::PaletteEntry.new(**Wmf::PaletteCodec::ENTRY_FIELDS.zip(entry).to_h)
        end
        [{ start: start, entries: palette }, prefix]
      end

      def scalar(klass)
        validate(@payload.bytesize == 4)
        value = @payload.unpack1("V")
        validate(value <= 0xFFFF)
        field = klass == Model::Wmf::Records::SelectPalette ? :object_index : :entry_count
        [{ field => value }, 8]
      end

      def validate(condition)
        return if condition

        raise ParseError.new(offset: @offset, record_code: @type, message: "invalid native WMF palette record at offset #{@offset}")
      end
    end
  end
end
