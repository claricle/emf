# frozen_string_literal: true

require "spec_helper"
require "rbconfig"
require_relative "../../support/region_records"

RSpec.describe "native region hydration" do
  include RegionRecords

  let(:library) do
    ENV.fetch("EMF_TEST_NATIVE_LIBRARY") do
      extension = RbConfig::CONFIG.fetch("host_os").include?("darwin") ? "dylib" : "so"
      File.expand_path("../../../emf-rs/target/debug/libemf_ffi.#{extension}", __dir__)
    end
  end
  let(:region_offsets) { { 71 => 32, 72 => 40, 73 => 28, 74 => 28, 75 => 16 } }
  let(:malformed_offsets) { [0, 8, 12] }
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

  before { skip "build emf-ffi or set EMF_TEST_NATIVE_LIBRARY" unless File.file?(library) }

  it "hydrates all five semantic classes directly and preserves nested and outer opaque bytes" do
    expect(Emf::Emr::Parser).not_to receive(:call)
    (71..75).each do |type|
      klass = Emf::Emr::Binary::Records.lookup(type)
      expect(klass).not_to receive(:read)
      record = region_record(type)
      parsed = Emf.parse("#{header}#{record}#{unknown}#{eof}tail")
      wire = parsed.records.first.wire
      expect(wire).to be_a(klass)
      expect(wire.rgn_data.region_type.to_i).to eq(0xFFFFFFFF)
      expect(wire.rgn_data.bounds.snapshot).to eq(left: -9, top: 10, right: 11, bottom: -12)
      expect(wire.rgn_data.rectangles.first.snapshot).to eq(left: -0x80000000, top: 2, right: 0x7FFFFFFF, bottom: -4)
      expect(wire.rgn_data.trailing.to_s).to eq("IN!!")
      expect(wire.body.to_s).to eq("OUT!")
      expect(wire.ih_brush.to_i).to eq(0x80000001) if (71..72).cover?(type)
      expect(wire.szl_stroke.snapshot).to eq(cx: -13, cy: 14) if type == 72
      expect(wire.dw_mode.to_i).to eq(0xFFFFFFFF) if type == 75
      expect(wire.to_binary_s).to eq(record)
      expect(Emf.serialize(parsed)).to eq("#{header}#{record}#{unknown}#{eof}tail")
      expect(parsed.errors).to be_empty
      wire.rgn_data.rectangles.first.left = -123
      edited = record.dup
      fixed = region_offsets.fetch(type)
      edited[fixed + 32, 4] = Array(-123).pack("l<")
      expect(wire.to_binary_s).to eq(edited)
      expect(Emf.parse(Emf.serialize(parsed)).records.first.wire.rgn_data.rectangles.first.left.to_i).to eq(-123)
    end
  end

  it "preserves empty regions and default clipping reset with suffixes" do
    (71..75).each do |type|
      record = region_record(type, rectangles: [], extra: "", suffix: "PAD!")
      parsed = Emf.parse(header + record + eof)
      expect(parsed.records.first.wire.rgn_data.rectangles).to be_empty
      expect(parsed.records.first.wire.to_binary_s).to eq(record)
    end
    reset = "#{[75, 20, 0, 5].pack('V4')}PAD!"
    parsed = Emf.parse(header + reset + unknown + eof)
    expect(parsed.records.first.wire).to be_a(Emf::Emr::Binary::Records::ExtSelectClipRgn)
    expect(parsed.records.first.wire.cb_rgn_data.to_i).to eq(0)
    expect(parsed.records.first.wire.body.to_s).to eq("PAD!")
    expect(Emf.serialize(parsed)).to eq(header + reset + unknown + eof)
  end

  it "rejects malformed snapshot lengths, counts, presence and record spans" do
    Emf::Native.backend
    data = [1, 0, 0, 0, 0].pack("V5") + [0, 0].pack("Q<2")
    expect(Emf::Native::Fields.region_data(data)).to include(header_size: 32, count_rects: 0, rectangles: [], trailing: "")
    expect { Emf::Native::Fields.region_data("#{data}extra") }.to raise_error(Emf::FormatError)
    excessive = data.dup
    excessive[20, 8] = [1_000_001].pack("Q<")
    expect { Emf::Native::Fields.region_data(excessive) }.to raise_error(Emf::FormatError)
    expect { Emf::Native::Fields.region([5, 2].pack("V2"), 80, "") }.to raise_error(Emf::FormatError)
    expect { Emf::Native::Fields.region([4, 0].pack("V2"), 80, "\0" * 16) }.to raise_error(Emf::FormatError)
    expect { Emf::Native::Fields.region([5, 0].pack("V2"), 80, "") }.to raise_error(Emf::FormatError)
    expect { Emf::Native::Fields.region([5, 1].pack("V2") + data, 80, "\0" * 16) }.to raise_error(Emf::FormatError)
  end

  it "recovers malformed region headers and truncated arrays as raw while retaining following records" do
    (71..75).each do |type|
      fixed = region_offsets.fetch(type)
      malformed_offsets.each do |offset|
        record = region_record(type)
        record[fixed + offset, 4] = Array(0xFFFFFFFF).pack("V")
        parsed = Emf.parse(header + record + unknown + eof)
        expect(parsed.records.first.wire).to be_a(Emf::Emr::Binary::Records::Raw)
        expect(parsed.records[1].wire.i_type.to_i).to eq(0xFFFF)
        expect(parsed.errors.length).to eq(1)
        expect(Emf.serialize(parsed)).to eq(header + record + unknown + eof)
      end
    end
  end
end
