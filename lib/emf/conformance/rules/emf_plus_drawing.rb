# frozen_string_literal: true

require_relative "emf_plus_common"

# EMF+ drawing geometry rules over the public decoded records: minimum point and
# rectangle counts, the image source unit. Counts that run past the record are
# emfplus.record.body_bounds (the body does not decode at all).
module Emf
  module Conformance
    module EmfPlusDrawing
      Records = Emf::EmfPlus::Records
      Support = EmfPlusSupport

      # record class => [minimum, noun, exact?] from the MS-EMFPLUS 2.3.4 Count descriptions.
      COUNTS = {
        Records::DrawBeziers => [4, "points", false], Records::DrawClosedCurve => [3, "points", false],
        Records::DrawCurve => [2, "points", false], Records::DrawLines => [2, "points", false],
        Records::FillClosedCurve => [3, "points", false], Records::FillPolygon => [3, "points", false],
        Records::DrawImagePoints => [3, "points", true],
        Records::DrawRects => [1, "rectangles", false], Records::FillRects => [1, "rectangles", false]
      }.freeze
      UNIT_PIXEL = 2
      # record class => { compressed? => [Size, DataSize] } from the MS-EMFPLUS 2.3.4.7 and 2.3.4.16 Size and DataSize tables.
      ELLIPSE_SIZES = {
        Records::DrawEllipse => { true => [0x14, 0x08], false => [0x1C, 0x10] },
        Records::FillEllipse => { true => [0x18, 0x0C], false => [0x20, 0x14] }
      }.freeze

      module_function

      def counts(located)
        record = located.record
        minimum, noun, exact = COUNTS.find { |klass, _| record.is_a?(klass) }&.last
        return unless minimum

        count = record.count
        return if exact ? count == minimum : count >= minimum

        "#{Support.type_name(record)} has #{count} #{noun}; #{exact ? 'exactly' : 'at least'} #{minimum} MUST be specified"
      end

      def ellipse_size(located)
        record = located.record
        sizes = ELLIPSE_SIZES.find { |klass, _| record.is_a?(klass) }&.last
        return unless sizes

        size, data_size = sizes.fetch(record.compressed?)
        problems = []
        problems << "Size is #{record.size}, MUST be 0x#{size.to_s(16).rjust(8, '0')}" unless record.size == size
        problems << "DataSize is #{record.data_size}, MUST be 0x#{data_size.to_s(16).rjust(8, '0')}" unless record.data_size == data_size
        return if problems.empty?

        "#{Support.type_name(record)} with the C bit #{record.compressed? ? 'set' : 'clear'}: #{problems.join(' and ')}"
      end

      def source_unit(located)
        record = located.record
        return unless record.is_a?(Records::DrawImage) || record.is_a?(Records::DrawImagePoints)
        return if record.src_unit == UNIT_PIXEL

        "#{Support.type_name(record)} SrcUnit is #{record.src_unit}, MUST be UnitTypePixel (2)"
      end
    end

    EmfPlusSupport.per_record(id: "emfplus.draw.count", citation: "MS-EMFPLUS 2.3.4", kind: :draw_count) do |located|
      EmfPlusDrawing.counts(located)
    end
    EmfPlusSupport.per_record(id: "emfplus.draw.ellipse_size", citation: "MS-EMFPLUS 2.3.4", kind: :draw_size) do |located|
      EmfPlusDrawing.ellipse_size(located)
    end
    EmfPlusSupport.per_record(id: "emfplus.draw.image_source_unit", citation: "MS-EMFPLUS 2.3.4", kind: :draw_source_unit,
                              tolerant_reason: "a real producer writes SrcUnit 0 (spec/fixtures/emf/test-038.emf)") do |located|
      EmfPlusDrawing.source_unit(located)
    end
  end
end
