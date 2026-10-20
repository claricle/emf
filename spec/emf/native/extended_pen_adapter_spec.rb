# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/extended_pen_records"

RSpec.describe "native extended pen hydration" do
  include ExtendedPenRecords

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

  it "hydrates semantic fields directly and preserves ordered spans, suffixes and subsequent records" do
    expect(Emf::Emr::Parser).not_to receive(:call)
    expect(Emf::Emr::Binary::Records::ExtCreatePen).not_to receive(:read)
    [false, true].each do |bits_first|
      record = extended_pen_record(bits_first: bits_first)
      input = "#{header}#{record}#{unknown}#{eof}tail"
      parsed = Emf.parse(input)
      wire = parsed.records.first.wire
      expect(wire).to be_a(Emf::Emr::Binary::Records::ExtCreatePen)
      expect(wire.ih_pen.to_i).to eq(0x80000001)
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
      expect(wire.body).to eq(record.byteslice(12..))
      expect(parsed.errors).to be_empty
      expect(Emf.serialize(parsed)).to eq(input)
      wire.width = 42
      wire.style_entries[0] = 13
      wire.bitmap_bits.assign("EDIT")
      edited = record.dup
      edited[32, 4] = Array(42).pack("V")
      edited[52, 4] = Array(13).pack("V")
      edited[wire.off_bits.to_i, 4] = "EDIT"
      expect(Emf.serialize(parsed)).to eq("#{header}#{edited}#{unknown}#{eof}tail")
    end
  end

  it "retains none versus empty bitmap spans and zero style arrays" do
    [[nil, nil], ["", nil], [nil, ""], ["", ""]].each do |info, bits|
      record = extended_pen_record(styles: [], info: info, bits: bits)
      parsed = Emf.parse(header + record + eof)
      wire = parsed.records.first.wire
      expect(wire.style_entries).to be_empty
      expect(wire.bitmap_info.nil?).to eq(info.nil?)
      expect(wire.bitmap_bits.nil?).to eq(bits.nil?)
      expect(wire.to_binary_s).to eq(record)
      expect(parsed.errors).to be_empty
    end
  end

  it "serializes structural edits when the caller updates wire counts, offsets and sizes" do
    record = extended_pen_record
    parsed = Emf.parse(header + record + eof)
    wire = parsed.records.first.wire
    wire.style_entries << 11
    wire.num_style_entries = 4
    wire.off_bmi = wire.off_bmi.to_i + 4
    wire.off_bits = wire.off_bits.to_i + 8
    wire.bitmap_info.assign("INFOEDIT")
    wire.cb_bmi = 8
    wire.n_size = wire.n_size.to_i + 8
    reparsed = Emf.parse(Emf.serialize(parsed))
    edited = reparsed.records.first.wire
    expect(edited.style_entries.snapshot).to eq([0, 0xFFFFFFFF, 7, 11])
    expect(edited.bitmap_info.to_s).to eq("INFOEDIT")
    expect(edited.bitmap_bits.to_s).to eq("BITS")
    expect(edited.trailing.to_s).to eq("TAIL")
    expect(reparsed.errors).to be_empty
  end

  it "retains alignment padding around unequal bitmap lengths in either order" do
    [false, true].each do |bits_first|
      record = extended_pen_record(info: "ABC", bits: "12345", bits_first: bits_first)
      parsed = Emf.parse(header + record + eof)
      wire = parsed.records.first.wire
      expect(wire.bitmap_info.to_s).to eq("ABC")
      expect(wire.bitmap_bits.to_s).to eq("12345")
      expect(wire.to_binary_s).to eq(record)
      expect(parsed.errors).to be_empty
    end
  end

  it "recovers malformed style counts and bitmap spans as Raw with diagnostics" do
    [[48, 0xFFFFFFFF], [12, 1], [16, 0xFFFFFFFF], [20, 68], [24, 0xFFFFFFFF]].each do |offset, value|
      record = extended_pen_record
      record[offset, 4] = [value].pack("V")
      input = header + record + unknown + eof
      parsed = Emf.parse(input)
      expect(parsed.records.first.wire).to be_a(Emf::Emr::Binary::Records::Raw)
      expect(parsed.records[1].wire.i_type.to_i).to eq(0xFFFF)
      expect(parsed.errors.length).to eq(1)
      expect(Emf.serialize(parsed)).to eq(input)
    end
  end

  it "checks snapshot counts, byte lengths, presence and alignment before constructing fields" do
    Emf::Native.backend
    payload = [1, 2, 3, 4, 5, 6].pack("V6") + [0].pack("Q<") + [0, 0, 0].pack("V3") + [0, 0, 0, 0].pack("Q<4")
    expect(Emf::Native::Fields.extended_pen(payload, "\0" * 52).last).to include(num_style_entries: 0, off_bmi: 0, off_bits: 0)
    [[24, [1_000_001].pack("Q<")], [32, [2].pack("V")], [36, [2].pack("V")],
     [40, [1].pack("V")], [44, [0xFFFFFFFFFFFFFFFF].pack("Q<")]].each do |offset, value|
      malformed = payload.dup
      malformed[offset, value.bytesize] = value
      expect { Emf::Native::Fields.extended_pen(malformed, "\0" * 52) }.to raise_error(Emf::FormatError)
    end
    expect { Emf::Native::Fields.extended_pen(payload, "") }.to raise_error(Emf::FormatError)
    expect { Emf::Native::Fields.extended_pen("#{payload}x", "\0" * 52) }.to raise_error(Emf::FormatError)
    malformed = payload.dup
    malformed[32, 4] = [1].pack("V")
    malformed[60, 8] = [1].pack("Q<")
    expect { Emf::Native::Fields.extended_pen("#{malformed}x", "\0" * 56) }.to raise_error(Emf::FormatError)
  end
end
