# frozen_string_literal: true

require "spec_helper"
require "rbconfig"
require "open3"
require "base64"

RSpec.describe Emf::Native do
  let(:library) do
    ENV.fetch("EMF_TEST_NATIVE_LIBRARY") do
      extension = RbConfig::CONFIG.fetch("host_os").include?("darwin") ? "dylib" : "so"
      File.expand_path("../../../emf-rs/target/debug/libemf_ffi.#{extension}", __dir__)
    end
  end
  let(:header) do
    Emf::Emr::Binary::Header.new(
      i_type: 1, n_size: 108, d_signature: 0x464D4520, n_version: 0x10000,
      rcl_bounds: { left: -5, top: 2, right: 40, bottom: 60 },
      szl_device: { cx: 800, cy: 600 }, szl_micrometers: { cx: 20, cy: 30 }
    ).to_binary_s
  end
  let(:eof) { [14, 20, 0, 0, 20].pack("V*") }
  let(:map_mode) { [17, 12, 8].pack("V*") }
  let(:polyline) { [4, 44].pack("V2") + [-5, 2, 40, 60].pack("l<4") + [2].pack("V") + [-1, 4, 9, -2].pack("l<4") }
  let(:comment) { "#{[70, 20, 5].pack('V3')}EMF+xPAD" }
  let(:unknown) { "#{[0xFFFF, 12].pack('V2')}raw!" }
  let(:bytes) { "#{header}#{map_mode}#{polyline}#{comment}#{unknown}#{eof}tail" }

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

  it "hydrates native fields without invoking Ruby wire readers and preserves editable models" do
    expect(Emf::Emr::Parser).not_to receive(:call)
    [Emf::Emr::Binary::Header, Emf::Emr::Binary::Records::SetMapMode,
     Emf::Emr::Binary::Records::Polyline, Emf::Emr::Binary::Records::Comment,
     Emf::Emr::Binary::Records::Raw, Emf::Emr::Binary::Records::Eof].each do |klass|
      expect(klass).not_to receive(:read)
    end
    parsed = Emf.parse(bytes)
    expect(parsed.header.bounds.left).to eq(-5)
    expect(parsed.header.szl_micrometers.cy).to eq(30)
    expect(parsed.records.map(&:offset)).to eq([108, 120, 164, 184, 196])
    expect(parsed.records[1].wire.aptl.map { |point| [point.x.to_i, point.y.to_i] }).to eq([[-1, 4], [9, -2]])
    expect(parsed.format).to eq(:emf_plus)
    expect(parsed.emf_plus).to eq("xPAD")
    expect(parsed.errors).to be_empty
    expect(Emf.serialize(parsed)).to eq(bytes)
    parsed.records.first.wire.map_mode = 7
    expect(Emf.serialize(parsed).byteslice(116, 4).unpack1("V")).to eq(7)
  end

  it "matches Ruby canonical models after every wire is traversed" do
    native = Emf.parse(bytes)
    ENV["EMF_BACKEND"] = "ruby"
    ruby = Emf.parse(bytes)
    expect(native.header.to_wire.to_binary_s).to eq(ruby.header.to_wire.to_binary_s)
    expect(native.records.map { |record| record.wire.snapshot }).to eq(ruby.records.map { |record| record.wire.snapshot })
    expect(native.records).to eq(ruby.records)
    expect(native.emf_plus).to eq(ruby.emf_plus)
    expect(native.trailing).to eq(ruby.trailing)
  end

  it "loads and parses through the public API in a fresh native process" do
    script = <<~SCRIPT
      require "emf"
      require "base64"
      bytes = Base64.strict_decode64(ARGV.fetch(0))
      parsed = Emf.parse(bytes)
      abort "wrong native result" unless parsed.records.size == 5 && Emf.serialize(parsed) == bytes
      puts parsed.format
    SCRIPT
    stdout, stderr, status = Open3.capture3(
      { "EMF_BACKEND" => "native", "EMF_NATIVE_LIBRARY" => library },
      RbConfig.ruby, "-Ilib", "-e", script, Base64.strict_encode64(bytes)
    )
    expect(status.success?).to be(true), stderr
    expect(stdout.strip).to eq("emf_plus")
  end

  it "keeps malformed short EOF raw and continues framing" do
    short = [14, 8].pack("V2")
    parsed = Emf.parse(header + short + map_mode + eof)
    expect(parsed.records.map { |record| record.wire.class }).to eq(
      [Emf::Emr::Binary::Records::Raw, Emf::Emr::Binary::Records::SetMapMode, Emf::Emr::Binary::Records::Eof]
    )
    expect(parsed.errors.first.record_code).to eq(14)
  end

  it "rejects an ABI mismatch during setup" do
    described_class.backend
    allow_any_instance_of(Emf::Native::Loader).to receive(:invoke).with(:emf_abi_version).and_return(9)
    expect { described_class.backend }.to raise_error(Emf::Native::Unavailable, /ABI version mismatch/)
  end

  it "treats missing ABI symbols as setup unavailability" do
    described_class.backend
    handle = double("library")
    allow(handle).to receive(:[]).and_raise(Fiddle::DLError, "missing symbol")
    allow(Fiddle).to receive(:dlopen).with(library).and_return(handle)
    expect { described_class.backend }.to raise_error(Emf::Native::Unavailable, /missing symbol/)
  end

  it "bounds checks and validates the snapshot transport" do
    backend = described_class.backend
    loader = backend.instance_variable_get(:@loader)
    snapshot = loader.document(header + eof) { |document| loader.snapshot(document) }
    expect { Emf::Native::Snapshot.new(snapshot.byteslice(0, 20)) }.to raise_error(Emf::FormatError)
    snapshot[4, 4] = [9].pack("V")
    expect { Emf::Native::Snapshot.new(snapshot) }.to raise_error(Emf::FormatError, /schema/)
  end

  it "copies input spans without per-record C buffers and frees the native document before returning the model" do
    backend = described_class.backend
    loader = backend.instance_variable_get(:@loader)
    calls = []
    allow(loader).to receive(:invoke).and_wrap_original do |original, name, *arguments|
      calls << name
      original.call(name, *arguments)
    end
    input = bytes.dup.force_encoding(Encoding::UTF_8)
    parsed = backend.parse(input)
    input.replace("changed after parsing")
    expect(calls.count(:emf_document_free)).to eq(1)
    expect(calls.count(:emf_record_bytes)).to eq(0)
    expect(calls.count(:emf_buffer_free)).to eq(1)
    GC.start
    expect(backend.serialize(parsed)).to eq(bytes)
  end

  it "rejects snapshot record spans outside the input and frees the native document" do
    backend = described_class.backend
    loader = backend.instance_variable_get(:@loader)
    allow(loader).to receive(:invoke).and_call_original
    [[-1, 12], [108, -1], [108, 7], [bytes.bytesize, 12], [108, bytes.bytesize]].each do |offset, length|
      allow(Emf::Native::Snapshot).to receive(:new).and_wrap_original do |original, transport|
        snapshot = original.call(transport)
        snapshot.records.first.merge!(offset: offset, length: length)
        snapshot
      end
      expect(loader).to receive(:invoke).with(:emf_document_free, anything).and_call_original
      expect { backend.parse(bytes) }.to raise_error(Emf::FormatError, /record span/)
    end
  end

  it "frees the native document when an unsupported typed family raises" do
    backend = described_class.backend
    loader = backend.instance_variable_get(:@loader)
    allow(loader).to receive(:invoke).and_call_original
    expect(loader).to receive(:invoke).with(:emf_document_free, anything).and_call_original
    expect(Emf::Emr::Parser).not_to receive(:call)
    expect { backend.parse(header + [18, 12, 1].pack("V3") + eof) }
      .to raise_error(Emf::FormatError, /does not support typed EMR record 18/)
  end

  it "preserves malformed supported records as Raw with native diagnostics and unframed bytes" do
    malformed = [4, 28].pack("V2") + [0, 0, 1, 1, 20].pack("V5")
    parsed = Emf.parse("#{header}#{malformed}abc")
    expect(parsed.records.first.wire).to be_a(Emf::Emr::Binary::Records::Raw)
    expect(parsed.errors.map(&:offset)).to eq([108, 136])
    expect(parsed.errors.first.record_code).to eq(4)
    expect(parsed.trailing).to eq("abc")
    expect(Emf.serialize(parsed)).to eq("#{header}#{malformed}abc")
  end

  it "propagates native parse errors without Ruby retry and frees the error handle" do
    backend = described_class.backend
    loader = backend.instance_variable_get(:@loader)
    allow(loader).to receive(:invoke).and_call_original
    expect(loader).to receive(:invoke).with(:emf_error_free, anything).and_call_original
    expect(Emf::Emr::Parser).not_to receive(:call)
    expect { backend.parse("broken") }.to raise_error(Emf::FormatError)
  end

  it "rejects extended EOF honestly rather than changing its palette layout" do
    expect { Emf.parse(header + [14, 24, 1, 16, 0, 24].pack("V6")) }
      .to raise_error(Emf::FormatError, /extended or paletted EOF/)
  end

  it "falls back only when loading fails during selection" do
    ENV["EMF_NATIVE_LIBRARY"] = "/missing/emf-native-library"
    ENV["EMF_BACKEND"] = "auto"
    expect(Emf.parse(header + eof).records.last.type_id).to eq(14)
    ENV["EMF_BACKEND"] = "native"
    expect { Emf.parse(header + eof) }.to raise_error(Emf::Native::Unavailable, /could not load/)
  end
end
