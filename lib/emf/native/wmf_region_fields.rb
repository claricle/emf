# frozen_string_literal: true

module Emf
  module Native
    class WmfRegionFields
      def initialize(record, raw)
        @record = record
        @raw = raw
        @type = record.fetch(:type)
        @offset = record.fetch(:offset)
        @payload = record.fetch(:payload)
      end

      def call
        validate(@record.fetch(:family) == 9 && @raw.bytesize >= 6 && @raw.bytesize.even?)
        klass = Wmf::RegionCodec::RECORDS.fetch(@type & 0xFF)
        fields = klass == Model::Wmf::Records::CreateRegion ? region : scalar(klass)
        record = klass.new(**fields, type_id: @type, offset: @offset)
        prefix = Wmf::RegionCodec.encode_payload(record)
        validate(@raw.bytesize >= prefix.bytesize + 6 && @raw.byteslice(6, prefix.bytesize) == prefix)
        record.suffix = @raw.byteslice((6 + prefix.bytesize)..)
        record
      rescue SerializeError
        validate(false)
      end

      private

      def scalar(klass)
        validate(@payload.bytesize == klass::WIRE_FIELDS.length * 4)
        values = @payload.unpack("V*").zip(klass::WIRE_TYPES).map do |value, type|
          if type == :int16
            value -= 0x100000000 if value >= 0x80000000
            validate(value.between?(-0x8000, 0x7FFF))
          else
            validate(value <= 0xFFFF)
          end
          value
        end
        klass::WIRE_FIELDS.zip(values).to_h
      end

      def region
        validate(@payload.bytesize >= 28)
        next_in_chain, object_count = @payload.unpack("V2")
        bounds = @payload.byteslice(8, 16).unpack("l<4")
        count = @payload.byteslice(24, 4).unpack1("V")
        validate(next_in_chain <= 0xFFFF && bounds.all? { |value| value.between?(-0x8000, 0x7FFF) })
        validate(count <= 0x7FFF && count <= (@payload.bytesize - 28) / 12)
        preflight_scans(count)
        { next_in_chain: next_in_chain, object_count: object_count,
          bounds: Model::Wmf::Records::RegionBounds.new(**Wmf::RegionCodec::BOUNDS_FIELDS.zip(bounds).to_h),
          scans: scans(count) }
      end

      def preflight_scans(count)
        cursor = 28
        source_size = 22
        count.times do
          validate(@payload.bytesize - cursor >= 12)
          top, bottom, lines = @payload.byteslice(cursor, 12).unpack("V3")
          validate(top <= 0xFFFF && bottom <= 0xFFFF && lines <= 0x3FFF && lines <= (@payload.bytesize - cursor - 12) / 8)
          source_size += 8 + (lines * 4)
          validate(source_size <= 0x7FFF)
          (lines * 2).times do |index|
            validate(@payload.byteslice(cursor + 12 + (index * 4), 4).unpack1("V") <= 0xFFFF)
          end
          cursor += 12 + (lines * 8)
        end
        validate(cursor == @payload.bytesize && @raw.bytesize >= source_size + 6)
      end

      def scans(count)
        cursor = 28
        Array.new(count) do
          top, bottom, count_lines = @payload.byteslice(cursor, 12).unpack("V3")
          lines = @payload.byteslice(cursor + 12, count_lines * 8).unpack("V*").each_slice(2).map do |left, right|
            Model::Wmf::Records::RegionScanLine.new(left: left, right: right)
          end
          cursor += 12 + (count_lines * 8)
          Model::Wmf::Records::RegionScan.new(top: top, bottom: bottom, lines: lines)
        end
      end

      def validate(condition)
        return if condition

        raise ParseError.new(offset: @offset, record_code: @type, message: "invalid native WMF region record at offset #{@offset}")
      end
    end
  end
end
