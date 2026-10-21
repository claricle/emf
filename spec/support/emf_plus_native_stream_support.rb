# frozen_string_literal: true

require_relative "emf_plus_generated_fixtures"

module Emf
  module SpecSupport
    # Helpers for comparing Emf::Native::EmfPlusStream with the Ruby Stream.
    module EmfPlusNativeStreamSupport
      module_function

      # Fixtures the native snapshot cannot stand in for: corrupted nested EMF+
      # (a malformed Size/DataSize, or an EMR_COMMENT whose cbData exceeds its data).
      NATIVE_FALLBACK = %w[
        spec/fixtures/emf-corrupted/bad_corrupted_2014-12-07-163010.emf
        spec/fixtures/emf-corrupted/bad_corrupted_2017-02-11-230400.emf
        spec/fixtures/emf-corrupted/bad_corrupted_2017-02-12-010400.emf
      ].freeze

      # Flag-only records have a typed empty body.
      EMPTY_BODY = %i[EndOfFile GetDC ResetClip ResetWorldTransform SetAntiAliasMode SetClipPath SetClipRegion
                      SetCompositingMode SetCompositingQuality SetInterpolationMode SetPixelOffsetMode SetTextContrast
                      SetTextRenderingHint].freeze
      DRAWING = %i[DrawArc DrawBeziers DrawClosedCurve DrawCurve DrawEllipse DrawImage DrawImagePoints DrawLines DrawPath
                   DrawPie DrawRects FillClosedCurve FillEllipse FillPath FillPie FillPolygon FillRects FillRegion].freeze

      FAMILY_BY_CLASS = {
        Emf::EmfPlus::Records::Header => :header,
        Emf::EmfPlus::Records::Clear => :clear,
        Emf::EmfPlus::Records::SetRenderingOrigin => :rendering_origin,
        Emf::EmfPlus::Records::BeginContainer => :begin_container,
        Emf::EmfPlus::Records::Save => :stack_index,
        Emf::EmfPlus::Records::Restore => :stack_index,
        Emf::EmfPlus::Records::EndContainer => :stack_index,
        Emf::EmfPlus::Records::BeginContainerNoParams => :stack_index,
        Emf::EmfPlus::Records::SetWorldTransform => :matrix,
        Emf::EmfPlus::Records::MultiplyWorldTransform => :matrix,
        Emf::EmfPlus::Records::TranslateWorldTransform => :pair,
        Emf::EmfPlus::Records::ScaleWorldTransform => :pair,
        Emf::EmfPlus::Records::OffsetClip => :pair,
        Emf::EmfPlus::Records::RotateWorldTransform => :scalar,
        Emf::EmfPlus::Records::SetPageTransform => :scalar,
        Emf::EmfPlus::Records::SetClipRect => :clip_rect,
        Emf::EmfPlus::Records::Object => :object,
        Emf::EmfPlus::Records::SerializableObject => :effect,
        Emf::EmfPlus::Records::SetTSGraphics => :ts_graphics,
        Emf::EmfPlus::Records::DrawString => :text,
        Emf::EmfPlus::Records::DrawDriverString => :text,
        # Typed in core but opaque in the frozen v1 schema.
        Emf::EmfPlus::Records::SetTSClip => :opaque,
        Emf::EmfPlus::Records::Comment => :opaque,
        Emf::EmfPlus::Records::Unknown => :opaque,
        **EMPTY_BODY.to_h { |name| [Emf::EmfPlus::Records.const_get(name), :empty] },
        **DRAWING.to_h { |name| [Emf::EmfPlus::Records.const_get(name), :drawing] }
      }.freeze

      ROLE_TYPES = { brush: 1, pen: 2, path: 3, region: 4, image: 5, font: 6, string_format: 7, image_attributes: 8 }.freeze

      def fixture_paths
        Dir.glob("spec/fixtures/**/*.emf")
      end

      def ruby_parse(bytes)
        previous = ENV.fetch("EMF_BACKEND", nil)
        ENV["EMF_BACKEND"] = "ruby"
        Emf.parse(bytes)
      ensure
        ENV["EMF_BACKEND"] = previous
      end

      # nil for the corrupted corpus files Ruby itself rejects.
      def try_parse(bytes)
        ruby_parse(bytes)
      rescue Emf::Error
        nil
      end

      def view(stream)
        { segments: stream.segments.map do |segment|
          [segment.record_index, segment.payload_range, segment.payload, segment.unframed, segment.tail, segment.dirty?]
        end,
          records: stream.records.map do |handle|
            [handle.record.class, handle.record.to_binary, handle.record.offset, handle.record.comment_index,
             handle.segment_index, handle.offset, handle.stream_index]
          end,
          gaps: stream.entries.select(&:gap?).map(&:range),
          errors: stream.errors.map { |error| [error.class.name, error.message] }, dirty: stream.dirty?, stale: stream.stale? }
      end

      # [kind, required object type, frame index, raw id, actual object type] per unresolved reference.
      def native_diagnostics(stream)
        stream.reference_diagnostics.map do |d|
          [d.kind, d.object_type, d.frame_index, d.id, d.actual_type]
        end
      end

      def ruby_diagnostics(stream)
        stream.records.flat_map do |handle|
          stream.resolve(handle).filter_map do |resolution|
            diagnostic = resolution.diagnostic or next
            actual = diagnostic.kind == :wrong_type ? stream.objects.lookup(resolution.raw_id, at: handle.stream_index).object_type : 0
            [diagnostic.kind, ROLE_TYPES.fetch(resolution.role), handle.stream_index, resolution.raw_id, actual]
          end
        end
      end

      # A FillRects of one integer rectangle; `brush` is an object ID or, with `solid`, an ARGB color.
      def fill(brush, solid: false)
        body = [brush, 1].pack("V2") + [0, 0, 1, 1].pack("s<4")
        EmfPlusGeneratedFixtures.record(0x400A, body, flags: 0x4000 | (solid ? 0x8000 : 0))
      end
    end
  end
end
