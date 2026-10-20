# frozen_string_literal: true

require_relative "../support/native_wmf_bridge"

RSpec.describe "Native WMF version compatibility" do
  include_context "native WMF bridge"

  it "matches Ruby acceptance of DIB transfers in both supported header versions" do
    bitmap = "\xDE\xAD\xBE\xEF".b
    body = [0xFEDCBA98].pack("V") + [-3, 4, -5, 6, -7, 8].pack("s<*") + bitmap
    inputs = [0x0100, 0x0300].map do |version|
      native_wmf_bytes([native_wmf_record(0x0940, body)]).tap do |bytes|
        bytes[4, 2] = [version].pack("v")
      end
    end

    ENV["EMF_BACKEND"] = "ruby"
    fallback = inputs.map { |bytes| Emf.parse(bytes) }
    expect(Emf::Wmf::Parser).not_to receive(:call)
    ENV["EMF_BACKEND"] = "native"

    inputs.zip(fallback, [0x0100, 0x0300]).each do |bytes, ruby, version|
      native = Emf.parse(bytes)
      expect(native.header.version).to eq(version)
      expect(native.errors).to eq(ruby.errors)
      expect(native.records.first).to be_a(Emf::Model::Wmf::Records::DibBitBlt)
      expect([native.records.first.source_y, native.records.first.bitmap]).to eq([-3, bitmap])
      expect([Emf.serialize(ruby), Emf.serialize(native)]).to eq([bytes, bytes])
    end
  end
end
