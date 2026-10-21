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

      # Independent expected EPSN encodings follow emf-plus-snapshot-v1.md and
      # the Rust FFI acceptance vectors, rather than deriving them from EPSN.
      def typed_cases
        object_cases + effect_cases + tsgraphics_cases + drawing_text_cases + fixed_cases
      end

      def object_cases
        version = EmfPlusGeneratedFixtures::VERSION
        [[EmfPlusGeneratedFixtures.object_record(1, 1, version + [0, 0x80FF0033].pack("V2")),
          0x105, [0, 0].pack("V2") + [1, 1].pack("Q<2") + [1, 1, 1, 1, 0xDBC01002, 0x80FF0033].pack("V6")],
         [EmfPlusGeneratedFixtures.object_record(127, 2, "OBJ!"),
          0x105, [[0, 0].pack("V2"), [2, 2].pack("Q<2"), [1, 2, 127, 0, 127].pack("V5"), [4].pack("Q<"), "OBJ!"].join]]
      end

      def effect_cases
        fixtures = EmfPlusGeneratedFixtures
        guid = [0xA4, 0x80, 0x3C, 0x63, 0x43, 0x18, 0x2B, 0x48, 0x9E, 0xF2, 0xBE, 0x28, 0x34, 0xC5, 0xFD, 0xD4].pack("C*")
        blur = [2.5].pack("e") + [0xFFFFFFFF].pack("V")
        [[fixtures.record(0x4038, guid + [8].pack("V") + blur), 0x103, [1].pack("V") + guid + blur],
         [fixtures.record(0x4038, [("G" * 16), [4].pack("V"), "FX!?"].join),
          0x103, [[0].pack("V"), ("G" * 16), [4].pack("Q<"), "FX!?"].join]]
      end

      def tsgraphics_cases
        transform = [-0.0, 0, 0, 1, 5, 6].pack("e6")
        fixed_body = [255, 128, 127, 254, -32_768, 32_767, 65_535, 165, 182].pack("C4s<2vC2") + transform
        fixed_typed = [255, 128, 127, 254, 0xFFFF8000, 32_767, 65_535, 165, 182].pack("V9") + transform
        style = [0xFEDCBA98].pack("V")
        [nil, [], [0x80FF0033, 0x00010203]].map do |entries|
          body = fixed_body.dup
          typed = fixed_typed.dup
          typed += [entries.nil? ? 0 : 1].pack("V")
          unless entries.nil?
            body += [0xFEDCBA98, entries.size, *entries].pack("V*")
            typed += style + [entries.size].pack("Q<") + entries.pack("V*")
          end
          [EmfPlusGeneratedFixtures.record(0x4039, body, flags: entries.nil? ? 0xFFFE : 0xFFFF), 0x104, typed]
        end
      end

      def drawing_text_cases
        fixtures = EmfPlusGeneratedFixtures
        ellipse = fixtures.record(0x400E, [0x80FF0033].pack("V") + [-3, 4, 5, 6].pack("s<4"), flags: 0xC000)
        ellipse_typed = [2, 1, 0x80FF0033, 1].pack("V4") + [-3, 4, 5, 6].pack("l<4")
        text = [0xD800, 0x0061, 0xFFFF].pack("v3")
        layout = [1, 2, 3, 4].pack("e4")
        string = fixtures.record(0x401C, [[7, 8, 3].pack("V3"), layout, text, "P!"].join, flags: 0x8005)
        string_typed = [[1, 7, 8].pack("V3"), layout, [3].pack("Q<"), text, [2].pack("Q<"), "P!"].join
        clip = fixtures.record(0x403A, "RAW!", flags: 0x8001)
        [[ellipse, 0x101, ellipse_typed], [string, 0x102, string_typed], [clip, 0, "".b]]
      end

      def fixed_cases
        { SetRenderingOrigin: 4, Save: 5, BeginContainer: 6, SetWorldTransform: 7,
          TranslateWorldTransform: 8, RotateWorldTransform: 9, SetClipRect: 10 }.map do |name, family|
          example = EmfPlusGeneratedFixtures.example(name)
          [EmfPlusGeneratedFixtures.typed_record(name), family, example.body]
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
