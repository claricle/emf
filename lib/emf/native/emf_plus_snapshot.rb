# frozen_string_literal: true

module Emf
  module Native
    # Reader for the native EMF+ snapshot (EPSN versions 1 and 2, emf-plus-snapshot-v1.md).
    # It validates every length against the buffer, so a truncated or inconsistent
    # snapshot raises FormatError rather than yielding partial data.
    class EmfPlusSnapshot
      HEADER_BYTES = 40
      SEGMENT_BYTES = 32
      FRAME_HEADER_BYTES = 64
      DIAGNOSTIC_BYTES = 24

      Segment = Struct.new(:record_index, :logical_start, :payload_length, :data_start, keyword_init: true)
      Frame = Struct.new(:index, :offset, :first_segment, :last_segment, :type, :flags, :frame_size, :data_size,
                         :family, :raw, :typed, keyword_init: true)
      # kind: :empty_slot, :wrong_type or :object_id_out_of_range (the names of
      # Emf::EmfPlus::ObjectTable diagnostics); role: the required object type.
      Diagnostic = Struct.new(:kind, :object_type, :frame_index, :id, :actual_type, keyword_init: true)

      KINDS = { 1 => :empty_slot, 2 => :wrong_type, 3 => :object_id_out_of_range }.freeze
      # The family tags of the frame table.
      FAMILIES = { 0 => :opaque, 1 => :header, 2 => :empty, 3 => :clear, 4 => :rendering_origin, 5 => :stack_index,
                   6 => :begin_container, 7 => :matrix, 8 => :pair, 9 => :scalar, 10 => :clip_rect,
                   0x101 => :drawing, 0x102 => :text, 0x103 => :effect, 0x104 => :ts_graphics,
                   0x105 => :object, 0x106 => :ts_clip }.freeze
      VERSIONS = [1, 2].freeze

      attr_reader :segments, :frames, :diagnostics

      def initialize(buffer)
        @buffer = buffer.b
        read_header
        @segments = read_segments
        @frames = read_frames
        @diagnostics = read_diagnostics
        raise FormatError, "EMF+ snapshot has trailing bytes" unless @cursor == @buffer.bytesize
      end

      private

      def read_header
        raise FormatError, "EMF+ snapshot is truncated" if @buffer.bytesize < HEADER_BYTES

        magic, version, total, @segment_count, @frame_count, @diagnostic_count = @buffer.unpack("a4VQ<4")
        raise FormatError, "not an EMF+ snapshot" unless magic == "EPSN"
        raise FormatError, "unsupported EMF+ snapshot version #{version}" unless VERSIONS.include?(version)
        raise FormatError, "EMF+ snapshot length mismatch" unless total == @buffer.bytesize

        @cursor = HEADER_BYTES
      end

      def take(length)
        raise FormatError, "EMF+ snapshot is truncated" if length.negative? || length > @buffer.bytesize - @cursor

        @buffer.byteslice(@cursor, length).tap { @cursor += length }
      end

      def read_segments
        Array.new(checked_count(@segment_count, SEGMENT_BYTES)) do
          index, start, length, data_start = take(SEGMENT_BYTES).unpack("Q<4")
          Segment.new(record_index: index, logical_start: start, payload_length: length, data_start: data_start)
        end
      end

      def read_frames
        Array.new(checked_count(@frame_count, FRAME_HEADER_BYTES)) do
          head = take(FRAME_HEADER_BYTES)
          index, offset, first, last, type, flags, size, data_size, tag, typed_length, raw_length = head.unpack("Q<4vvVVVQ<2")
          raw = take(raw_length)
          raise FormatError, "EMF+ snapshot frame size mismatch" unless raw_length == size

          Frame.new(index: index, offset: offset, first_segment: first, last_segment: last, type: type, flags: flags,
                    frame_size: size, data_size: data_size, family: FAMILIES.fetch(tag) { raise FormatError, "unknown EMF+ family #{tag}" },
                    raw: raw, typed: take(typed_length))
        end
      end

      def read_diagnostics
        Array.new(checked_count(@diagnostic_count, DIAGNOSTIC_BYTES)) do
          kind, role, frame, id, actual = take(DIAGNOSTIC_BYTES).unpack("VVQ<VV")
          Diagnostic.new(kind: KINDS.fetch(kind) { raise FormatError, "unknown EMF+ diagnostic kind #{kind}" },
                         object_type: role, frame_index: frame, id: id, actual_type: actual)
        end
      end

      # A count the remaining bytes cannot possibly hold is corrupt; this also
      # bounds Array.new before any allocation.
      def checked_count(count, minimum)
        raise FormatError, "EMF+ snapshot count exceeds its length" if count > (@buffer.bytesize - @cursor) / minimum

        count
      end
    end
  end
end
