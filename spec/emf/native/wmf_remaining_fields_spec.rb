# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/emf/native/wmf_fields"

RSpec.describe Emf::Native::WmfRemainingFields do
  let(:offset) { 18 }
  let(:type) { 0xAB10 }
  let(:values) { [-32_768, 32_767, 0, -1] }
  let(:suffix) { "\xFE\xAD".b }
  let(:raw) { [8, type].pack("Vv") + values.pack("s<4") + suffix }
  let(:descriptor) { { type: type, offset: offset, family: 12, payload: values.pack("l<4") } }
  let(:escape_type) { 0xAB26 }
  let(:data) { "\x00\xFF\x26".b }
  let(:escape_raw) { [8, escape_type, 0x11D8, 3].pack("Vv3") + data + "\xA5".b + suffix }
  let(:escape_descriptor) { { type: escape_type, offset: offset, family: 13, payload: [0x11D8, 3].pack("VQ<") + data } }

  it "hydrates signed geometry fields and retains exact source framing and suffix" do
    record = described_class.new(descriptor, raw).call
    expect(record).to be_a(Emf::Model::Wmf::Records::ScaleWindowExt)
    expect([record.y_denom, record.y_num, record.x_denom, record.x_num]).to eq(values)
    expect([record.type_id, record.offset, record.suffix]).to eq([type, offset, suffix])
    expect(Emf::Wmf::GeometryCodec.encode(record)).to eq(raw)
  end

  it "rejects wrong geometry families, lengths, narrowing and descriptor/source disagreement" do
    invalid = [
      [descriptor.merge(family: 13), raw],
      [descriptor.merge(payload: descriptor[:payload].byteslice(0, 15)), raw],
      [descriptor.merge(payload: [32_768, *values.drop(1)].pack("l<4")), raw],
      [descriptor.merge(payload: [-32_769, *values.drop(1)].pack("l<4")), raw],
      [descriptor.merge(payload: [0, *values.drop(1)].pack("l<4")), raw],
      [descriptor, raw.byteslice(0, 12)],
      [descriptor, raw.byteslice(0, 15)],
      [descriptor, [9, type].pack("Vv") + raw.byteslice(6..)],
      [descriptor, [8, 0x0410].pack("Vv") + raw.byteslice(6..)]
    ]
    invalid.each do |fields, bytes|
      expect { described_class.new(fields, bytes).call }.to raise_error(Emf::ParseError) do |error|
        expect([error.offset, error.record_code]).to eq([offset, type])
      end
    end
  end

  it "rejects invalid flood modes and color mismatches without narrowing them" do
    function = 0x0548
    bytes = [8, function, 1, 0xFFFFFFFF, -1, 2].pack("VvvVs<2")
    fields = { type: function, offset: offset, family: 12, payload: [1, 0xFFFFFFFF, -1, 2].pack("V2l<2") }
    record = described_class.new(fields, bytes).call
    expect([record.mode, record.color, record.y, record.x]).to eq([1, 0xFFFFFFFF, -1, 2])
    [2, 65_536].each do |mode|
      invalid = fields.merge(payload: [mode, 0xFFFFFFFF, -1, 2].pack("V2l<2"))
      expect { described_class.new(invalid, bytes).call }.to raise_error(Emf::ParseError)
    end
    expect { described_class.new(fields.merge(payload: [1, 0, -1, 2].pack("V2l<2")), bytes).call }
      .to raise_error(Emf::ParseError)
  end

  it "hydrates inert Escape bytes and obtains alignment and suffix only from the source" do
    record = described_class.new(escape_descriptor, escape_raw).call
    expect(record).to be_a(Emf::Model::Wmf::Records::Escape)
    expect([record.escape_function, record.data, record.padding, record.suffix]).to eq([0x11D8, data, 0xA5, suffix])
    expect(Emf::Wmf::DcEscapeCodec.encode(record)).to eq(escape_raw)
  end

  it "rejects malformed Escape counts, narrowing, missing padding and source mismatches" do
    invalid = [
      [escape_descriptor.merge(family: 12), escape_raw],
      [escape_descriptor.merge(payload: "".b), escape_raw],
      [escape_descriptor.merge(payload: [0x10000, 3].pack("VQ<") + data), escape_raw],
      [escape_descriptor.merge(payload: [0x11D8, 65_536].pack("VQ<") + data), escape_raw],
      [escape_descriptor.merge(payload: [0x11D8, 4].pack("VQ<") + data), escape_raw],
      [escape_descriptor.merge(payload: "#{[0x11D8, 3].pack('VQ<')}xyz"), escape_raw],
      [escape_descriptor, [6, escape_type, 0x11D8, 3].pack("Vv3") + data.byteslice(0, 2)],
      [escape_descriptor, [8, escape_type, 0x11D8, 2].pack("Vv3") + escape_raw.byteslice(10..)]
    ]
    invalid.each do |fields, bytes|
      expect { described_class.new(fields, bytes).call }.to raise_error(Emf::ParseError)
    end
  end

  it "requires empty descriptors for zero-prefix DC records and signed RestoreDc agreement" do
    nonempty_payload = [0].pack("V")
    [0x001E, 0x0105].each do |function|
      fields = { type: function, offset: offset, family: 13, payload: "".b }
      bytes = [4, function].pack("Vv") + suffix
      expect(described_class.new(fields, bytes).call.suffix).to eq(suffix)
      expect { described_class.new(fields.merge(payload: nonempty_payload), bytes).call }.to raise_error(Emf::ParseError)
    end
    fields = { type: 0x0127, offset: offset, family: 13, payload: [-32_768].pack("l<") }
    bytes = [5, 0x0127, -32_768].pack("Vvs<") + suffix
    expect(described_class.new(fields, bytes).call.saved_dc).to eq(-32_768)
    [-32_769, 32_768, -1].each do |value|
      expect { described_class.new(fields.merge(payload: [value].pack("l<")), bytes).call }.to raise_error(Emf::ParseError)
    end
  end
end
