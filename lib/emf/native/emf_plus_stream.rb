# frozen_string_literal: true

require "digest"
require_relative "library_path"
require_relative "emf_plus_loader"
require_relative "emf_plus_snapshot"

module Emf
  module Native
    # An Emf::EmfPlus::Stream whose framing comes from the native EMF+ snapshot
    # instead of the Ruby framer. The model is the Ruby one (Segment, typed
    # Records, ObjectTable, editing, rebuild): each native frame's validated raw
    # bytes are decoded by the same Records classes, so unedited output is
    # byte-identical to the source. The native structured payloads are exposed
    # beside it through #snapshot (frame family, normalized payload, and the
    # object-reference diagnostics computed in Rust).
    #
    # Native framing follows the Ruby framer: each comment is framed on its own,
    # a malformed header ends that comment's framing (the rest stays #unframed and
    # the ParseError is collected), and an EMR_COMMENT whose cbData exceeds its
    # record is clamped to the bytes it holds.
    #
    # .from_metafile returns nil whenever the native snapshot cannot stand in for
    # the Ruby parse (library unavailable, a record whose typed layout the native
    # decoder rejects where Ruby keeps an Unknown record, resource limits, or a
    # segment layout that differs from Ruby's);
    # the caller then uses Emf::EmfPlus::Stream.from_metafile, which keeps
    # Ruby's error-collecting recovery. An edited stream (#with_record) keeps
    # the Ruby model but carries no snapshot.
    class EmfPlusStream < Emf::EmfPlus::Stream
      SEGMENT = Emf::EmfPlus::Stream::Segment
      LOADERS_LOCK = Mutex.new
      private_constant :SEGMENT, :LOADERS_LOCK

      attr_reader :snapshot

      class << self
        # `bytes` is the EMF file the metafile was parsed from; it is rebuilt from
        # the metafile when omitted. `library` defaults to the configured native library.
        def from_metafile(metafile, bytes: nil, library: LibraryPath.new.call)
          return unless metafile.format == :emf_plus && library && !library.empty?

          bytes ||= Emf::Emr::Serializer.call(metafile)
          snapshot = EmfPlusSnapshot.new(loader(library).emf_plus_snapshot(bytes))
          build(metafile, snapshot)
        rescue Emf::Error
          nil
        end

        private

        def loader(library)
          LOADERS_LOCK.synchronize { (@loaders ||= {})[library] ||= EmfPlusLoader.new(library) }
        end

        def build(metafile, snapshot)
          comments = ruby_comment_segments(metafile)
          return unless comments.map(&:first) == snapshot.segments.map(&:record_index)

          errors = []
          segments = comments.zip(snapshot.segments).map do |(index, payload_length), row|
            segment(metafile, snapshot, index, row, payload_length, errors)
          end
          return if segments.any?(&:nil?)

          new(source: metafile, segments: segments, errors: errors, digests: digests_of(metafile, segments), snapshot: snapshot)
        end

        # [comment record index, payload length] exactly as Segment.from_comment selects them.
        def ruby_comment_segments(metafile)
          metafile.records.each_with_index.filter_map do |record, index|
            wire = record.wire
            next unless wire.is_a?(Emf::Emr::Binary::Records::Comment) && wire.cb_data >= SEGMENT::IDENTIFIER.bytesize
            next unless wire.data.b.start_with?(SEGMENT::IDENTIFIER)

            [index, [wire.cb_data, wire.data.bytesize].min - SEGMENT::IDENTIFIER.bytesize]
          end
        end

        def segment(metafile, snapshot, record_index, row, payload_length, errors)
          return unless row.payload_length == payload_length && row.data_start == SEGMENT::IDENTIFIER.bytesize

          data = metafile.records[record_index].wire.data.b
          payload = data.byteslice(SEGMENT::IDENTIFIER.bytesize, payload_length)
          frames = snapshot.frames.select { |frame| within?(frame, row) }
          return unless frames.all? { |frame| spans_only?(frame, snapshot.segments, row) }

          framed = frames.sum(&:frame_size)
          return unless unframed_error(payload, framed, record_index, errors)

          records = frames.map { |frame| decode(frame, row, record_index, errors) }
          payload_end = SEGMENT::IDENTIFIER.bytesize + payload_length
          SEGMENT.new(record_index: record_index, payload_range: SEGMENT::IDENTIFIER.bytesize...payload_end,
                      records: records, unframed: payload.byteslice(framed..), tail: data.byteslice(payload_end..))
        end

        # Native framing stops where the Ruby framer does; the unframed remainder
        # must raise the same ParseError there (recorded in framing order, before
        # record decode errors). A remainder Ruby would frame disagrees: no adoption.
        def unframed_error(payload, framed, record_index, errors)
          return true if framed == payload.bytesize

          Emf::EmfPlus::Parser.read_frame(payload, framed, record_index)
          false
        rescue ParseError => e
          errors << e
          true
        end

        def within?(frame, row)
          frame.offset >= row.logical_start && frame.offset < row.logical_start + row.payload_length
        end

        # A frame that crosses comments is malformed for Ruby (a record cannot span
        # comments); only a frame wholly inside one segment is adopted.
        def spans_only?(frame, segments, row)
          segments[frame.first_segment].equal?(row) && frame.last_segment == frame.first_segment
        end

        def decode(frame, row, record_index, errors)
          framed = Emf::EmfPlus::Frame.new(type: frame.type, flags: frame.flags, size: frame.frame_size, data_size: frame.data_size,
                                           data: frame.raw.byteslice(Emf::EmfPlus::Frame::HEADER_BYTES..),
                                           offset: frame.offset - row.logical_start, comment_index: record_index)
          Emf::EmfPlus::Records.decode(framed)
        rescue ParseError => e
          errors << e
          Emf::EmfPlus::Records::Unknown.new(framed)
        end

        def digests_of(metafile, segments)
          segments.map { |segment| Digest::SHA256.digest(metafile.records[segment.record_index].to_binary_s) }
        end
      end

      def initialize(snapshot: nil, **arguments)
        super(**arguments)
        @snapshot = snapshot
      end

      # The native family (EmfPlusSnapshot::FAMILIES) of the record at `handle`, or nil once edited.
      def native_family(handle)
        frame = snapshot&.frames&.at(handle.stream_index)
        frame&.family
      end

      # Object-reference problems Rust found, resolved against the same table order as #resolve.
      def reference_diagnostics = snapshot ? snapshot.diagnostics : []
    end
  end
end
