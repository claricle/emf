# frozen_string_literal: true

require "spec_helper"
require "rbconfig"

RSpec.describe "EMR_PIXELFORMAT semantic descriptor bytes" do
  let(:header) { Emf::Emr::Binary::Header.new(i_type: 1, n_size: 108, d_signature: 0x464D4520).to_binary_s }
  let(:following) { [17, 12, 7].pack("V3") + [14, 20, 0, 0, 20].pack("V5") + "tail\xFF".b }
  let(:suffix) { "suffix\x00\x80\xFF".b }
  let(:descriptor) do
    [40, 1, 0x89ABCDEF].pack("v2V") + (0..19).to_a.pack("C*") + [0x80000000, 0xFFFFFFFF, 0x01234567].pack("V3")
  end
  let(:body) { descriptor + suffix }
  let(:fields) do
    [[:pfd_size, 0, "v", 2, 0xFFFF], [:pfd_version, 2, "v", 2, 0xFFFF], [:dw_flags, 4, "V", 4, 0xFFFFFFFF],
     [:i_pixel_type, 8, "C", 1, 0xFF], [:c_color_bits, 9, "C", 1, 0xFF], [:c_red_bits, 10, "C", 1, 0xFF],
     [:c_red_shift, 11, "C", 1, 0xFF], [:c_green_bits, 12, "C", 1, 0xFF], [:c_green_shift, 13, "C", 1, 0xFF],
     [:c_blue_bits, 14, "C", 1, 0xFF], [:c_blue_shift, 15, "C", 1, 0xFF], [:c_alpha_bits, 16, "C", 1, 0xFF],
     [:c_alpha_shift, 17, "C", 1, 0xFF], [:c_accum_bits, 18, "C", 1, 0xFF], [:c_accum_red_bits, 19, "C", 1, 0xFF],
     [:c_accum_green_bits, 20, "C", 1, 0xFF], [:c_accum_blue_bits, 21, "C", 1, 0xFF], [:c_accum_alpha_bits, 22, "C", 1, 0xFF],
     [:c_depth_bits, 23, "C", 1, 0xFF], [:c_stencil_bits, 24, "C", 1, 0xFF], [:c_aux_buffers, 25, "C", 1, 0xFF],
     [:i_layer_type, 26, "C", 1, 0xFF], [:b_reserved, 27, "C", 1, 0xFF], [:dw_layer_mask, 28, "V", 4, 0xFFFFFFFF],
     [:dw_visible_mask, 32, "V", 4, 0xFFFFFFFF], [:dw_damage_mask, 36, "V", 4, 0xFFFFFFFF]]
  end
  let(:invalid_types) { [nil, "1"] }
  let(:invalid_descriptor_values) { [nil, "x" * 39, "x" * 41] }
  let(:record_bytes) { [104, body.bytesize + 8].pack("V2") + body }
  let(:klass) { Emf::Emr::Binary::Records::PixelFormat }
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

  it "reads every descriptor field from its documented little-endian offset" do
    wire = klass.read(record_bytes)
    fields.each do |name, offset, format, width, _maximum|
      expect(wire.public_send(name)).to eq(descriptor.byteslice(offset, width).unpack1(format))
    end
    expect(wire.pfd_bytes).to eq(descriptor)
    expect(wire.pfd_bytes.encoding).to eq(Encoding::BINARY)
    copy = wire.pfd_bytes
    copy.setbyte(0, 0)
    expect(wire.pfd_bytes).to eq(descriptor)
  end

  it "edits each scalar only at its exact wire span and preserves suffix and header" do
    fields.each do |name, offset, format, _width, maximum|
      wire = klass.read(record_bytes)
      expected = record_bytes.dup
      replacement = [maximum].pack(format)
      wire.public_send("#{name}=", maximum)
      expected[8 + offset, replacement.bytesize] = replacement
      expect(wire.to_binary_s).to eq(expected)
    end

    wire = klass.read(record_bytes)
    replacement = "\xA5".b * 40
    wire.pfd_bytes = replacement
    expect(wire.to_binary_s).to eq([104, record_bytes.bytesize].pack("V2") + replacement + suffix)
  end

  it "rejects invalid scalar and descriptor writes without changing any bytes" do
    fields.each do |name, _offset, _format, _width, maximum|
      wire = klass.read(record_bytes)
      invalid_types.each do |value|
        expect { wire.public_send("#{name}=", value) }.to raise_error(ArgumentError)
        expect(wire.to_binary_s).to eq(record_bytes)
      end
      [maximum + 1, -1].each do |value|
        expect { wire.public_send("#{name}=", value) }.to raise_error(RangeError)
        expect(wire.to_binary_s).to eq(record_bytes)
      end
    end

    invalid_descriptor_values.each do |value|
      wire = klass.read(record_bytes)
      expect { wire.pfd_bytes = value }.to raise_error(ArgumentError)
      expect(wire.to_binary_s).to eq(record_bytes)
    end
  end

  it "requires the full descriptor while retaining short opaque bodies and observing reassignment" do
    [0, 39].each do |length|
      short_body = "s".b * length
      short_record = [104, short_body.bytesize + 8].pack("V2") + short_body
      wire = klass.read(short_record)
      fields.each do |name, _offset, _format, _width, maximum|
        expect { wire.public_send(name) }.to raise_error(ArgumentError)
        expect { wire.public_send("#{name}=", maximum) }.to raise_error(ArgumentError)
      end
      expect { wire.pfd_bytes }.to raise_error(ArgumentError)
      expect { wire.pfd_bytes = descriptor }.to raise_error(ArgumentError)
      expect(wire.to_binary_s).to eq(short_record)
    end

    wire = klass.read(record_bytes)
    replacement = descriptor.dup
    replacement[0, 2] = [0xFEDC].pack("v")
    wire.body = replacement + suffix
    expect(wire.pfd_size).to eq(0xFEDC)
    expect(wire.pfd_bytes).to eq(replacement)
  end

  it "preserves Ruby and native parse, snapshot, edit and reparse parity" do
    skip "set EMF_TEST_NATIVE_LIBRARY to test native EMF" unless File.file?(library)

    input = header + record_bytes + following
    expected_record = record_bytes.dup
    expected_record[8 + 4, 4] = [0xFFFFFFFF].pack("V")
    %w[ruby native].each do |backend|
      ENV["EMF_BACKEND"] = backend
      parsed = Emf.parse(input)
      expect(parsed.errors).to be_empty
      expect(parsed.records.first.wire).to be_a(klass)
      wire = parsed.records.first.wire
      expect(wire.snapshot).to eq(i_type: 104, n_size: record_bytes.bytesize, body: body)
      expect(Emf.serialize(parsed)).to eq(input)
      wire.dw_flags = 0xFFFFFFFF
      output = Emf.serialize(parsed)
      expect(output).to eq(header + expected_record + following)
      reparsed = Emf.parse(output)
      expect(reparsed.records.first.wire.dw_flags).to eq(0xFFFFFFFF)
      expect(Emf.serialize(reparsed)).to eq(output)
    end
  end
end
