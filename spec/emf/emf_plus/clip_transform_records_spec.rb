# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/emf_plus_records"

RSpec.describe "EMF+ clipping and transform records" do
  include Emf::SpecSupport::EmfPlusRecords

  let(:records) { Emf::EmfPlus::Records }

  def decode(bytes)
    records.decode(Emf::EmfPlus::Parser.call(bytes).first)
  end

  def floats(*values) = values.pack("e*")

  shared_examples "a typed record" do |klass_name|
    it "decodes to its class and re-encodes identically" do
      expect(decode(bytes)).to be_a(records.const_get(klass_name))
      expect(decode(bytes).to_binary).to eq(bytes)
    end
  end

  shared_examples "a record that rejects a short body" do |type|
    it "raises ParseError with offset and record code" do
      expect { decode(short) }
        .to raise_error(Emf::ParseError, /malformed/) { |e| expect([e.offset, e.record_code]).to eq([0, type]) }
    end
  end

  describe Emf::EmfPlus::Records::ResetClip do
    let(:bytes) { record(0x4031, "", flags: 0x1234) }

    include_examples "a typed record", :ResetClip
  end

  describe Emf::EmfPlus::Records::OffsetClip do
    let(:bytes) { record(0x4035, floats(1.5, -2.0)) }
    let(:short) { record(0x4035, floats(1.5)) }

    include_examples "a typed record", :OffsetClip
    include_examples "a record that rejects a short body", 0x4035

    it "decodes dx and dy" do
      expect(decode(bytes)).to have_attributes(dx: 1.5, dy: -2.0)
    end
  end

  describe Emf::EmfPlus::Records::SetClipRect do
    let(:bytes) { record(0x4032, floats(1.0, 2.0, 30.0, 40.0), flags: 0x0300) }
    let(:short) { record(0x4032, floats(1.0, 2.0, 30.0)) }

    include_examples "a typed record", :SetClipRect
    include_examples "a record that rejects a short body", 0x4032

    it "decodes the combine mode and the rectangle" do
      rec = decode(bytes)

      expect(rec.combine_mode).to eq(3)
      expect(rec.clip_rect).to have_attributes(x: 1.0, y: 2.0, width: 30.0, height: 40.0)
    end
  end

  [[0x4033, :SetClipPath], [0x4034, :SetClipRegion]].each do |type, name|
    describe "SetClip#{name.to_s.delete_prefix('SetClip')}" do
      let(:bytes) { record(type, "", flags: 0x0407) }

      include_examples "a typed record", name

      it "decodes the combine mode and object id from Flags" do
        expect(decode(bytes)).to have_attributes(combine_mode: 4, emf_object_id: 7)
      end

      it "masks the reserved bits out of both fields" do
        expect(decode(record(type, "", flags: 0xF0FF))).to have_attributes(combine_mode: 0, emf_object_id: 0xFF)
      end
    end
  end

  describe Emf::EmfPlus::Records::SetTSClip do
    let(:wide) { [1, -2, 300, 400, 5, 6, 7, 8].pack("s<*") }
    let(:bytes) { record(0x403A, wide, flags: 2) }

    include_examples "a typed record", :SetTSClip

    it "decodes uncompressed rectangles as x, y, width, height" do
      rec = decode(bytes)

      expect(rec).not_to be_compressed
      expect(rec).to have_attributes(rect_count: 2, rects: [[1, -2, 300, 400], [5, 6, 7, 8]])
    end

    it "keeps compressed rectangle data raw and reads the count" do
      packed = "\x81\x82\x83\x84".b
      rec = decode(record(0x403A, packed, flags: 0x8001))

      expect(rec).to be_compressed
      expect(rec).to have_attributes(rect_count: 1, rect_data: packed, rects: [])
      expect(rec.to_binary).to eq(record(0x403A, packed, flags: 0x8001))
    end

    it "raises ParseError when DataSize outruns the data" do
      expect { decode(record(0x403A, wide, flags: 2, size: 12 + wide.bytesize, data_size: wide.bytesize + 8)) }
        .to raise_error(Emf::ParseError)
    end
  end

  describe Emf::EmfPlus::Records::SetWorldTransform do
    let(:bytes) { record(0x402A, floats(1, 0, 0, 1, 10, 20)) }
    let(:short) { record(0x402A, floats(1, 0, 0, 1, 10)) }

    include_examples "a typed record", :SetWorldTransform
    include_examples "a record that rejects a short body", 0x402A

    it "decodes the six matrix elements" do
      expect(decode(bytes).matrix).to have_attributes(m11: 1, m12: 0, m21: 0, m22: 1, dx: 10, dy: 20)
    end
  end

  describe Emf::EmfPlus::Records::ResetWorldTransform do
    let(:bytes) { record(0x402B, "") }

    include_examples "a typed record", :ResetWorldTransform
  end

  describe Emf::EmfPlus::Records::MultiplyWorldTransform do
    let(:bytes) { record(0x402C, floats(2, 0, 0, 3, 1, 1), flags: 0x2000) }
    let(:short) { record(0x402C, floats(2, 0, 0, 3)) }

    include_examples "a typed record", :MultiplyWorldTransform
    include_examples "a record that rejects a short body", 0x402C

    it "decodes the matrix and the post-multiply flag" do
      rec = decode(bytes)

      expect(rec).to be_post_multiply
      expect(rec.matrix).to have_attributes(m11: 2, m22: 3, dx: 1, dy: 1)
      expect(decode(record(0x402C, floats(2, 0, 0, 3, 1, 1)))).not_to be_post_multiply
    end
  end

  describe Emf::EmfPlus::Records::TranslateWorldTransform do
    let(:bytes) { record(0x402D, floats(4.0, 5.0), flags: 0x2000) }
    let(:short) { record(0x402D, floats(4.0)) }

    include_examples "a typed record", :TranslateWorldTransform
    include_examples "a record that rejects a short body", 0x402D

    it "decodes dx, dy and post-multiply" do
      expect(decode(bytes)).to be_post_multiply.and have_attributes(dx: 4.0, dy: 5.0)
    end
  end

  describe Emf::EmfPlus::Records::ScaleWorldTransform do
    let(:bytes) { record(0x402E, floats(2.0, 0.5)) }
    let(:short) { record(0x402E, floats(2.0)) }

    include_examples "a typed record", :ScaleWorldTransform
    include_examples "a record that rejects a short body", 0x402E

    it "decodes sx, sy and pre-multiply" do
      expect(decode(bytes)).not_to be_post_multiply
      expect(decode(bytes)).to have_attributes(sx: 2.0, sy: 0.5)
    end
  end

  describe Emf::EmfPlus::Records::RotateWorldTransform do
    let(:bytes) { record(0x402F, floats(90.0), flags: 0x2000) }
    let(:short) { record(0x402F, "".b) }

    include_examples "a typed record", :RotateWorldTransform
    include_examples "a record that rejects a short body", 0x402F

    it "decodes the angle and post-multiply" do
      expect(decode(bytes)).to be_post_multiply.and have_attributes(angle: 90.0)
    end
  end

  describe Emf::EmfPlus::Records::SetPageTransform do
    let(:bytes) { record(0x4030, floats(0.25), flags: 0x0002) }
    let(:short) { record(0x4030, "".b) }

    include_examples "a typed record", :SetPageTransform
    include_examples "a record that rejects a short body", 0x4030

    it "decodes the page unit and scale" do
      expect(decode(bytes)).to have_attributes(page_unit: 2, page_scale: 0.25)
    end
  end

  describe "against the corpus" do
    types = (0x4031..0x4035).to_a + [0x403A] + (0x402A..0x4030).to_a
    fixtures = Dir[File.expand_path("../../fixtures/{emf,emf-ea,simple}/*.emf", __dir__)].select do |path|
      next false unless File.binread(path).include?("EMF+")

      Emf.parse(File.binread(path)).emf_plus
    rescue Emf::Error
      false
    end

    it "finds EMF+ fixtures to check" do
      expect(fixtures).not_to be_empty
    end

    it "decodes every clip/transform record typed, byte-identical, in every valid fixture" do
      decoded = fixtures.flat_map do |path|
        frames = Emf::EmfPlus::Parser.call(Emf.parse(File.binread(path)).emf_plus)
        frames.select { |f| types.include?(f.type) }.map { |f| [f, records.decode(f)] }
      end

      expect(decoded).not_to be_empty
      expect(decoded.map { |_, r| r }).to all(satisfy { |r| !r.is_a?(records::Unknown) })
      expect(decoded.map { |f, r| [r.to_binary, f.to_binary] }).to all(satisfy { |a, b| a == b })
    end
  end
end
