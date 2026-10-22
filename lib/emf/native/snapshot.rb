# frozen_string_literal: true

module Emf
  module Native
    # Decodes the versioned transport, never the original EMF wire format.
    class Snapshot
      # Five integers per record, in record order: index, offset, length,
      # type | family << 32 and payload length (the 40-byte entry as u64 words).
      attr_reader :header, :raw_header, :table, :record_count, :diagnostics, :trailing, :unframed

      TYPE_MASK = 0xFFFF_FFFF

      def initialize(bytes)
        @bytes = bytes
        @position = 0
        raise FormatError, "invalid native snapshot schema" unless take(4) == "EMFS"

        schema = u32
        raise FormatError, "invalid native snapshot schema" unless [2, 3].include?(schema)
        raise FormatError, "invalid native snapshot length" unless u64 == bytes.bytesize

        header_length, record_count, diagnostic_count, trailing_length, unframed_length = Array.new(5) { u64 }
        raise FormatError, "invalid native snapshot counts" if record_count > bytes.bytesize / 40 || diagnostic_count > bytes.bytesize / 40

        @header = Array.new(28) { u32 }
        @raw_header = take(header_length)
        @record_count = record_count
        schema == 3 ? read_table : read_entries
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

      # The record at `index` as a Hash with its typed payload.
      def record(index)
        base = index * 5
        type_family = @table[base + 3]
        { index: @table[base], offset: @table[base + 1], length: @table[base + 2], type: type_family & TYPE_MASK,
          family: type_family >> 32, payload: payload(index) }
      end

      def records
        @records ||= Array.new(@record_count) { |index| record(index) }
      end

      def payload(index)
        length = @table[(index * 5) + 4]
        length.zero? ? EMPTY_PAYLOAD : @bytes.byteslice(@payload_at[index], length)
      end

      private

      EMPTY_PAYLOAD = "".b.freeze
      private_constant :EMPTY_PAYLOAD

      # Schema 3: every entry in one fixed-stride table, then the payloads.
      def read_table
        raise FormatError, "truncated native snapshot" if @bytes.bytesize - @position < @record_count * 40

        @table = @bytes.unpack("Q<#{@record_count * 5}", offset: @position)
        @position += @record_count * 40
        @payload_at = Array.new(@record_count) do |index|
          at = @position
          @position += @table[(index * 5) + 4]
          at
        end
        raise FormatError, "truncated native snapshot" if @position > @bytes.bytesize
      end

      # Schema 2: each entry is followed by its payload.
      def read_entries
        @table = []
        @payload_at = Array.new(@record_count) do
          raise FormatError, "truncated native snapshot" if @bytes.bytesize - @position < 40

          @table.concat(@bytes.unpack("Q<5", offset: @position))
          @position += 40
          at = @position
          take(@table.last)
          at
        end
      end
    end
  end
end
