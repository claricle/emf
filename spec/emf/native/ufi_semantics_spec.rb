# frozen_string_literal: true

require "spec_helper"
require "rbconfig"

RSpec.describe "EMR UFI semantic fields" do
  let(:header) { Emf::Emr::Binary::Header.new(i_type: 1, n_size: 108, d_signature: 0x464D4520).to_binary_s }
  let(:following) { [17, 12, 7].pack("V3") }
  let(:eof) { [14, 20, 0, 0, 20].pack("V5") }
  let(:tail) { "tail\xFF".b }
  let(:suffix) { "suffix\xFE".b }
  let(:reserved) { "reserved".b }
  let(:first_ufi) { [0x80000001, 0xFFFFFFFF].pack("V2") }
  let(:second_ufi) { [0x12345678, 0x87654321].pack("V2") }
  let(:scalar_names) { %i[ufi_checksum ufi_index] }
  let(:invalid_values) { [nil, "1", 1.0] }
  let(:bounds) { [0, 0xFFFFFFFF] }
  let(:backends) { %w[ruby native] }
  let(:cases) do
    [
      [109, Emf::Emr::Binary::Records::ForceUfiMapping, first_ufi + suffix, 0],
      [119, Emf::Emr::Binary::Records::SetLinkedUfis, [2].pack("V") + first_ufi + second_ufi + reserved + suffix, 4]
    ].map do |type, klass, body, offset|
      record = [type, body.bytesize + 8].pack("V2") + body
      { type: type, klass: klass, body: body, offset: offset, record: record,
        input: header + record + following + eof + tail }
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

  it "reads unsigned fields and detached UFI bytes from current body storage" do
    cases.each do |entry|
      wire = entry[:klass].read(entry[:record])
      args = entry[:type] == 119 ? [0] : []
      expect(wire.ufi_checksum(*args)).to eq(0x80000001)
      expect(wire.ufi_index(*args)).to eq(0xFFFFFFFF)
      returned = wire.ufi_bytes(*args)
      expect(returned).to eq(first_ufi)
      expect(returned.encoding).to eq(Encoding::BINARY)
      returned.setbyte(0, 0)
      expect(wire.to_binary_s).to eq(entry[:record])
      replacement = entry[:body].dup
      replacement[entry[:offset], 8] = second_ufi
      wire.body = replacement
      expect(wire.ufi_bytes(*args)).to eq(second_ufi)
      next unless entry[:type] == 119

      expect(wire.u_num_linked_ufi).to eq(2)
      expect(wire).not_to respond_to(:u_num_linked_ufi=)
      expect(wire.ufi_bytes(1)).to eq(second_ufi)
    end
  end

  it "writes exact scalar bounds and rejects invalid values atomically" do
    out_of_range = [-1, 0x100000000]
    cases.each do |entry|
      scalar_names.each_with_index do |name, field|
        wire = entry[:klass].read(entry[:record])
        setter = entry[:type] == 119 ? "set_#{name}" : "#{name}="
        args = entry[:type] == 119 ? [1] : []
        offset = entry[:offset] + (field * 4) + (args.empty? ? 0 : 8)
        bounds.each do |value|
          wire.public_send(setter, *args, value)
          expected = entry[:record].dup
          expected[8 + offset, 4] = [value].pack("V")
          expect(wire.to_binary_s).to eq(expected)
        end
        before = wire.to_binary_s
        invalid_values.each do |value|
          expect { wire.public_send(setter, *args, value) }.to raise_error(ArgumentError)
          expect(wire.to_binary_s).to eq(before)
        end
        out_of_range.each do |value|
          expect { wire.public_send(setter, *args, value) }.to raise_error(RangeError)
          expect(wire.to_binary_s).to eq(before)
        end
      end
    end
  end

  it "replaces one UFI while preserving headers, sibling entries, reserved bytes and suffixes" do
    invalid_bytes = [nil, 1, "", "x" * 7, "x" * 9]
    cases.each do |entry|
      wire = entry[:klass].read(entry[:record])
      setter = entry[:type] == 119 ? :set_ufi_bytes : :ufi_bytes=
      args = entry[:type] == 119 ? [0] : []
      wire.public_send(setter, *args, second_ufi)
      expected = entry[:record].dup
      expected[8 + entry[:offset], 8] = second_ufi
      expect(wire.to_binary_s).to eq(expected)
      expect(wire.snapshot).to eq(i_type: entry[:type], n_size: entry[:record].bytesize, body: expected.byteslice(8..))
      invalid_bytes.each do |value|
        expect { wire.public_send(setter, *args, value) }.to raise_error(ArgumentError)
        expect(wire.to_binary_s).to eq(expected)
      end
    end
  end

  it "rejects invalid linked indices across typed and raw access without changing bytes" do
    entry = cases.last
    wire = entry[:klass].read(entry[:record])
    [nil, "0", 0.0, -1, 2, 0xFFFFFFFF].each do |index|
      scalar_names.each do |name|
        expect { wire.public_send(name, index) }.to raise_error(ArgumentError)
        expect { wire.public_send("set_#{name}", index, 0) }.to raise_error(ArgumentError)
      end
      expect { wire.ufi_bytes(index) }.to raise_error(ArgumentError)
      expect { wire.set_ufi_bytes(index, first_ufi) }.to raise_error(ArgumentError)
      expect(wire.to_binary_s).to eq(entry[:record])
    end
  end

  it "preserves zero counts and requires the complete array and ignored reserved bytes" do
    entry = cases.last
    body = [0].pack("V") + reserved + suffix
    record = [119, body.bytesize + 8].pack("V2") + body
    wire = entry[:klass].read(record)
    expect(wire.u_num_linked_ufi).to eq(0)
    expect { wire.ufi_bytes(0) }.to raise_error(ArgumentError)
    expect(wire.to_binary_s).to eq(record)
    bodies = [[1].pack("V") + first_ufi, [2].pack("V") + first_ufi + reserved,
              [0xFFFFFFFF].pack("V") + reserved]
    bodies.each do |short_body|
      short_record = [119, short_body.bytesize + 8].pack("V2") + short_body
      truncated = entry[:klass].read(short_record)
      expect { truncated.ufi_bytes(0) }.to raise_error(ArgumentError)
      expect { truncated.set_ufi_checksum(0, 0) }.to raise_error(ArgumentError)
      expect(truncated.to_binary_s).to eq(short_record)
    end
  end

  it "matches Ruby and native snapshots, edits, complete output and reparsing" do
    skip "set EMF_TEST_NATIVE_LIBRARY to test native EMF" unless File.file?(library)

    cases.each do |entry|
      backends.each do |backend|
        ENV["EMF_BACKEND"] = backend
        parsed = Emf.parse(entry[:input])
        wire = parsed.records.first.wire
        expect(wire).to be_a(entry[:klass])
        expect(wire.snapshot).to eq(i_type: entry[:type], n_size: entry[:record].bytesize, body: entry[:body])
        if entry[:type] == 119
          wire.set_ufi_bytes(0, second_ufi)
        else
          wire.ufi_bytes = second_ufi
        end
        expected = entry[:record].dup
        expected[8 + entry[:offset], 8] = second_ufi
        output = Emf.serialize(parsed)
        expect(output).to eq(header + expected + following + eof + tail)
        reparsed = Emf.parse(output)
        expected_snapshot = { i_type: entry[:type], n_size: expected.bytesize, body: expected.byteslice(8..) }
        expect(reparsed.records.first.wire.snapshot).to eq(expected_snapshot)
        expect(Emf.serialize(reparsed)).to eq(output)
      end
    end
  end

  it "retains short opaque bodies through semantic failures and both backend parsers" do
    skip "set EMF_TEST_NATIVE_LIBRARY to test native EMF" unless File.file?(library)

    oversized_count = [0xFFFFFFFF].pack("V")
    cases.each do |entry|
      bodies = entry[:type] == 119 ? ["".b, "abc".b, oversized_count] : ["".b, "x".b * 7]
      bodies.each do |body|
        record = [entry[:type], body.bytesize + 8].pack("V2") + body
        input = header + record + following + eof + tail
        backends.each do |backend|
          ENV["EMF_BACKEND"] = backend
          parsed = Emf.parse(input)
          wire = parsed.records.first.wire
          if entry[:type] == 119
            expect { wire.ufi_bytes(0) }.to raise_error(ArgumentError)
            expect { wire.set_ufi_bytes(0, first_ufi) }.to raise_error(ArgumentError)
            expect { wire.u_num_linked_ufi }.to raise_error(ArgumentError) if body.bytesize < 4
          else
            expect { wire.ufi_bytes }.to raise_error(ArgumentError)
            expect { wire.ufi_checksum = 0 }.to raise_error(ArgumentError)
            expect { wire.ufi_index }.to raise_error(ArgumentError)
          end
          expect(wire.snapshot).to eq(i_type: entry[:type], n_size: record.bytesize, body: body)
          expect(Emf.serialize(parsed)).to eq(input)
        end
      end
    end
  end
end
