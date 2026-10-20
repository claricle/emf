# frozen_string_literal: true

require "spec_helper"
require "rbconfig"
require "emf/native/fields"
require "emf/native/font_fields"

RSpec.describe "native font hydration" do
  let(:library) do
    ENV.fetch("EMF_TEST_NATIVE_LIBRARY") do
      extension = RbConfig::CONFIG.fetch("host_os").include?("darwin") ? "dylib" : "so"
      File.expand_path("../../../emf-rs/target/debug/libemf_ffi.#{extension}", __dir__)
    end
  end
  let(:header) { Emf::Emr::Binary::Header.new(i_type: 1, n_size: 108, d_signature: 0x464D4520).to_binary_s }
  let(:eof) { [14, 20, 0, 0, 20].pack("V*") }
  let(:unknown) { "#{[0xFFFF, 12].pack('V2')}RAW!" }
  let(:fonts) do
    logical = [-0x80000000, 7, -3, 4, 900].pack("l<5") + (1..8).to_a.pack("C8") +
              [0xD800, 0, 0xFFFF, *Array.new(29, 0)].pack("v32")
    panose = [logical, Array.new(96, 0xFFFF).pack("v*"), [1, 2, 3, 4].pack("V4"),
              "ABCD", [0xFFFFFFFF].pack("V"), (1..12).to_a.pack("C*")].join
    extended = "#{logical}#{Array.new(128, 0xDFFF).pack('v*')}#{[0x08007664, 2].pack('V2')}#{[-0x80000000, 0x7FFFFFFF].pack('l<2')}TAIL"
    [logical, panose.byteslice(0, 96), panose, extended].map { |body| [82, body.bytesize + 12, 0x80000001].pack("V3") + body }
  end

  around do |example|
    previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
    ENV["EMF_BACKEND"] = "native"
    ENV["EMF_NATIVE_LIBRARY"] = library
    example.run
  ensure
    %w[EMF_BACKEND EMF_NATIVE_LIBRARY].each { |key| ENV[key] = previous[key] }
  end

  before { skip "build emf-ffi or set EMF_TEST_NATIVE_LIBRARY" unless File.file?(library) }

  it "hydrates editable semantic variants without Ruby readers and preserves every other byte" do
    expect(Emf::Emr::Parser).not_to receive(:call)
    expect(Emf::Emr::Binary::Records::CreateFontIndirectW).not_to receive(:read)
    edited_height = [-123].pack("l<")
    fonts.each do |record|
      input = "#{header}#{record}#{unknown}#{eof}tail"
      parsed = Emf.parse(input)
      wire = parsed.records.first.wire
      expect(wire).to be_a(Emf::Emr::Binary::Records::CreateFontIndirectW)
      logical = wire.elw.respond_to?(:log_font) ? wire.elw.log_font : wire.elw
      expect(logical.height.to_i).to eq(-0x80000000)
      expect(logical.facename.snapshot.first(3)).to eq([0xD800, 0, 0xFFFF])
      expect(wire.ih_object.to_i).to eq(0x80000001)
      expect(parsed.errors).to be_empty
      expect(Emf.serialize(parsed)).to eq(input)
      logical.height = -123
      expected_record = record.dup
      expected_record[12, 4] = edited_height
      expect(Emf.serialize(parsed)).to eq("#{header}#{expected_record}#{unknown}#{eof}tail")
    end
  end

  it "edits Panose and design-vector fields while preserving names, padding and suffixes" do
    [[fonts[2], 320, "\x09".b], [fonts[3], 368, [42].pack("l<")]].each do |record, offset, bytes|
      parsed = Emf.parse(header + record + eof)
      font = parsed.records.first.wire.elw
      if font.is_a?(Emf::Emr::Binary::LogFontPanose)
        expect(font.vendor_id.snapshot).to eq("ABCD".bytes)
        expect(font.padding.snapshot).to eq([11, 12])
        font.panose.family_type = 9
      else
        expect(font.design_vector.axis_values.snapshot).to eq([-0x80000000, 0x7FFFFFFF])
        expect(font.trailing.snapshot).to eq("TAIL")
        font.design_vector.axis_values[0] = 42
      end
      expected = record.dup
      expected[offset, bytes.bytesize] = bytes
      expect(Emf.serialize(parsed)).to eq(header + expected + eof)
    end
  end

  it "agrees with Ruby parsing and continues after malformed fonts" do
    records = fonts + [[82, 16, 1, 0].pack("V4")]
    records.each do |record|
      input = header + record + unknown + eof
      native = Emf.parse(input)
      ENV["EMF_BACKEND"] = "ruby"
      ruby = Emf.parse(input)
      ENV["EMF_BACKEND"] = "native"
      expect(native.records.map { |entry| entry.wire.snapshot }).to eq(ruby.records.map { |entry| entry.wire.snapshot })
      expect(Emf.serialize(native)).to eq(Emf.serialize(ruby))
      expect(native.records.last.wire.i_type.to_i).to eq(14)
    end
  end

  it "rejects inconsistent font snapshot variants, lengths, omitted fields and excessive axes" do
    raw = fonts.first
    payload = [0x80000001, 0, 92].pack("V2Q<") + raw.byteslice(12..)
    invalid = [payload.byteslice(0...-1), "#{payload}x", payload.dup, payload.dup]
    invalid[2][4, 4] = [3].pack("V")
    invalid[3][8, 8] = [91].pack("Q<")
    invalid.each { |bytes| expect { Emf::Native::FontFields.new(bytes, raw).call }.to raise_error(Emf::FormatError) }
    partial = [1, 1, 96].pack("V2Q<") + fonts[2].byteslice(12..)
    expect { Emf::Native::FontFields.new(partial, fonts[1]).call }.to raise_error(Emf::FormatError, /partial/)
    extended = [1, 2, 364].pack("V2Q<") + fonts.last.byteslice(12, 364)
    extended[16 + 352, 4] = [17].pack("V")
    expect { Emf::Native::FontFields.new(extended, fonts.last).call }.to raise_error(Emf::FormatError, /design vector/)
  end
end
