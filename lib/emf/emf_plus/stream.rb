# frozen_string_literal: true

require "digest"

module Emf
  module EmfPlus
    # A lazy, typed view of the EMF+ records of a parsed Metafile. Reading never
    # changes the Metafile; edits yield a new Metafile in which only the
    # comments of edited segments are rebuilt. Framing problems are collected in
    # #errors (never raised, never added to Metafile#errors) and the affected
    # bytes stay in the segment, so nothing is dropped.
    class Stream
      include Enumerable

      autoload :Segment, "emf/emf_plus/stream/segment"
      autoload :RecordHandle, "emf/emf_plus/stream/record_handle"
      autoload :EmfGap, "emf/emf_plus/stream/emf_gap"
      autoload :Rebuild, "emf/emf_plus/stream/rebuild"
      autoload :Editor, "emf/emf_plus/stream/editor"
      autoload :LinkIndex, "emf/emf_plus/stream/link_index"

      attr_reader :source, :segments

      def self.from_metafile(metafile)
        errors = []
        segments = metafile.records.each_with_index.filter_map do |record, index|
          Segment.from_comment(index, record.wire, errors) if record.wire.is_a?(Emf::Emr::Binary::Records::Comment)
        end
        new(source: metafile, segments: segments, errors: errors, digests: digests_of(metafile, segments))
      end

      def self.digests_of(metafile, segments)
        segments.map { |segment| Digest::SHA256.digest(metafile.records[segment.record_index].to_binary_s) }
      end
      private_class_method :digests_of

      def initialize(source:, segments:, errors:, digests:)
        @source = source
        @segments = segments.freeze
        @framing_errors = errors.freeze
        @digests = digests.freeze
      end

      def ok? = errors.empty?

      # Framing problems, then object table and effect link diagnostics.
      def errors
        @errors ||= (@framing_errors + objects.errors + links.errors).freeze
      end

      # EMF+ records and EMF gaps in file order.
      def entries
        @entries ||= build_entries.freeze
      end

      def each(&block)
        return to_enum(:each) unless block

        entries.each(&block)
      end

      def each_record(&block)
        return to_enum(:each_record) unless block

        entries.each { |entry| yield entry unless entry.gap? }
      end

      def records = each_record.to_a

      # True once a source comment's bytes differ from what this stream was built from.
      def stale?
        segments.each_with_index.any? do |segment, index|
          Digest::SHA256.digest(source.records[segment.record_index].to_binary_s) != @digests[index]
        end
      end

      def dirty? = segments.any?(&:dirty?)

      # Returns a new Stream with `handle`'s record replaced; the receiver is unchanged.
      def with_record(handle, new_record)
        assert_fresh!
        segment = segments.fetch(handle.segment_index)
        position = segment.records.index { |record| record.equal?(handle.record) }
        raise ArgumentError, "record does not belong to this stream" unless position

        swapped = segments.dup.tap { |list| list[handle.segment_index] = segment.replace(position, new_record) }
        self.class.new(source: source, segments: swapped, errors: @framing_errors, digests: @digests)
      end

      # Yields an Editor (#replace(handle, record)) and returns the edited Metafile.
      def edit
        editor = Editor.new(self)
        yield editor
        editor.stream.to_metafile
      end

      # The source itself when nothing was edited.
      def to_metafile
        assert_fresh!
        return source unless dirty?

        Rebuild.new(source, segments.select(&:dirty?)).call
      end

      def assert_fresh!
        raise StaleStreamError, "the source metafile's EMF+ comments changed after this stream was built" if stale?
      end

      # The object table over this stream's records in stream order.
      def objects
        @objects ||= ObjectTable.new(records.map(&:record))
      end

      # Resolutions of the object references `handle`'s record carries.
      def resolve(handle) = objects.resolve(handle.record, at: handle.stream_index)

      def dc_spans = links.dc_spans

      # The SerializableObject handle linked to an E-flag draw handle, or nil.
      def effect_for(handle) = links.effect_for(handle)

      private

      def links
        @links ||= LinkIndex.new(source, records, segments)
      end

      def build_entries
        stream_index = 0
        cursor = 0
        segments.each_with_index.flat_map do |segment, segment_index|
          gap = gap_before(cursor, segment.record_index)
          cursor = segment.record_index + 1
          offset = 0
          handles = segment.records.map do |record|
            handle = RecordHandle.new(record: record, segment_index: segment_index, offset: offset, stream_index: stream_index)
            offset += record.to_binary.bytesize
            stream_index += 1
            handle
          end
          gap + handles
        end + gap_before(cursor, source.records.size)
      end

      def gap_before(from, upto)
        from < upto ? [EmfGap.new(from...upto)] : []
      end
    end
  end
end
