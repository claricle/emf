# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emf::Emr::Binary::FastFill do
  codes = Emf::Emr::Binary::TypeCodes
  # [type code, wire class, fixed size, field edit]
  types = {
    "SelectObject" => [codes::SELECTOBJECT, 12, ->(w) { w.ih_object = 7 }],
    "DeleteObject" => [codes::DELETEOBJECT, 12, ->(w) { w.ih_object = 7 }],
    "MoveToEx" => [codes::MOVETOEX, 16, ->(w) { w.origin.x = -7 }],
    "LineTo" => [codes::LINETO, 16, ->(w) { w.origin.y = -7 }],
    "CreateBrushIndirect" => [codes::CREATEBRUSHINDIRECT, 24, ->(w) { w.color.green = 7 }]
  }

  extras = [0, 4, 8].freeze

  def body(size)
    Array.new(size - 8) { |i| (0x80 + (i * 37)) & 0xFF }.pack("C*")
  end

  def record_bytes(type, size, total)
    ([type, total].pack("VV") + body(size) + ("\xAB".b * (total - size)))
  end

  it "is registered only for enabled types" do
    expect(described_class.for(codes::EOF)).to be_nil
  end

  types.each do |name, (type, size, edit)|
    describe name do
      let(:klass) { Emf::Emr::Binary::Records.const_get(name) }
      let(:filler) { described_class.for(type) }

      it "uses the layout's fixed size" do
        expect(filler.size).to eq(size)
      end

      extras.each do |extra|
        context "with #{extra} bytes beyond the layout" do
          let(:bytes) { record_bytes(type, size, size + extra) }
          let(:read) { klass.read(bytes) }

          it "builds the same wire class with identical bytes and snapshot" do
            wire, = filler.call(bytes)
            expect(wire).to be_a(klass)
            expect(wire.to_binary_s).to eq(read.to_binary_s)
            expect(wire.snapshot).to eq(read.snapshot)
            expect(wire).to eq(read)
          end

          it "keeps the trailing bytes as a frozen binary suffix" do
            _, suffix = filler.call(bytes)
            expect(suffix).to eq(Emf::Model::Emr::Records::WireAdapter.suffix_of(bytes, read))
            expect(suffix).to be_frozen
            expect(suffix.encoding).to eq(Encoding::BINARY)
          end
        end
      end

      it "yields editable BinData fields that re-serialise like a read record" do
        bytes = record_bytes(type, size, size)
        wire, = filler.call(bytes)
        read = klass.read(bytes)
        edit.call(wire)
        edit.call(read)
        expect(wire.to_binary_s).to eq(read.to_binary_s)
        expect(wire.to_binary_s).not_to eq(bytes)
      end

      it "falls back to Raw with the BinData error when nSize is below the layout" do
        parsed = parse_with(record_bytes(type, 8, 8))
        expect(parsed.records.first.wire).to be_a(Emf::Emr::Binary::Records::Raw)
        expect(parsed.errors.map(&:message)).to eq([short_read_message(klass, type)])
      end

      it "parses records at, above the layout size through the adapter" do
        parsed = parse_with(record_bytes(type, size, size), record_bytes(type, size, size + 8))
        adapters = parsed.records.first(2)
        expect(adapters.map { |r| r.wire.class }).to all(eq(klass))
        expect(adapters.map { |r| r.suffix.bytesize }).to eq([0, 8])
        expect(parsed.errors).to be_empty
      end
    end
  end

  def parse_with(*records)
    source = File.binread("spec/fixtures/emf/test-031.emf")
    header = source.byteslice(0, source.unpack1("@4V"))
    Emf::Emr::Parser.call(header + records.join + [14, 20, 0, 16, 20].pack("V*"))
  end

  def short_read_message(klass, type)
    klass.read([type, 8].pack("VV"))
  rescue StandardError => e
    "#{e.class}: #{e.message}"
  end
end
