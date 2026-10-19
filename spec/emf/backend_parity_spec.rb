# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe "Parser compatibility baseline" do
  let(:bytes) { Emf::SpecSupport::FixturePath.read_fixture("simple", "image1.emf") }
  let(:metafile) { Emf.parse(bytes) }

  it "keeps format detection separate from the parsed EMF+ format" do
    expect(Emf.detect_format(bytes)).to eq(:emf)
    expect(metafile.format).to eq(:emf_plus)
    expect(metafile.errors).to be_empty
    expect(metafile.header.to_wire.to_binary_s).to eq(bytes.byteslice(0, metafile.header.n_size))
    expect(Emf.serialize(metafile)).to eq(bytes)
  end

  it "preserves the file API's binary content and byte-count return value" do
    Tempfile.create(["emf-parity", ".emf"]) do |file|
      expect(Emf.serialize_file(metafile, file.path)).to eq(bytes.bytesize)
      expect(File.binread(file.path)).to eq(bytes)
      expect(Emf.serialize(Emf.parse_file(file.path))).to eq(bytes)
    end
  end

  it "preserves detection and parse errors through the file API" do
    invalid = "invalid metafile".b
    message = "unrecognised format (first uint32=0x61766E69)"
    expect { Emf.detect_format(invalid) }.to raise_error(Emf::FormatError, message)
    expect { Emf.parse(invalid) }.to raise_error(Emf::FormatError, message)
    Tempfile.create(["emf-invalid", ".emf"]) do |file|
      File.binwrite(file.path, invalid)
      expect { Emf.parse_file(file.path) }.to raise_error(Emf::FormatError, message)
    end
  end

  {
    scalar: [98, ->(wire) { wire.mode = 2 }],
    nested: [36, ->(wire) { wire.xform.dx = 12.5 }],
    array: [86, ->(wire) { wire.apts[0].x = 241 }]
  }.each do |shape, (type_id, mutate)|
    it "serializes #{shape} wire edits after earlier reads and serialization" do
      index = metafile.records.index { |record| record.type_id == type_id }
      expect(index).to be_a(Integer)
      record = metafile.records.fetch(index)
      independent = Emf.parse(bytes).records.fetch(index)
      wire = record.wire
      original_record_bytes = wire.to_binary_s
      sibling_bytes = metafile.records.map { |sibling| sibling.wire.to_binary_s }
      original_inspect = record.inspect

      expect(wire).to be_a(BinData::Record)
      expect(record.wire).to equal(wire)
      expect(record).to eq(independent)
      expect(record.eql?(independent)).to be(true)
      expect(record.hash).to eq(independent.hash)
      expect(Emf.serialize(metafile)).to eq(bytes)

      mutate.call(wire)
      expect(record.wire).to equal(wire)
      expect(wire.to_binary_s).not_to eq(original_record_bytes)
      expect(record).not_to eq(independent)
      expect(record.eql?(independent)).to be(false)
      expect(record.type_id).to eq(type_id)
      expect(record.inspect).to eq(original_inspect)

      edited_bytes = Emf.serialize(metafile)
      expect(edited_bytes).not_to eq(bytes)
      expect(Emf.serialize(metafile)).to eq(edited_bytes)
      reparsed = Emf.parse(edited_bytes)
      expect(reparsed.errors).to be_empty
      expect(reparsed.records.fetch(index)).to eq(record)
      expect(reparsed.records.fetch(index).hash).to eq(record.hash)
      expect(reparsed.header.to_wire.to_binary_s).to eq(metafile.header.to_wire.to_binary_s)
      metafile.records.each_with_index do |sibling, sibling_index|
        next if sibling_index == index

        expect(sibling.wire.to_binary_s).to eq(sibling_bytes.fetch(sibling_index))
        expect(reparsed.records.fetch(sibling_index).wire.to_binary_s).to eq(sibling_bytes.fetch(sibling_index))
      end
      expect(Emf.serialize(reparsed)).to eq(edited_bytes)
    end
  end
end
