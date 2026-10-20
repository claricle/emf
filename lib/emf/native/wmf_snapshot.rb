# frozen_string_literal: true

module Emf
  module Native
    class WmfSnapshot
      attr_reader :header, :placeable, :records, :diagnostics, :trailing, :source_length

      def initialize(bytes)
        @bytes = bytes
        @position = 0
        raise FormatError, "invalid native WMF snapshot schema" unless take(4) == "WMFS" && u32 == 1
        raise FormatError, "invalid native WMF snapshot length" unless u64 == bytes.bytesize

        record_count, diagnostic_count, trailing_length, @source_length = Array.new(4) { u64 }
        if record_count > bytes.bytesize / 40 || diagnostic_count > bytes.bytesize / 40
          raise FormatError, "invalid native WMF snapshot counts"
        end

        @header = Array.new(10) { u32 }
        @placeable = take(32).unpack("Vl<4V3")
        @records = Array.new(record_count) { read_record }
        @diagnostics = Array.new(diagnostic_count) { take(40).unpack("V4Q<3") }
        @trailing = take(trailing_length)
        raise FormatError, "unconsumed native WMF snapshot bytes" unless @position == bytes.bytesize
      end

      def take(length)
        raise FormatError, "truncated native WMF snapshot" if length.negative? || length > @bytes.bytesize - @position

        result = @bytes.byteslice(@position, length)
        @position += length
        result
      end

      def u32
        take(4).unpack1("V")
      end

      def u64
        take(8).unpack1("Q<")
      end

      private

      def read_record
        index, offset, length, type, family, payload_length = take(40).unpack("Q<3V2Q<")
        { index: index, offset: offset, length: length, type: type, family: family, payload: take(payload_length) }
      end
    end
  end
end
