# frozen_string_literal: true

require "spec_helper"
require "rbconfig"

RSpec.describe "EMR SmallTextOut semantic byte regions" do
  let(:type) { 108 }
  let(:klass) { Emf::Emr::Binary::Records::SmallTextOut }
  let(:header) do
    Emf::Emr::Binary::Header.new(i_type: 1, n_size: 108, d_signature: 0x464D4520).to_binary_s
  end
  let(:eof) { [14, 20, 0, 0, 20].pack("V5") }
  let(:following) { [17, 12, 7].pack("V3") }
  let(:trailing) { "tail\xA5".b }
  let(:bounds_bytes) { [-10, 20, 300, -400].pack("l<4") }
  let(:text8) { "\x00\x80\xFF".b }
  let(:text16) { "\x00\x00\x80\xFF\xFF\x7F".b }
  let(:suffix) { "sfx\x00\xFE".b }
  let(:flag_cases) { [0, 0x100, 0x200, 0x300] }
  let(:scales) { [1.0, -2.0].pack("e2") }
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

  it "exposes detached bounds and text bytes for all flag combinations" do
    flag_cases.each do |flags|
      has_bounds = flags.nobits?(0x100)
      text = flags.nobits?(0x200) ? text16 : text8
      body = (has_bounds ? bounds_bytes : "".b) + text + suffix
      record = [type, 36 + body.bytesize, -12, 25, 3, flags, 3].pack("V2l<2V3") + scales + body
      wire = klass.read(record)

      expect(wire.bounds).to eq(has_bounds ? bounds_bytes : nil)
      expect(wire.text_bytes).to eq(text)
      expect(wire.bounds).not_to equal(wire.bounds) if has_bounds
      expect(wire.text_bytes).not_to equal(wire.text_bytes)
      returned_text = wire.text_bytes
      returned_text.setbyte(0, 0x55)
      expect(wire.text_bytes).to eq(text)
      if has_bounds
        returned_bounds = wire.bounds
        returned_bounds.setbyte(0, 0x55)
        expect(wire.bounds).to eq(bounds_bytes)
      end
      expect(wire.to_binary_s).to eq(record)
    end
  end

  it "edits exact regions while preserving headers, flags, count, suffix, and siblings" do
    flag_cases.each do |flags|
      has_bounds = flags.nobits?(0x100)
      text = flags.nobits?(0x200) ? text16 : text8
      body = (has_bounds ? bounds_bytes : "".b) + text + suffix
      record = [type, 36 + body.bytesize, -12, 25, 3, flags, 3].pack("V2l<2V3") + scales + body
      input = header + record + following + eof + trailing
      parsed = Emf::Emr::Parser.call(input)
      wire = parsed.records.first.wire

      if has_bounds
        replacement_bounds = "\xA5".b * 16
        before = wire.to_binary_s
        wire.bounds = replacement_bounds
        expected = before.dup
        expected[36, 16] = replacement_bounds
        expect(wire.to_binary_s).to eq(expected)
      end

      replacement_text = "\xFE\x00".b * (text.bytesize / 2) if flags.nobits?(0x200)
      replacement_text = "\xFE\x00\x80".b if flags.anybits?(0x200)
      before = wire.to_binary_s
      wire.text_bytes = replacement_text
      expected = before.dup
      text_offset = has_bounds ? 52 : 36
      expected[text_offset, text.bytesize] = replacement_text
      expect(wire.to_binary_s).to eq(expected)
      expect(Emf::Emr::Serializer.call(parsed)).to eq(header + expected + following + eof + trailing)
    end
  end

  it "rejects invalid lengths and types without changing wire bytes" do
    flags = 0
    body = bounds_bytes + text16 + suffix
    record = [type, 36 + body.bytesize, -12, 25, 3, flags, 3].pack("V2l<2V3") + [1.0, -2.0].pack("e2") + body
    wire = klass.read(record)
    invalid_text_values = ["short".b, "longer!".b, 123]
    invalid_text_values.each do |value|
      before = wire.to_binary_s
      expect { wire.text_bytes = value }.to raise_error(ArgumentError)
      expect(wire.to_binary_s).to eq(before)
    end
    ["short".b, "longer!".b, 123].each do |value|
      before = wire.to_binary_s
      expect { wire.bounds = value }.to raise_error(ArgumentError)
      expect(wire.to_binary_s).to eq(before)
    end

    absent_body = text8 + suffix
    absent_record = [type, 36 + absent_body.bytesize, -12, 25, 3, 0x300, 3].pack("V2l<2V3") + [1.0, -2.0].pack("e2") + absent_body
    absent_wire = klass.read(absent_record)
    expect(absent_wire.bounds).to be_nil
    before = absent_wire.to_binary_s
    expect { absent_wire.bounds = "\x00".b * 16 }.to raise_error(ArgumentError)
    expect(absent_wire.to_binary_s).to eq(before)

    max_count_record = record.dup
    max_count_record[16, 4] = [0xFFFFFFFF].pack("V")
    max_count_wire = klass.read(max_count_record)
    before = max_count_wire.to_binary_s
    expect { max_count_wire.text_bytes }.to raise_error(ArgumentError)
    expect { max_count_wire.text_bytes = "".b }.to raise_error(ArgumentError)
    expect(max_count_wire.to_binary_s).to eq(before)
  end

  it "accepts an empty text value and preserves its suffix" do
    body = bounds_bytes + suffix
    record = [type, 36 + body.bytesize, -12, 25, 0, 0, 3].pack("V2l<2V3") + [1.0, -2.0].pack("e2") + body
    wire = klass.read(record)
    expect(wire.text_bytes).to eq("".b)

    before = wire.to_binary_s
    wire.text_bytes = "".b
    expect(wire.to_binary_s).to eq(before)
    expect(wire.text_bytes).to eq("".b)
  end

  it "reports truncated bounds and text without mutating or losing opaque bytes" do
    short_bodies = ["".b, "\x01".b * 15, bounds_bytes, bounds_bytes + text16.byteslice(0, 5)]
    short_bodies.each do |short_body|
      record = [type, 36 + short_body.bytesize, -12, 25, 3, 0, 3].pack("V2l<2V3") + scales + short_body
      wire = klass.read(record)
      before = wire.to_binary_s
      if short_body.bytesize < 16
        expect { wire.bounds }.to raise_error(ArgumentError)
        expect { wire.bounds = bounds_bytes }.to raise_error(ArgumentError)
      else
        expect(wire.bounds).to eq(bounds_bytes)
        expect(wire.bounds).not_to be_nil
      end
      expect { wire.text_bytes }.to raise_error(ArgumentError)
      expect { wire.text_bytes = text16 }.to raise_error(ArgumentError)
      expect(wire.to_binary_s).to eq(before)
    end
  end

  it "matches native byte-region access and edits when the native library is available" do
    skip "set EMF_TEST_NATIVE_LIBRARY to test native EMF" unless File.file?(library)

    flag_cases.each do |flags|
      has_bounds = flags.nobits?(0x100)
      text = flags.nobits?(0x200) ? text16 : text8
      body = (has_bounds ? bounds_bytes : "".b) + text + suffix
      record = [type, 36 + body.bytesize, -12, 25, 3, flags, 3].pack("V2l<2V3") + scales + body
      input = header + record + following + eof + trailing
      ENV["EMF_BACKEND"] = "ruby"
      ruby = Emf.parse(input)
      ENV["EMF_BACKEND"] = "native"
      native = Emf.parse(input)
      edited_text = text.dup
      edited_text.setbyte(0, edited_text.getbyte(0) ^ 0xFF)
      [ruby, native].each do |parsed|
        wire = parsed.records.first.wire
        expect(wire).to be_a(klass)
        expect(wire.bounds).to eq(has_bounds ? bounds_bytes : nil)
        expect(wire.text_bytes).to eq(text)
        wire.text_bytes = edited_text
      end
      expected_record = record.dup
      expected_record[(has_bounds ? 52 : 36), text.bytesize] = edited_text
      expected = header + expected_record + following + eof + trailing
      expect(Emf.serialize(native)).to eq(Emf.serialize(ruby))
      expect(Emf.serialize(native)).to eq(expected)
      reparsed = Emf.parse(expected)
      expect(reparsed.records.first.wire.text_bytes).to eq(edited_text)
      expect(Emf.serialize(reparsed)).to eq(expected)
    end

    ["".b, "\x01".b * 15, bounds_bytes].each do |short_body|
      record = [type, 36 + short_body.bytesize, -12, 25, 3, 0, 3].pack("V2l<2V3") + scales + short_body
      input = header + record + following + eof + trailing
      ENV["EMF_BACKEND"] = "ruby"
      ruby = Emf.parse(input)
      ENV["EMF_BACKEND"] = "native"
      native = Emf.parse(input)
      expect(native.records.first.wire.snapshot).to eq(ruby.records.first.wire.snapshot)
      [ruby, native].each do |parsed|
        wire = parsed.records.first.wire
        expect { wire.bounds }.to raise_error(ArgumentError) if short_body.bytesize < 16
        expect { wire.text_bytes }.to raise_error(ArgumentError)
      end
      expect(Emf.serialize(native)).to eq(input)
      expect(Emf.serialize(ruby)).to eq(input)
    end
  end
end
