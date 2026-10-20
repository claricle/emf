# frozen_string_literal: true

require "emf/native/loader"
require_relative "emf_plus_generated_fixtures"

module Emf
  module SpecSupport
    # Test-only binding: EPSN is independent of the production outer snapshot loader.
    class EmfPlusNativeSnapshot < Emf::Native::Loader
      def initialize(path)
        super
        @epsn_library = Fiddle.dlopen(path)
        signature = [POINTER, POINTER, POINTER, POINTER, POINTER]
        @functions[:emf_document_emf_plus_snapshot_v1] = Fiddle::Function.new(
          @epsn_library["emf_document_emf_plus_snapshot_v1"], signature, Fiddle::TYPE_INT
        )
      end

      def call(bytes)
        options = [16, 1, 1 << 20].pack("VVQ<")
        document(bytes) { |handle| buffer(:emf_document_emf_plus_snapshot_v1, handle, options, 0) }
      end
    end

    module EmfPlusSegmentParity
      module_function

      def parse(bytes, backend, library)
        previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
        ENV["EMF_BACKEND"] = backend
        ENV["EMF_NATIVE_LIBRARY"] = library
        Emf.parse(bytes)
      ensure
        %w[EMF_BACKEND EMF_NATIVE_LIBRARY].each { |key| ENV[key] = previous[key] }
      end

      def file(payloads)
        fixtures = EmfPlusGeneratedFixtures
        gap = [25, 12, 0x12345678].pack("V3")
        comments = payloads.map do |payload|
          comment = fixtures.comment(payload)
          # Preserve bytes outside cbData, including nonzero alignment and a suffix.
          data_length = 4 + payload.bytesize
          comment[(12 + data_length)..] = "#{"\xA5".b * (-data_length % 4)}TAIL".b
          comment[4, 4] = [comment.bytesize].pack("V")
          comment
        end
        body = [gap, *comments.flat_map { |comment| [comment, gap] }, fixtures::EOF_RECORD].join.b
        fixtures.header_bytes(88 + body.bytesize, (comments.size * 2) + 3) + body
      end

      def segment_rows(stream)
        logical_start = 0
        stream.segments.map do |segment|
          length = segment.payload.bytesize
          row = [segment.record_index, logical_start, length, segment.payload_range.begin]
          logical_start += length
          row
        end
      end

      def frames(snapshot)
        count = snapshot.byteslice(24, 8).unpack1("Q<")
        offset = 40 + (snapshot.byteslice(16, 8).unpack1("Q<") * 32)
        Array.new(count) do
          header = snapshot.byteslice(offset, 64)
          typed_length, raw_length = header.byteslice(48, 16).unpack("Q<2")
          raw = snapshot.byteslice(offset + 64, raw_length)
          typed = snapshot.byteslice(offset + 64 + raw_length, typed_length)
          offset += 64 + raw_length + typed_length
          { range: header.byteslice(8, 24).unpack("Q<3"), raw: raw,
            family: header.byteslice(44, 4).unpack1("V"), typed: typed }
        end
      end

      def view(stream)
        { segments: stream.segments.map do |segment|
          [segment.record_index, segment.payload_range, segment.payload,
           segment.unframed, segment.tail, segment.dirty?]
        end,
          records: stream.records.map do |handle|
            [handle.record.class.name, handle.record.to_binary,
             handle.segment_index, handle.offset, handle.stream_index]
          end,
          gaps: stream.entries.select(&:gap?).map(&:range),
          errors: stream.errors.map { |error| [error.class.name, error.message] }, dirty: stream.dirty?, stale: stream.stale? }
      end
    end
  end
end
