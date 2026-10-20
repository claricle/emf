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
end
