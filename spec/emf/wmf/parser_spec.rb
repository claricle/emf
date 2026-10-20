# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emf::Wmf::Parser do
  let(:standard) { File.binread(File.expand_path("../../fixtures/wmf/standard-line.wmf", __dir__)) }
  let(:placeable) { File.binread(File.expand_path("../../fixtures/wmf/placeable-line.wmf", __dir__)) }

  it "parses signed points and unknown records through the public Ruby backend" do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("EMF_BACKEND", "auto").and_return("ruby")
    metafile = Emf.parse(standard)
    expect(Emf.serialize(metafile)).to eq(standard)
    expect(metafile.format).to eq(:wmf)
    expect(metafile).to be_ok
    expect(metafile.header).to be_a(Emf::Model::Wmf::Header)
    expect(metafile.header.number_of_members).to eq(7)
    expect(metafile.records.map(&:type_id)).to eq([0x214, 0x7FFE, 0x213, 0])
    expect(metafile.records.first).to be_a(Emf::Model::Wmf::Records::MoveTo)
    expect([metafile.records.first.x, metafile.records.first.y]).to eq([-10, -20])
    expect([metafile.records[2].x, metafile.records[2].y]).to eq([-32_768, 32_767])
    expect(metafile.records[1].raw_bytes).to eq(standard.byteslice(28, 10))
    expect(metafile.records.last).to be_a(Emf::Model::Wmf::Records::Eof)
  end

  it "preserves standard, placeable, unknown and trailing bytes exactly" do
    [standard, placeable, standard + "\xFFtrailing".b].each do |bytes|
      expect(Emf::Wmf::Serializer.call(described_class.call(bytes))).to eq(bytes)
    end
    header = described_class.call(placeable).header.placeable
    expect([header.left, header.top, header.right, header.bottom, header.inch]).to eq([-100, -200, 300, 400, 1440])
  end

  it "accepts both type/version enums and noncanonical upper function bytes" do
    bytes = standard.dup
    bytes[0, 2] = [1].pack("v")
    bytes[4, 2] = [0x100].pack("v")
    bytes[22, 2] = [0x7F14].pack("v")
    metafile = described_class.call(bytes)
    expect(metafile.records.first).to be_a(Emf::Model::Wmf::Records::MoveTo)
    expect(Emf::Wmf::Serializer.call(metafile)).to eq(bytes)
  end

  it "rejects truncated headers and invalid standard fields" do
    [0, 3, 17].each { |length| expect { described_class.call(standard.byteslice(0, length)) }.to raise_error(Emf::FormatError) }
    [[0, 3], [2, 8], [4, 0x200], [6, 8], [12, 4]].each do |offset, value|
      bytes = standard.dup
      bytes[offset, 2] = [value].pack("v")
      expect { described_class.call(bytes) }.to raise_error(Emf::FormatError)
    end
    expect { described_class.call(placeable.byteslice(0, 21)) }.to raise_error(Emf::FormatError)
  end

  it "rejects malformed record lengths, truncated records and absent EOF" do
    [0, 2, 4, 0xFFFF_FFFF].each do |words|
      bytes = standard.dup
      bytes[18, 4] = [words].pack("V")
      expect { described_class.call(bytes) }.to raise_error(Emf::ParseError) { |error| expect(error.offset).to eq(18) }
    end
    bytes = standard.byteslice(0, standard.bytesize - 6)
    bytes[6, 4] = [bytes.bytesize / 2].pack("V")
    expect { described_class.call(bytes) }.to raise_error(Emf::ParseError, /EOF/)
    expect { described_class.call(standard.byteslice(0, standard.bytesize - 1)) }.to raise_error(Emf::FormatError)
  end

  it "validates placeable checksum, reserved data and on-disk handle" do
    [4, 16, 20].each do |offset|
      bytes = placeable.dup
      bytes.setbyte(offset, bytes.getbyte(offset) ^ 1)
      bytes[20, 2] = [Emf::Wmf::Binary.checksum(bytes.byteslice(0, 20))].pack("v") unless offset == 20
      expect { described_class.call(bytes) }.to raise_error(Emf::FormatError)
    end
  end

  it "preserves the resource handle for in-memory placeable WMF" do
    bytes = placeable.dup
    bytes[4, 2] = [123].pack("v")
    bytes[22, 2] = [1].pack("v")
    bytes[20, 2] = [Emf::Wmf::Binary.checksum(bytes.byteslice(0, 20))].pack("v")
    metafile = described_class.call(bytes)
    expect(metafile.header.placeable.handle).to eq(123)
    expect(Emf::Wmf::Serializer.call(metafile)).to eq(bytes)
  end

  it "serializes checked coordinate and bounding-box edits and recalculates checksum" do
    metafile = described_class.call(placeable)
    metafile.records.first.x = -1234
    metafile.header.placeable.left = -123
    bytes = Emf::Wmf::Serializer.call(metafile)
    reparsed = described_class.call(bytes)
    expect(reparsed.records.first.x).to eq(-1234)
    expect(reparsed.header.placeable.left).to eq(-123)
    expect(reparsed.records[1].raw_bytes).to eq(metafile.records[1].raw_bytes)
    metafile.records.first.x = 32_768
    expect { Emf::Wmf::Serializer.call(metafile) }.to raise_error(Emf::SerializeError, /out of range/)
  end

  it "recalculates file size and largest record after record edits" do
    metafile = described_class.call(standard)
    records = [metafile.records.last]
    edited = Emf::Model::Metafile.new(format: :wmf, header: metafile.header, records: records)
    reparsed = described_class.call(Emf::Wmf::Serializer.call(edited))
    expect(reparsed.header.size_words).to eq(12)
    expect(reparsed.header.max_record_words).to eq(3)
    expect(reparsed.records.map(&:type_id)).to eq([0])
  end

  it "rejects EOF framing errors and partial record headers within the declared size" do
    bytes = standard.dup
    bytes[6, 4] = [(standard.bytesize + 2) / 2].pack("V")
    bytes << "\x00\x00".b
    expect { described_class.call(bytes) }.to raise_error(Emf::ParseError, /after EOF/)
    bytes[standard.bytesize - 6, 4] = [4].pack("V")
    expect { described_class.call(bytes) }.to raise_error(Emf::ParseError, /EOF length/)
    bytes = standard.byteslice(0, 20)
    bytes[6, 4] = [10].pack("V")
    expect { described_class.call(bytes) }.to raise_error(Emf::ParseError, /truncated record header/)
  end

  it "preserves unknown functions with a zero low byte" do
    bytes = standard.dup
    bytes[32, 2] = [0x100].pack("v")
    metafile = described_class.call(bytes)
    expect(metafile.records[1]).to be_a(Emf::Model::Wmf::Records::UnknownRecord)
    expect(Emf::Wmf::Serializer.call(metafile)).to eq(bytes)
  end

  it "enforces input and record resource limits" do
    metafile = described_class.call(placeable)
    stub_const("Emf::Wmf::Binary::MAX_RECORDS", 2)
    expect { described_class.call(standard) }.to raise_error(Emf::ParseError, /record limit/)
    expect { Emf::Wmf::Serializer.call(metafile) }.to raise_error(Emf::SerializeError, /record limit/)
    stub_const("Emf::Wmf::Binary::MAX_RECORDS", 4)
    stub_const("Emf::Wmf::Binary::MAX_INPUT_BYTES", placeable.bytesize - 1)
    expect { Emf::Wmf::Serializer.call(metafile) }.to raise_error(Emf::SerializeError, /input too large/)
    stub_const("Emf::Wmf::Binary::MAX_INPUT_BYTES", 10)
    expect { described_class.call(standard) }.to raise_error(Emf::FormatError, /input too large/)
  end

  it "rejects missing EOF, invalid raw framing and mismatched typed functions when serializing" do
    metafile = described_class.call(standard)
    [[], [metafile.records.last, metafile.records.last],
     [Emf::Model::Wmf::Records::UnknownRecord.new(type_id: 0x7FFE, raw_bytes: "bad"), metafile.records.last],
     [Emf::Model::Wmf::Records::MoveTo.new(x: 1, y: 2, type_id: 0x213), metafile.records.last]].each do |records|
      edited = Emf::Model::Metafile.new(format: :wmf, header: metafile.header, records: records)
      expect { Emf::Wmf::Serializer.call(edited) }.to raise_error(Emf::SerializeError)
    end
  end

  it "visits WMF records through the shared visitor contract" do
    visitor = Emf::Model::Visitor.new
    metafile = described_class.call(standard)
    expect(visitor).to receive(:visit_wmf_record).with(metafile.records.first).ordered
    metafile.records.drop(1).each { |record| expect(visitor).to receive(:visit_wmf_record).with(record).ordered }
    visitor.visit_all(metafile)
  end
end
