# frozen_string_literal: true

require "spec_helper"
require "rbconfig"

RSpec.describe "EMR SetColorAdjustment semantic fields" do
  let(:type) { 23 }
  let(:klass) { Emf::Emr::Binary::Records.lookup(type) }
  let(:header) do
    Emf::Emr::Binary::Header.new(i_type: 1, n_size: 108, d_signature: 0x464D4520).to_binary_s
  end
  let(:eof) { [14, 20, 0, 0, 20].pack("V5") }
  let(:following) { [17, 12, 7].pack("V3") }
  let(:trailing) { "tail\xA5".b }
  let(:field_specs) do
    [
      [:adjustment_size, 0, 0x8001, 0, 0xFFFF, 0x1_0000],
      [:values, 2, 0xFFFF, 0, 0xFFFF, 0x1_0000],
      [:illuminant_index, 4, 0x8000, 0, 0xFFFF, 0x1_0000],
      [:red_gamma, 6, 0xFFFF, 0, 0xFFFF, 0x1_0000],
      [:green_gamma, 8, 0x8000, 0, 0xFFFF, 0x1_0000],
      [:blue_gamma, 10, 0xFFFF, 0, 0xFFFF, 0x1_0000],
      [:reference_black, 12, 0x8001, 0, 0xFFFF, 0x1_0000],
      [:reference_white, 14, 0xFFFF, 0, 0xFFFF, 0x1_0000],
      [:contrast, 16, -32_768, -32_768, 32_767, 32_768],
      [:brightness, 18, -1234, -32_768, 32_767, 32_768],
      [:colorfulness, 20, 0, -32_768, 32_767, 32_768],
      [:red_green_tint, 22, 32_767, -32_768, 32_767, 32_768]
    ]
  end
  let(:field_values) { field_specs.to_h { |field, _offset, value, _min, _max, _overflow| [field, value] } }
  let(:body) { field_specs.map { |_field, _offset, value, *_bounds| value & 0xFFFF }.pack("v*") + "opaque".b }
  let(:record) { [type, 8 + body.bytesize].pack("V2") + body }
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

  it "reads all twelve fields and edits only each field's two bytes" do
    wire = klass.read(record)

    field_values.each do |field, value|
      expect(wire.public_send(field).to_i).to eq(value)
    end
    expect(wire.body.to_s).to eq(body)
    expect(wire.snapshot).to eq(i_type: type, n_size: record.bytesize, body: body)
    expect(wire.to_binary_s).to eq(record)

    field_specs.each do |field, offset, _value, minimum, maximum, _overflow|
      before = wire.to_binary_s
      wire.public_send("#{field}=", minimum)
      expected = before.dup
      expected[8 + offset, 2] = [minimum & 0xFFFF].pack("v")
      expect(wire.to_binary_s).to eq(expected)
      expect(wire.public_send(field).to_i).to eq(minimum)

      before = wire.to_binary_s
      wire.public_send("#{field}=", maximum)
      expected = before.dup
      expected[8 + offset, 2] = [maximum & 0xFFFF].pack("v")
      expect(wire.to_binary_s).to eq(expected)
      expect(wire.public_send(field).to_i).to eq(maximum)
    end
  end

  it "rejects invalid values unchanged and requires all 24 body bytes" do
    wire = klass.read(record)
    field_specs.each do |field, _offset, _value, minimum, _maximum, overflow|
      before = wire.to_binary_s
      expect { wire.public_send("#{field}=", minimum - 1) }.to raise_error(RangeError)
      expect(wire.to_binary_s).to eq(before)

      before = wire.to_binary_s
      expect { wire.public_send("#{field}=", overflow) }.to raise_error(RangeError)
      expect(wire.to_binary_s).to eq(before)

      before = wire.to_binary_s
      expect { wire.public_send("#{field}=", "1") }.to raise_error(ArgumentError)
      expect(wire.to_binary_s).to eq(before)
    end

    short_bodies = ["".b, "\x01".b, "\x01".b * 23]
    short_bodies.each do |short_body|
      short_record = [type, 8 + short_body.bytesize].pack("V2") + short_body
      short_wire = klass.read(short_record)
      expect(short_wire.to_binary_s).to eq(short_record)
      expect(short_wire.snapshot).to eq(i_type: type, n_size: short_record.bytesize, body: short_body)
      field_values.each_key do |field|
        expect { short_wire.public_send(field) }.to raise_error(ArgumentError)
        expect { short_wire.public_send("#{field}=", 1) }.to raise_error(ArgumentError)
      end
      expect(short_wire.to_binary_s).to eq(short_record)
    end

    exact_record = [type, 32].pack("V2") + body.byteslice(0, 24)
    exact_wire = klass.read(exact_record)
    expect(exact_wire.red_green_tint.to_i).to eq(field_values.fetch(:red_green_tint))
    expect(exact_wire.to_binary_s).to eq(exact_record)
  end

  it "refreshes fields after body reassignment and preserves surrounding records" do
    input = header + record + following + eof + trailing
    parsed = Emf::Emr::Parser.call(input)
    wire = parsed.records.first.wire
    replacement_values = field_values.merge(contrast: 1234, red_green_tint: -32_768)
    replacement = field_specs.map { |field, _offset, *_rest| replacement_values.fetch(field) & 0xFFFF }.pack("v*") + "change".b
    wire.body = replacement
    expect(wire.contrast.to_i).to eq(1234)
    expect(wire.red_green_tint.to_i).to eq(-32_768)
    expected_record = [type, 8 + replacement.bytesize].pack("V2") + replacement
    expect(Emf::Emr::Serializer.call(parsed)).to eq(header + expected_record + following + eof + trailing)
    expect(parsed.records.drop(1).map(&:to_binary_s).join + parsed.trailing).to eq(following + eof + trailing)
  end

  it "matches native parsing and field edits when the native library is available" do
    skip "set EMF_TEST_NATIVE_LIBRARY to test native EMF" unless File.file?(library)

    inputs = [body, "".b, "\x01".b, "\x01".b * 23].map do |candidate_body|
      candidate_record = [type, 8 + candidate_body.bytesize].pack("V2") + candidate_body
      header + candidate_record + following + eof + trailing
    end
    inputs.each do |input|
      ENV["EMF_BACKEND"] = "ruby"
      ruby = Emf.parse(input)
      ENV["EMF_BACKEND"] = "native"
      native = Emf.parse(input)
      # Typed native decoding diagnoses a truncated known record while preserving
      # its body-backed public class and source bytes, like other recovered families.
      expect(native.errors.size).to eq(native.records.first.wire.body.to_s.bytesize < 24 ? 1 : 0)
      expect(native.records.first.wire.snapshot).to eq(ruby.records.first.wire.snapshot)
      expect(Emf.serialize(native)).to eq(input)
      next if native.records.first.wire.body.to_s.bytesize < 24

      [ruby, native].each do |parsed|
        wire = parsed.records.first.wire
        wire.red_green_tint = -32_768
      end
      expect(Emf.serialize(native)).to eq(Emf.serialize(ruby))
      expect(Emf.parse(Emf.serialize(native)).records.first.wire.red_green_tint.to_i).to eq(-32_768)
    end
  end
end
