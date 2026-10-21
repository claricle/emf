# frozen_string_literal: true

require "spec_helper"
require "rbconfig"
require "emf/native/gradient_fields"

RSpec.describe "native gradient hydration" do
  let(:library) do
    ENV.fetch("EMF_TEST_NATIVE_LIBRARY") do
      extension = RbConfig::CONFIG.fetch("host_os").include?("darwin") ? "dylib" : "so"
      File.expand_path("../../../emf-rs/target/debug/libemf_ffi.#{extension}", __dir__)
    end
  end
  let(:header) { Emf::Emr::Binary::Header.new(i_type: 1, n_size: 108, d_signature: 0x464D4520).to_binary_s }
  let(:eof) { [14, 20, 0, 0, 20].pack("V*") }
  let(:unknown) { "#{[0xFFFF, 12].pack('V2')}RAW!" }
  let(:edited_vertex) { [-999].pack("l<") }
  let(:edited_bound) { [-123].pack("l<") }
  let(:vertices) { [-15, 2, 0xABCD1234, 0xFFFF8000].pack("l<2V2") * 3 }

  around do |example|
    previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
    ENV["EMF_BACKEND"] = "native"
    ENV["EMF_NATIVE_LIBRARY"] = library
    example.run
  ensure
    %w[EMF_BACKEND EMF_NATIVE_LIBRARY].each { |key| ENV[key] = previous[key] }
  end

  before { skip "build emf-ffi or set EMF_TEST_NATIVE_LIBRARY" unless File.file?(library) }

  (0..2).each do |mode|
    it "hydrates mode #{mode} directly with Ruby parity, editable bounds and mesh bytes" do
      mesh = [0, 1, mode == 2 ? 2 : 0xDEADBEEF].pack("V3")
      record = "#{[118, 100, -10, 20, 30, 40, 3, 1, mode].pack('V2l<4V3')}#{vertices}#{mesh}TAIL"
      klass = Emf::Emr::Binary::Records::GradientFill
      expected = klass.read(record).snapshot
      expect(klass).not_to receive(:read)
      expect(Emf::Emr::Parser).not_to receive(:call)
      input = "#{header}#{record}#{unknown}#{eof}tail"
      parsed = Emf.parse(input)
      wire = parsed.records.first.wire
      expect(wire).to be_a(klass)
      expect(wire.snapshot).to eq(expected)
      expect(Emf.serialize(parsed)).to eq(input)
      wire.rcl_bounds.left = -123
      wire.body = wire.body.to_s.dup.tap { |body| body[0, 4] = edited_vertex }
      edited = record.dup
      edited[8, 4] = edited_bound
      edited[36, 4] = edited_vertex
      expect(Emf.serialize(parsed)).to eq("#{header}#{edited}#{unknown}#{eof}tail")
    end
  end

  it "keeps malformed gradients with Ruby parity and continues through EOF" do
    record = "#{[118, 40, 0, 0, 0, 0, 0, 0, 3].pack('V*')}TAIL"
    parsed, ruby = parse_both(header + record + eof)
    expect(parsed.records.first.wire.class).to eq(ruby.records.first.wire.class)
    expect(parsed.errors.length).to eq(ruby.errors.length)
    expect(parsed.records.last.wire).to be_a(Emf::Emr::Binary::Records::Eof)
    expect(Emf.serialize(parsed)).to eq(header + record + eof)
  end

  it "rejects impossible transport counts before constructing the Ruby body" do
    payload = [0, 0, 0, 0, 2].pack("V*") + [0xFFFFFFFFFFFFFFFF, 1].pack("Q<2")
    expect { Emf::Native::GradientFields.call(payload, "".b) }.to raise_error(Emf::FormatError)
  end

  def parse_both(input)
    native = Emf.parse(input)
    ENV["EMF_BACKEND"] = "ruby"
    ruby = Emf.parse(input)
    [native, ruby]
  ensure
    ENV["EMF_BACKEND"] = "native"
  end
end
