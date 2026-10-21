# frozen_string_literal: true

require "spec_helper"
require "rbconfig"

RSpec.shared_examples "a color-space handle record" do
  let(:klass) { Emf::Emr::Binary::Records.lookup(type) }
  let(:header) do
    Emf::Emr::Binary::Header.new(i_type: 1, n_size: 108, d_signature: 0x464D4520).to_binary_s
  end
  let(:eof) { [14, 20, 0, 0, 20].pack("V5") }
  let(:following) { [17, 12, 7].pack("V3") }
  let(:trailing) { "tail\xA5".b }
  let(:field_values) { [0x80000000, 0xFFFFFFFF] }
  let(:body) { [field_values.first].pack("V") + "opaque\x00\x80\xFF".b }
  let(:record) { [type, 8 + body.bytesize].pack("V2") + body }
  let(:library) do
    ENV.fetch("EMF_TEST_NATIVE_LIBRARY") do
      extension = RbConfig::CONFIG.fetch("host_os").include?("darwin") ? "dylib" : "so"
      File.expand_path("../../../emf-rs/target/debug/libemf_ffi.#{extension}", __dir__)
    end
  end
  let(:invalid_values) { [-1, 0x1_0000_0000, "1"] }
  let(:short_bodies) { ["".b, "\x01".b, "\x01\x02\x03".b] }

  around do |example|
    previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
    ENV["EMF_NATIVE_LIBRARY"] = library
    example.run
  ensure
    %w[EMF_BACKEND EMF_NATIVE_LIBRARY].each { |key| ENV[key] = previous[key] }
  end

  it "reads unsigned handles and edits only the first four body bytes" do
    wire = klass.read(record)

    expect(wire.ih_cs.to_i).to eq(field_values.first)
    expect(wire.body.to_s).to eq(body)
    expect(wire.snapshot).to eq(i_type: type, n_size: record.bytesize, body: body)
    expect(wire.to_binary_s).to eq(record)

    before = wire.to_binary_s
    wire.ih_cs = field_values.last
    expected = before.dup
    expected[8, 4] = [field_values.last].pack("V")
    expect(wire.to_binary_s).to eq(expected)
    expect(wire.ih_cs.to_i).to eq(field_values.last)
    expect(wire.body.to_s.byteslice(4..)).to eq(body.byteslice(4..))

    exact_body = [field_values.last].pack("V")
    exact_record = [type, 12].pack("V2") + exact_body
    exact_wire = klass.read(exact_record)
    expect(exact_wire.ih_cs.to_i).to eq(field_values.last)
    expect(exact_wire.to_binary_s).to eq(exact_record)
  end

  it "rejects invalid setters without changing bytes and keeps short bodies opaque" do
    wire = klass.read(record)
    invalid_values.each do |value|
      before = wire.to_binary_s
      error = value.is_a?(String) ? ArgumentError : RangeError
      expect { wire.ih_cs = value }.to raise_error(error)
      expect(wire.to_binary_s).to eq(before)
    end

    short_bodies.each do |short_body|
      short_record = [type, 8 + short_body.bytesize].pack("V2") + short_body
      short_wire = klass.read(short_record)
      expect(short_wire.to_binary_s).to eq(short_record)
      expect(short_wire.snapshot).to eq(i_type: type, n_size: short_record.bytesize, body: short_body)
      expect { short_wire.ih_cs }.to raise_error(ArgumentError)
      expect { short_wire.ih_cs = 1 }.to raise_error(ArgumentError)
      expect(short_wire.to_binary_s).to eq(short_record)
    end
  end

  it "refreshes the handle after body reassignment and preserves neighboring records" do
    input = header + record + following + eof + trailing
    parsed = Emf::Emr::Parser.call(input)
    wire = parsed.records.first.wire
    expect(wire.snapshot).to eq(i_type: type, n_size: record.bytesize, body: body)
    expect(Emf::Emr::Serializer.call(parsed)).to eq(input)

    replacement = [field_values.last].pack("V") + "new-tail".b
    wire.body = replacement
    expect(wire.ih_cs.to_i).to eq(field_values.last)
    expected_record = [type, record.bytesize].pack("V2") + replacement
    expect(Emf::Emr::Serializer.call(parsed)).to eq(header + expected_record + following + eof + trailing)
    expect(parsed.records.drop(1).map(&:to_binary_s).join + parsed.trailing).to eq(following + eof + trailing)
  end

  it "matches native handle parsing, edits, and reparsing when available" do
    skip "set EMF_TEST_NATIVE_LIBRARY to test native EMF" unless File.file?(library)

    input = header + record + following + eof + trailing
    ENV["EMF_BACKEND"] = "ruby"
    ruby = Emf.parse(input)
    ENV["EMF_BACKEND"] = "native"
    native = Emf.parse(input)
    [ruby, native].each do |parsed|
      expect(parsed.errors).to be_empty
      expect(parsed.records.first.wire).to be_a(klass)
      expect(parsed.records.first.wire.ih_cs.to_i).to eq(field_values.first)
      expect(Emf.serialize(parsed)).to eq(input)
      parsed.records.first.wire.ih_cs = field_values.last
      expected_record = [type, record.bytesize].pack("V2") + [field_values.last].pack("V") + body.byteslice(4..)
      expected = header + expected_record + following + eof + trailing
      expect(Emf.serialize(parsed)).to eq(expected)
      reparsed = Emf.parse(expected)
      expect(reparsed.records.first.wire.ih_cs.to_i).to eq(field_values.last)
      expect(Emf.serialize(reparsed)).to eq(expected)
    end
  end
end

RSpec.describe "EMR color-space handle wire fields" do
  context "for SetColorspace" do
    let(:type) { 100 }

    it_behaves_like "a color-space handle record"
  end

  context "for DeleteColorspace" do
    let(:type) { 101 }

    it_behaves_like "a color-space handle record"
  end
end
