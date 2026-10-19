# frozen_string_literal: true

module Emf
  module Native
    # Decodes the versioned transport, never the original EMF wire format.
    class Snapshot
      attr_reader :header, :raw_header, :records, :diagnostics, :trailing, :unframed

      def initialize(bytes)
        @bytes = bytes
        @position = 0
        raise FormatError, "invalid native snapshot schema" unless take(4) == "EMFS" && u32 == 2
        raise FormatError, "invalid native snapshot length" unless u64 == bytes.bytesize

        header_length, record_count, diagnostic_count, trailing_length, unframed_length = Array.new(5) { u64 }
        raise FormatError, "invalid native snapshot counts" if record_count > bytes.bytesize / 40 || diagnostic_count > bytes.bytesize / 40

        @header = Array.new(28) { u32 }
        @raw_header = take(header_length)
        @records = Array.new(record_count) { read_record }
        @diagnostics = Array.new(diagnostic_count) { take(40).unpack("V4Q<3") }
        @trailing = take(trailing_length)
        @unframed = take(unframed_length)
        raise FormatError, "unconsumed native snapshot bytes" unless @position == bytes.bytesize
      end

      def take(length)
        raise FormatError, "truncated native snapshot" if length > @bytes.bytesize - @position

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
