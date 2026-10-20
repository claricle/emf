# frozen_string_literal: true

require "spec_helper"
require "emf/native/fields"
require "emf/native/snapshot"
require "emf/native/hydrator"
require_relative "../../support/palette_records"

RSpec.describe "native palette hydration" do
  include PaletteRecords

  let(:library) { ENV.fetch("EMF_TEST_NATIVE_LIBRARY") }
  let(:header) { Emf::Emr::Binary::Header.new(i_type: 1, n_size: 108, d_signature: 0x464D4520).to_binary_s }
  let(:eof) { [14, 20, 0, 0, 20].pack("V*") }
  let(:unknown) { "#{[0xFFFF, 12].pack('V2')}RAW!" }

  around do |example|
    previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
    ENV["EMF_BACKEND"] = "native"
    ENV["EMF_NATIVE_LIBRARY"] = library
    example.run
  ensure
    %w[EMF_BACKEND EMF_NATIVE_LIBRARY].each { |key| ENV[key] = previous[key] }
  end

  it "hydrates all palette fields directly and matches Ruby wire snapshots" do
    (48..52).each do |kind|
      record = palette_record(kind)
      klass = Emf::Emr::Binary::Records.lookup(kind)
      expected = klass.read(record).snapshot
      expect(klass).not_to receive(:read)
      expect(Emf::Emr::Parser).not_to receive(:call)
      input = "#{header}#{record}#{unknown}#{eof}tail"
      parsed = Emf.parse(input)
      wire = parsed.records.first.wire
      expect(wire).to be_a(klass)
      expect(wire.snapshot).to eq(expected)
      expect(parsed.errors).to be_empty
      expect(Emf.serialize(parsed)).to eq(input)
      wire.assign(wire.snapshot)
      expect(Emf.serialize(parsed)).to eq(input)
    end
  end

  it "serializes scalar and nested edits while retaining unknown bytes" do
    (48..51).each do |kind|
      record = palette_record(kind)
      parsed = Emf.parse("#{header}#{record}#{unknown}#{eof}tail")
      wire = parsed.records.first.wire
      wire.ih_pal = 7
      edited = record.dup
      edited[8, 4] = "\x07\0\0\0".b
      if (49..50).cover?(kind)
        fixed = kind == 49 ? 16 : 20
        if kind == 49
          wire.version = 0x300
          edited[12, 2] = "\0\x03".b
        else
          wire.start = 0
          edited[12, 4] = "\0" * 4
        end
        wire.palette_entries[0].flags = 0xFE
        wire.palette_entries[1].blue = 42
        edited[fixed + 3] = "\xFE".b
        edited[fixed + 6] = "*"
      elsif kind == 51
        wire.entry_count = 0
        edited[12, 4] = "\0" * 4
      end
      expect(Emf.serialize(parsed)).to eq("#{header}#{edited}#{unknown}#{eof}tail")
    end
  end

  it "retains suffixes and subsequent records through caller-counted growth shrink and zero edits" do
    counts = [0, 1, 3]
    [49, 50].each do |kind|
      counts.each do |count|
        parsed = Emf.parse("#{header}#{palette_record(kind)}#{unknown}#{eof}tail")
        wire = parsed.records.first.wire
        colors = Array.new(count) { { red: 7, green: 8, blue: 9, flags: 0xFF } }
        wire.palette_entries.assign(colors)
        wire.entry_count = count
        wire.n_size = (kind == 49 ? 16 : 20) + (count * 4) + 4
        reparsed = Emf.parse(Emf.serialize(parsed))
        actual = reparsed.records.first.wire
        expect(actual.palette_entries.snapshot).to eq(colors)
        expect(actual.entry_count.to_i).to eq(count)
        expect(actual.trailing.to_s).to eq("TAIL")
        expect(reparsed.records[1].wire.to_binary_s).to eq(unknown)
        expect(reparsed.trailing).to eq("tail")
        expect(reparsed.errors).to be_empty
      end
    end
  end

  it "hydrates empty entry arrays and recovers malformed counts as Raw with diagnostics" do
    [49, 50].each do |kind|
      empty = palette_record(kind, entries: [])
      parsed = Emf.parse(header + empty + eof)
      expect(parsed.records.first.wire.palette_entries).to be_empty
      expect(Emf.serialize(parsed)).to eq(header + empty + eof)
      record = palette_record(kind)
      offset, format = kind == 49 ? [14, "v"] : [16, "V"]
      record[offset, kind == 49 ? 2 : 4] = Array.new(1, 0xFFFF).pack(format)
      input = "#{header}#{record}#{unknown}#{eof}tail"
      malformed = Emf.parse(input)
      expect(malformed.records.first.wire).to be_a(Emf::Emr::Binary::Records::Raw)
      expect(malformed.records[1].wire.to_binary_s).to eq(unknown)
      expect(malformed.errors.length).to eq(1)
      expect(Emf.serialize(malformed)).to eq(input)
    end
  end

  it "rejects invalid snapshot counts lengths and create versions before allocating entries" do
    payload = [7, 0x300, 0].pack("V2Q<")
    invalid_counts = [0xFFFFFFFFFFFFFFFF, 1].map { |count| Array.new(1, count).pack("Q<") }
    [83, 84].each do |family|
      raw = "\0" * (family == 83 ? 16 : 20)
      klass, fields = Emf::Native::PaletteFields.call(payload, family, raw)
      expect(klass).to eq(Emf::Emr::Binary::Records.lookup(family == 83 ? 49 : 50))
      expect(fields).to include(entry_count: 0, palette_entries: [])
      invalid_counts.each do |bytes|
        malformed = payload.dup
        malformed[8, bytes.bytesize] = bytes
        expect { Emf::Native::PaletteFields.call(malformed, family, raw) }.to raise_error(Emf::FormatError)
        snapshot = palette_snapshot(malformed, family, raw)
        expect { Emf::Native::Hydrator.new(snapshot, header + raw).call }.to raise_error(Emf::FormatError)
      end
      expect { Emf::Native::PaletteFields.call(payload.byteslice(0, 15), family, raw) }.to raise_error(Emf::FormatError)
      expect { Emf::Native::PaletteFields.call("#{payload}x", family, raw) }.to raise_error(Emf::FormatError)
      expect { Emf::Native::PaletteFields.call(payload, family, "") }.to raise_error(Emf::FormatError)
    end
    expect { Emf::Native::PaletteFields.call([7, 0x10000, 0].pack("V2Q<"), 83, "\0" * 16) }.to raise_error(Emf::FormatError)
    [[82, 4], [85, 8], [86, 0]].each do |family, length|
      expect { Emf::Native::PaletteFields.call("\0" * (length + 1), family, "\0" * 20) }.to raise_error(Emf::FormatError)
      expect { Emf::Native::PaletteFields.call("\0" * length, family, "") }.to raise_error(Emf::FormatError)
    end
  end
end
