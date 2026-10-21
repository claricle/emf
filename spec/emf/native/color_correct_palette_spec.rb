# frozen_string_literal: true

require "spec_helper"
require "rbconfig"

RSpec.describe "EMR ColorCorrectPalette wire layout" do
  let(:header) do
    Emf::Emr::Binary::Header.new(i_type: 1, n_size: 108, d_signature: 0x464D4520).to_binary_s
  end
  let(:eof) { [14, 20, 0, 0, 20].pack("V5") }
  let(:following) { [0xFFFF, 12].pack("V2") + "NEXT".b }
  let(:field_values) { [0x80000001, 0xFEDCBA98, 0xFFFFFFFF, 0xFFFFFFFF] }
  let(:body) { field_values.pack("V4") + "TAIL\xA5".b }
  let(:record) { [111, 24 + body.bytesize - 16].pack("V2") + body }
  let(:library) do
    ENV.fetch("EMF_TEST_NATIVE_LIBRARY") do
      extension = RbConfig::CONFIG.fetch("host_os").include?("darwin") ? "dylib" : "so"
      File.expand_path("../../../emf-rs/target/debug/libemf_ffi.#{extension}", __dir__)
    end
  end

  around do |example|
    previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
    ENV["EMF_NATIVE_LIBRARY"] = library
    example.run
  ensure
    %w[EMF_BACKEND EMF_NATIVE_LIBRARY].each { |key| ENV[key] = previous[key] }
  end

  it "exposes the four unsigned fields and edits only their own bytes" do
    wire = Emf::Emr::Binary::Records::ColorCorrectPalette.read(record)

    expect([wire.ih_palette.to_i, wire.first_entry.to_i, wire.entry_count.to_i, wire.reserved.to_i]).to eq(field_values)
    expect(wire.body.to_s).to eq(body)
    expect(wire.to_binary_s).to eq(record)

    [[0, :ih_palette, 0x12345678], [4, :first_entry, 0x80000000],
     [8, :entry_count, 0x7FFFFFFF], [12, :reserved, 0x12345678]].each do |offset, field, value|
      expected = wire.to_binary_s
      wire.public_send("#{field}=", value)
      expected[8 + offset, 4] = [value].pack("V")
      expect(wire.to_binary_s).to eq(expected)
    end
  end

  it "validates values and requires a complete body before semantic access or edits" do
    wire = Emf::Emr::Binary::Records::ColorCorrectPalette.read(record)
    invalid_values = [-1, 0x1_0000_0000, "1"]
    fields = %i[ih_palette first_entry entry_count reserved]
    fields.each do |field|
      invalid_values.each do |value|
        before = wire.to_binary_s
        error = value.is_a?(String) ? ArgumentError : RangeError
        expect { wire.public_send("#{field}=", value) }.to raise_error(error)
        expect(wire.to_binary_s).to eq(before)
      end
    end

    ["".b, "\x01\x02\x03".b, "\x01".b * 15].each do |short_body|
      short_record = [111, 8 + short_body.bytesize].pack("V2") + short_body
      short_wire = Emf::Emr::Binary::Records::ColorCorrectPalette.read(short_record)
      expect(short_wire.body.to_s).to eq(short_body)
      expect(short_wire.to_binary_s).to eq(short_record)
      fields.each do |field|
        expect { short_wire.public_send(field) }.to raise_error(ArgumentError)
        expect { short_wire.public_send("#{field}=", 1) }.to raise_error(ArgumentError)
        expect(short_wire.to_binary_s).to eq(short_record)
      end
    end

    complete_body = [1, 2, 3, 4].pack("V4")
    complete_record = [111, 24].pack("V2") + complete_body
    complete_wire = Emf::Emr::Binary::Records::ColorCorrectPalette.read(complete_record)
    expect([complete_wire.ih_palette.to_i, complete_wire.first_entry.to_i,
            complete_wire.entry_count.to_i, complete_wire.reserved.to_i]).to eq([1, 2, 3, 4])
    expect(complete_wire.to_binary_s).to eq(complete_record)
  end

  it "refreshes semantic fields after body reassignment and preserves following records" do
    input = header + record + following + eof
    parsed = Emf::Emr::Parser.call(input)
    wire = parsed.records.first.wire
    expect(parsed.records[1].wire.to_binary_s).to eq(following)
    expect(Emf::Emr::Serializer.call(parsed)).to eq(input)

    replacement = [1, 2, 3, 4].pack("V4") + "NEW!!".b
    wire.body = replacement
    expect([wire.ih_palette.to_i, wire.first_entry.to_i, wire.entry_count.to_i, wire.reserved.to_i]).to eq([1, 2, 3, 4])
    expected_record = [111, record.byteslice(4, 4).unpack1("V")].pack("V2") + replacement
    expect(Emf::Emr::Serializer.call(parsed)).to eq(header + expected_record + following + eof)

    short_input = header + [111, 11].pack("V2") + "xyz".b + following + eof
    short_parsed = Emf::Emr::Parser.call(short_input)
    expect(short_parsed.records.first.wire.body.to_s).to eq("xyz".b)
    expect(Emf::Emr::Serializer.call(short_parsed)).to eq(short_input)
  end

  it "matches native parsing and field edits when the native library is available" do
    skip "set EMF_TEST_NATIVE_LIBRARY to test native EMF" unless File.file?(library)

    input = header + record + following + eof
    ENV["EMF_BACKEND"] = "ruby"
    ruby = Emf.parse(input)
    ENV["EMF_BACKEND"] = "native"
    native = Emf.parse(input)
    edited_record = record.dup
    edited_record[12, 4] = [0x80000000].pack("V")
    [ruby, native].each do |parsed|
      wire = parsed.records.first.wire
      expect(parsed.errors).to be_empty
      expect(wire).to be_a(Emf::Emr::Binary::Records::ColorCorrectPalette)
      expect([wire.ih_palette.to_i, wire.first_entry.to_i, wire.entry_count.to_i, wire.reserved.to_i]).to eq(field_values)
      expect(Emf.serialize(parsed)).to eq(input)
      wire.first_entry = 0x80000000
      expect(Emf.serialize(parsed)).to eq(header + edited_record + following + eof)
    end
  end
end
