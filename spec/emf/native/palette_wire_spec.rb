# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/palette_records"

RSpec.describe "palette wire layout" do
  include PaletteRecords

  it "exposes mixed-width create framing and raw RGB/flag bytes" do
    [49, 50].each do |kind|
      bytes = palette_record(kind)
      klass = Emf::Emr::Binary::Records.lookup(kind)
      wire = klass.read(bytes)
      expect(wire.ih_pal.to_i).to eq(0x87654321)
      expect(wire.palette_entries.snapshot).to eq([{ red: 1, green: 2, blue: 255, flags: 128 },
                                                   { red: 254, green: 3, blue: 0, flags: 255 }])
      expect(wire.version.to_i).to eq(0xFEDC) if kind == 49
      expect(wire.start.to_i).to eq(0xFFFFFFFF) if kind == 50
      expect(wire.entry_count.to_i).to eq(2)
      expect(wire.trailing.to_s).to eq("TAIL")
      expect(wire.to_binary_s).to eq(bytes)
      wire.palette_entries[0].flags = 0xFE
      wire.palette_entries[1].red = 42
      edited = bytes.dup
      fixed = kind == 49 ? 16 : 20
      edited[fixed + 3] = "\xFE".b
      edited[fixed + 4] = "*"
      expect(wire.to_binary_s).to eq(edited)
    end
  end

  it "retains scalar and unit record suffixes" do
    [48, 51, 52].each do |kind|
      bytes = palette_record(kind)
      wire = Emf::Emr::Binary::Records.lookup(kind).read(bytes)
      expect(wire.trailing.to_s).to eq("TAIL")
      expect(wire.ih_pal.to_i).to eq(kind == 48 ? 0x8000000F : 0x87654321) unless kind == 52
      expect(wire.entry_count.to_i).to eq(0xFFFFFFFF) if kind == 51
      expect(wire.to_binary_s).to eq(bytes)
    end
  end

  it "applies legacy body assignment to typed fields atomically" do
    [49, 50, 51].each do |kind|
      wire = Emf::Emr::Binary::Records.lookup(kind).read(palette_record(kind))
      offset = kind == 49 ? 12 : 8
      replacement = palette_record(kind, entries: [[7, 8, 9, 0xFE]]).byteslice(offset..)
      mutations = %i[setter assign]
      mutations.each do |mutation|
        mutation == :setter ? wire.body = replacement : wire.body.assign(replacement)
        expect(wire.body.to_s).to eq(replacement)
        expect(wire.to_binary_s.byteslice(offset..)).to eq(replacement)
        expect(wire.palette_entries.first.flags.to_i).to eq(0xFE) unless kind == 51
        expected = wire.to_binary_s
        expect { mutation == :setter ? wire.body = "short" : wire.body.assign("short") }.to raise_error(ArgumentError)
        expect(wire.to_binary_s).to eq(expected)
        next if kind == 51

        invalid = replacement.dup
        count_offset, width = kind == 49 ? [2, 2] : [8, 4]
        invalid[count_offset, width] = "\xFF".b * width
        expect { mutation == :setter ? wire.body = invalid : wire.body.assign(invalid) }.to raise_error(ArgumentError)
        expect(wire.to_binary_s).to eq(expected)
      end
      if kind == 51
        wire.entry_count = 3
        expect(wire.body.to_s.byteslice(4, 4)).to eq("\x03\0\0\0".b)
      else
        wire.palette_entries.first.red = 42
        expect(wire.body.to_s.getbyte(kind == 49 ? 4 : 12)).to eq(42)
      end
    end
  end

  it "rejects invalid Ruby palette counts before invoking typed readers" do
    header = Emf::Emr::Binary::Header.new(i_type: 1, n_size: 108, d_signature: 0x464D4520).to_binary_s
    sibling = palette_record(48)
    eof = [14, 20, 0, 0, 20].pack("V*")
    [49, 50].each do |kind|
      klass = Emf::Emr::Binary::Records.lookup(kind)
      expect(klass).not_to receive(:read)
      malformed = palette_record(kind)
      offset, width = kind == 49 ? [14, 2] : [16, 4]
      malformed[offset, width] = "\xFF".b * width
      input = "#{header}#{malformed}#{sibling}#{eof}tail"
      parsed = Emf::Emr::Parser.call(input)
      expect(parsed.records.first.wire).to be_a(Emf::Emr::Binary::Records::Raw)
      expect(parsed.errors.length).to eq(1)
      expect(parsed.records[1].wire.to_binary_s).to eq(sibling)
      expect(parsed.trailing).to eq("tail")
      expect(Emf::Emr::Serializer.call(parsed)).to eq(input)
    end
  end
end
