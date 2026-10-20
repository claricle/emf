# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/emf_plus_records"

RSpec.describe "EMF+ text and image records" do
  include Emf::SpecSupport::EmfPlusRecords

  let(:plus) { Emf::EmfPlus::Records }

  def decode(bytes)
    plus.decode(Emf::EmfPlus::Parser.call(bytes).first)
  end

  def utf16(text) = text.encode(Encoding::UTF_16LE).b

  shared_examples "a lossless record" do
    it "re-encodes byte-identically" do
      expect(subject.to_binary).to eq(bytes)
    end
  end

  shared_examples "a record that rejects a truncated body" do |type|
    it "raises ParseError carrying the offset and record code" do
      cut = record(type, body.byteslice(0, body.bytesize - 8), flags: flags)

      expect { decode(cut) }.to raise_error(Emf::ParseError) { |e| expect(e.record_code).to eq(type) }
    end
  end

  describe "DrawString" do
    let(:flags) { 0x8002 }
    let(:text) { "Hi!" }
    let(:body) do
      [0xFF112233, 4, 3].pack("VVV") + [1.0, 2.0, 30.0, 40.0].pack("e4") + utf16(text) + "\x00\x00".b
    end
    let(:bytes) { record(0x401C, body, flags: flags) }
    subject(:draw_string) { decode(bytes) }

    it "decodes the layout, string and flag bits" do
      expect(draw_string).to be_a(plus::DrawString)
      expect(draw_string).to have_attributes(brush_id: 0xFF112233, format_id: 4, length: 3, text: "Hi!",
                                             font_object_id: 2, layout_rect: [1.0, 2.0, 30.0, 40.0])
      expect(draw_string).to be_solid_color
    end

    it "reads a clear S bit as a brush object id" do
      expect(decode(record(0x401C, body, flags: 0x0002))).not_to be_solid_color
    end

    it "keeps alignment padding in trailing" do
      expect(draw_string.trailing).to eq("\x00\x00".b)
    end

    it_behaves_like "a lossless record"
    it_behaves_like "a record that rejects a truncated body", 0x401C
  end

  describe "DrawDriverString" do
    let(:flags) { 0x8004 }
    let(:matrix) { [1.0, 0.0, 0.0, 1.0, 5.0, 6.0] }
    let(:body) do
      [0xFF000000, 1, 1, 2].pack("VVVV") + [0x53, 0x41].pack("v2") +
        [1.0, 2.0, 3.0, 4.0].pack("e4") + matrix.pack("e6")
    end
    let(:bytes) { record(0x4036, body, flags: flags) }
    subject(:driver_string) { decode(bytes) }

    it "decodes glyphs, positions, options and the optional matrix" do
      expect(driver_string).to be_a(plus::DrawDriverString)
      expect(driver_string).to have_attributes(brush_id: 0xFF000000, glyph_count: 2, glyphs: [0x53, 0x41],
                                               glyph_positions: [[1.0, 2.0], [3.0, 4.0]], transform_matrix: matrix,
                                               font_object_id: 4)
      expect(driver_string).to be_solid_color.and be_cmap_lookup.and be_matrix_present
    end

    it "omits the matrix when MatrixPresent is zero" do
      plain = [0, 0, 0, 2].pack("VVVV") + [7, 8].pack("v2") + [1.0, 2.0, 3.0, 4.0].pack("e4")
      driver = decode(record(0x4036, plain, flags: 0x0001))

      expect(driver).to have_attributes(transform_matrix: nil, glyphs: [7, 8], glyph_positions: [[1.0, 2.0], [3.0, 4.0]])
      expect(driver).not_to be_cmap_lookup
      expect(driver.to_binary).to eq(record(0x4036, plain, flags: 0x0001))
    end

    it_behaves_like "a lossless record"
    it_behaves_like "a record that rejects a truncated body", 0x4036
  end

  describe "DrawImage" do
    let(:src) { [0.0, 0.0, 10.0, 20.0].pack("e4") }

    context "with the C flag" do
      let(:flags) { 0x4003 }
      let(:body) { [7, 2].pack("Vl<") + src + [1, 2, 3, 4].pack("s<4") }
      let(:bytes) { record(0x401A, body, flags: flags) }
      subject(:image) { decode(bytes) }

      it "reads RectData as an integer EmfPlusRect" do
        expect(image).to be_a(plus::DrawImage)
        expect(image).to have_attributes(image_object_id: 3, image_attributes_id: 7, src_unit: 2,
                                         src_rect: [0.0, 0.0, 10.0, 20.0], dest_rect: [1, 2, 3, 4])
        expect(image).to be_compressed
      end

      it_behaves_like "a lossless record"
      it_behaves_like "a record that rejects a truncated body", 0x401A
    end

    context "without the C flag" do
      let(:flags) { 0x0003 }
      let(:body) { [7, 2].pack("Vl<") + src + [1.5, 2.5, 3.5, 4.5].pack("e4") }
      let(:bytes) { record(0x401A, body, flags: flags) }
      subject(:image) { decode(bytes) }

      it "reads RectData as a float EmfPlusRectF" do
        expect(image.dest_rect).to eq([1.5, 2.5, 3.5, 4.5])
        expect(image).not_to be_compressed
      end

      it_behaves_like "a lossless record"
      it_behaves_like "a record that rejects a truncated body", 0x401A
    end
  end

  describe "DrawImagePoints" do
    let(:head) { [1, 2].pack("Vl<") + [0.0, 0.0, 10.0, 20.0].pack("e4") + [3].pack("V") }
    subject(:points) { decode(bytes) }
    let(:bytes) { record(0x401B, body, flags: flags) }

    context "with absolute float points" do
      let(:flags) { 0x0005 }
      let(:body) { head + [1.0, 2.0, 3.0, 4.0, 5.0, 6.0].pack("e6") }

      it "decodes PointF elements" do
        expect(points).to be_a(plus::DrawImagePoints)
        expect(points).to have_attributes(image_object_id: 5, image_attributes_id: 1, src_unit: 2, count: 3,
                                          src_rect: [0.0, 0.0, 10.0, 20.0],
                                          points: [[1.0, 2.0], [3.0, 4.0], [5.0, 6.0]])
        expect(points).not_to be_compressed
        expect(points).not_to be_relative
        expect(points).not_to be_effect
      end

      it_behaves_like "a lossless record"
      it_behaves_like "a record that rejects a truncated body", 0x401B
    end

    context "with the C flag" do
      let(:flags) { 0x4005 }
      let(:body) { head + [1, -2, 3, 4, 5, 6].pack("s<6") }

      it "decodes 16-bit Point elements" do
        expect(points.points).to eq([[1, -2], [3, 4], [5, 6]])
        expect(points).to be_compressed
      end

      it_behaves_like "a lossless record"
    end

    context "with the E flag" do
      let(:flags) { 0x2005 }
      let(:body) { head + [1.0, 2.0, 3.0, 4.0, 5.0, 6.0].pack("e6") }

      it "reports that an effect precedes the draw" do
        expect(points).to be_effect
      end
    end

    context "with the P flag (C ignored)" do
      let(:flags) { 0x4805 }
      # (5,-3) as Integer7s; (300,-1) as Integer15s; (0,4000) as Integer7 then Integer15; padded to 4.
      let(:body) do
        head + [0x05, 0x7D, 0x81, 0x2C, 0xFF, 0xFF, 0x00, 0x8F, 0xA0, 0x00, 0x00, 0x00].pack("C*")
      end

      it "decodes variable-length EmfPlusPointR elements" do
        expect(points).to be_relative
        expect(points).not_to be_compressed
        expect(points.points).to eq([[5, -3], [300, -1], [0, 4000]])
        expect(points.trailing).to eq("\x00\x00\x00".b)
      end

      it_behaves_like "a lossless record"
    end

    context "with the P flag and extreme values" do
      let(:flags) { 0x0800 }
      let(:body) { head + [0xC0, 0x00, 0xFF, 0xFF, 0x7F, 0x3F, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00].pack("C*") }

      it "sign-extends Integer7 and Integer15 values" do
        expect(points.points).to eq([[-16_384, -1], [-1, 63], [-64, 0]])
      end
    end
  end

  describe "SerializableObject" do
    let(:guid_bytes) { [0x633C80A4, 0x1843, 0x482B, 0x9E, 0xF2, 0xBE, 0x28, 0x34, 0xC5, 0xFD, 0xD4].pack("VvvC8") }
    let(:buffer) { [8, 0x4170].pack("Vv") + "\x00\x00".b }
    let(:flags) { 0 }
    let(:body) { guid_bytes + [buffer.bytesize].pack("V") + buffer }
    let(:bytes) { record(0x4038, body) }
    subject(:serializable) { decode(bytes) }

    it "decodes the GUID in canonical form and the buffer" do
      expect(serializable).to be_a(plus::SerializableObject)
      expect(serializable).to have_attributes(object_guid: "633c80a4-1843-482b-9ef2-be2834c5fdd4",
                                              buffer_size: 8, buffer: buffer)
    end

    it_behaves_like "a lossless record"
    it_behaves_like "a record that rejects a truncated body", 0x4038
  end

  describe "against the corpus" do
    types = %i[DrawString DrawDriverString DrawImage DrawImagePoints SerializableObject]
            .map { |name| Emf::EmfPlus::Records.const_get(name) }.freeze
    fixtures = Dir[File.expand_path("../../fixtures/{emf,emf-ea,simple}/*.emf", __dir__)].select do |path|
      next false unless File.binread(path).include?("EMF+")

      Emf.parse(File.binread(path)).emf_plus
    rescue Emf::Error
      false
    end

    it "finds EMF+ fixtures to check" do
      expect(fixtures).not_to be_empty
    end

    fixtures.each do |path|
      it "decodes and re-encodes every text/image record of #{File.basename(path)}" do
        frames = Emf::EmfPlus::Parser.call(Emf.parse(File.binread(path)).emf_plus)
        mine = frames.select { |f| types.map { |t| t::TYPE }.include?(f.type) }

        decoded = mine.map { |f| plus.decode(f) }
        expect(decoded).to all(satisfy { |r| types.include?(r.class) })
        expect(decoded.map(&:to_binary)).to eq(mine.map { |f| Emf::EmfPlus::Serializer.call([f]) })
      end
    end
  end
end
