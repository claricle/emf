# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/wmf_geometry"

RSpec.describe "WMF text records" do
  include WmfGeometrySupport

  def text_record(function, payload)
    [3 + (payload.bytesize / 2), function].pack("Vv") + payload
  end

  def text_out(text, x: -123, y: 456, padding: "\xFE".b, function: 0x0521)
    text_record(function, [text.bytesize].pack("s<") + text + (text.bytesize.odd? ? padding : "".b) + [y, x].pack("s<2"))
  end

  def ext_text_out(text, options: 0, rectangle: "".b, dx: "".b, suffix: "".b, function: 0x0A32)
    text_record(function, [-32_768, 32_767, text.bytesize, options].pack("s<3v") + rectangle + text +
                           (text.bytesize.odd? ? "\xFD".b : "".b) + dx + suffix)
  end

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("EMF_BACKEND", "auto").and_return("ruby")
  end

  it "decodes raw text bytes, signed positions, embedded nulls and nonzero padding" do
    raw = text_out("\xFF\x00\x81".b)
    bytes = geometry_file([raw])
    record = Emf.parse(bytes).records.first
    expect(record).to be_a(Emf::Model::Wmf::Records::TextOut)
    expect([record.text, record.x, record.y, record.padding, record.offset])
      .to eq(["\xFF\x00\x81".b, -123, 456, "\xFE".b, 18])
    expect(record.text.encoding).to eq(Encoding::BINARY)
    expect(Emf.serialize(Emf.parse(bytes))).to eq(bytes)
  end

  it "preserves expanded TextOut string padding and reads coordinates from the final words" do
    raw = text_out("abc".b, padding: "\xFE\xBE\xEF".b)
    bytes = geometry_file([raw])
    record = Emf.parse(bytes).records.first
    expect([record.padding, record.x, record.y]).to eq(["\xFE\xBE\xEF".b, -123, 456])
    expect(Emf.serialize(Emf.parse(bytes))).to eq(bytes)
  end

  it "decodes optional rectangles in left top right bottom order for either rectangle flag" do
    rectangle = [-1, -2, 3, 4].pack("s<4")
    [2, 4, 6, 0xFFFF].each do |options|
      bytes = geometry_file([ext_text_out("\x81\x00".b, options: options, rectangle: rectangle)])
      record = Emf.parse(bytes).records.first
      expect(record).to be_a(Emf::Model::Wmf::Records::ExtTextOut)
      expect([record.text, record.x, record.y, record.options, record.rectangle.to_a, record.dx])
        .to eq(["\x81\x00".b, 32_767, -32_768, options, [-1, -2, 3, 4], nil])
      expect(Emf.serialize(Emf.parse(bytes))).to eq(bytes)
    end
  end

  it "preserves optional signed spacing, unknown option bits and suffix bytes" do
    bytes = geometry_file([ext_text_out("abc".b, options: 0xA010, dx: [-32_768, 0, 32_767].pack("s<3"), suffix: "\xBE\xEF".b)])
    record = Emf.parse(bytes).records.first
    expect([record.dx, record.options, record.padding, record.suffix]).to eq([[-32_768, 0, 32_767], 0xA010, "\xFD".b, "\xBE\xEF".b])
    expect(Emf.serialize(Emf.parse(bytes))).to eq(bytes)
  end

  it "round-trips empty strings and absent spacing arrays" do
    records = [text_out("".b), ext_text_out("".b), ext_text_out("ab".b), ext_text_out("".b, suffix: "\xBE\xEF".b)]
    bytes = geometry_file(records)
    decoded = Emf.parse(bytes).records.take(4)
    expect(decoded.map(&:text)).to eq(["", "", "ab", ""])
    expect(decoded.drop(1).map(&:dx)).to eq([nil, nil, nil])
    expect(decoded.last.suffix).to eq("\xBE\xEF".b)
    expect(Emf.serialize(Emf.parse(bytes))).to eq(bytes)
  end

  it "constructs records and serializes text, rectangle, spacing and position edits exactly" do
    models = Emf::Model::Wmf::Records
    metafile = Emf.parse(geometry_file([], placeable: true, trailing: "tail"))
    plain = models::TextOut.new(text: "a".b, x: 1, y: 2)
    extended = models::ExtTextOut.new(text: "a".b, x: 3, y: 4)
    plain.text = "even".b
    plain.x = -32_768
    plain.y = 32_767
    extended.text = "xyz".b
    extended.x = 32_767
    extended.y = -32_768
    extended.options = 6
    extended.rectangle = models::TextRectangle.new(left: -4, top: -3, right: 2, bottom: 1)
    extended.dx = [-1, 0, 1]
    extended.padding = "\xFD".b
    extended.suffix = "\xAA\xBB".b
    edited = geometry_with_records(metafile, [plain, extended, metafile.records.last])
    expected = geometry_file([text_out("even".b, x: -32_768, y: 32_767),
                              ext_text_out("xyz".b, options: 6, rectangle: [-4, -3, 2, 1].pack("s<4"),
                                                    dx: [-1, 0, 1].pack("s<3"), suffix: "\xAA\xBB".b)],
                             placeable: true, trailing: "tail")
    expect(Emf.serialize(edited)).to eq(expected)
    extended.options = 0
    extended.rectangle = nil
    extended.dx = nil
    extended.suffix = "".b
    expect(Emf.parse(Emf.serialize(edited)).records[1].rectangle).to be_nil
  end

  it "preserves high function words, unknown siblings and trailing bytes in both header forms" do
    unknown = text_record(0x7FFE, "\xAA\xBB".b)
    [false, true].each do |placeable|
      bytes = geometry_file([unknown, text_out("abc".b, function: 0x7F21),
                             ext_text_out("ab".b, function: 0x7F32), unknown], placeable: placeable, trailing: "tail\xFF".b)
      records = Emf.parse(bytes).records
      expect(records.values_at(1, 2).map(&:type_id)).to eq([0x7F21, 0x7F32])
      expect(records.values_at(0, 3).map(&:raw_bytes)).to eq([unknown, unknown])
      expect(Emf.serialize(Emf.parse(bytes))).to eq(bytes)
    end
  end

  it "bounds signed counts before reading strings or allocating spacing arrays" do
    invalid = [text_record(0x0521, [-1, 0, 0].pack("s<3")),
               text_record(0x0521, [32_767, 0, 0].pack("s<3")),
               text_record(0x0A32, [0, 0, -1, 0].pack("s<3v")),
               text_record(0x0A32, [0, 0, 32_767, 0].pack("s<3v"))]
    invalid.each do |raw|
      expect { Emf.parse(geometry_file([raw])) }.to raise_error(Emf::ParseError) do |error|
        expect(error.offset).to eq(18)
        expect(error.record_code).to eq(raw.byteslice(4, 2).unpack1("v"))
        expect(error.message).to match(/negative text length|truncated text string/)
      end
    end
  end

  it "rejects truncated prefixes, required rectangles, alignment bytes and partial spacing arrays" do
    missing_alignment = [0, 0, 3, 0].pack("s<3v")
    invalid = [text_record(0x0521, "\x00\x00".b), text_record(0x0A32, "\x00\x00".b),
               text_record(0x0A32, [0, 0, 0, 6].pack("s<3v") + "\x00\x00".b),
               text_record(0x0A32, "#{missing_alignment}ab"),
               ext_text_out("abc".b, dx: [1, 2].pack("s<2"))]
    invalid.each do |raw|
      expect { Emf.parse(geometry_file([raw])) }.to raise_error(Emf::ParseError, /truncated text/)
    end
  end

  it "accepts the maximum signed byte count and rejects larger edited text" do
    bytes = geometry_file([ext_text_out("a" * 32_767)])
    metafile = Emf.parse(bytes)
    expect(Emf.serialize(metafile)).to eq(bytes)
    metafile.records.first.text << "b"
    expect { Emf.serialize(metafile) }.to raise_error(Emf::SerializeError, /StringLength/)
  end

  it "rejects invalid edits and typed functions disguised as unknown records" do
    metafile = Emf.parse(geometry_file([ext_text_out("abc".b)]))
    record = metafile.records.first
    { text: nil, x: 32_768, y: -32_769, padding: "ab", options: 65_536,
      rectangle: Object.new, dx: [1, 2], suffix: "x" }.each do |field, value|
      original = record.public_send(field)
      record.public_send("#{field}=", value)
      expect { Emf.serialize(metafile) }.to raise_error(Emf::SerializeError)
      record.public_send("#{field}=", original)
    end
    record.dx = [-32_769, 0, 0]
    expect { Emf.serialize(metafile) }.to raise_error(Emf::SerializeError, /Dx/)
    record.dx = nil
    record.suffix = "xx"
    expect { Emf.serialize(metafile) }.to raise_error(Emf::SerializeError, /complete spacing array/)
    record.suffix = "".b
    record.options = 6
    expect { Emf.serialize(metafile) }.to raise_error(Emf::SerializeError, /require a rectangle/)
    mismatch = Emf::Model::Wmf::Records::ExtTextOut.new(text: "", x: 0, y: 0, type_id: 0x0521)
    expect { Emf.serialize(geometry_with_records(metafile, [mismatch, metafile.records.last])) }
      .to raise_error(Emf::SerializeError, /RecordFunction mismatch/)
    [text_out("abc".b), ext_text_out("abc".b)].each do |raw|
      opaque = Emf::Model::Wmf::Records::UnknownRecord.new(type_id: raw.byteslice(4, 2).unpack1("v"), raw_bytes: raw)
      expect { Emf.serialize(geometry_with_records(metafile, [opaque, metafile.records.last])) }
        .to raise_error(Emf::SerializeError, /invalid raw WMF record/)
    end
  end
end
