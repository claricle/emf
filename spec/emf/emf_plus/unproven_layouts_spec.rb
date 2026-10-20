# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/emf_plus_records"

# Layouts no corpus file exercises, pinned against [MS-EMFPLUS] 2.2.2.21,
# 2.2.2.22, 2.2.2.37, 2.3.4.6 and 2.3.8.1 (reference-docs/ms-emfplus).
RSpec.describe "EMF+ layouts without corpus coverage" do
  include Emf::SpecSupport::EmfPlusRecords

  let(:plus) { Emf::EmfPlus::Records }

  def decode(bytes) = plus.decode(Emf::EmfPlus::Parser.call(bytes).first)

  describe "PointR" do
    let(:described_class) { plus::Primitives::PointR }

    def read(*bytes) = described_class.read(bytes.pack("C*"))

    def coordinates(point) = [point.x.to_i, point.y.to_i]

    # Integer7 is a 0 bit then 7 bits; Integer15 is a 1 bit then 15 bits
    # (2.2.2.21, 2.2.2.22). The 15-bit value is high-order byte first.
    {
      [0x00, 0x00] => [0, 0],
      [0x3F, 0x40] => [63, -64],
      [0x7F, 0x41] => [-1, -63],
      [0x80, 0x00, 0x80, 0x01] => [0, 1],
      [0xBF, 0xFF, 0xC0, 0x00] => [16_383, -16_384],
      [0xFF, 0xFF, 0xFF, 0xFE] => [-1, -2],
      [0x81, 0x02, 0x82, 0x01] => [258, 513],
      [0x05, 0x81, 0x02] => [5, 258],
      [0x81, 0x02, 0x05] => [258, 5]
    }.each do |bytes, expected|
      it "decodes #{bytes.map { |b| format('%02X', b) }.join(' ')} to #{expected.inspect} and re-encodes it" do
        point = read(*bytes)

        expect(coordinates(point)).to eq(expected)
        expect(point.to_binary_s.bytes).to eq(bytes)
      end
    end

    it "reads a 15-bit value high byte first, not as a little-endian word" do
      expect(read(0x81, 0x02, 0x00).x.to_i).not_to eq(0x0281)
    end

    context "inside a DrawLines record with the P flag" do
      let(:points) { "\x05\xC0\x00\x81\x02\x3F\x80\x01\x00".b }
      let(:bytes) { record(0x400D, [3].pack("V") + points + "\0\0\0".b, flags: 0x4800, data_size: 4 + points.bytesize) }

      it "re-encodes byte-identically and survives an edit" do
        lines = decode(bytes)
        edited = lines.with(item_count: 1, point_data: { relative_points: [{ x: { lead: 0xBF, low: 0xFF }, y: { lead: 0x40 } }] })

        expect(lines.points.map { |p| [p.x.to_i, p.y.to_i] }).to eq([[5, -16_384], [258, 63], [1, 0]])
        expect(lines.to_binary).to eq(bytes)
        expect(decode(edited.to_binary).points.map { |p| [p.x.to_i, p.y.to_i] }).to eq([[16_383, -64]])
      end
    end
  end

  describe "DrawDriverString with an odd glyph count" do
    # Glyphs then GlyphPos run on with no padding between them; the record is
    # then padded to a 32-bit Size (2.3.4.6 has no padding field).
    let(:matrix) { [1.0, 0.0, 0.0, 1.0, 5.0, 6.0] }
    let(:glyphs) { [0x41, 0x42, 0x43] }
    let(:positions) { [1.0, 2.0, 3.0, 4.0, 5.0, 6.0] }
    let(:head) { ->(matrix_present) { [0xFF000000, 1, matrix_present, 3].pack("V4") } }
    let(:plain) { head.call(0) + glyphs.pack("v*") + positions.pack("e*") }
    let(:with_matrix) { head.call(1) + glyphs.pack("v*") + positions.pack("e*") + matrix.pack("e*") }

    it "reads positions straight after the glyphs, with the pad bytes left over" do
      bytes = record(0x4036, plain + "\0\0".b, flags: 0x8002, data_size: plain.bytesize)
      rec = decode(bytes)

      expect(rec).to have_attributes(glyphs: glyphs, glyph_positions: [[1.0, 2.0], [3.0, 4.0], [5.0, 6.0]],
                                     transform_matrix: nil, trailing: "\0\0".b)
      expect(rec.to_binary).to eq(bytes)
    end

    it "reads the matrix after the positions" do
      bytes = record(0x4036, with_matrix + "\0\0".b, flags: 0x8002, data_size: with_matrix.bytesize)
      rec = decode(bytes)

      expect(rec).to have_attributes(glyph_positions: [[1.0, 2.0], [3.0, 4.0], [5.0, 6.0]], transform_matrix: matrix)
      expect(rec.to_binary).to eq(bytes)
    end

    it "keeps Size 32-bit aligned when a glyph is added or removed" do
      rec = decode(record(0x4036, plain + "\0\0".b, flags: 0x8002, data_size: plain.bytesize))
      four = rec.with(glyph_count: 4, glyphs: [1, 2, 3, 4], glyph_positions: Array.new(4) { { x: 1.0, y: 2.0 } })
      frame = Emf::EmfPlus::Parser.call(four.to_binary).first

      expect([frame.size, frame.data_size]).to eq([28 + 40, 16 + 40])
      expect(decode(four.to_binary).glyphs).to eq([1, 2, 3, 4])
    end
  end

  describe "SetTSClip" do
    # C set: 4 bytes per rectangle (Size = NumRects * 4 + 12).
    let(:packed) { "\x81\x82\x03\x04\x85\x86\x07\x08".b }
    let(:bytes) { record(0x403A, packed, flags: 0x8002) }

    it "frames NumRects 4-byte rectangles and re-encodes them unchanged" do
      rec = decode(bytes)

      expect(rec).to be_compressed
      expect(rec).to have_attributes(rect_count: 2, rect_data: packed)
      expect(rec.to_binary).to eq(bytes)
      expect(rec.size).to eq((2 * 4) + 12)
    end

    it "reads 8-byte rectangles when C is clear" do
      wide = [1, 2, 3, 4, 5, 6, 7, 8].pack("s<*")
      rec = decode(record(0x403A, wide, flags: 0x0002))

      expect(rec).to have_attributes(rect_count: 2, rects: [[1, 2, 3, 4], [5, 6, 7, 8]])
      expect(rec.size).to eq((2 * 8) + 12)
    end

    it "flips between the two forms through the C flag, keeping the data and count" do
      edited = decode(bytes).with(compressed: false, rect_data: [1, 2, 3, 4, 5, 6, 7, 8].pack("s<*"))

      expect(decode(edited.to_binary)).to have_attributes(compressed?: false, rect_count: 2, rects: [[1, 2, 3, 4], [5, 6, 7, 8]])
    end
  end
end
