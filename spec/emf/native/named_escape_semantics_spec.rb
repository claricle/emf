# frozen_string_literal: true

require "spec_helper"
require "rbconfig"

RSpec.describe "EMR NamedEscape semantic byte spans" do
  let(:header) { Emf::Emr::Binary::Header.new(i_type: 1, n_size: 108, d_signature: 0x464D4520).to_binary_s }
  let(:following) { [17, 12, 7, 14, 20, 0, 0, 20].pack("V8") + "tail\xFF".b }
  let(:driver) { "P\x00X".b }
  let(:data) { "\x00\x80\xFFdriver".b }
  let(:suffix) { "padding\xA5".b }
  let(:body) { [0xFEDCBA98, driver.bytesize, data.bytesize].pack("V3") + driver + data + suffix }
  let(:record) { [110, body.bytesize + 8].pack("V2") + body }
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

  it "reads current unsigned fields and detached raw byte spans" do
    wire = Emf::Emr::Binary::Records::NamedEscape.read(record)
    expect([wire.i_escape, wire.cj_driver, wire.cj_in]).to eq([0xFEDCBA98, driver.bytesize, data.bytesize])
    expect(wire.driver_name_bytes).to eq(driver)
    expect(wire.data_bytes).to eq(data)
    expect(wire.driver_name_bytes.encoding).to eq(Encoding::BINARY)
    expect(wire.data_bytes.encoding).to eq(Encoding::BINARY)
    wire.driver_name_bytes.setbyte(0, 0xFF)
    wire.data_bytes.setbyte(0, 0xFF)
    expect(wire.driver_name_bytes).to eq(driver)
    expect(wire.data_bytes).to eq(data)

    replacement = body.dup
    replacement[0, 4] = [7].pack("V")
    wire.body = replacement
    expect(wire.i_escape).to eq(7)
  end

  it "edits only the selected fields and preserves suffix, record header and following bytes" do
    parsed = Emf::Emr::Parser.call(header + record + following)
    wire = parsed.records.first.wire
    expected = record.dup
    wire.i_escape = 0xFFFFFFFF
    expected[8, 4] = [0xFFFFFFFF].pack("V")
    expect(wire.to_binary_s).to eq(expected)
    wire.driver_name_bytes = "\xA1\xA2\xA3".b
    expected[20, driver.bytesize] = "\xA1\xA2\xA3".b
    expect(wire.to_binary_s).to eq(expected)
    wire.data_bytes = "\x05\x06\x07\x08\x09\x0A\x0B\x0C\x0D".b
    expected[20 + driver.bytesize, data.bytesize] = "\x05\x06\x07\x08\x09\x0A\x0B\x0C\x0D".b
    expect(wire.to_binary_s).to eq(expected)
    expect(wire.snapshot).to eq(i_type: 110, n_size: record.bytesize, body: expected.byteslice(8..))
    expect(Emf::Emr::Serializer.call(parsed)).to eq(header + expected + following)
  end

  it "rejects invalid field and span edits without mutation" do
    invalid_values = [nil, "1", 1.5]
    wire = Emf::Emr::Binary::Records::NamedEscape.read(record)
    invalid_values.each do |value|
      expect { wire.i_escape = value }.to raise_error(ArgumentError)
      expect(wire.to_binary_s).to eq(record)
    end
    [-1, 0x100000000].each do |value|
      expect { wire.i_escape = value }.to raise_error(RangeError)
      expect(wire.to_binary_s).to eq(record)
    end
    [nil, 1, "", "longer"].each do |value|
      expect { wire.driver_name_bytes = value }.to raise_error(ArgumentError)
      expect(wire.to_binary_s).to eq(record)
      expect { wire.data_bytes = value }.to raise_error(ArgumentError)
      expect(wire.to_binary_s).to eq(record)
    end

    malformed_bodies = [
      ["".b, true, true], ["short".b, true, true],
      [[1, 0xFFFFFFFF, 0].pack("V3"), true, true],
      ["#{[1, 1, 3].pack('V3')}x", false, true]
    ]
    malformed_bodies.each do |malformed_body, invalid_driver, invalid_data|
      malformed = [110, malformed_body.bytesize + 8].pack("V2") + malformed_body
      malformed_wire = Emf::Emr::Binary::Records::NamedEscape.read(malformed)
      expect { malformed_wire.i_escape }.to raise_error(ArgumentError) if malformed_body.bytesize < 12
      expect { malformed_wire.cj_driver }.to raise_error(ArgumentError) if malformed_body.bytesize < 12
      expect { malformed_wire.cj_in }.to raise_error(ArgumentError) if malformed_body.bytesize < 12
      expect { malformed_wire.driver_name_bytes }.to raise_error(ArgumentError) if invalid_driver
      expect { malformed_wire.driver_name_bytes = driver }.to raise_error(ArgumentError) if invalid_driver
      expect { malformed_wire.data_bytes }.to raise_error(ArgumentError) if invalid_data
      expect { malformed_wire.data_bytes = data }.to raise_error(ArgumentError) if invalid_data
      expect(malformed_wire.to_binary_s).to eq(malformed)
    end
  end

  it "keeps zero-length spans and arbitrary short bodies opaque" do
    empty_body = [3, 0, 0].pack("V3") + suffix
    empty_record = [110, empty_body.bytesize + 8].pack("V2") + empty_body
    empty = Emf::Emr::Binary::Records::NamedEscape.read(empty_record)
    expect(empty.driver_name_bytes).to eq("".b)
    expect(empty.data_bytes).to eq("".b)
    empty.driver_name_bytes = ""
    empty.data_bytes = ""
    expect(empty.to_binary_s).to eq(empty_record)

    ["".b, "x".b, "x".b * 11].each do |short_body|
      short_record = [110, short_body.bytesize + 8].pack("V2") + short_body
      short = Emf::Emr::Binary::Records::NamedEscape.read(short_record)
      expect { short.i_escape }.to raise_error(ArgumentError)
      expect { short.i_escape = 1 }.to raise_error(ArgumentError)
      expect { short.cj_driver }.to raise_error(ArgumentError)
      expect { short.cj_in }.to raise_error(ArgumentError)
      expect { short.driver_name_bytes }.to raise_error(ArgumentError)
      expect { short.data_bytes = "" }.to raise_error(ArgumentError)
      expect(short.to_binary_s).to eq(short_record)
    end
  end

  it "matches Ruby and native semantic edits, snapshots and reparsing" do
    skip "set EMF_TEST_NATIVE_LIBRARY to test native EMF" unless File.file?(library)

    expected = record.dup
    expected[8, 4] = [0xFFFFFFFF].pack("V")
    expected[20, driver.bytesize] = "\xA1\xA2\xA3".b
    expected[20 + driver.bytesize, data.bytesize] = "\x05\x06\x07\x08\x09\x0A\x0B\x0C\x0D".b
    input = header + record + following
    outputs = backends.map do |backend|
      ENV["EMF_BACKEND"] = backend
      parsed = Emf.parse(input)
      wire = parsed.records.first.wire
      expect(wire).to be_a(Emf::Emr::Binary::Records::NamedEscape)
      expect(wire.snapshot).to eq(i_type: 110, n_size: record.bytesize, body: body)
      expect(wire.driver_name_bytes).to eq(driver)
      expect(wire.data_bytes).to eq(data)
      wire.i_escape = 0xFFFFFFFF
      wire.driver_name_bytes = "\xA1\xA2\xA3".b
      wire.data_bytes = "\x05\x06\x07\x08\x09\x0A\x0B\x0C\x0D".b
      output = Emf.serialize(parsed)
      expect(output).to eq(header + expected + following)
      expect(Emf.serialize(Emf.parse(output))).to eq(output)
      output
    end
    expect(outputs).to eq([header + expected + following] * 2)

    malformed_body = [1, 0xFFFFFFFF, 0].pack("V3")
    malformed_input = header + [110, malformed_body.bytesize + 8].pack("V2") + malformed_body + following
    backends.each do |backend|
      ENV["EMF_BACKEND"] = backend
      parsed = Emf.parse(malformed_input)
      expect { parsed.records.first.wire.driver_name_bytes }.to raise_error(ArgumentError)
      expect(Emf.serialize(parsed)).to eq(malformed_input)
    end
  end
end
