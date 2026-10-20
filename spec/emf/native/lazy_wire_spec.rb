# frozen_string_literal: true

require "spec_helper"
require "emf/native"
require "rbconfig"

RSpec.describe "Native lazy wire compatibility" do
  let(:library) do
    ENV.fetch("EMF_TEST_NATIVE_LIBRARY") do
      extension = RbConfig::CONFIG.fetch("host_os").include?("darwin") ? "dylib" : "so"
      File.expand_path("../../../emf-rs/target/debug/libemf_ffi.#{extension}", __dir__)
    end
  end
  let(:header) { Emf::Emr::Binary::Header.new(i_type: 1, n_size: 108, d_signature: 0x464D4520, n_version: 0x10000).to_binary_s }
  let(:eof) { [14, 20, 0, 0, 20].pack("V*") }
  let(:mode) { [17, 16, 8, 0x41424344].pack("V*") }
  let(:points) { [4, 44, 0, 0, 10, 10, 2, 1, 2, 3, 4].pack("V*") }
  let(:comment) { "#{[70, 20, 5].pack('V*')}EMF+xPAD" }
  let(:bytes) { "#{header}#{mode}#{points}#{comment}#{eof}tail" }

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

  it "constructs no BinData record until exposure, including comments and serialization" do
    [Emf::Emr::Binary::Records::SetMapMode, Emf::Emr::Binary::Records::Polyline,
     Emf::Emr::Binary::Records::Comment, Emf::Emr::Binary::Records::Eof].each do |klass|
      expect(klass).not_to receive(:new)
    end
    parsed = Emf.parse(bytes)
    expect(parsed.records.map(&:type_id)).to eq([17, 4, 70, 14])
    expect(parsed.format).to eq(:emf_plus)
    expect(parsed.emf_plus).to eq("xPAD")
    expect(Emf.serialize(parsed)).to eq(bytes)
  end

  it "caches actual wires, preserves nested edits, and supports retained records after GC" do
    record = Emf.parse(bytes).records.fetch(1)
    GC.start
    expect(record).to be_a(Emf::Model::Emr::Records::WireAdapter)
    wire = record.wire
    expect(wire).to be_a(Emf::Emr::Binary::Records::Polyline)
    expect(record.wire).to equal(wire)
    expect(wire.to_binary_s).to eq(points)
    wire.aptl[0].x = 19
    expect(record.wire.aptl[0].x.to_i).to eq(19)
    expect(record.wire.to_binary_s.byteslice(28, 4).unpack1("V")).to eq(19)
  end

  it "keeps visitor dispatch, value operations and manual adapters coherent" do
    parsed = Emf.parse(bytes)
    record = parsed.records.fetch(1)
    visitor = Emf::Model::Visitor.new
    expect(visitor).to receive(:visit_emr_wire_record).with(record)
    record.accept(visitor)
    manual = Emf::Model::Emr::Records::WireAdapter.new(wire: Emf::Emr::Binary::Records::Polyline.read(points), offset: 124)
    expect(record).to eq(manual)
    expect(record.hash).to eq(manual.hash)
    expect(record.inspect).to include("type_id=4 (Polyline)")
    record.wire.aptl[0].x = 19
    expect(record).not_to eq(manual)
    expect(record.hash).not_to eq(manual.hash)
    expect(Emf.serialize(parsed).byteslice(header.bytesize + mode.bytesize + 28, 4).unpack1("V")).to eq(19)
    record.wire.i_type = 3
    expect(record.type_id.to_i).to eq(3)
  end

  it "serializes mixed manual and lazy adapters using their current wires" do
    parsed = Emf.parse(bytes)
    manual = Emf::Model::Emr::Records::WireAdapter.new(wire: Emf::Emr::Binary::Records::Polyline.read(points))
    manual.wire.aptl[0].x = 23
    mixed = Emf::Model::Metafile.new(format: parsed.format, header: parsed.header,
                                     records: [parsed.records.first, manual, *parsed.records.drop(2)], trailing: parsed.trailing)
    expected = "#{header}#{mode}#{manual.wire.to_binary_s}#{comment}#{eof}tail"
    expect(Emf.serialize(mixed)).to eq(expected)
    # Exposure keeps the record's surplus bytes: the typed layout is 12 bytes of the declared 16.
    expect(parsed.records.first.wire.to_binary_s).to eq(mode.byteslice(0, 12))
    expect(Emf.serialize(mixed)).to eq(expected)
  end
end
