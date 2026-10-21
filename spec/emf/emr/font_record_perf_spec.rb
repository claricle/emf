# frozen_string_literal: true

require "spec_helper"
require "emf/emr/binary/records/create_font_indirect_w"
require_relative "../../support/font_record_helpers"

RSpec.describe Emf::Emr::Binary::Records::CreateFontIndirectW do
  include FontRecordHelpers

  def allocations
    GC.disable
    before = GC.stat(:total_allocated_objects)
    yield
    GC.stat(:total_allocated_objects) - before
  ensure
    GC.enable
  end

  variants = {
    "LOGFONTW only" => :log_font_bytes,
    "Panose ELW" => :panose_font_bytes,
    "LOGFONTEXDV with design vector" => :exdv_font_bytes
  }

  variants.each_key do |label|
    it "round trips the #{label} body byte for byte" do
      bytes = font_record_bytes(send(variants.fetch(label)))
      expect(described_class.read(bytes).to_binary_s).to eq(bytes)
    end
  end

  # Ceilings are under half of the per-unit-object baseline: parse 1027 / serialize 364.
  it "parses and serializes the ExDv body without one object per UTF-16 unit" do
    bytes = font_record_bytes(exdv_font_bytes)
    described_class.read(bytes)
    wire = nil
    expect(allocations { wire = described_class.read(bytes) }).to be < 500
    expect(allocations { wire.to_binary_s }).to be < 180
  end

  it "keeps the fixed UTF-16 fields BinData arrays of uint16 elements" do
    elw = described_class.read(font_record_bytes(exdv_font_bytes)).elw
    [elw.log_font.facename, elw.fullname, elw.style, elw.script].each do |field|
      expect(field).to be_a(BinData::Array)
      expect(field[0]).to be_a(BinData::Uint16le)
    end
    expect([elw.log_font.facename.length, elw.fullname.length, elw.style.length, elw.script.length])
      .to eq([32, 64, 32, 32])
  end

  it "reads element values and snapshots after a lazy read" do
    field = described_class.read(font_record_bytes(log_font_bytes)).elw.facename
    expect(field[0].value).to eq(0xD800)
    expect(field[2].snapshot).to eq(0xDC00)
    expect(field.snapshot.first(3)).to eq([0xD800, 0, 0xDC00])
    expect(field.map(&:value)).to eq(field.to_a.map(&:snapshot))
  end

  it "assigns elements and whole fields, clamping to uint16" do
    wire = described_class.read(font_record_bytes(log_font_bytes))
    field = wire.elw.facename
    field[0].assign(70_000)
    field[1] = -5
    field[2].assign(0x41)
    expect([field[0].value, field[1].value, field[2].value]).to eq([0xFFFF, 0, 0x41])
    expect(wire.to_binary_s.byteslice(12 + 28, 6)).to eq("\xFF\xFF\x00\x00\x41\x00".b)
    wire.elw.facename = [70_000, -1] + Array.new(30, 0)
    expect(wire.to_binary_s.byteslice(12 + 28, 4)).to eq("\xFF\xFF\x00\x00".b)
  end

  it "writes edits made to a nested field after a lazy read" do
    wire = described_class.read(font_record_bytes(exdv_font_bytes))
    wire.elw.script[0] = 0x41
    wire.elw.log_font.facename = [0x42] + Array.new(31, 0)
    reread = described_class.read(wire.to_binary_s).elw
    expect(reread.script.snapshot.first(2)).to eq([0x41, 68])
    expect(reread.log_font.facename.snapshot.first(2)).to eq([0x42, 0])
  end

  it "reports clear only for an all-zero field and clears on request" do
    wire = described_class.read(font_record_bytes(log_font_bytes))
    expect(wire.elw.facename).not_to be_clear
    wire.elw.facename.clear
    expect(wire.elw.facename).to be_clear
    expect(wire.elw.facename.snapshot.uniq).to eq([0])
  end

  it "compares equal to a field read from the same bytes" do
    bytes = font_record_bytes(panose_font_bytes)
    first = described_class.read(bytes).elw.fullname
    second = described_class.read(bytes).elw.fullname
    second[0]
    expect(first).to eq(second)
  end

  it "builds fields from Integer arrays as the native adapter does" do
    exdv = Emf::Emr::Binary::LogFontExDv.new(
      log_font: { facename: [65] + Array.new(31, 0) }, fullname: Array.new(64, 66), style: Array.new(32, 67),
      script: Array.new(32, 68), design_vector: { signature: 0x08007664, num_axes: 0, axis_values: [] },
      trailing: "".b
    )
    expect(exdv.fullname).to be_a(BinData::Array)
    expect(exdv.log_font.facename[0].value).to eq(65)
    expect(exdv.script.snapshot).to eq(Array.new(32, 68))
    expect(exdv.to_binary_s.byteslice(28, 4)).to eq("A\0\0\0".b)
    expect(Emf::Emr::Binary::LogFontExDv.read(exdv.to_binary_s).style.snapshot).to eq(Array.new(32, 67))
  end
end
