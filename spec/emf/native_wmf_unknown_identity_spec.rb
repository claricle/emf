# frozen_string_literal: true

require_relative "../support/native_wmf_bridge"

RSpec.describe "Native WMF unknown function identity" do
  include_context "native WMF bridge"

  let(:unknown_records) do
    [
      native_wmf_record(0x80FE, "\xDE\xAD\xBE\xEF".b),
      native_wmf_record(0xAB00, "\x00\xFF\x17\xE2".b)
    ]
  end
  let(:move) { native_wmf_record(0xAB14, [-3, 7].pack("s<2")) }

  it "preserves full unknown function words and opaque bytes across edits in both containers" do
    inputs = [false, true].map do |placeable|
      input = native_wmf_bytes([unknown_records.first, move, unknown_records.last],
                               placeable: placeable, trailing: "\x91\x00tail".b)

      ENV["EMF_BACKEND"] = "ruby"
      fallback = Emf.parse(input)
      fallback_unknowns = fallback.records.grep(Emf::Model::Wmf::Records::UnknownRecord)
      expect(fallback_unknowns.map(&:type_id)).to eq([0x80FE, 0xAB00])
      expect(fallback_unknowns.map(&:raw_bytes)).to eq(unknown_records)
      expect(Emf.serialize(fallback)).to eq(input)

      [input, fallback_unknowns.map(&:type_id), fallback_unknowns.map(&:raw_bytes)]
    end

    ENV["EMF_BACKEND"] = "native"
    expect(Emf::Wmf::Parser).not_to receive(:call)
    inputs.each do |input, fallback_types, fallback_raw_bytes|
      parsed = Emf.parse(input)
      native_unknowns = parsed.records.grep(Emf::Model::Wmf::Records::UnknownRecord)
      expect(native_unknowns.map(&:type_id)).to eq(fallback_types)
      expect(native_unknowns.map(&:raw_bytes)).to eq(fallback_raw_bytes)
      expect(parsed.trailing).to eq("\x91\x00tail".b)

      parsed.records[1].x = -123
      edited_bytes = Emf.serialize(parsed)
      reparsed = Emf.parse(edited_bytes)

      expect(reparsed.records[1].x).to eq(-123)
      expect(reparsed.records.grep(Emf::Model::Wmf::Records::UnknownRecord).map(&:type_id)).to eq([0x80FE, 0xAB00])
      expect(reparsed.records.grep(Emf::Model::Wmf::Records::UnknownRecord).map(&:raw_bytes)).to eq(unknown_records)
      expect(reparsed.trailing).to eq("\x91\x00tail".b)
    end
  end
end
