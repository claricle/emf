# frozen_string_literal: true

module Emf
  module EmfPlus
    class Stream
      # A typed EMF+ record with its position: the segment it lives in, its byte
      # offset inside that segment's payload and its index among all records.
      # `comment_offset` is the file offset of the containing EMR_COMMENT, or nil
      # when the source record has none (a rebuilt or hand-made metafile).
      class RecordHandle
        attr_reader :record, :segment_index, :offset, :stream_index, :comment_offset

        def initialize(record:, segment_index:, offset:, stream_index:, comment_offset: nil)
          @record = record
          @segment_index = segment_index
          @offset = offset
          @stream_index = stream_index
          @comment_offset = comment_offset
          freeze
        end

        def gap? = false
      end
    end
  end
end
