# frozen_string_literal: true

module Emf
  module EmfPlus
    # One EMF+ record as framed on the wire: the 12-byte header fields plus the
    # undecoded body. `data` is every byte after the header up to `size`, so a
    # frame always re-serializes to the bytes it was read from.
    #
    # `offset` is the frame's position within its byte stream; `comment_index`
    # is the index into Metafile#records of the EMR_COMMENT it was read from
    # (nil when framed from a bare stream).
    class Frame
      HEADER_BYTES = 12

      attr_reader :type, :flags, :size, :data_size, :data, :offset, :comment_index

      def initialize(type:, flags:, size:, data_size:, data:, offset: 0, comment_index: nil)
        @type = type
        @flags = flags
        @size = size
        @data_size = data_size
        @data = data.b.freeze
        @offset = offset
        @comment_index = comment_index
        freeze
      end

      # Size must stay 32-bit aligned, so the body is zero-padded; DataSize keeps the real length.
      def with_data(new_data)
        padded = new_data.b + ("\0" * (-new_data.bytesize % 4))
        self.class.new(type: type, flags: flags, size: HEADER_BYTES + padded.bytesize,
                       data_size: new_data.bytesize, data: padded,
                       offset: offset, comment_index: comment_index)
      end

      def to_binary
        [type, flags, size, data_size].pack("vvVV") + data
      end
    end
  end
end
