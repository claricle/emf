# frozen_string_literal: true

require "spec_helper"
require "rbconfig"

RSpec.describe "semantic flood fill and text justification" do
  let(:header) { Emf::Emr::Binary::Header.new(i_type: 1, n_size: 108, d_signature: 0x464D4520).to_binary_s }
  let(:eof) { [14, 20, 0, 0, 20].pack("V*") }
  let(:library) do
    ENV.fetch("EMF_TEST_NATIVE_LIBRARY") do
      extension = RbConfig::CONFIG.fetch("host_os").include?("darwin") ? "dylib" : "so"
      File.expand_path("../../../emf-rs/target/debug/libemf_ffi.#{extension}", __dir__)
    end
  end
  let(:cases) do
    [
      [53, 91, Emf::Emr::Binary::Records::ExtFloodFill, [0x80000000, 0x7FFFFFFF, 0xFEDCBA98, 0xFFFFFFFF].pack("V*"),
       { start: { x: -2_147_483_648, y: 2_147_483_647 }, color: { red: 152, green: 186, blue: 220, reserved: 254 },
         flood_fill_mode: 0xFFFFFFFF }],
      [120, 92, Emf::Emr::Binary::Records::SetTextJustification, [-2_147_483_648, -1].pack("l<2"),
       { n_break_extra: -2_147_483_648, n_break_count: -1 }]
    ]
  end

  around do |example|
    previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
    ENV["EMF_BACKEND"] = "native"
    ENV["EMF_NATIVE_LIBRARY"] = library
    example.run
  ensure
    %w[EMF_BACKEND EMF_NATIVE_LIBRARY].each { |key| ENV[key] = previous[key] }
  end

  before { skip "build emf-ffi or set EMF_TEST_NATIVE_LIBRARY" unless File.file?(library) }

  it "decodes typed wire fields and preserves body assignment compatibility" do
    cases.each do |type, _family, klass, body, fields|
      bytes = [[type, body.bytesize + 12].pack("V2"), body, "TAIL"].join
      wire = klass.read(bytes)
      fields.each { |field, value| expect(wire.public_send(field).snapshot).to eq(value) }
      expect(wire.body).to eq("#{body}TAIL")
      expect(wire.to_binary_s).to eq(bytes)
      wire.body = "#{body}EDIT"
      expect(wire.trailing.to_s).to eq("EDIT")
      wire.body.assign("#{body}NEXT")
      expect(wire.to_binary_s).to eq(bytes.sub("TAIL", "NEXT"))
      expect { wire.body = body.byteslice(0...-1) }.to raise_error(ArgumentError)
      expect(wire.to_binary_s).to eq(bytes.sub("TAIL", "NEXT"))
    end
  end

  it "hydrates directly and preserves suffixes, following records and editable typed fields" do
    following = [17, 12, 9].pack("V3")
    replacement = [-17].pack("l<")
    expect(Emf::Emr::Parser).not_to receive(:call)
    cases.each do |type, _family, klass, body, fields|
      expect(klass).not_to receive(:read)
      record = [[type, body.bytesize + 12].pack("V2"), body, "TAIL"].join
      input = "#{header}#{record}#{following}#{eof}tail"
      parsed = Emf.parse(input)
      wire = parsed.records.first.wire
      fields.each { |field, value| expect(wire.public_send(field).snapshot).to eq(value) }
      expect(wire.trailing.to_s).to eq("TAIL")
      expect(parsed.records[1].wire.map_mode.to_i).to eq(9)
      expect(parsed.errors).to be_empty
      expect(Emf.serialize(parsed)).to eq(input)
      if type == 53
        wire.start.x = -17
      else
        wire.n_break_extra = -17
      end
      expected = input.dup
      expected[header.bytesize + 8, 4] = replacement
      expect(Emf.serialize(parsed)).to eq(expected)
    end
  end

  it "keeps every truncated fixed payload raw with diagnostics and following records" do
    following = [17, 12, 9].pack("V3")
    cases.each do |type, _family, _klass, body, _fields|
      body.bytesize.times do |length|
        record = [type, length + 8].pack("V2") + body.byteslice(0, length)
        input = header + record + following + eof
        parsed = Emf.parse(input)
        expect(parsed.records.first.wire).to be_a(Emf::Emr::Binary::Records::Raw)
        expect(parsed.records.first.wire.payload.to_s).to eq(body.byteslice(0, length))
        expect(parsed.errors.map(&:record_code)).to eq([type])
        expect(parsed.records[1].wire.map_mode.to_i).to eq(9)
        expect(Emf.serialize(parsed)).to eq(input)
      end
    end
  end

  it "checks snapshot bounds and decodes legacy body snapshots without wire reads" do
    short_legacy = "#{[3].pack('Q<')}bad"
    invalid_legacy = ["", "#{[0].pack('Q<')}extra", [0xFFFFFFFFFFFFFFFF].pack("Q<")]
    cases.each do |_type, family, klass, body, fields|
      expect(klass).not_to receive(:read)
      [0, body.bytesize - 1, body.bytesize + 1, body.bytesize + 8].each do |length|
        expect { Emf::Native::Fields.call("x" * length, family) }
          .to raise_error(Emf::FormatError, "invalid native typed payload length")
      end
      legacy = family == 91 ? 68 : 73
      invalid_legacy.each do |invalid|
        expect { Emf::Native::Fields.call(invalid, legacy) }
          .to raise_error(Emf::FormatError, "invalid native opaque payload length")
      end
      decoded_class, decoded = Emf::Native::Fields.call("#{[body.bytesize + 4].pack('Q<')}#{body}TAIL", legacy)
      expect(decoded_class).to eq(klass)
      expect(decoded).to eq(fields.merge(trailing: "TAIL"))
      decoded_class, decoded = Emf::Native::Fields.call(short_legacy, legacy)
      expect(decoded_class).to eq(Emf::Emr::Binary::Records::Raw)
      expect(decoded).to eq(payload: "bad")
    end
  end
end
