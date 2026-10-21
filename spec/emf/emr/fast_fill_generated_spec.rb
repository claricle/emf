# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emf::Emr::Binary::FastFill do
  codes = Emf::Emr::Binary::TypeCodes
  enabled = codes.constants.map { |name| codes.const_get(name) }.uniq.select { |id| described_class.for(id) }

  def record_for(type, filler, seed)
    body = Array.new(filler.size - 8) { |i| (0x80 + (i * 37) + seed) & 0xFF }.pack("C*")
    [type, filler.size].pack("VV") + body
  end

  it "covers every enabled type" do
    expect(enabled.size).to eq(37)
  end

  enabled.each do |type|
    describe "type #{type}" do
      let(:filler) { described_class.for(type) }
      let(:klass) { filler.wire_class }
      let(:record) { record_for(type, filler, 0) }

      it "builds the object BinData reads" do
        wire, suffix = filler.call(record)
        expect(wire.snapshot).to eq(klass.read(record).snapshot)
        expect(wire.class).to eq(klass)
        expect(suffix).to eq("".b)
      end

      it "serializes the filled object to the input bytes" do
        wire, = filler.call(record)
        expect(wire.to_binary_s).to eq(record)
        expect(filler.pack(wire) || wire.to_binary_s).to eq(record)
      end

      it "gives each call an independent object" do
        first, = filler.call(record)
        second, = filler.call(record_for(type, filler, 5))
        first.n_size = 99
        expect(second.n_size.to_i).to eq(filler.size)
        expect(filler.call(record).first.snapshot).to eq(klass.read(record).snapshot)
      end

      it "serializes edits made after the fill like a BinData read" do
        wire, = filler.call(record)
        reference = klass.read(record)
        [wire, reference].each { |target| target.n_size = filler.size + 4 }
        expect(filler.pack(wire) || wire.to_binary_s).to eq(reference.to_binary_s)
      end
    end
  end
end
