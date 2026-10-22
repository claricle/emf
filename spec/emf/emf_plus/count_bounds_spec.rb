# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/emf_plus_generated_fixtures"

RSpec.describe Emf::EmfPlus::Records, "untrusted element counts" do
  let(:fixtures) { Emf::SpecSupport::EmfPlusGeneratedFixtures }
  let(:huge) { 0xFFFFFFF0 }
  let(:count_and_one_element) { [huge, 1].pack("V2") }

  def stream_of(type, body, flags: 0)
    bytes = fixtures.single_comment(fixtures.record(type, body, flags: flags))
    Emf.parse(bytes).emf_plus_stream
  end

  flag_variants = [0, 0x4000, 0x0800].freeze

  # Each case: record type, the body bytes before the count, and the count's own field.
  {
    "FillRects" => [0x400A, [0].pack("V")],
    "DrawRects" => [0x400B, ""],
    "FillPolygon" => [0x400C, [0].pack("V")],
    "DrawLines" => [0x400D, ""],
    "FillClosedCurve" => [0x4016, [0].pack("V") + [0.0].pack("e")],
    "DrawClosedCurve" => [0x4017, [0.0].pack("e")],
    "DrawCurve" => [0x4018, [0.0].pack("e") + [0, 1].pack("V2")],
    "DrawBeziers" => [0x4019, ""],
    "DrawImagePoints" => [0x401B, [0, 0].pack("V2") + ([0.0] * 4).pack("e4")],
    "DrawDriverString" => [0x4036, [0, 0, 0].pack("V3")]
  }.each do |name, (type, prefix)|
    flag_variants.each do |flags|
      context "with #{name} (flags #{format('0x%04X', flags)}) claiming 4294967280 elements in 4 bytes" do
        let(:stream) { stream_of(type, prefix + count_and_one_element, flags: flags) }

        it "is diagnosed as a malformed record and kept as Unknown" do
          expect(stream.records.map { |handle| handle.record.class.name.split("::").last })
            .to eq(%w[Header Unknown EndOfFile])
          expect(stream.errors.map(&:class)).to eq([Emf::ParseError])
          expect(stream.errors.first.record_code).to eq(type)
          expect(stream.errors.first.message).to match(/malformed .* body at offset \d+/)
        end
      end
    end
  end

  context "with a count that fits the record" do
    it "still reads two compressed rectangles" do
      body = [0, 2].pack("V2") + [1, 2, 3, 4, 5, 6, 7, 8].pack("s<8")
      record = stream_of(0x400A, body, flags: 0x4000).records.fetch(1).record

      expect(record.class).to eq(described_class::FillRects)
      expect(record.rects.map { |rect| rect.snapshot.values.map(&:to_i) }).to eq([[1, 2, 3, 4], [5, 6, 7, 8]])
      expect(record.count).to eq(2)
    end

    it "reads a count of zero" do
      record = stream_of(0x400D, [0].pack("V")).records.fetch(1).record

      expect([record.class, record.count]).to eq([described_class::DrawLines, 0])
    end
  end

  context "with a SetTSGraphics palette claiming a huge PaletteCount" do
    let(:record) { stream_of(0x4039, ("\0".b * 36) + [0, huge].pack("V2") + [1].pack("V"), flags: 1).records.fetch(1).record }

    it "has no decoded palette and keeps its bytes" do
      expect(record.decoded_palette).to be_nil
      expect(record.palette.bytesize).to eq(12)
    end

    it "reads a palette whose count fits" do
      palette = [0, 1].pack("V2") + [1, 2, 3, 4].pack("C4")
      decoded = stream_of(0x4039, ("\0".b * 36) + palette, flags: 1).records.fetch(1).record.decoded_palette

      expect(decoded.palette_count).to eq(1)
    end
  end

  context "with a bounded array outside any record" do
    it "raises EOFError before building elements" do
      expect { Emf::EmfPlus::Records::Primitives::Palette.read([0, huge].pack("V2")) }.to raise_error(EOFError, /need at least/)
    end
  end
end
