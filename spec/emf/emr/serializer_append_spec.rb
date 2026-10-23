# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emf::Emr::Serializer, "appending record bytes" do
  let(:adapter_class) { Emf::Model::Emr::Records::WireAdapter }
  let(:select_object) { Emf::Emr::Binary::Records::SelectObject }

  def built(handle)
    adapter_class.build(select_object, i_type: 37, ih_object: handle)
  end

  describe "WireAdapter#append_to" do
    it "appends the bytes of an untouched built record without handing out its own String" do
      adapter = built(3)
      out = String.new(encoding: Encoding::BINARY)
      expect(adapter.append_to(out)).to equal(out)
      expect(out).to eq(adapter.to_binary_s)
      out << "x"
      expect(adapter.to_binary_s).to eq(built(3).to_binary_s)
    end

    it "serializes an edit made through #wire, never the stale bytes" do
      adapter = built(3)
      stale = adapter.to_binary_s
      adapter.wire.ih_object.assign(9)
      out = String.new(encoding: Encoding::BINARY)
      adapter.append_to(out)
      expect(out).not_to eq(stale)
      expect(out).to eq(built(9).to_binary_s)
    end

    it "serializes a wire read without edit identically to the original bytes" do
      adapter = built(3)
      original = adapter.to_binary_s
      adapter.wire
      out = String.new(encoding: Encoding::BINARY)
      adapter.append_to(out)
      expect(out).to eq(original)
    end

    it "appends a built shell's bytes without packing it again" do
      wire = select_object.new(i_type: 37, ih_object: 3)
      expected = wire.to_binary_s
      allow(wire).to receive(:to_binary_s).and_call_original
      out = String.new(encoding: Encoding::BINARY)
      expect(adapter_class.new(wire: wire).append_to(out)).to equal(out)
      expect(out).to eq(expected)
      expect(wire).not_to have_received(:to_binary_s)
    end

    it "appends the suffix of a built record and the size that includes it" do
      wire = select_object.new(i_type: 37, ih_object: 3)
      adapter = adapter_class.new(wire: wire, suffix: "tail".b)
      out = "ab".b
      adapter.append_to(out)
      expect(out).to eq("#{'ab'.b}#{[37, 16, 3].pack('V3')}tail")
      expect(out.byteslice(2 + 4, 4).unpack1("V")).to eq(16)
    end

    it "round-trips a parsed record with trailing bytes, untouched, read and edited" do
      original = "#{[37, 16, 3].pack('V3')}tail"
      parse = -> { Emf::Emr::Parser.read_record_at(original.b.freeze, 0, []) }
      make = -> { adapter_class.new(wire: parse.call[0], suffix: parse.call[1]) }
      appended = lambda do |adapter|
        String.new(encoding: Encoding::BINARY).tap { |out| adapter.append_to(out) }
      end
      expect(appended.call(make.call)).to eq(original)
      read = make.call.tap(&:wire)
      expect(appended.call(read)).to eq(original)
      edited = make.call.tap { |adapter| adapter.wire.ih_object = 9 }
      expect(appended.call(edited)).to eq("#{[37, 16, 9].pack('V3')}tail")
    end

    it "appends a record held as bytes straight from its source" do
      source = Struct.new(:bytes) do
        def append_to(out) = out << "src"
        def to_binary_s = raise("must not be packed")
      end.new("abcd".b)
      out = "x".b
      expect(adapter_class.lazy(source: source).append_to(out)).to eq("xsrc")
    end
  end

  describe ".call" do
    it "serializes records edited after being built in order, with the rest untouched" do
      records = [built(1), built(2), built(3)]
      records[1].wire.ih_object.assign(8)
      metafile = Emf::Model::Metafile.new(format: :emf, header: Emf.parse(File.binread(Dir["spec/fixtures/emf/*.emf"].first)).header,
                                          records: records, errors: [], emf_plus: nil, trailing: "".b, emf_plus_source: nil)
      body = described_class.call(metafile).byteslice(-36, 36)
      expect(body).to eq([built(1), built(8), built(3)].map(&:to_binary_s).join)
    end
  end
end
