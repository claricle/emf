# frozen_string_literal: true

require "spec_helper"
require "emf/binary/types"

RSpec.describe "Emf::Binary::Float32Le" do
  let(:primitive) { Emf::Binary::Float32Le }
  let(:record_class) do
    Class.new(BinData::Record) do
      endian :little
      float32_le :lead
      float32_le :trail
    end
  end

  def bytes_for(bits, other = 0x3f800000)
    [bits, other].pack("V2")
  end

  {
    "signalling NaN" => 0x7fa00001, "NaN with low payload" => 0x7f800001,
    "negative NaN payload" => 0xffc12345, "quiet NaN" => 0x7fc00000,
    "-0.0" => 0x80000000, "denormal" => 0x00000001, "+Inf" => 0x7f800000, "-Inf" => 0xff800000
  }.each do |label, bits|
    it "round-trips #{label} byte for byte" do
      input = bytes_for(bits)
      expect(record_class.read(input).to_binary_s).to eq(input)
    end
  end

  it "reads a Float" do
    expect(record_class.read(bytes_for(0x7fa00001)).lead).to be_nan
    expect(record_class.read(bytes_for(0x40490fdb)).lead).to be_within(1e-6).of(3.14159274)
  end

  it "re-encodes an assigned Float and drops the read bits" do
    rec = record_class.read(bytes_for(0x7fa00001))
    rec.lead = 2.5
    expect(rec.to_binary_s).to eq([2.5, 1.0].pack("e2"))
  end

  it "drops the read bits when a NaN Float is assigned" do
    rec = record_class.read(bytes_for(0x7fa00001))
    rec.lead = Float::NAN
    expect(rec.to_binary_s.unpack1("V")).to eq(0x7fc00000)
  end

  it "keeps the bits of a field when its sibling is edited" do
    rec = record_class.read(bytes_for(0x7fa00001))
    rec.trail = 5.0
    expect(rec.to_binary_s).to eq([0x7fa00001].pack("V") + [5.0].pack("e"))
  end

  it "keeps the bits on dup" do
    rec = record_class.read(bytes_for(0x7f800001))
    expect(rec.dup.to_binary_s).to eq(bytes_for(0x7f800001))
  end

  it "forgets the bits on clear" do
    rec = record_class.read(bytes_for(0x7fa00001))
    rec.lead.clear
    expect(rec.lead.to_binary_s).to eq([0.0].pack("e"))
  end

  it "assigns raw bits as the same Float and bytes a read produces" do
    field = primitive.new
    field.assign_bits(0xffc12345)
    expect(field.to_binary_s.unpack1("V")).to eq(0xffc12345)
    expect(field.value).to be_nan
  end

  it "treats a non-NaN bit pattern as a plain Float" do
    field = primitive.new
    field.assign_bits(0x40490fdb)
    expect(field.value).to eq([0x40490fdb].pack("V").unpack1("e"))
  end

  it "keeps NaN bits in all six XForm fields" do
    input = ([0x7fa00001, 0x7f800001, 0xffc12345] * 2).pack("V6")
    expect(Emf::Binary::Types::XForm.read(input).to_binary_s).to eq(input)
  end

  nan_patterns = [0x7fa00001, 0x7f800001, 0xffc12345].freeze
  records = {
    35 => ->(body) { [35, 32].pack("VV") + body },
    36 => ->(body) { [36, 36].pack("VV") + body + [2].pack("V") }
  }.freeze

  records.each do |type, build|
    nan_patterns.each do |bits|
      it "round-trips type #{type} with float bits #{bits.to_s(16)} through the whole-file API" do
        input = whole_file(build.call([bits, 0x3f800000, 0, 0x3f800000, 0, 0].pack("V6")))
        expect(Emf.serialize(Emf.parse(input))).to eq(input)
      end
    end
  end

  def whole_file(record)
    header = [1, 88, 0, 0, 10, 10, 0, 0, 10, 10, 0x464D4520, 0x10000, 0, 3, 1, 0, 0, 0, 0, 1024, 768, 270, 203]
             .pack("VVl<4l<4VVVVvvVVVl<4")
    file = header + record + [14, 20, 0, 16, 20].pack("V5")
    file.dup.tap { |f| f[48, 4] = [f.bytesize].pack("V") }
  end
end
