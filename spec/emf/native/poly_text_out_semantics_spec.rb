# frozen_string_literal: true

require "spec_helper"
require "rbconfig"

RSpec.describe "EMR PolyTextOut semantic byte regions" do
  let(:header) do
    Emf::Emr::Binary::Header.new(i_type: 1, n_size: 108, d_signature: 0x464D4520).to_binary_s
  end
  let(:following) { [17, 12, 7].pack("V3") }
  let(:eof) { [14, 20, 0, 0, 20].pack("V5") }
  let(:trailing) { "tail\xA5".b }
  let(:bounds) { [-10, 20, 300, -400].pack("l<4") }
  let(:record_bounds) { [-1, 2, 30, 40].pack("l<4") }
  let(:text_values) { ["A\x00\xFF".b, "".b] }
  let(:dx_fixture) { [3, 0x80000000, 7].pack("V3") }
  let(:replacement_dx) { [9, 10, 11].pack("V3") }
  let(:invalid_indices) { [-1, 2, 0xFFFFFFFF] }
  let(:invalid_pointer) { [0xFFFFFFFF].pack("V") }
  let(:dx_values) { [[3, 0x80000000, 7].pack("V3"), nil] }
  let(:library) do
    ENV.fetch("EMF_TEST_NATIVE_LIBRARY") do
      extension = RbConfig::CONFIG.fetch("host_os").include?("darwin") ? "dylib" : "so"
      File.expand_path("../../../emf-rs/target/debug/libemf_ffi.#{extension}", __dir__)
    end
  end
  let(:fixtures) do
    variants = [
      [:a_rect, 96, true, text_values], [:w_rect, 97, true, ["\x00\x00\x3D\xD8\x00\xDE".b, "".b]],
      [:a_plain, 96, false, text_values], [:w_plain, 97, false, ["\x00\x00\x3D\xD8\x00\xDE".b, "".b]],
      [:a_replacement, 96, true, ["new".b, "".b]], [:w_replacement, 97, true, ["\xFE\xFF\x01\x00\x02\x00".b, "".b]]
    ]
    variants.to_h do |key, type, with_rect, texts|
      width = type == 96 ? 1 : 2
      dx = [dx_fixture, nil]
      count = 2
      rect_flags = with_rect ? [0, 0x100] : [0x100, 0x100]
      descriptor_sizes = rect_flags.map { |flag| flag.anybits?(0x100) ? 24 : 40 }
      table_end = 32 + descriptor_sizes.sum
      payload = "GAP!".b
      strings = []
      dx_offsets = []
      texts.each_with_index do |text, index|
        payload << "s" if index.positive?
        strings << (text.empty? ? 0 : 8 + 32 + descriptor_sizes.sum + payload.bytesize)
        payload << text
        if dx[index]
          payload << "d" while (8 + 32 + descriptor_sizes.sum + payload.bytesize) % 4 != 0
          dx_offsets << (8 + 32 + descriptor_sizes.sum + payload.bytesize)
          payload << dx[index]
        else
          dx_offsets << 0
        end
      end
      descriptors = texts.each_with_index.map do |text, index|
        flag = rect_flags[index]
        entry_bounds = flag.nobits?(0x100) ? bounds : "".b
        reference = [index - 4, 12 + index].pack("l<2")
        chars = text.bytesize / width
        off_string = strings[index].zero? ? 0 : strings[index]
        [reference, [chars, off_string, flag].pack("V3"), entry_bounds, [dx_offsets[index]].pack("V")].join
      end.join
      fixed = record_bounds + [2, 1.25, -0.5, count].pack("VeeV")
      [key, [type, fixed + descriptors + payload, texts, dx, table_end]]
    end
  end

  around do |example|
    previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
    ENV["EMF_NATIVE_LIBRARY"] = library
    example.run
  ensure
    %w[EMF_BACKEND EMF_NATIVE_LIBRARY].each { |key| ENV[key] = previous[key] }
  end

  it "reads mixed entries as detached binary strings for A and W" do
    [[96, Emf::Emr::Binary::Records::PolyTextOutA], [97, Emf::Emr::Binary::Records::PolyTextOutW]].each do |type, klass|
      _fixture_type, body, texts, dx, = fixtures.fetch(type == 96 ? :a_rect : :w_rect)
      wire = klass.read([type, 8 + body.bytesize].pack("V2") + body)

      expect(wire.c_strings.to_i).to eq(2)
      expect(wire.bounds).to eq(record_bounds)
      expect(wire.bounds).not_to equal(wire.bounds)
      texts.each_with_index do |text, index|
        expect(wire.text_bytes(index)).to eq(text)
        expect(wire.text_bytes(index)).not_to equal(wire.text_bytes(index))
        expect(wire.entry_bounds(index)).to eq(index.zero? ? bounds : nil)
        expect(wire.dx_bytes(index)).to eq(dx[index])
      end
      expect(wire.to_binary_s).to eq([type, 8 + body.bytesize].pack("V2") + body)
    end
  end

  it "edits only requested spans and preserves suffix, siblings and trailing bytes" do
    [[96, Emf::Emr::Binary::Records::PolyTextOutA], [97, Emf::Emr::Binary::Records::PolyTextOutW]].each do |type, _klass|
      _fixture_type, body, texts, dx, = fixtures.fetch(type == 96 ? :a_rect : :w_rect)
      record = [type, 8 + body.bytesize].pack("V2") + body
      input = header + record + following + eof + trailing
      parsed = Emf::Emr::Parser.call(input)
      wire = parsed.records.first.wire
      width = type == 96 ? 1 : 2
      replacement_text = width == 1 ? "Z\x00\x80".b : "\xFE\xFF\x00\x00\xFF\x7F".b
      text_offset = wire.to_binary_s.index(texts.first)
      before = wire.to_binary_s
      wire.set_text_bytes(0, replacement_text)
      expected_record = before.dup
      expected_record[text_offset, texts.first.bytesize] = replacement_text
      expect(wire.to_binary_s).to eq(expected_record)

      dx_offset = expected_record.index(dx.first)
      wire.set_dx_bytes(0, replacement_dx)
      expected_record[dx_offset, dx.first.bytesize] = replacement_dx
      replacement_bounds = "\xA5".b * 16
      bounds_offset = 8 + 32 + 20
      wire.set_entry_bounds(0, replacement_bounds)
      expected_record[bounds_offset, 16] = replacement_bounds
      expect(Emf::Emr::Serializer.call(parsed)).to eq(header + expected_record + following + eof + trailing)
      reparsed = Emf::Emr::Parser.call(header + expected_record + following + eof + trailing)
      expect(reparsed.records.first.wire.text_bytes(0)).to eq(replacement_text)
      expect(parsed.records[1].wire.to_binary_s).to eq(following)
    end
  end

  it "handles empty text, absent spacing, and rejects malformed spans without mutation" do
    [[96, Emf::Emr::Binary::Records::PolyTextOutA], [97, Emf::Emr::Binary::Records::PolyTextOutW]].each do |type, klass|
      _fixture_type, body, texts, = fixtures.fetch(type == 96 ? :a_plain : :w_plain)
      wire = klass.read([type, 8 + body.bytesize].pack("V2") + body)
      expect(wire.text_bytes(1)).to eq("".b)
      expect(wire.dx_bytes(1)).to be_nil
      expect { wire.set_dx_bytes(1, "".b) }.to raise_error(ArgumentError)
      expect { wire.set_entry_bounds(1, "\x00".b * 16) }.to raise_error(ArgumentError)

      ["x".b * (texts.first.bytesize + 1), 123].each do |value|
        before = wire.to_binary_s
        expect { wire.set_text_bytes(0, value) }.to raise_error(ArgumentError)
        expect(wire.to_binary_s).to eq(before)
      end
      invalid_indices.each do |index|
        expect { wire.text_bytes(index) }.to raise_error(ArgumentError)
      end

      malformed = body.dup
      malformed[44, 4] = invalid_pointer
      malformed_wire = klass.read([type, 8 + malformed.bytesize].pack("V2") + malformed)
      before = malformed_wire.to_binary_s
      expect { malformed_wire.text_bytes(0) }.to raise_error(ArgumentError)
      expect(malformed_wire.to_binary_s).to eq(before)
    end
  end

  it "preserves malformed short bodies as raw records and body reassignment refreshes reads" do
    [96, 97].each do |type|
      ["".b, "x".b * 31].each do |short_body|
        input = header + [type, 8 + short_body.bytesize].pack("V2") + short_body + eof
        parsed = Emf::Emr::Parser.call(input)
        klass = type == 96 ? Emf::Emr::Binary::Records::PolyTextOutA : Emf::Emr::Binary::Records::PolyTextOutW
        expect(parsed.records.first.wire.class).to eq(klass)
        before = parsed.records.first.wire.to_binary_s
        expect { parsed.records.first.wire.text_bytes(0) }.to raise_error(ArgumentError)
        expect(parsed.records.first.wire.to_binary_s).to eq(before)
        expect(Emf::Emr::Serializer.call(parsed)).to eq(input)
      end
      klass = type == 96 ? Emf::Emr::Binary::Records::PolyTextOutA : Emf::Emr::Binary::Records::PolyTextOutW
      _fixture_type, body, texts, = fixtures.fetch(type == 96 ? :a_plain : :w_plain)
      wire = klass.read([type, 8 + body.bytesize].pack("V2") + body)
      replacement_key = type == 96 ? :a_replacement : :w_replacement
      _fixture_type, replacement_body, replacement_texts, = fixtures.fetch(replacement_key)
      wire.body = replacement_body
      expect(wire.text_bytes(0)).to eq(replacement_texts.first)
      expect(wire.text_bytes(0)).not_to eq(texts.first)
    end
  end

  it "matches actual native parsing and edit/reparse behavior" do
    skip "build emf-ffi or set EMF_TEST_NATIVE_LIBRARY" unless File.file?(library)
    [[96, Emf::Emr::Binary::Records::PolyTextOutA], [97, Emf::Emr::Binary::Records::PolyTextOutW]].each do |type, klass|
      _fixture_type, body, texts, = fixtures.fetch(type == 96 ? :a_rect : :w_rect)
      input = header + [type, 8 + body.bytesize].pack("V2") + body + following + eof + trailing
      ENV["EMF_BACKEND"] = "ruby"
      ruby = Emf.parse(input)
      ENV["EMF_BACKEND"] = "native"
      native = Emf.parse(input)
      expect(native.records).to eq(ruby.records)
      expect(Emf.serialize(native)).to eq(input)
      wire = native.records.first.wire
      expect(wire).to be_a(klass)
      expect(wire.text_bytes(0)).to eq(texts.first)
      replacement = "\x80\x00".b * (texts.first.bytesize / 2) if type == 97
      replacement = "\x80\x00\xFE".b if type == 96
      wire.set_text_bytes(0, replacement)
      output = Emf.serialize(native)
      ENV["EMF_BACKEND"] = "ruby"
      reparsed = Emf.parse(output)
      expect(reparsed.records.first.wire.text_bytes(0)).to eq(replacement)
      expect(reparsed.records[1].wire.to_binary_s).to eq(following)
      expect(output.end_with?(trailing)).to be(true)
    end
  end
end
