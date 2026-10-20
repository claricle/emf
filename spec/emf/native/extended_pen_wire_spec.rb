# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/extended_pen_records"

RSpec.describe "extended pen wire layout" do
  include ExtendedPenRecords

  it "exposes unsigned pen fields, styles, bitmap spans and opaque preservation bytes" do
    [false, true].each do |bits_first|
      bytes = extended_pen_record(bits_first: bits_first)
      wire = Emf::Emr::Binary::Records::ExtCreatePen.read(bytes)
      expect(wire.pen_style.to_i).to eq(0xFFFFFFFF)
      expect(wire.width.to_i).to eq(0x80000000)
      expect(wire.brush_style.to_i).to eq(0xFFFFFFFE)
      expect(wire.color.snapshot).to eq(red: 0x98, green: 0xBA, blue: 0xDC, reserved: 0xFE)
      expect(wire.brush_hatch.to_i).to eq(0xFFFFFFFF)
      expect(wire.style_entries.snapshot).to eq([0, 0xFFFFFFFF, 7])
      expect(wire.bitmap_info.to_s).to eq("INFO")
      expect(wire.bitmap_bits.to_s).to eq("BITS")
      expect(wire.info_padding.to_s).to eq("GAP!")
      expect(wire.bits_padding.to_s).to eq("GAP!")
      expect(wire.trailing.to_s).to eq("TAIL")
      expect(wire.body).to eq(bytes.byteslice(12..))
      expect(wire.to_binary_s).to eq(bytes)
      wire.style_entries[1] = 42
      wire.bitmap_info.assign("EDIT")
      wire.pen_style = 123
      edited = bytes.dup
      edited[28, 4] = Array(123).pack("V")
      edited[56, 4] = Array(42).pack("V")
      edited[wire.off_bmi.to_i, 4] = "EDIT"
      expect(wire.to_binary_s).to eq(edited)
    end
  end

  it "distinguishes absent and present empty bitmap buffers with zero styles" do
    [[nil, nil], ["", nil], [nil, ""], ["", ""]].each do |info, bits|
      bytes = extended_pen_record(styles: [], info: info, bits: bits)
      wire = Emf::Emr::Binary::Records::ExtCreatePen.read(bytes)
      expect(wire.style_entries).to be_empty
      expect(wire.bitmap_info.nil?).to eq(info.nil?)
      expect(wire.bitmap_bits.nil?).to eq(bits.nil?)
      expect(wire.to_binary_s).to eq(bytes)
    end
  end

  it "applies legacy body writes to the typed fields" do
    bytes = extended_pen_record
    wire = Emf::Emr::Binary::Records::ExtCreatePen.read(bytes)
    replacement = bytes.byteslice(12..)
    replacement[16, 4] = [123].pack("V")
    wire.body = replacement
    expect(wire.pen_style.to_i).to eq(123)
    replacement[20, 4] = [42].pack("V")
    wire.body.assign(replacement)
    expect(wire.width.to_i).to eq(42)
    expect(wire.style_entries.snapshot).to eq([0, 0xFFFFFFFF, 7])
    expect(wire.bitmap_info.to_s).to eq("INFO")
    expect(wire.to_binary_s).to eq(bytes.byteslice(0, 12) + replacement)
    expect { wire.body = ("\0" * 36) + [0xFFFFFFFF].pack("V") }.to raise_error(ArgumentError)
    expect(wire.to_binary_s).to eq(bytes.byteslice(0, 12) + replacement)
  end

  it "guards invalid style counts before typed allocation and preserves the following record" do
    header = Emf::Emr::Binary::Header.new(i_type: 1, n_size: 108, d_signature: 0x464D4520).to_binary_s
    following = "#{[0xFFFF, 12].pack('V2')}NEXT"
    expect(Emf::Emr::Binary::Records::ExtCreatePen).not_to receive(:read)
    [500, 0xFFFFFFFF].each do |count|
      record = extended_pen_record
      record[48, 4] = [count].pack("V")
      input = header + record + following
      parsed = Emf::Emr::Parser.call(input)
      expect(parsed.records.first.wire).to be_a(Emf::Emr::Binary::Records::Raw)
      expect(parsed.errors.length).to eq(1)
      expect(parsed.errors.first.message).to include("more entries than nSize allows")
      expect(parsed.records[1].wire.to_binary_s).to eq(following)
      expect(Emf::Emr::Serializer.call(parsed)).to eq(input)
    end
  end
end
