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
end
