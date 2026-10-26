# frozen_string_literal: true

module Emf
  module Wmf
    # Record shapes the specification rules out but real producers write and readers (LibreOffice) import. Each is
    # framed by its own declared RecordSize inside the input, so the record is kept and the departure is recorded in
    # Metafile#errors instead of raising. Both backends call .record on the same raw record bytes, so the models
    # are identical. Anything not listed here, and any shape that cannot be framed safely, is left to the strict
    # decoders, which reject it.
    #
    #   406  an EOF record longer than three words: it still ends the stream; the surplus is ignored
    #   801  an object record (pen, brush, select, delete) with bytes after its payload: the payload is read, the
    #        surplus is ignored; a shorter record is still rejected
    #   701  a font record shorter than 32 face-name bytes but holding the 18 fixed bytes: the face name is
    #        zero-padded; a record without the fixed bytes is still rejected
    #   1003 a text record with a negative StringLength: no string can be framed, so the record is kept verbatim
    #        as an UnknownRecord; a truncated text record or rectangle is still rejected first
    #   903  a META_POLYGON with NumberOfPoints 0 and no point bytes (PowerPoint, seen in Apache POI's
    #        empty-polygon-close.wmf): kept as a Polygon without points; 1 and negative counts are still rejected
    #   1203 a META_CREATEREGION whose ObjectCount is two bytes wide (libUEMF, the library Inkscape writes WMF with,
    #        declares it uint16, so every later field sits two bytes early) and whose RegionSize, read there, is exactly
    #        the body: the region is kept verbatim as an UnknownRecord (it still takes its object-table slot, from the
    #        low byte of its function); any other invalid header is still rejected
    module Recovery
      EOF_BYTES = 6
      FONT_FIXED_BYTES = 18
      # function => [offset of StringLength, shortest record]
      TEXT_COUNTS = { 0x21 => [6, 12], 0x32 => [10, 14] }.freeze
      CLIP_OR_OPAQUE = 6
      RECTANGLE_BYTES = 8
      POLYGON = 0x24
      REGION = 0xFF
      POLYGON_EMPTY_BYTES = 8

      module_function

      # [record, reason] when `raw` (one whole record) is a recoverable shape, otherwise nil.
      def record(raw, function, offset)
        low = function & 0xFF
        return [Model::Wmf::Records::Eof.new(offset: offset), 406] if function.zero? && raw.bytesize > EOF_BYTES
        return object(raw, function, offset) if Binary::OBJECT_RECORDS.key?(low)
        return font(raw, function, offset) if low == 0xFB
        return polygon(raw, function, offset) if low == POLYGON
        return region(raw, function, offset) if low == REGION

        text(raw, function, offset) if TEXT_COUNTS.key?(low)
      end

      def object(raw, function, offset)
        klass = Binary::OBJECT_RECORDS.fetch(function & 0xFF)
        return unless raw.bytesize > 6 + klass::PAYLOAD_BYTES

        values = raw.byteslice(6, klass::PAYLOAD_BYTES).unpack(klass::WIRE_FORMAT)
        [klass.new(**klass::WIRE_FIELDS.zip(values).to_h, type_id: function, offset: offset), 801]
      end

      def font(raw, function, offset)
        klass = Model::Wmf::Records::CreateFontIndirect
        return unless raw.bytesize.between?(6 + FONT_FIXED_BYTES, 6 + klass::PAYLOAD_BYTES - 1)

        values = raw.byteslice(6..).ljust(klass::PAYLOAD_BYTES, "\0".b).unpack(klass::WIRE_FORMAT)
        [klass.new(**klass::WIRE_FIELDS.zip(values).to_h, type_id: function, offset: offset), 701]
      end

      def polygon(raw, function, offset)
        return unless raw.bytesize == POLYGON_EMPTY_BYTES && raw.byteslice(6, 2).unpack1("s<").zero?

        [Model::Wmf::Records::Polygon.new(points: [], type_id: function, offset: offset), 903]
      end

      def region(raw, function, offset)
        body = raw.byteslice(6..)
        return unless body.bytesize >= RegionCodec::HEADER_BYTES && RegionCodec.header_invalid?(body)

        kind, size, count = body.unpack("@2v@6s<@8s<")
        return unless kind == RegionCodec::KIND && size == body.bytesize && !count.negative?

        [Model::Wmf::Records::UnknownRecord.new(type_id: function, raw_bytes: raw, offset: offset), 1203]
      end

      def text(raw, function, offset)
        count_at, minimum = TEXT_COUNTS.fetch(function & 0xFF)
        return if raw.bytesize < minimum
        return if function & 0xFF == 0x32 && rectangle_truncated?(raw, minimum)
        return unless raw.byteslice(count_at, 2).unpack1("s<").negative?

        [Model::Wmf::Records::UnknownRecord.new(type_id: function, raw_bytes: raw, offset: offset), 1003]
      end

      def rectangle_truncated?(raw, minimum)
        raw.byteslice(12, 2).unpack1("v").anybits?(CLIP_OR_OPAQUE) && raw.bytesize < minimum + RECTANGLE_BYTES
      end
    end
  end
end
