# frozen_string_literal: true

require "spec_helper"
require "emf/native/poly_text_fields"

RSpec.describe Emf::Native::PolyTextFields do
  let(:fixtures) do
    wide_units = [0xD800, 0xFFFF].pack("v*")
    prefix = [-1, 2, -3, 4, 2, 0x7FC01234, 0x80000000].pack("V*")
    reference = [-19, 7].pack("l<2")
    rectangle = [-4, 5, 6, -7].pack("l<4")
    dx = [0xFFFFFFFF, 0x80000000, 17, 29].pack("V*")
    one = [1].pack("V")
    flags = [0x2000, 1].pack("V2")
    counts = [2, 1, 4].pack("Q<VQ<")
    [false, true].to_h do |wide|
      type = wide ? 97 : 96
      units = wide ? wide_units : "\x80\xFF".b
      string_offset = 84
      dx_offset = 92
      body = prefix + one + reference + [2, string_offset, 0x2000].pack("V3") + rectangle + [dx_offset].pack("V")
      body << "GAP!" << units
      body << "g" while body.bytesize + 8 < dx_offset
      body << dx << "SUFFIX!!"
      raw = [type, body.bytesize + 8].pack("V2") + body
      snapshot = prefix + one.ljust(8, "\0") + reference + flags + rectangle + counts + units + dx
      [wide, [type, raw, snapshot]]
    end
  end

  let(:invalid_snapshot_offsets) { [0, 36, 44, 48, 68, 76, 80, 88] }
  let(:invalid_string_offsets) { [0, 40, 85, 0xFFFFFFFF] }

  [false, true].each do |wide|
    it "validates #{wide ? 'W code units' : 'A bytes'} and keeps the body including gaps and suffix" do
      type, raw, payload = fixtures.fetch(wide)
      klass, fields = described_class.call(payload, wide ? 105 : 104, raw, type)
      expect(klass).to eq(Emf::Emr::Binary::Records.lookup(type))
      expect(fields).to eq(body: raw.byteslice(8..))
      wire = klass.read(raw)
      wire.body = fields.fetch(:body)
      expect(wire.to_binary_s).to eq(raw)
    end

    it "rejects mismatched semantic values, counts, flags, truncation and invalid source spans" do
      type, raw, payload = fixtures.fetch(wide)
      family = wide ? 105 : 104
      invalid_snapshot_offsets.each do |offset|
        bad = payload.dup
        bad.setbyte(offset, bad.getbyte(offset) ^ 1)
        expect { described_class.call(bad, family, raw, type) }.to raise_error(Emf::FormatError)
      end
      ["".b, payload.byteslice(0, payload.bytesize - 1), "#{payload}extra"].each do |bad|
        expect { described_class.call(bad, family, raw, type) }.to raise_error(Emf::FormatError)
      end
      invalid_string_offsets.each do |offset|
        bad = raw.dup
        bad[52, 4] = [offset].pack("V")
        expect { described_class.call(payload, family, bad, type) }.to raise_error(Emf::FormatError)
      end
      expect { described_class.call(payload, family, raw, 23) }.to raise_error(Emf::FormatError)
    end
  end

  it "validates all color words while retaining signed bits and opaque suffix" do
    payload = [0x8001, 0xFFFF, 0x8000, 1, 2, 3, 4, 5, 0x8000, 0xFFFF, 0, 0x7FFF].pack("v*")
    raw = "#{[23, 38].pack('V2')}#{payload}opaque".b
    klass, fields = described_class.call(payload, 106, raw, 23)
    wire = klass.read(raw)
    expect(fields.fetch(:body)).to eq("#{payload}opaque".b)
    expect(wire.contrast.to_i).to eq(-32_768)
    expect(wire.brightness.to_i).to eq(-1)
    wire.red_green_tint = -32_768
    expect(wire.to_binary_s.byteslice(32..)).to eq("opaque")
    expect { described_class.call(payload.reverse, 106, raw, 23) }.to raise_error(Emf::FormatError)
    expect { described_class.call(payload, 106, raw.byteslice(0, 31), 23) }.to raise_error(Emf::FormatError)
  end
end
