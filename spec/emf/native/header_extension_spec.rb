# frozen_string_literal: true

require "spec_helper"
require "rbconfig"

RSpec.describe "EMF extended header preservation" do
  let(:following) { [17, 12, 7].pack("V3") }
  let(:eof) { [14, 20, 0, 0, 20].pack("V5") }
  let(:extension_payload) { "GAPFDGAP!A\x00B\x00END".b }
  let(:backends) { %w[ruby native] }
  let(:headers) do
    [
      [88, 0, 0x12345678, 0x76543210, "".b],
      [100, 0, 0x12345678, 0x76543210, "".b],
      [108, 0, 0x12345678, 0x76543210, "".b],
      [124, 3, 117, 110, extension_payload]
    ].to_h do |size, pixel_size, description_offset, pixel_offset, trailing|
      wire = Emf::Emr::Binary::Header.new(
        i_type: 1, n_size: size, d_signature: 0x464D4520, n_version: 0x10000,
        n_bytes: size + following.bytesize + eof.bytesize, n_records: 2,
        n_description: size == 124 ? 2 : 0, off_description: description_offset,
        cb_pixel_format: pixel_size, off_pixel_format: pixel_offset,
        b_open_gl: 0xA5A5A5A5, trailing: trailing
      ).to_binary_s
      [size, wire]
    end
  end
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

  it "round-trips 88-, 100-, 108- and extended-size header layouts with opaque spans" do
    headers.each do |size, header|
      input = header + following + eof + "TRAIL\xFF".b
      backends.each do |backend|
        ENV["EMF_BACKEND"] = backend
        parsed = Emf.parse(input)
        expected_pixel_offset = if size == 124
                                  110
                                elsif size > 88
                                  0x76543210
                                else
                                  0
                                end
        expect(parsed.errors).to be_empty
        expect(parsed.header.n_size).to eq(size)
        expect(parsed.header.n_description).to eq(size == 124 ? 2 : 0)
        expect(parsed.header.off_description).to eq(size == 124 ? 117 : 0x12345678)
        expect(parsed.header.cb_pixel_format).to eq(size == 124 ? 3 : 0)
        expect(parsed.header.off_pixel_format).to eq(expected_pixel_offset)
        expect(Emf.serialize(parsed)).to eq(input)
        expect(parsed.records.first.wire.to_binary_s).to eq(following)
        expect(parsed.trailing).to eq("TRAIL\xFF".b)
      end
    end
  end

  it "edits a following record while preserving the complete extended header" do
    header = headers.fetch(124)
    input = header + following + eof + "TRAIL\xFF".b
    expected_following = [17, 12, 9].pack("V3")

    backends.each do |backend|
      ENV["EMF_BACKEND"] = backend
      parsed = Emf.parse(input)
      expect(parsed.errors).to be_empty
      parsed.records.first.wire.map_mode = 9
      output = Emf.serialize(parsed)
      expect(output).to eq(header + expected_following + eof + "TRAIL\xFF".b)
      reparsed = Emf.parse(output)
      expect(reparsed.header.n_size).to eq(124)
      expect(reparsed.header.off_description).to eq(117)
      expect(reparsed.header.off_pixel_format).to eq(110)
      expect(reparsed.records.first.wire.map_mode).to eq(9)
      expect(Emf.serialize(reparsed)).to eq(output)
    end
  end
end
