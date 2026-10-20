# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/emf/native/wmf_fields"

RSpec.describe Emf::Native::WmfFields do
  let(:type) { 0x0102 }
  let(:offset) { 22 }
  let(:payload) { [2].pack("V") }
  let(:raw) { [4, type, 2].pack("Vvv") }
  let(:descriptor) { { type: type, offset: offset, payload: payload, family: 6 } }
  let(:font_type) { 0x02FB }
  let(:font_payload) do
    ([12, 0, 0, 0, 400] + Array.new(8, 0) + ["Example".b.ljust(32, "\x00".b)]).then do |values|
      [values.first(5).pack("l<5"), values[5, 8].pack("V8"), values.last].join.b
    end
  end
  let(:font_wire_payload) do
    [12, 0, 0, 0, 400].pack("s<5") + Array.new(8, 0).pack("C8") + "Example".b.ljust(32, "\x00".b)
  end
  let(:font_raw) { [28].pack("V") + [font_type].pack("v") + font_wire_payload }
  let(:font_descriptor) { { type: font_type, offset: offset, payload: font_payload, family: 7 } }
  let(:palette_type) { 0x00F7 }
  let(:palette_payload) { [0x0300, 2, 1, 2, 3, 4, 5, 6, 7, 8].pack("V*") }
  let(:palette_raw) { [9, palette_type].pack("Vv") + [0x0300, 2].pack("v2") + [1, 2, 3, 4, 5, 6, 7, 8].pack("C*") }
  let(:palette_descriptor) { { type: palette_type, offset: offset, payload: palette_payload, family: 8 } }
  let(:region_type) { 0x06FF }
  let(:region_payload) do
    [0xABCD, 0x12345678].pack("V2") + [-2, -32_768, 300, 400].pack("l<4") +
      [2, 32_769, 65_534, 1, 32_770, 65_535, 30, 40, 2, 10, 20, 50, 60].pack("V*")
  end
  let(:region_raw) do
    body = [0xABCD, 6, 0x5678, 0x1234, 50, 2, 4, 0xFFFE, 0x8000, 300, 400,
            2, 0x8001, 0xFFFE, 0x8002, 0xFFFF, 2, 4, 30, 40, 10, 20, 50, 60, 4].pack("v*")
    [28, region_type].pack("Vv") + body
  end
  let(:region_descriptor) { { type: region_type, offset: offset, payload: region_payload, family: 9 } }

  it "rejects a supported state with a non-state native family" do
    record = descriptor.merge(family: 4)

    expect { described_class.new(record, raw).call }.to raise_error(Emf::Error)
  end

  it "rejects a state payload whose LE-u32 field count is wrong" do
    record = descriptor.merge(payload: "".b)

    expect { described_class.new(record, raw).call }.to raise_error(Emf::Error)
  end

  it "rejects a u16 state value that exceeds its unsigned range" do
    record = descriptor.merge(payload: [0x10000].pack("V"))

    expect { described_class.new(record, raw).call }.to raise_error(Emf::Error)
  end

  it "rejects a raw state record shorter than its fixed prefix" do
    expect { described_class.new(descriptor, raw.byteslice(0, 6)).call }.to raise_error(Emf::Error)
  end

  it "decodes a native font descriptor and preserves its raw wire suffix" do
    suffix = "\xAA\xBB".b
    record = described_class.new(font_descriptor, font_raw + suffix).call

    expect(record).to be_a(Emf::Model::Wmf::Records::CreateFontIndirect)
    expect(record.height).to eq(12)
    expect(record.weight).to eq(400)
    expect(record.face_name).to eq("Example".b.ljust(32, "\x00".b))
    expect(record.suffix).to eq(suffix)
  end

  it "rejects malformed native font descriptors" do
    invalid = [
      [font_descriptor.merge(family: 6), font_raw],
      [font_descriptor.merge(payload: font_payload.byteslice(0, 83)), font_raw],
      [font_descriptor.merge(payload: [-32_769, 0, 0, 0, 400].pack("l<5") + font_payload.byteslice(20..)), font_raw],
      [font_descriptor.merge(payload: [32_768, 0, 0, 0, 400].pack("l<5") + font_payload.byteslice(20..)), font_raw],
      [font_descriptor.merge(payload: font_payload.byteslice(0, 20) + [256].pack("V") + font_payload.byteslice(24..)), font_raw],
      [font_descriptor, font_raw.byteslice(0, 55)]
    ]

    invalid.each do |record, raw_bytes|
      expect { described_class.new(record, raw_bytes).call }.to raise_error(Emf::Error)
    end
  end

  it "decodes native palette entries and preserves the raw suffix" do
    suffix = "\xAA\xBB".b
    record = described_class.new(palette_descriptor, palette_raw + suffix).call

    expect(record).to be_a(Emf::Model::Wmf::Records::CreatePalette)
    expect(record.start).to eq(0x0300)
    expect(record.entries.map { |entry| [entry.red, entry.green, entry.blue, entry.flags] })
      .to eq([[1, 2, 3, 4], [5, 6, 7, 8]])
    expect(record.suffix).to eq(suffix)
  end

  it "rejects malformed family 8 payload lengths, ranges and raw bounds" do
    invalid = [
      [palette_descriptor.merge(family: 7), palette_raw],
      [palette_descriptor.merge(payload: palette_payload.byteslice(0, 31)), palette_raw],
      [palette_descriptor.merge(payload: [0x10000, 0].pack("V2")), [6, palette_type].pack("Vv")],
      [palette_descriptor.merge(payload: [0, 2, 1, 2, 3, 4, 256, 0, 0, 0].pack("V*")), palette_raw],
      [palette_descriptor, palette_raw.byteslice(0, 17)]
    ]

    invalid.each do |record, raw_bytes|
      expect { described_class.new(record, raw_bytes).call }.to raise_error(Emf::Error)
    end
  end

  it "decodes native CreateRegion scan data and preserves its raw suffix" do
    suffix = "\xAA\xBB".b
    raw_with_suffix = [29, region_type].pack("Vv") + region_raw.byteslice(6..) + suffix
    record = described_class.new(region_descriptor, raw_with_suffix).call

    expect(record).to be_a(Emf::Model::Wmf::Records::CreateRegion)
    expect([record.next_in_chain, record.object_count, record.bounds.to_a]).to eq([0xABCD, 0x12345678, [-2, -32_768, 300, 400]])
    expect(record.scans.map { |scan| [scan.top, scan.bottom, scan.lines.map(&:to_a)] })
      .to eq([[32_769, 65_534, [[32_770, 65_535]]], [30, 40, [[10, 20], [50, 60]]]])
    expect(record.suffix).to eq(suffix)
  end

  it "rejects malformed family 9 fields, scan counts and raw bounds" do
    invalid = [
      [region_descriptor.merge(family: 8), region_raw],
      [region_descriptor.merge(payload: region_payload.byteslice(0, 59)), region_raw],
      [region_descriptor.merge(payload: [0x10000].pack("V") + region_payload.byteslice(4..)), region_raw],
      [region_descriptor.merge(payload: [0xABCD, 0x12345678].pack("V2") +
        [32_768, -32_768, 300, 400].pack("l<4") + region_payload.byteslice(24..)), region_raw],
      [region_descriptor.merge(payload: [0xABCD, 0x12345678].pack("V2") + [-2, -32_768, 300, 400].pack("l<4") +
        [2, 32_769, 65_534, 1, 65_536, 65_535, 30, 40, 2, 10, 20, 50, 60].pack("V*")), region_raw],
      [region_descriptor, region_raw.byteslice(0, 12)]
    ]

    invalid.each do |record, raw_bytes|
      expect { described_class.new(record, raw_bytes).call }.to raise_error(Emf::Error)
    end
  end
end
