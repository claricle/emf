# frozen_string_literal: true

require "spec_helper"
require "rbconfig"

RSpec.describe "EMR logical color space semantic fields" do
  let(:header) { Emf::Emr::Binary::Header.new(i_type: 1, n_size: 108, d_signature: 0x464D4520).to_binary_s }
  let(:following) { [17, 12, 7].pack("V3") }
  let(:eof) { [14, 20, 0, 0, 20].pack("V5") }
  let(:trailing) { "tail\xFF".b }
  let(:suffix) { "padding\xA5".b }
  let(:profile) { "\xFF\x00\x80icc".b }
  let(:endpoints) { (0...36).to_a.pack("C*") }
  let(:byte_fields) { %i[endpoints_bytes filename_bytes] }
  let(:backends) { %w[ruby native] }
  let(:scalar_fields) do
    [
      [:ih_cs, 0, "V", 0x80000001],
      [:lcs_signature, 4, "V", 0x50534F43],
      [:lcs_version, 8, "V", 0x400],
      [:lcs_size, 12, "V", 0xFFFFFFFF],
      [:color_space_type, 16, "l<", -123],
      [:intent, 20, "l<", -0x80000000],
      [:gamma_red, 60, "V", 0x80000000],
      [:gamma_green, 64, "V", 0xFFFFFFFF],
      [:gamma_blue, 68, "V", 0x01234567]
    ]
  end
  let(:cases) do
    [
      [99, Emf::Emr::Binary::Records::CreateColorspace, 332, 260],
      [122, Emf::Emr::Binary::Records::CreateColorspaceW, 592, 520]
    ].map do |type, klass, fixed_size, filename_size|
      filename = Array.new(filename_size) { |index| index % 256 }.pack("C*")
      body = "\xCD".b * fixed_size
      scalar_fields.each { |_name, offset, format, value| body[offset, 4] = [value].pack(format) }
      body[24, 36] = endpoints
      body[72, filename_size] = filename
      body += [0x80000001, profile.bytesize].pack("V2") + profile if type == 122
      body += suffix
      record = [type, body.bytesize + 8].pack("V2") + body
      { type: type, klass: klass, fixed_size: fixed_size, filename: filename, body: body, record: record,
        input: header + record + following + eof + trailing }
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

  it "reads every scalar at its documented offset and returns detached binary spans" do
    changed_gamma = [123].pack("V")
    cases.each do |entry|
      wire = entry[:klass].read(entry[:record])
      scalar_fields.each { |name, _offset, _format, value| expect(wire.public_send(name)).to eq(value) }
      expect(wire.snapshot).to eq(i_type: entry[:type], n_size: entry[:record].bytesize, body: entry[:body])
      expect(wire.endpoints_bytes).to eq(endpoints)
      expect(wire.filename_bytes).to eq(entry[:filename])
      [wire.endpoints_bytes, wire.filename_bytes].each do |returned|
        expect(returned.encoding).to eq(Encoding::BINARY)
        returned.setbyte(0, 0xFF)
      end
      expect(wire.to_binary_s).to eq(entry[:record])
      changed = entry[:body].dup
      changed[60, 4] = changed_gamma
      wire.body = changed
      expect(wire.gamma_red).to eq(123)
    end
  end

  it "accepts each scalar's exact signed or unsigned bounds and rejects invalid values atomically" do
    invalid_values = [nil, "1", 1.0]
    cases.each do |entry|
      scalar_fields.each do |name, offset, format, _value|
        wire = entry[:klass].read(entry[:record])
        bounds = format == "l<" ? [-0x80000000, 0x7FFFFFFF] : [0, 0xFFFFFFFF]
        bounds.each do |value|
          wire.public_send("#{name}=", value)
          expected = entry[:record].dup
          expected[8 + offset, 4] = [value].pack(format)
          expect(wire.to_binary_s).to eq(expected)
        end
        before = wire.to_binary_s
        invalid_values.each do |value|
          expect { wire.public_send("#{name}=", value) }.to raise_error(ArgumentError)
          expect(wire.to_binary_s).to eq(before)
        end
        [bounds.first - 1, bounds.last + 1].each do |value|
          expect { wire.public_send("#{name}=", value) }.to raise_error(RangeError)
          expect(wire.to_binary_s).to eq(before)
        end
      end
    end
  end

  it "edits exact endpoint and filename spans while preserving headers, suffixes and following records" do
    cases.each do |entry|
      parsed = Emf::Emr::Parser.call(entry[:input])
      wire = parsed.records.first.wire
      expected = entry[:record].dup
      wire.endpoints_bytes = "\xFE".b * 36
      expected[32, 36] = "\xFE".b * 36
      expect(wire.to_binary_s).to eq(expected)
      wire.filename_bytes = "\xD8".b * entry[:filename].bytesize
      expected[80, entry[:filename].bytesize] = "\xD8".b * entry[:filename].bytesize
      expect(wire.snapshot).to eq(i_type: entry[:type], n_size: entry[:record].bytesize, body: expected.byteslice(8..))
      expect(Emf::Emr::Serializer.call(parsed)).to eq(header + expected + following + eof + trailing)
      byte_fields.each do |name|
        length = wire.public_send(name).bytesize
        [nil, 1, "x" * (length - 1), "x" * (length + 1)].each do |value|
          expect { wire.public_send("#{name}=", value) }.to raise_error(ArgumentError)
          expect(wire.to_binary_s).to eq(expected)
        end
      end
    end
  end

  it "exposes W flags and read-only count and edits only the declared profile bytes" do
    entry = cases.last
    wire = entry[:klass].read(entry[:record])
    expect([wire.dw_flags, wire.cb_data]).to eq([0x80000001, profile.bytesize])
    expect(wire).not_to respond_to(:cb_data=)
    expect(wire.profile_bytes).to eq(profile)
    returned = wire.profile_bytes
    expect(returned.encoding).to eq(Encoding::BINARY)
    returned.setbyte(0, 0)
    expect(wire.profile_bytes).to eq(profile)
    expected = entry[:record].dup
    [0, 0xFFFFFFFF].each do |value|
      wire.dw_flags = value
      expected[600, 4] = [value].pack("V")
      expect(wire.to_binary_s).to eq(expected)
    end
    wire.profile_bytes = "\xA5".b * profile.bytesize
    expected[608, profile.bytesize] = "\xA5".b * profile.bytesize
    expect(wire.to_binary_s).to eq(expected)
    [nil, 1.0, "1"].each { |value| expect { wire.dw_flags = value }.to raise_error(ArgumentError) }
    [-1, 0x100000000].each { |value| expect { wire.dw_flags = value }.to raise_error(RangeError) }
    [nil, 1, "", "x" * (profile.bytesize + 1)].each do |value|
      expect { wire.profile_bytes = value }.to raise_error(ArgumentError)
      expect(wire.to_binary_s).to eq(expected)
    end
  end

  it "preserves truncated raw bodies while requiring complete logical structures" do
    cases.each do |entry|
      [0, 3, 4, entry[:fixed_size] - 1].each do |length|
        body = entry[:body].byteslice(0, length)
        record = [entry[:type], length + 8].pack("V2") + body
        wire = entry[:klass].read(record)
        scalar_fields.each do |name, _offset, _format, _value|
          next if name == :ih_cs && length >= 4

          expect { wire.public_send(name) }.to raise_error(ArgumentError)
          expect { wire.public_send("#{name}=", 0) }.to raise_error(ArgumentError)
        end
        expect(wire.ih_cs).to eq(0x80000001) if length >= 4
        byte_fields.each do |name|
          expect { wire.public_send(name) }.to raise_error(ArgumentError)
          expect { wire.public_send("#{name}=", "") }.to raise_error(ArgumentError)
        end
        expect(wire.snapshot).to eq(i_type: entry[:type], n_size: record.bytesize, body: body)
        expect(wire.to_binary_s).to eq(record)
      end
    end
  end

  it "bounds W profile counts by available bytes and preserves empty profiles and suffixes" do
    entry = cases.last
    bodies = [entry[:body].byteslice(0, 592), entry[:body].byteslice(0, 599),
              entry[:body].byteslice(0, 596) + [0xFFFFFFFF].pack("V") + suffix]
    bodies.each do |body|
      record = [122, body.bytesize + 8].pack("V2") + body
      wire = entry[:klass].read(record)
      expect { wire.profile_bytes }.to raise_error(ArgumentError)
      expect { wire.profile_bytes = "" }.to raise_error(ArgumentError)
      if body.bytesize < 600
        expect { wire.dw_flags }.to raise_error(ArgumentError)
        expect { wire.dw_flags = 0 }.to raise_error(ArgumentError)
        expect { wire.cb_data }.to raise_error(ArgumentError)
      end
      expect(wire.to_binary_s).to eq(record)
    end
    body = entry[:body].byteslice(0, 592) + [0, 0].pack("V2") + suffix
    record = [122, body.bytesize + 8].pack("V2") + body
    wire = entry[:klass].read(record)
    expect(wire.profile_bytes).to eq("".b)
    wire.profile_bytes = ""
    expect(wire.to_binary_s).to eq(record)
  end

  it "matches Ruby and native semantic edits, complete snapshots and reparsed bytes" do
    skip "set EMF_TEST_NATIVE_LIBRARY to test native EMF" unless File.file?(library)

    edited_value = [42]
    cases.each do |entry|
      expected = entry[:record].dup
      scalar_fields.each { |_name, offset, format, _value| expected[8 + offset, 4] = edited_value.pack(format) }
      expected[32, 36] = "\xFE".b * 36
      expected[80, entry[:filename].bytesize] = "\xD8".b * entry[:filename].bytesize
      expected[608, profile.bytesize] = "\xA5".b * profile.bytesize if entry[:type] == 122
      backends.each do |backend|
        ENV["EMF_BACKEND"] = backend
        parsed = Emf.parse(entry[:input])
        wire = parsed.records.first.wire
        expect(wire).to be_a(entry[:klass])
        expect(wire.snapshot).to eq(i_type: entry[:type], n_size: entry[:record].bytesize, body: entry[:body])
        scalar_fields.each do |name, _offset, _format, value|
          expect(wire.public_send(name)).to eq(value)
          wire.public_send("#{name}=", 42)
        end
        wire.endpoints_bytes = "\xFE".b * 36
        wire.filename_bytes = "\xD8".b * entry[:filename].bytesize
        wire.profile_bytes = "\xA5".b * profile.bytesize if entry[:type] == 122
        output = Emf.serialize(parsed)
        expect(output).to eq(header + expected + following + eof + trailing)
        reparsed = Emf.parse(output)
        expected_snapshot = { i_type: entry[:type], n_size: entry[:record].bytesize, body: expected.byteslice(8..) }
        expect(reparsed.records.first.wire.snapshot).to eq(expected_snapshot)
        expect(Emf.serialize(reparsed)).to eq(output)
      end
    end
  end

  it "preserves short and oversized profile records through both backend parsers" do
    skip "set EMF_TEST_NATIVE_LIBRARY to test native EMF" unless File.file?(library)

    oversized_count = [0xFFFFFFFF].pack("V")
    cases.each do |entry|
      bodies = ["".b, "abc".b, entry[:body].byteslice(0, entry[:fixed_size] - 1)]
      bodies << (entry[:body].byteslice(0, 596) + oversized_count) if entry[:type] == 122
      bodies.each do |body|
        record = [entry[:type], body.bytesize + 8].pack("V2") + body
        input = header + record + following + eof + trailing
        backends.each do |backend|
          ENV["EMF_BACKEND"] = backend
          parsed = Emf.parse(input)
          wire = parsed.records.first.wire
          expect(wire.snapshot).to eq(i_type: entry[:type], n_size: record.bytesize, body: body)
          if body.bytesize < entry[:fixed_size]
            expect { wire.filename_bytes }.to raise_error(ArgumentError)
          else
            expect { wire.profile_bytes }.to raise_error(ArgumentError)
          end
          expect(Emf.serialize(parsed)).to eq(input)
        end
      end
    end
  end
end
