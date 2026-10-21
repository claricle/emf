# frozen_string_literal: true

require "spec_helper"

# emfsvg (pinned 101356dc, translation/record_emitter.rb) builds font records
# from a raw LOGFONTW body and serializes them before setting n_size:
#   wire = CreateFontIndirectW.new(i_type:, ih_object:, body: bytes)
#   wire.n_size = wire.to_binary_s.bytesize
RSpec.describe Emf::Emr::Binary::Records::CreateFontIndirectW, "built by a consumer before nSize is set" do
  let(:type) { Emf::Emr::Binary::TypeCodes::EXTCREATEFONTINDIRECTW }

  def logfont(face = "Arial")
    [-16, 0, 0, 0, 400, 0, 0, 0, 1, 0, 0, 0, 0].pack("l<5C8") + face.encode("UTF-16LE").b.ljust(64, "\0".b)
  end

  def consumer_record(body)
    wire = described_class.new(i_type: type, ih_object: 1, body: body)
    wire.n_size = wire.to_binary_s.bytesize
    wire
  end

  it "serializes a LOGFONTW body assigned without a record size" do
    wire = consumer_record(logfont)

    expect(wire.n_size).to eq(12 + 92)
    expect(wire.to_binary_s.byteslice(12..)).to eq(logfont)
  end

  it "round-trips the consumer-built record through the parser" do
    bytes = consumer_record(logfont("Courier New")).to_binary_s
    parsed = described_class.read(bytes)

    expect(parsed.to_binary_s).to eq(bytes)
    expect(parsed.body.font.facename.to_a.pack("v*").force_encoding("UTF-16LE").encode("UTF-8").delete("\0")).to eq("Courier New")
  end

  it "keeps a partial Panose body at its assigned size" do
    body = logfont + ("\0".b * 8)
    expect(consumer_record(body).to_binary_s.byteslice(12..)).to eq(body)
  end

  it "still rejects a body that disagrees with an explicit record size" do
    wire = described_class.new(i_type: type, ih_object: 1, n_size: 12 + 100, body: logfont)

    expect { wire.to_binary_s }.to raise_error(BinData::ValidityError, /font body does not match record size/)
  end
end
