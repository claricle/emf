# frozen_string_literal: true

require "spec_helper"
require_relative "../support/emf_plus_builder"

RSpec.describe "EMF+ framing and control rules" do
  let(:build) { Emf::SpecSupport::EmfPlusBuilder }
  let(:crafted) { Emf::SpecSupport::CraftedEmf }
  let(:comment_offset) { 88 }

  def found(bytes, id, profile: :strict) = build.diagnostics(bytes, id, profile: profile)

  it "stays silent on a conformant Header ... EndOfFile stream" do
    ids = Emf::Conformance.check(build.stream(build.record(0x4025, body: [1].pack("V")))).diagnostics.map(&:requirement_id)
    expect(ids).to be_empty
  end

  describe "emfplus.record.fixed_size" do
    it "flags a Save with a wrong DataSize and Size, at the carrying comment" do
      bad = build.stream(build.record(0x4025, body: [1, 2].pack("V2")))
      diagnostic = found(bad, "emfplus.record.fixed_size").first
      expect(diagnostic.message).to include("Save DataSize is 8, MUST be 4", "Size is 20, MUST be 16")
      expect(diagnostic.offset).to eq(comment_offset)
      expect(diagnostic.record_type).to eq(0x4025)
    end

    it "flags a GetDC that carries data" do
      expect(found(build.stream(build.record(0x4004, body: [0].pack("V"))), "emfplus.record.fixed_size").size).to eq(1)
    end

    it "accepts a SetAntiAliasMode with DataSize 0 whatever its flags, and flags one with data" do
      expect(found(build.stream(build.record(0x401E, flags: 0x03)), "emfplus.record.fixed_size")).to be_empty
      expect(found(build.stream(build.record(0x401E, body: [0].pack("V"))), "emfplus.record.fixed_size").size).to eq(1)
    end
  end

  describe "emfplus.record.data_size" do
    # DrawLines (0x400D): Count 2 uncompressed points = 4 + 16 bytes.
    let(:lines) { [2].pack("V") + build.float(0, 0, 5, 5) }

    it "flags bytes inside DataSize that the decoded fields do not account for" do
      bad = build.stream(build.record(0x400D, body: lines + "\0\0\0\0".b))
      expect(found(bad, "emfplus.record.data_size").first.message).to include("DrawLines DataSize is 24 but its fields occupy 20 bytes")
      expect(found(bad, "emfplus.record.data_size", profile: :tolerant).first.severity).to eq(:warning)
    end

    it "accepts exact fields and padding after an odd-length field" do
      expect(found(build.stream(build.record(0x400D, body: lines)), "emfplus.record.data_size")).to be_empty
      # DrawString: 1 character = 2 bytes; DataSize is padded to the 4-byte alignment.
      string = [0xFF000000, 0, 1].pack("V3") + build.rect_f + "A\0".b
      expect(found(build.stream(build.record(0x401C, body: string, data_size: 36)), "emfplus.record.data_size")).to be_empty
    end
  end

  describe "emfplus.record.data_size_alignment" do
    it "flags a DataSize that is not a multiple of 4 and accepts an aligned one" do
      bad = build.stream(build.record(0x4003, body: "abc".b))
      expect(found(bad, "emfplus.record.data_size_alignment").first.message).to include("DataSize 3")
      expect(found(build.stream(build.record(0x4003, body: "abcd".b)), "emfplus.record.data_size_alignment")).to be_empty
    end
  end

  describe "emfplus.record.body_bounds" do
    it "flags a defined record whose Count runs past its DataSize" do
      bad = build.stream(build.record(0x400D, body: [1000].pack("V") + build.float(0, 0)))
      expect(found(bad, "emfplus.record.body_bounds").first.message).to include("DrawLines body does not fit")
    end

    it "does not flag an undefined type or a decodable record" do
      expect(found(build.stream(build.record(0x7FFF)), "emfplus.record.body_bounds")).to be_empty
      expect(found(build.stream(build.record(0x4025, body: [1].pack("V"))), "emfplus.record.body_bounds")).to be_empty
    end
  end

  describe "emfplus.header.signature" do
    it "flags a Header with the wrong MetafileSignature and accepts 0xDBC01" do
      bad = build.stream(header: build.header(body: [(0x12345 << 12) | 1, 0, 96, 96].pack("V4")))
      expect(found(bad, "emfplus.header.signature").first.message).to include("0x12345", "0xDBC01")
      expect(found(build.stream, "emfplus.header.signature")).to be_empty
    end
  end

  describe "emfplus.eof.placement" do
    let(:other_comment) { crafted.record(70, [4, 0x64636261].pack("V2")) }

    it "flags a stream with no EndOfFile" do
      bytes = crafted.build(records: [build.comment(build.header)])
      expect(found(bytes, "emfplus.eof.placement").first.message).to include("no EmfPlusEndOfFile")
    end

    it "flags records after the EndOfFile" do
      bytes = crafted.build(records: [build.comment(build.header, build.eof, build.record(0x4025, body: [1].pack("V")))])
      expect(found(bytes, "emfplus.eof.placement").first.message).to include("records follow it")
    end

    it "flags an EndOfFile whose comment is not immediately before EMR_EOF" do
      bytes = crafted.build(records: [build.comment(build.header, build.eof), other_comment])
      expect(found(bytes, "emfplus.eof.placement").first.message).to include("not the record immediately before EMR_EOF")
    end

    it "accepts the EndOfFile in its own last comment" do
      bytes = crafted.build(records: [build.comment(build.header), build.comment(build.eof)])
      expect(found(bytes, "emfplus.eof.placement")).to be_empty
    end
  end
end
