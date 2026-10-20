# frozen_string_literal: true

require "spec_helper"
require "rbconfig"

RSpec.describe "EMR Escape semantic byte spans" do
  let(:header) { Emf::Emr::Binary::Header.new(i_type: 1, n_size: 108, d_signature: 0x464D4520).to_binary_s }
  let(:siblings) { [17, 12, 7, 14, 20, 0, 0, 20].pack("V8") + "tail\xFF".b }
  let(:data) { "\x00\x80\xFFdriver".b }
  let(:suffix) { "padding\xA5".b }
  let(:body) { [0xFEDCBA98, data.bytesize].pack("V2") + data + suffix }
  let(:cases) { [[105, Emf::Emr::Binary::Records::DrawEscape], [106, Emf::Emr::Binary::Records::ExtEscape]] }
  let(:backends) { %w[ruby native] }
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

  it "reads unsigned driver codes, byte counts and detached data from the current body" do
    replacement_code = [7].pack("V")
    cases.each do |type, klass|
      wire = klass.read([type, body.bytesize + 8].pack("V2") + body)
      expect(wire.i_escape).to eq(0xFEDCBA98)
      expect(wire.cj_in).to eq(data.bytesize)
      expect(wire.data_bytes).to eq(data)
      expect(wire.data_bytes.encoding).to eq(Encoding::BINARY)
      detached = wire.data_bytes
      detached.setbyte(0, 0xFF)
      expect(wire.data_bytes).to eq(data)
      replacement = body.dup
      replacement[0, 4] = replacement_code
      replacement.setbyte(8, 0x42)
      wire.body = replacement
      expect(wire.i_escape).to eq(7)
      expect(wire.data_bytes.getbyte(0)).to eq(0x42)
    end
  end

  it "edits exactly the selected driver code or declared data span" do
    codes = [0, 0xFFFFFFFF]
    cases.each do |type, klass|
      record = [type, body.bytesize + 8].pack("V2") + body
      wire = klass.read(record)
      expected = record.dup
      codes.each do |value|
        wire.i_escape = value
        expected[8, 4] = [value].pack("V")
        expect(wire.to_binary_s).to eq(expected)
      end
      wire.data_bytes = "\xA5".b * data.bytesize
      expected[16, data.bytesize] = "\xA5".b * data.bytesize
      expect(wire.to_binary_s).to eq(expected)
      expect(wire.cj_in).to eq(data.bytesize)
    end
  end

  it "rejects invalid edits atomically and supports empty data with suffix bytes" do
    invalid_codes = [nil, "1", 1.5, -1, 0x100000000]
    invalid_data = [nil, 1, "", "#{data}x"]
    empty_body = [1, 0].pack("V2") + suffix
    cases.each do |type, klass|
      record = [type, body.bytesize + 8].pack("V2") + body
      wire = klass.read(record)
      invalid_codes.each do |value|
        expect { wire.i_escape = value }.to raise_error(ArgumentError)
        expect(wire.to_binary_s).to eq(record)
      end
      invalid_data.each do |value|
        expect { wire.data_bytes = value }.to raise_error(ArgumentError)
        expect(wire.to_binary_s).to eq(record)
      end
      empty_record = [type, empty_body.bytesize + 8].pack("V2") + empty_body
      empty = klass.read(empty_record)
      expect(empty.cj_in).to eq(0)
      expect(empty.data_bytes).to eq("".b)
      empty.data_bytes = ""
      expect(empty.to_binary_s).to eq(empty_record)
    end
  end

  it "preserves raw malformed bodies while semantic reads and edits reject unavailable spans" do
    malformed = ["".b, "x".b * 7, [1, 0xFFFFFFFF].pack("V2"), "#{[1, 2].pack('V2')}x"]
    cases.each do |type, klass|
      malformed.each do |bytes|
        record = [type, bytes.bytesize + 8].pack("V2") + bytes
        wire = klass.read(record)
        expect { wire.data_bytes }.to raise_error(ArgumentError)
        expect { wire.data_bytes = data }.to raise_error(ArgumentError)
        if bytes.bytesize < 8
          expect { wire.i_escape }.to raise_error(ArgumentError)
          expect { wire.cj_in }.to raise_error(ArgumentError)
          expect { wire.i_escape = 7 }.to raise_error(ArgumentError)
        else
          expect(wire.i_escape).to eq(1)
        end
        expect(wire.to_binary_s).to eq(record)
      end
    end
  end

  it "preserves inputs, snapshots, edits, siblings and malformed spans through both backends" do
    skip "set EMF_TEST_NATIVE_LIBRARY to test native EMF" unless File.file?(library)

    malformed_body = [1, 0xFFFFFFFF].pack("V2")
    replacement_code = [0xFFFFFFFF].pack("V")
    cases.map(&:first).each do |type|
      record = [type, body.bytesize + 8].pack("V2") + body
      input = header + record + siblings
      expected = record.dup
      expected[8, 4] = replacement_code
      expected[16, data.bytesize] = "\xA5".b * data.bytesize
      backends.each do |backend|
        ENV["EMF_BACKEND"] = backend
        parsed = Emf.parse(input)
        wire = parsed.records.first.wire
        expect(wire.snapshot[:body]).to eq(body)
        expect(wire.i_escape).to eq(0xFEDCBA98)
        expect(wire.data_bytes).to eq(data)
        expect(Emf.serialize(parsed)).to eq(input)
        wire.i_escape = 0xFFFFFFFF
        wire.data_bytes = "\xA5".b * data.bytesize
        output = Emf.serialize(parsed)
        expect(output).to eq(header + expected + siblings)
        expect(Emf.serialize(Emf.parse(output))).to eq(output)
        malformed = header + [type, malformed_body.bytesize + 8].pack("V2") + malformed_body + siblings
        raw = Emf.parse(malformed)
        expect { raw.records.first.wire.data_bytes }.to raise_error(ArgumentError)
        expect(Emf.serialize(raw)).to eq(malformed)
      end
    end
  end
end
