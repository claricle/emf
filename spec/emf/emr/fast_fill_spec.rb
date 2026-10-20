# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emf::Emr::Binary::FastFill do
  let(:klass) { Emf::Emr::Binary::Records::SelectObject }
  let(:select_object) { Emf::Emr::Binary::TypeCodes::SELECTOBJECT }
  let(:filler) { described_class.for(select_object) }

  def record_bytes(n_size, handle = 0x80000005)
    ([37, n_size, handle].pack("VVV") + ("\xAB".b * [n_size - 12, 0].max))[0, n_size]
  end

  it "is registered only for enabled types" do
    expect(described_class.for(Emf::Emr::Binary::TypeCodes::EOF)).to be_nil
  end

  [12, 16, 20].each do |n_size|
    context "with nSize #{n_size}" do
      let(:bytes) { record_bytes(n_size) }
      let(:filled) { filler.call(bytes) }
      let(:read) { klass.read(bytes) }

      it "builds the same wire class with identical bytes and snapshot" do
        wire, = filled
        expect(wire).to be_a(klass)
        expect(wire.to_binary_s).to eq(read.to_binary_s)
        expect(wire.snapshot).to eq(read.snapshot)
        expect(wire).to eq(read)
      end

      it "keeps the bytes beyond the fixed layout as a frozen suffix" do
        _, suffix = filled
        expect(suffix).to eq(Emf::Model::Emr::Records::WireAdapter.suffix_of(bytes, read))
        expect(suffix).to be_frozen
        expect(suffix.encoding).to eq(Encoding::BINARY)
      end
    end
  end

  it "exposes editable BinData fields" do
    wire, = filler.call(record_bytes(12))
    expect(wire.ih_object).to be_a(BinData::Uint32le)
    wire.ih_object = 7
    expect(wire.to_binary_s).to eq([37, 12, 7].pack("VVV"))
    wire.ih_object.assign(9)
    expect(wire.ih_object.value).to eq(9)
  end

  context "when parsing" do
    def parse_with(*sizes)
      body = sizes.map { |n| record_bytes(n) }.join
      eof = [14, 20, 0, 16, 20].pack("V*")
      source = File.binread("spec/fixtures/emf/test-031.emf")
      header = source.byteslice(0, source.unpack1("@4V"))
      Emf::Emr::Parser.call(header + body + eof)
    end

    it "matches the BinData read path for ==, > and fixed size" do
      parsed = parse_with(12, 20)
      adapters = parsed.records.first(2)
      expect(adapters.map { |r| r.wire.class }).to all(eq(klass))
      expect(adapters.map { |r| r.suffix.bytesize }).to eq([0, 8])
      expect(parsed.errors).to be_empty
    end

    it "falls back to Raw with a ParseError when nSize is below the fixed size" do
      parsed = parse_with(8)
      expect(parsed.records.first.wire).to be_a(Emf::Emr::Binary::Records::Raw)
      expect(parsed.errors.size).to eq(1)
      expect(parsed.errors.first.message).to eq(begin
        klass.read([37, 8].pack("VV"))
      rescue StandardError => e
        "#{e.class}: #{e.message}"
      end)
    end
  end
end
