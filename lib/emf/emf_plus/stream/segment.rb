# frozen_string_literal: true

module Emf
  module EmfPlus
    class Stream
      # The EMF+ payload of one EMR_COMMENT. `record_index` locates the comment
      # in Metafile#records and `payload_range` the payload inside its wire
      # data (after the "EMF+" identifier). Bytes the framer could not read
      # (`unframed`) and bytes after cb_data (`tail`) are kept verbatim.
      class Segment
        IDENTIFIER = "EMF+".b.freeze

        attr_reader :record_index, :payload_range, :records, :unframed, :tail

        # Returns nil unless the comment carries an EMF+ payload.
        def self.from_comment(record_index, wire, errors)
          data = wire.data.b
          return unless wire.cb_data >= IDENTIFIER.bytesize && data.start_with?(IDENTIFIER)

          length = [wire.cb_data, data.bytesize].min - IDENTIFIER.bytesize
          payload = data.byteslice(IDENTIFIER.bytesize, length)
          frames = Parser.call(payload, errors: errors, comment_index: record_index)
          framed = frames.sum(&:size)
          payload_end = IDENTIFIER.bytesize + length
          new(record_index: record_index, payload_range: IDENTIFIER.bytesize...payload_end, records: decode(frames, errors),
              unframed: payload.byteslice(framed..), tail: data.byteslice(payload_end..))
        end

        def self.decode(frames, errors)
          frames.map do |frame|
            Records.decode(frame)
          rescue ParseError => e
            errors << e
            Records::Unknown.new(frame)
          end
        end

        def initialize(record_index:, payload_range:, records:, unframed:, tail:, dirty: false)
          @record_index = record_index
          @payload_range = payload_range
          @records = records.freeze
          @unframed = unframed.freeze
          @tail = tail.freeze
          @dirty = dirty
          freeze
        end

        def dirty? = @dirty

        def payload
          records.map(&:to_binary).join.b + unframed
        end

        def replace(position, record)
          swapped = records.dup.tap { |list| list[position] = record }
          self.class.new(record_index: record_index, payload_range: payload_range, records: swapped,
                         unframed: unframed, tail: tail, dirty: true)
        end

        # The EMR_COMMENT wire for this segment with cb_data and nSize recomputed.
        def comment_wire(original)
          data = IDENTIFIER + payload + tail
          padded = data + ("\0" * (-data.bytesize % 4))
          Emf::Emr::Binary::Records::Comment.new(i_type: original.i_type, n_size: 12 + padded.bytesize,
                                                 cb_data: IDENTIFIER.bytesize + payload.bytesize, data: padded)
        end
      end
    end
  end
end
