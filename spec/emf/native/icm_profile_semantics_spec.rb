# frozen_string_literal: true

require "spec_helper"
require "rbconfig"

RSpec.describe "EMR ICM profile semantic byte spans" do
  let(:header) { Emf::Emr::Binary::Header.new(i_type: 1, n_size: 108, d_signature: 0x464D4520).to_binary_s }
  let(:following) { [17, 12, 7].pack("V3") }
  let(:eof) { [14, 20, 0, 0, 20].pack("V5") }
  let(:trailing) { "tail\xFF".b }
  let(:profile) { "\xFF\x00\x80icc".b }
  let(:suffix) { "padding\xA5".b }
  let(:backends) { %w[ruby native] }
  let(:cases) do
    [
      [112, Emf::Emr::Binary::Records::SetIcmProfileA, "x\x80\x00".b],
      [113, Emf::Emr::Binary::Records::SetIcmProfileW, "x\x00\x00\xD8\x00\x00".b]
    ].map do |type, klass, name|
      body = [0x80000001, name.bytesize, profile.bytesize].pack("V3") + name + profile + suffix
      record = [type, body.bytesize + 8].pack("V2") + body
      { type: type, klass: klass, name: name, body: body, record: record,
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

  it "exposes byte counts and detached raw names and profiles without decoding" do
    cases.each do |entry|
      wire = entry[:klass].read(entry[:record])
      expect([wire.dw_flags, wire.cb_name, wire.cb_data]).to eq([0x80000001, entry[:name].bytesize, profile.bytesize])
      expect(wire.name_bytes).to eq(entry[:name])
      expect(wire.profile_bytes).to eq(profile)
      expect(wire.name_bytes.encoding).to eq(Encoding::BINARY)
      returned = wire.name_bytes
      returned.setbyte(0, 0xFF)
      expect(wire.name_bytes).to eq(entry[:name])
      returned = wire.profile_bytes
      returned.setbyte(0, 0)
      expect(wire.profile_bytes).to eq(profile)
      expect(wire.to_binary_s).to eq(entry[:record])
      replacement_body = entry[:body].dup
      replacement_body.setbyte(12, 0x55)
      wire.body = replacement_body
      expect(wire.name_bytes.getbyte(0)).to eq(0x55)
    end
  end

  it "edits only the selected span and preserves counts, suffix, siblings and trailing bytes" do
    flags_bytes = [0xFFFFFFFF].pack("V")
    cases.each do |entry|
      parsed = Emf::Emr::Parser.call(entry[:input])
      wire = parsed.records.first.wire
      expected = entry[:record].dup
      wire.dw_flags = 0xFFFFFFFF
      expected[8, 4] = flags_bytes
      expect(wire.to_binary_s).to eq(expected)
      wire.name_bytes = "\xFE".b * entry[:name].bytesize
      expected[20, entry[:name].bytesize] = "\xFE".b * entry[:name].bytesize
      expect(wire.to_binary_s).to eq(expected)
      wire.profile_bytes = "\xA5".b * profile.bytesize
      expected[20 + entry[:name].bytesize, profile.bytesize] = "\xA5".b * profile.bytesize
      expect(wire.to_binary_s).to eq(expected)
      expect(Emf::Emr::Serializer.call(parsed)).to eq(header + expected + following + eof + trailing)
    end
  end

  it "rejects invalid edits without changing bytes" do
    invalid_flags = [-1, 0x100000000]
    cases.each do |entry|
      wire = entry[:klass].read(entry[:record])
      [nil, 1, "", "#{entry[:name]}x"].each do |value|
        expect { wire.name_bytes = value }.to raise_error(ArgumentError)
        expect(wire.to_binary_s).to eq(entry[:record])
      end
      [nil, 1, "", "#{profile}x"].each do |value|
        expect { wire.profile_bytes = value }.to raise_error(ArgumentError)
        expect(wire.to_binary_s).to eq(entry[:record])
      end
      expect { wire.dw_flags = "1" }.to raise_error(ArgumentError)
      invalid_flags.each do |value|
        expect { wire.dw_flags = value }.to raise_error(RangeError)
      end
      expect(wire.to_binary_s).to eq(entry[:record])
    end
  end

  it "keeps zero-length spans empty without consuming suffix bytes" do
    body = [7, 0, 0].pack("V3") + suffix
    cases.each do |entry|
      record = [entry[:type], body.bytesize + 8].pack("V2") + body
      wire = entry[:klass].read(record)
      expect(wire.name_bytes).to eq("".b)
      expect(wire.profile_bytes).to eq("".b)
      wire.name_bytes = ""
      wire.profile_bytes = ""
      expect(wire.to_binary_s).to eq(record)
    end
  end

  it "preserves short and oversized opaque bodies while semantic access raises" do
    short_bodies = ["".b, "x".b * 11, [1, 0xFFFFFFFF, 0xFFFFFFFF].pack("V3"),
                    "#{[1, 1, 2].pack('V3')}x"]
    cases.each do |entry|
      short_bodies.each do |body|
        record = [entry[:type], body.bytesize + 8].pack("V2") + body
        wire = entry[:klass].read(record)
        expect { wire.profile_bytes }.to raise_error(ArgumentError)
        expect { wire.profile_bytes = profile }.to raise_error(ArgumentError)
        if body.bytesize < 12
          expect { wire.dw_flags }.to raise_error(ArgumentError)
          expect { wire.dw_flags = 1 }.to raise_error(ArgumentError)
          expect { wire.name_bytes }.to raise_error(ArgumentError)
        end
        expect(wire.to_binary_s).to eq(record)
      end
    end
  end

  it "matches Ruby and native access, edits, snapshots and reparsing" do
    skip "set EMF_TEST_NATIVE_LIBRARY to test native EMF" unless File.file?(library)

    flags_bytes = [0].pack("V")
    short_bodies = ["".b, "short".b, [1, 0xFFFFFFFF, 0].pack("V3")]
    cases.each do |entry|
      outputs = backends.map do |backend|
        ENV["EMF_BACKEND"] = backend
        parsed = Emf.parse(entry[:input])
        wire = parsed.records.first.wire
        expect(wire).to be_a(entry[:klass])
        expect(wire.snapshot[:body]).to eq(entry[:body])
        expect(wire.name_bytes).to eq(entry[:name])
        expect(wire.profile_bytes).to eq(profile)
        wire.dw_flags = 0
        wire.profile_bytes = "\xA5".b * profile.bytesize
        output = Emf.serialize(parsed)
        expect(Emf.serialize(Emf.parse(output))).to eq(output)
        output
      end
      expected = entry[:record].dup
      expected[8, 4] = flags_bytes
      expected[20 + entry[:name].bytesize, profile.bytesize] = "\xA5".b * profile.bytesize
      expect(outputs).to eq([header + expected + following + eof + trailing] * 2)
      short_bodies.each do |body|
        record = [entry[:type], body.bytesize + 8].pack("V2") + body
        input = header + record + following + eof + trailing
        backends.each do |backend|
          ENV["EMF_BACKEND"] = backend
          parsed = Emf.parse(input)
          expect(parsed.records.first.wire.body.to_s).to eq(body)
          expect { parsed.records.first.wire.name_bytes }.to raise_error(ArgumentError)
          expect(Emf.serialize(parsed)).to eq(input)
        end
      end
    end
  end
end
