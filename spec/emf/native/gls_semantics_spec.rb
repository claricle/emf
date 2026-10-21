# frozen_string_literal: true

require "spec_helper"
require "rbconfig"

RSpec.describe "EMR GLS semantic byte spans" do
  let(:header) { Emf::Emr::Binary::Header.new(i_type: 1, n_size: 108, d_signature: 0x464D4520).to_binary_s }
  let(:siblings) { [17, 12, 7, 14, 20, 0, 0, 20].pack("V8") + "tail\xFF".b }
  let(:data) { "\x00\x80\xFFgls".b }
  let(:bounds) { [-10, -20, 30, 40].pack("l<4") }
  let(:suffix) { "padding\xA5".b }
  let(:backends) { %w[ruby native] }
  let(:cases) do
    [[102, Emf::Emr::Binary::Records::GlsRecord, "".b],
     [103, Emf::Emr::Binary::Records::GlsBoundedRecord, bounds]].map do |type, klass, prefix|
      body = prefix + [data.bytesize].pack("V") + data + suffix
      record = [type, body.bytesize + 8].pack("V2") + body
      { type: type, klass: klass, prefix: prefix, body: body, record: record, offset: prefix.bytesize + 4 }
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

  it "reads detached binary data, declared counts and bounded rectangles" do
    cases.each do |entry|
      wire = entry[:klass].read(entry[:record])
      expect(wire.cb_data).to eq(data.bytesize)
      expect(wire.data_bytes).to eq(data)
      expect(wire.data_bytes.encoding).to eq(Encoding::BINARY)
      copy = wire.data_bytes
      copy.setbyte(0, 0xFF)
      expect(wire.data_bytes).to eq(data)
      if entry[:type] == 103
        expect(wire.bounds).to eq(bounds)
        rectangle = wire.bounds
        rectangle.setbyte(0, 0)
        expect(wire.bounds).to eq(bounds)
      end
      replacement = entry[:body].dup
      replacement.setbyte(entry[:offset], 0x44)
      wire.body = replacement
      expect(wire.data_bytes.getbyte(0)).to eq(0x44)
    end
  end

  it "edits only the selected data or rectangle bytes" do
    cases.each do |entry|
      wire = entry[:klass].read(entry[:record])
      expected = entry[:record].dup
      wire.data_bytes = "\xA5".b * data.bytesize
      expected[8 + entry[:offset], data.bytesize] = "\xA5".b * data.bytesize
      expect(wire.to_binary_s).to eq(expected)
      next unless entry[:type] == 103

      wire.bounds = "\x5A".b * 16
      expected[8, 16] = "\x5A".b * 16
      expect(wire.to_binary_s).to eq(expected)
    end
  end

  it "rejects invalid edits atomically and preserves empty data and suffixes" do
    invalid_bounds = [nil, 16, "x" * 15, "x" * 17]
    zero_count = [0].pack("V")
    cases.each do |entry|
      wire = entry[:klass].read(entry[:record])
      [nil, 1, "", "#{data}x"].each do |value|
        expect { wire.data_bytes = value }.to raise_error(ArgumentError)
        expect(wire.to_binary_s).to eq(entry[:record])
      end
      if entry[:type] == 103
        invalid_bounds.each do |value|
          expect { wire.bounds = value }.to raise_error(ArgumentError)
          expect(wire.to_binary_s).to eq(entry[:record])
        end
      end
      body = entry[:prefix] + zero_count + suffix
      record = [entry[:type], body.bytesize + 8].pack("V2") + body
      empty = entry[:klass].read(record)
      expect(empty.cb_data).to eq(0)
      expect(empty.data_bytes).to eq("".b)
      empty.data_bytes = ""
      expect(empty.to_binary_s).to eq(record)
    end
  end

  it "keeps malformed bodies opaque while semantic access and edits reject truncation" do
    oversized_count = [0xFFFFFFFF].pack("V")
    short_data = "#{[2].pack('V')}x"
    cases.each do |entry|
      bodies = ["".b, "x".b * (entry[:offset] - 1), entry[:prefix] + oversized_count,
                entry[:prefix] + short_data]
      bodies.each do |body|
        record = [entry[:type], body.bytesize + 8].pack("V2") + body
        wire = entry[:klass].read(record)
        expect { wire.data_bytes }.to raise_error(ArgumentError)
        expect { wire.data_bytes = data }.to raise_error(ArgumentError)
        if body.bytesize < entry[:offset]
          expect { wire.cb_data }.to raise_error(ArgumentError)
          expect { wire.bounds }.to raise_error(ArgumentError) if entry[:type] == 103
        end
        expect(wire.to_binary_s).to eq(record)
      end
    end
  end

  it "preserves snapshots, edits, siblings and malformed bodies through Ruby and native reparsing" do
    skip "set EMF_TEST_NATIVE_LIBRARY to test native EMF" unless File.file?(library)

    oversized_count = [0xFFFFFFFF].pack("V")
    cases.each do |entry|
      input = header + entry[:record] + siblings
      expected = entry[:record].dup
      expected[8 + entry[:offset], data.bytesize] = "\xA5".b * data.bytesize
      backends.each do |backend|
        ENV["EMF_BACKEND"] = backend
        parsed = Emf.parse(input)
        wire = parsed.records.first.wire
        expect(wire.snapshot[:body]).to eq(entry[:body])
        expect(wire.data_bytes).to eq(data)
        expect(Emf.serialize(parsed)).to eq(input)
        wire.data_bytes = "\xA5".b * data.bytesize
        output = Emf.serialize(parsed)
        expect(output).to eq(header + expected + siblings)
        expect(Emf.serialize(Emf.parse(output))).to eq(output)
        body = entry[:prefix] + oversized_count
        malformed = header + [entry[:type], body.bytesize + 8].pack("V2") + body + siblings
        raw = Emf.parse(malformed)
        expect { raw.records.first.wire.data_bytes }.to raise_error(ArgumentError)
        expect(Emf.serialize(raw)).to eq(malformed)
      end
    end
  end
end
