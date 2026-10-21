# frozen_string_literal: true

require "spec_helper"
require "emf/native"
require "rbconfig"

RSpec.describe "Native filled wires" do
  let(:library) do
    ENV.fetch("EMF_TEST_NATIVE_LIBRARY") do
      extension = RbConfig::CONFIG.fetch("host_os").include?("darwin") ? "dylib" : "so"
      File.expand_path("../../../emf-rs/target/debug/libemf_ffi.#{extension}", __dir__)
    end
  end
  let(:fixture) { File.binread(File.expand_path("../../fixtures/emf/test-000.emf", __dir__)) }
  let(:ruby_records) { Emf::Emr::Parser.call(fixture).records }
  let(:native_records) { Emf.parse(fixture).records }

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

  def filled?(record)
    record.instance_variable_get(:@wire_source).is_a?(Emf::Native::FilledWire)
  end

  it "reads most fixed-layout and point-array records from their bytes alone" do
    expect(native_records.count { |record| filled?(record) }).to be > native_records.size / 2
  end

  it "needs no BinData constructor to expose a filled record" do
    record = native_records.find { |candidate| filled?(candidate) }
    expect(record.wire.class).not_to receive(:new)
    expect(record.wire.to_binary_s).to eq(record.to_binary_s)
  end

  it "builds wires identical to the Ruby backend's, with the same suffix" do
    expect(native_records.size).to eq(ruby_records.size)
    native_records.zip(ruby_records).each do |native, ruby|
      expect(native.wire.class).to eq(ruby.wire.class)
      expect(native.wire.snapshot).to eq(ruby.wire.snapshot)
      expect(native.suffix).to eq(ruby.suffix)
      expect(native.to_binary_s).to eq(ruby.to_binary_s)
    end
  end

  it "serializes an edit after exposure exactly as the Ruby backend does" do
    index = native_records.index { |record| filled?(record) && record.wire.respond_to?(:ih_object) }
    expect(index).not_to be_nil
    [native_records, ruby_records].each { |records| records.fetch(index).wire.ih_object = 0x80000007 }
    expect(native_records.fetch(index).to_binary_s).to eq(ruby_records.fetch(index).to_binary_s)
    expect(native_records.fetch(index).to_binary_s.unpack1("V", offset: 8)).to eq(0x80000007)
  end

  it "keeps a point count that overruns its bytes on the recovered Raw path" do
    offset = 0
    offset += fixture.unpack1("V", offset: offset + 4) until fixture.unpack1("V", offset: offset) == 86
    bad = fixture.dup
    bad[offset + 24, 4] = [1000].pack("V")
    record = Emf.parse(bad).records.find { |candidate| candidate.offset == offset }
    expect(filled?(record)).to be(false)
    expect(record.wire).to be_a(Emf::Emr::Binary::Records::Raw)
  end
end
