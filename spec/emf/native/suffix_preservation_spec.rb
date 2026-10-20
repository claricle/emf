# frozen_string_literal: true

require "spec_helper"
require "emf/native"
require "rbconfig"

RSpec.describe "Native typed record suffix preservation" do
  let(:library) do
    ENV.fetch("EMF_TEST_NATIVE_LIBRARY") do
      extension = RbConfig::CONFIG.fetch("host_os").include?("darwin") ? "dylib" : "so"
      File.expand_path("../../../emf-rs/target/debug/libemf_ffi.#{extension}", __dir__)
    end
  end
  let(:header) { Emf::Emr::Binary::Header.new(i_type: 1, n_size: 108, d_signature: 0x464D4520, n_version: 0x10000).to_binary_s }
  let(:eof) { [14, 20, 0, 0, 20].pack("V*") }
  let(:unknown) { "#{[0xFFFF, 12].pack('V2')}raw!" }
  let(:suffix) { "opaque\x00\xFF".b }
  let(:siblings) { "#{unknown}#{eof}tail" }

  around do |example|
    previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
    ENV["EMF_BACKEND"] = "native"
    ENV["EMF_NATIVE_LIBRARY"] = library
    example.run
  ensure
    %w[EMF_BACKEND EMF_NATIVE_LIBRARY].each { |key| ENV[key] = previous[key] }
  end

  before do
    skip "build emf-ffi or set EMF_TEST_NATIVE_LIBRARY" unless File.file?(library)
  end

  [
    [24, [0xDBFF8000], :color, { red: 19, green: 128, blue: 255, reserved: 219 }, 8],
    [22, [0xFFFFFFFF], :text_align_mode, 19, 8],
    [54, [1, 2], :origin, { x: 19, y: 2 }, 8],
    [4, [1, 2, 3, 4, 2, 5, 6, 7, 8], :rcl_bounds, { left: 19, top: 2, right: 3, bottom: 4 }, 8],
    [7, [1, 2, 3, 4, 1, 2, 2, 5, 6, 7, 8], :rcl_bounds, { left: 19, top: 2, right: 3, bottom: 4 }, 8],
    [56, [1, 2, 3, 4, 2, 5, 6, 7, 8], :rcl_bounds, { left: 19, top: 2, right: 3, bottom: 4 }, 8],
    [16, [0xFFFFFFFF], :flags, 19, 8],
    [31, [1, 2, 3, 4], :x_num, 19, 8],
    [36, [0x3FC00000, 0xC0000000, 0, 0x80000000, 0x42F68000, 0xC0900000, 0xFFFFFFFF], :modify_mode, 19, 32],
    [43, [1, 2, 3, 4], :rcl_box, { left: 19, top: 2, right: 3, bottom: 4 }, 8]
  ].each do |type, words, field, edited, offset|
    it "preserves type #{type} bytes after exposure and typed edits" do
      payload = words.pack("V*")
      payload += "\x80\xFF".b if type == 56
      record = [type, 8 + payload.bytesize + suffix.bytesize].pack("V2") + payload + suffix
      input = header + record + siblings
      parsed = Emf.parse(input)
      expect(parsed.errors).to be_empty
      expect(Emf.serialize(parsed)).to eq(input)
      wire = parsed.records.first.wire
      expect(wire).not_to be_a(Emf::Emr::Binary::Records::Raw)
      expect(parsed.records.first.to_binary_s).to eq(record)
      expect(Emf.serialize(parsed)).to eq(input)
      wire.public_send("#{field}=", edited)
      expected_record = record.dup
      expected_record[offset, 4] = "\x13\x00\x00\x00".b
      expected = header + expected_record + siblings
      expect(parsed.records.first.to_binary_s).to eq(expected_record)
      expect(Emf.serialize(parsed)).to eq(expected)
      reparsed = Emf.parse(expected)
      expect(reparsed.errors).to be_empty
      expect(reparsed.records.first.wire.public_send(field).snapshot).to eq(edited)
      expect(Emf.serialize(reparsed)).to eq(expected)
    end
  end

  it "retains the suffix and updates framing when a point array grows" do
    payload = [1, 2, 3, 4, 1, 5, 6].pack("V*")
    record = [4, 8 + payload.bytesize + suffix.bytesize].pack("V2") + payload + suffix
    parsed = Emf.parse(header + record + siblings)
    wire = parsed.records.first.wire
    wire.cptl = 2
    wire.aptl = [{ x: 5, y: 6 }, { x: 19, y: 20 }]
    expected_record = [4, record.bytesize + 8, 1, 2, 3, 4, 2, 5, 6, 19, 20].pack("V*") + suffix
    expected = header + expected_record + siblings
    expect(parsed.records.first.to_binary_s).to eq(expected_record)
    expect(parsed.records.first.to_binary_s.byteslice(4, 4).unpack1("V")).to eq(expected_record.bytesize)
    expect(Emf.serialize(parsed)).to eq(expected)
    reparsed = Emf.parse(expected)
    expect(reparsed.errors).to be_empty
    expect(reparsed.records.map(&:type_id)).to eq([4, 0xFFFF, 14])
    expect(reparsed.records.first.wire.aptl.snapshot).to eq([{ x: 5, y: 6 }, { x: 19, y: 20 }])
    expect(Emf.serialize(reparsed)).to eq(expected)
  end
end
