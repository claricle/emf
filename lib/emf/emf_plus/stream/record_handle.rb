# frozen_string_literal: true

module Emf
  module EmfPlus
    class Stream
      # A typed EMF+ record with its position: the segment it lives in, its byte
      # offset inside that segment's payload and its index among all records.
      class RecordHandle
        attr_reader :record, :segment_index, :offset, :stream_index

        def initialize(record:, segment_index:, offset:, stream_index:)
          @record = record
          @segment_index = segment_index
          @offset = offset
          @stream_index = stream_index
          freeze
        end

        def gap? = false
      end
    end
  end
end
