# frozen_string_literal: true

require "spec_helper"
require "emf/emr/binary/region_data"
require_relative "../../support/region_records"
require_relative "../../support/emf_plus_generated_fixtures"

RSpec.describe Emf::Emr::Binary::RegionData, "allocation bounds" do
  include RegionRecords

  bounds = [0, 0, 1, 1].pack("l<4")
  invalid_count = [0xFFFFFFFF].pack("V")
  following = [27, 16, 12, 34].pack("V2l<2")
  data_offsets = { 71 => 32, 72 => 40, 73 => 28, 74 => 28, 75 => 16 }.freeze

  [2, 0xFFFFFFFF].each do |count|
    it "rejects #{count} rectangles before allocating an undersized region array" do
      data = [32, 1, count, 0].pack("V4") + bounds
      expect { described_class.read(data, byte_length: data.bytesize) }
        .to raise_error(BinData::ValidityError, /region rectangles exceed/)
    end
  end

  it "preserves the observed malformed PaintRgn input without expanding its count" do
    bytes = %w[
      010000006c0000000000000000000000ec010000d40000000000000000000000f32f0000ba18000020454d46
      0000010054730100df01000003000000000000000000000000000000000500002003000040010000f0000000
      00000000000000000000000000e2040080a903004a0000005300000000c60aa572d61e0000fe006c00000c00
      7e5d82260f9b7d2b47319fca7a44dd0000ac00fc21bd15321ef800d59d56f7ee00d5bb8d009c79a500b16931
      00b36500213da2840000731900e220
    ].join.then { |hex| [hex].pack("H*") }
    parsed = Emf::Emr::Parser.call(bytes)

    expect(parsed.errors.first.message).to include("more entries than nSize allows")
    expect(parsed.records.first.wire).to be_a(Emf::Emr::Binary::Records::Raw)
    expect(Emf.serialize(parsed)).to eq(bytes)
  end

  (71..75).each do |type|
    it "rejects an oversized region byte length in record #{type}" do
      record = region_record(type)
      length_offset = type == 75 ? 8 : 24
      record[length_offset, 4] = invalid_count
      errors = []
      wire, = Emf::Emr::Parser.read_record(StringIO.new(record), 0, errors)

      expect(errors.first.message).to include("more entries than nSize allows")
      expect(wire).to be_a(Emf::Emr::Binary::Records::Raw)
      expect(wire.to_binary_s).to eq(record)
    end

    it "preserves malformed region #{type} as raw and continues to the next record" do
      record = region_record(type, rectangles: [], extra: "", suffix: "")
      data_offset = data_offsets.fetch(type)
      record[data_offset + 8, 4] = invalid_count
      fixtures = Emf::SpecSupport::EmfPlusGeneratedFixtures
      bytes = fixtures.header_bytes(88 + record.bytesize + following.bytesize, 3) + record + following
      parsed = Emf::Emr::Parser.call(bytes)

      expect(parsed.errors.length).to eq(1)
      expect(parsed.errors.first.record_code).to eq(type)
      expect(parsed.errors.first.message).to include("region rectangles exceed")
      expect(parsed.records.first.wire).to be_a(Emf::Emr::Binary::Records::Raw)
      expect(parsed.records.last.wire.to_binary_s).to eq(following)
      expect(Emf.serialize(parsed)).to eq(bytes)
    end
  end
end
