# frozen_string_literal: true

require "spec_helper"
require "rbconfig"
require "emf/wmf/text_codec"
require_relative "../support/native_wmf"

RSpec.describe "Native WMF bridge" do
  include NativeWmfSupport

  let(:library) do
    ENV.fetch("EMF_TEST_NATIVE_LIBRARY") do
      extension = RbConfig::CONFIG.fetch("host_os").include?("darwin") ? "dylib" : "so"
      File.expand_path("../../emf-rs/target/debug/libemf_ffi.#{extension}", __dir__)
    end
  end
  let(:move) { native_wmf_record(0xAB14, [-3, 7].pack("s<2")) }
  let(:unknown) { native_wmf_record(0x7FFE, "raw!") }

  around do |example|
    previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
    ENV["EMF_BACKEND"] = "native"
    ENV["EMF_NATIVE_LIBRARY"] = library
    example.run
  ensure
    %w[EMF_BACKEND EMF_NATIVE_LIBRARY].each { |key| ENV[key] = previous[key] }
  end

  before do
    skip "build emf-ffi or set EMF_TEST_NATIVE_LIBRARY" unless File.file?(library)
  end

  it "hydrates geometry and preserves placeable headers, unknown siblings and trailing bytes through edits" do
    input = native_wmf_bytes([move, unknown], placeable: true)
    expect(Emf::Wmf::Parser).not_to receive(:call)
    expect(Emf::Wmf::TextCodec).not_to receive(:decode)
    parsed = Emf.parse(input)
    expect(parsed.format).to eq(:wmf)
    expect(parsed.records.map(&:class)).to eq([
                                                Emf::Model::Wmf::Records::MoveTo, Emf::Model::Wmf::Records::UnknownRecord, Emf::Model::Wmf::Records::Eof
                                              ])
    expect(parsed.header.number_of_members).to eq(7)
    expect(parsed.header.placeable.left).to eq(-5)
    expect(parsed.records.first.type_id).to eq(0xAB14)
    expect(parsed.records[1].raw_bytes).to eq(unknown)
    expect(parsed.trailing).to eq("tail")
    expect(Emf.serialize(parsed)).to eq(input)
    parsed.records.first.x = -123
    parsed.header.placeable.left = -90
    edited = Emf.parse(Emf.serialize(parsed))
    expect(edited.records.first.x).to eq(-123)
    expect(edited.header.placeable.left).to eq(-90)
    expect(edited.records[1].raw_bytes).to eq(unknown)
    expect(edited.trailing).to eq("tail")
  end

  it "hydrates objects and point arrays with signed coordinates and editable typed fields" do
    pen = native_wmf_record(0x02FA, [3, -2, -4, 0xFF123456].pack("vs<2V"))
    select = native_wmf_record(0x012D, [0].pack("v"))
    points = native_wmf_record(0x0538, [2, 2, 1, -5, 6, 7, -8, 9, 10].pack("v3s<6"))
    input = native_wmf_bytes([pen, select, points, unknown])
    parsed = Emf.parse(input)
    expect(parsed.records.first.width_x).to eq(-2)
    expect(parsed.records.first.color_ref).to eq(0xFF123456)
    expect(parsed.records[2].points_per_polygon).to eq([2, 1])
    expect(parsed.records[2].points.map { |point| [point.x, point.y] }).to eq([[-5, 6], [7, -8], [9, 10]])
    expect(Emf.serialize(parsed)).to eq(input)
    parsed.records.first.width_y = -21
    parsed.records[2].points.first.x = -19
    reparsed = Emf.parse(Emf.serialize(parsed))
    expect(reparsed.records.first.width_y).to eq(-21)
    expect(reparsed.records[2].points.first.x).to eq(-19)
  end

  it "hydrates both text models without Ruby decoding and preserves arbitrary padding and suffix bytes" do
    text = native_wmf_record(0x0521, "#{[3].pack('s<')}#{"a\x80z".b}PAD#{[-5, 8].pack('s<2')}")
    extended = native_wmf_record(0x0A32, "#{[-2, 7, 3, 6, -4, 5, 6, -7].pack('s<3vs<4')}#{"x\xFFy!".b}#{[-1, 2, -3].pack('s<3')}ZZ")
    input = native_wmf_bytes([text, extended, unknown])
    expect(Emf::Wmf::Parser).not_to receive(:call)
    expect(Emf::Wmf::TextCodec).not_to receive(:decode)
    parsed = Emf.parse(input)
    expect(parsed.records.first.text).to eq("a\x80z".b)
    expect(parsed.records.first.padding).to eq("PAD")
    expect(parsed.records[1].rectangle.left).to eq(-4)
    expect(parsed.records[1].dx).to eq([-1, 2, -3])
    expect(parsed.records[1].suffix).to eq("ZZ")
    expect(Emf.serialize(parsed)).to eq(input)
    parsed.records.first.text = "new"
    parsed.records[1].dx[0] = -15
    reparsed = Emf.parse(Emf.serialize(parsed))
    expect(reparsed.records.first.text).to eq("new")
    expect(reparsed.records[1].dx.first).to eq(-15)
    expect(reparsed.records[1].suffix).to eq("ZZ")
  end

  it "preserves Ruby spacing and suffix semantics when the PDY flag is set" do
    records = [
      native_wmf_record(0x0A32, "#{[2, -3, 2, 0x2000].pack('s<3v')}xy#{[-4, 5].pack('s<2')}"),
      native_wmf_record(0x0A32, "#{[2, -3, 2, 0x2000].pack('s<3v')}xy#{[-4, 5, 6, -7].pack('s<4')}")
    ]
    input = native_wmf_bytes(records)
    expect(Emf::Wmf::Parser).not_to receive(:call)
    expect(Emf::Wmf::TextCodec).not_to receive(:decode)
    parsed = Emf.parse(input)
    expect(parsed.records[0].dx).to eq([-4, 5])
    expect(parsed.records[0].suffix).to eq("")
    expect(parsed.records[1].dx).to eq([-4, 5])
    expect(parsed.records[1].suffix).to eq([6, -7].pack("s<2"))
    expect(Emf.serialize(parsed)).to eq(input)
    parsed.records[1].dx[0] = 13
    expect(Emf.parse(Emf.serialize(parsed)).records[1].dx).to eq([13, 5])
  end

  it "rejects malformed Ruby typed families and invalid object references without Ruby retry" do
    malformed = [
      native_wmf_record(0x0214, [1].pack("s<")),
      native_wmf_record(0x0324, [1, 2, 3].pack("s<3")),
      native_wmf_record(0x0521, [-1, 0, 0].pack("s<3")),
      native_wmf_record(0x012D, [0].pack("v"))
    ]
    expect(Emf::Wmf::Parser).not_to receive(:call)
    malformed.each do |record|
      expect { Emf.parse(native_wmf_bytes([record])) }.to raise_error(Emf::Error)
    end
  end

  it "keeps Rust-only families unknown even when their native payload is malformed" do
    # SetBkColor is understood by Rust but has no typed Ruby WMF model.
    record = native_wmf_record(0x0201, [3].pack("v"))
    input = native_wmf_bytes([record])
    expect(Emf::Wmf::Parser).not_to receive(:call)
    expect(Emf::Wmf::TextCodec).not_to receive(:decode)
    parsed = Emf.parse(input)
    expect(parsed.records.first).to be_a(Emf::Model::Wmf::Records::UnknownRecord)
    expect(parsed.records.first.raw_bytes).to eq(record)
    expect(Emf.serialize(parsed)).to eq(input)
  end

  it "preserves newly typed native escape records as opaque Ruby records" do
    passthrough = [0xDEADBEEF, 1, 0x80].pack("VvC")
    color_table = [12, 0].pack("v2") + [0x11223344].pack("V")
    postscript = "#{[36, 1, -1, 2, -3, 4, -5, 6].pack('V2l<6')}EPS!"
    escapes = [
      native_wmf_escape(0x11D8, passthrough, padding: "\xF7".b),
      native_wmf_escape(0x0005, color_table),
      native_wmf_escape(0x1014, postscript)
    ]
    input = native_wmf_bytes([*escapes, unknown])
    expect(Emf::Wmf::Parser).not_to receive(:call)
    parsed = Emf.parse(input)
    expect(parsed.errors).to be_empty
    expect(parsed.records.first(3).map(&:class)).to all(eq(Emf::Model::Wmf::Records::UnknownRecord))
    expect(parsed.records.first(3).map(&:raw_bytes)).to eq(escapes)
    expect(parsed.records[3].raw_bytes).to eq(unknown)
    expect(Emf.serialize(parsed)).to eq(input)

    reparsed = Emf.parse(Emf.serialize(parsed))
    expect(reparsed.records.first(3).map(&:raw_bytes)).to eq(escapes)
    expect(reparsed.records[3].raw_bytes).to eq(unknown)
  end

  it "matches Ruby rejection of invalid headers, EOF boundaries and object state" do
    ordinary = native_wmf_bytes([move])
    placeable = native_wmf_bytes([move], placeable: true)
    malformed = [
      ordinary.dup.tap { |bytes| bytes[4, 2] = [0x200].pack("v") },
      ordinary.dup.tap { |bytes| bytes[6, 4] = [8].pack("V") },
      ordinary.dup.tap { |bytes| bytes[6, 4] = [bytes.bytesize].pack("V") },
      placeable.dup.tap { |bytes| bytes[20, 2] = [1].pack("v") },
      placeable.dup.tap do |bytes|
        bytes[16, 4] = [1].pack("V")
        bytes[20, 2] = [Emf::Wmf::Binary.checksum(bytes.byteslice(0, 20))].pack("v")
      end,
      native_wmf_bytes([native_wmf_record(0, "xx")]),
      native_wmf_bytes([native_wmf_record(0, ""), move]),
      native_wmf_bytes([native_wmf_record(0x01F0, [0].pack("v"))])
    ]
    malformed.each { |bytes| expect { Emf::Wmf::Parser.call(bytes) }.to raise_error(Emf::Error) }
    expect(Emf::Wmf::Parser).not_to receive(:call)
    expect(Emf::Wmf::TextCodec).not_to receive(:decode)
    malformed.each { |bytes| expect { Emf.parse(bytes) }.to raise_error(Emf::Error) }
  end

  it "rejects a wrong MaxRecord even when all individual records are valid" do
    input = native_wmf_bytes([move])
    input[12, 4] = [3].pack("V")
    expect { Emf.parse(input) }.to raise_error(Emf::Error)
  end
end
