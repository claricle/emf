# frozen_string_literal: true

require "spec_helper"
require "emf/native"
require "rbconfig"

RSpec.describe "native small text hydration" do
  let(:library) do
    ENV.fetch("EMF_TEST_NATIVE_LIBRARY") do
      extension = RbConfig::CONFIG.fetch("host_os").include?("darwin") ? "dylib" : "so"
      File.expand_path("../../../emf-rs/target/debug/libemf_ffi.#{extension}", __dir__)
    end
  end
  let(:header) { Emf::Emr::Binary::Header.new(i_type: 1, n_size: 108, d_signature: 0x464D4520).to_binary_s }
  let(:float_bits) { [0x7FC01234, 0x80000000].pack("V2") }
  let(:body) { "\x91\x00opaque\xFF".b }
  let(:small_text) do
    prefix = [108, 36 + body.bytesize, -12, 25, 3, 0x12, 1].pack("V2l<2V3") + float_bits
    prefix + body
  end
  let(:following) { [17, 12, 7].pack("V3") }
  let(:eof) { [14, 20, 0, 0, 20].pack("V*") }

  around do |example|
    previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
    ENV["EMF_BACKEND"] = "native"
    ENV["EMF_NATIVE_LIBRARY"] = library
    example.run
  ensure
    %w[EMF_BACKEND EMF_NATIVE_LIBRARY].each { |key| ENV[key] = previous[key] }
  end

  before { skip "build emf-ffi or set EMF_TEST_NATIVE_LIBRARY" unless File.file?(library) }

  it "hydrates, mutates, and reserializes while retaining opaque body, float bits, and following records" do
    input = header + small_text + following + eof
    parsed = Emf.parse(input)
    wire = parsed.records.first.wire

    expect(wire).to be_a(Emf::Emr::Binary::Records::SmallTextOut)
    expect(wire.body.to_s).to eq(body)
    expect(Emf.serialize(parsed)).to eq(input)

    wire.x_dest = 99
    expected = small_text.dup
    expected[8, 4] = [99].pack("l<")
    expect(Emf.serialize(parsed)).to eq(header + expected + following + eof)
    expect(parsed.records[1].wire.to_binary_s).to eq(following)
  end

  it "leaves a short type 108 record raw and preserves opaque typed records" do
    short = [108, 16].pack("V2") + "short!!!".b
    parsed = Emf.parse(header + short + eof)
    expect(parsed.records.first.wire).to be_a(Emf::Emr::Binary::Records::Raw)
    expect(Emf.serialize(parsed)).to eq(header + short + eof)

    opaque = [96, 12].pack("V2") + "RAWW".b
    parsed = Emf.parse(header + opaque + eof)
    expect(parsed.records.first.wire).to be_a(Emf::Emr::Binary::Records::PolyTextOutA)
    expect(parsed.records.first.wire.to_binary_s).to eq(opaque)
    expect(Emf.serialize(parsed)).to eq(header + opaque + eof)
  end
end
