# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/emf_plus_records"

RSpec.describe "EMF+ version rules" do
  include Emf::SpecSupport::EmfPlusRecords

  let(:records) { Emf::EmfPlus::Records }

  def header(version_dword, flags: 1) = record(0x4001, [version_dword, 0, 96, 96].pack("V4"), flags: flags)

  def decode_all(bytes) = records.decode_all(Emf::EmfPlus::Parser.call(bytes))

  describe "EmfPlusGraphicsVersion" do
    [0, 1, 2, 3, 0xFFF].each do |version|
      it "keeps version #{version} as an integer behind a valid signature and re-encodes it" do
        bytes = header((0xDBC01 << 12) | version)
        decoded = decode_all(bytes).first

        expect(decoded).to be_valid_signature.and have_attributes(graphics_version: version)
        expect(decoded.to_binary).to eq(bytes)
      end
    end
  end

  describe "GDI+ 1.1 records under a GDI+ 1.0 header" do
    let(:guid) { [0x633C80A4, 0x1843, 0x482B, 0x9E, 0xF2, 0xBE, 0x28, 0x34, 0xC5, 0xFD, 0xD4].pack("VvvC8") }
    let(:serializable) { record(0x4038, guid + [8].pack("V") + [8, 0x4170].pack("Vv") + "\0\0".b) }
    let(:ts_clip) { record(0x403A, "\x81\x82\x03\x04".b, flags: 0x8001) }
    let(:ts_graphics) do
      record(0x4039, [1, 2, 3, 4, -5, 6, 7, 8, 9].pack("C4 s<2 S< C2") + [1.0, 0, 0, 1.0, 0, 0].pack("e6"))
    end
    let(:stream) { header(0xDBC01001) + serializable + ts_clip + ts_graphics }

    it "decodes every version-1.1 record typed whatever the header says" do
      expect(decode_all(stream).map(&:class))
        .to eq([records::Header, records::SerializableObject, records::SetTSClip, records::SetTSGraphics])
    end

    it "re-encodes the stream byte for byte" do
      expect(decode_all(stream).map(&:to_binary).join).to eq(stream)
    end
  end
end
