# frozen_string_literal: true

module Emf
  module Wmf
    # META_ESCAPE_ENHANCED_METAFILE (Escape 0x000F): an EMF stream split across consecutive
    # Escape records. Segment bytes stay inert; assembly concatenates them and does not
    # parse the EMF (use Emf.parse on the result). Records are never modified.
    #
    # ByteCount is checked as 34 plus CurrentRecordSize. The literal MS-WMF text says
    # "34 plus EnhancedMetafileDataSize", which cannot hold for a stream split into
    # 8,192-byte segments; the two agree for a single segment.
    module EmbeddedEmf
      ESCAPE = 0x000F
      METADATA_BYTES = 34
      MAX_SEGMENT_BYTES = 8192
      COMMENT_IDENTIFIER = 0x43464D57
      COMMENT_TYPE = 1

      # Raised for an invalid segment or sequence; reason is a Symbol such as
      # :comment_identifier, :segment_too_large, :remaining_mismatch or :incomplete.
      class Invalid < Emf::Error
        def initialize(reason)
          @reason = reason
          super("invalid embedded EMF escape: #{reason}")
        end

        attr_reader :reason
      end

      Segment = Struct.new(:version, :checksum, :flags, :record_count, :current_size, :remaining_bytes, :total_size, :data,
                           keyword_init: true)
      # checksum_valid is the one's complement of the XOR of the stream's 16-bit words
      # compared with the first segment's Checksum; a mismatch is reported, not rejected.
      Stream = Struct.new(:version, :checksum, :checksum_valid, :bytes, keyword_init: true)
      # error is nil when the run assembled into stream.
      Sequence = Struct.new(:first_record, :segment_count, :stream, :error, keyword_init: true)

      module_function

      def escape?(record)
        record.is_a?(Model::Wmf::Records::Escape) && record.escape_function == ESCAPE
      end

      # Validates one segment against the record's own fields. Raises Invalid.
      def segment(record)
        raise Invalid, :not_embedded_emf unless escape?(record) && record.type_id & 0xFF == 0x26

        data = record.data
        raise Invalid, :transport unless record.padding.nil? != data.bytesize.odd? && data.bytesize <= 0xFFFF
        raise Invalid, :metadata if data.bytesize < METADATA_BYTES

        identifier, type, version, checksum, flags, count, current, remaining, total = data.unpack("V3vV5")
        validate_metadata(identifier, type, flags, count, current, remaining, total)
        raise Invalid, :metadata unless data.bytesize == METADATA_BYTES + current

        Segment.new(version: version, checksum: checksum, flags: flags, record_count: count, current_size: current,
                    remaining_bytes: remaining, total_size: total, data: data.byteslice(METADATA_BYTES..))
      end

      def validate_metadata(identifier, type, flags, count, current, remaining, total)
        raise Invalid, :comment_identifier unless identifier == COMMENT_IDENTIFIER
        raise Invalid, :comment_type unless type == COMMENT_TYPE
        raise Invalid, :non_zero_flags unless flags.zero?
        raise Invalid, :zero_record_count if count.zero?
        raise Invalid, :segment_too_large if current > MAX_SEGMENT_BYTES
        raise Invalid, :inconsistent_sizes if current + remaining > total
      end

      def checksum(bytes)
        bytes = bytes.b
        bytes += "\0".b if bytes.bytesize.odd?
        ~bytes.unpack("v*").reduce(0, :^) & 0xFFFF
      end

      # Assembles escapes that must form exactly one complete sequence, in order.
      # Raises Invalid; max_bytes bounds the declared total before any copying.
      def assemble(records, max_bytes: Wmf::Binary::MAX_INPUT_BYTES)
        head = nil
        bytes = "".b
        seen = 0
        complete = false
        records.each do |record|
          raise Invalid, :record_count_mismatch if complete

          segment = segment(record)
          head ||= segment
          check_against(head, segment, bytes.bytesize, max_bytes)
          bytes << segment.data
          seen += 1
          complete = segment.remaining_bytes.zero?
          raise Invalid, :record_count_mismatch unless complete == (seen == head.record_count)
        end
        raise Invalid, :incomplete unless complete

        Stream.new(version: head.version, checksum: head.checksum, checksum_valid: checksum(bytes) == head.checksum, bytes: bytes)
      end

      def check_against(head, segment, consumed, max_bytes)
        same = segment.record_count == head.record_count && segment.total_size == head.total_size
        raise Invalid, :sequence_mismatch unless same
        raise Invalid, :limit_exceeded if head.total_size > max_bytes
        raise Invalid, :remaining_mismatch unless head.total_size - consumed - segment.current_size == segment.remaining_bytes
      end

      # Groups consecutive 0x000F escapes in a record list into Sequences. A run ends when it
      # completes, fails validation (the failing segment is included) or another record follows.
      def sequences(records, max_bytes: Wmf::Binary::MAX_INPUT_BYTES)
        result = []
        index = 0
        while index < records.length
          (index += 1 and next) unless escape?(records[index])

          stop, outcome = scan_run(records, index, max_bytes)
          result << Sequence.new(first_record: index, segment_count: stop - index, stream: outcome.is_a?(Stream) ? outcome : nil,
                                 error: outcome.is_a?(Stream) ? nil : outcome)
          index = stop
        end
        result
      end

      def scan_run(records, first, max_bytes)
        stop = first
        outcome = :incomplete
        while stop < records.length && escape?(records[stop])
          stop += 1
          outcome = begin
            assemble(records[first...stop], max_bytes: max_bytes)
          rescue Invalid => e
            e.reason
          end
          break unless outcome == :incomplete
        end
        [stop, outcome]
      end
    end
  end
end
