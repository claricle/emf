# frozen_string_literal: true

require_relative "../support/native_wmf_bridge"

RSpec.describe "Native WMF bitmap transfer controls" do
  include_context "native WMF bridge"

  let(:image) { "\xDE\xAD\xBE\xEF".b }
  let(:unknown) { native_wmf_record(0x7FFE, "raw!") }
  let(:trailing) { "\x91\x00tail".b }
  let(:bodies) do
    rop = [0xFEDCBA98].pack("V")
    blt = rop + [-32_768, 32_767, -3, 4, -5, 6].pack("s<6") + image
    stretch = rop + [-32_768, 32_767, -3, 4, -5, 6, -7, 8].pack("s<8") + image
    device = [65_535, 65_534, 65_533, 65_532, 65_531, 65_530, 65_529, 65_528, 65_527].pack("v*") + image
    dib_stretch = [0xFEDCBA98, 65_535].pack("Vv") + stretch.byteslice(4..)

    { 0x0922 => blt, 0x0940 => blt, 0x0B23 => stretch, 0x0B41 => stretch,
      0xAD33 => device, 0xBE43 => dib_stretch }
  end

  it "rejects malformed typed headers and missing mandatory images without Ruby retry" do
    expect(Emf::Wmf::Parser).not_to receive(:call)

    header_sizes = { 0x22 => 16, 0x40 => 16, 0x23 => 20, 0x41 => 20, 0x33 => 18, 0x43 => 22 }
    bodies.each do |function, body|
      header_size = header_sizes.fetch(function & 0xFF)
      malformed_header = body.byteslice(0, header_size - 2)
      expect { Emf.parse(native_wmf_bytes([native_wmf_record(function, malformed_header)])) }
        .to raise_error(Emf::ParseError)
    end

    [0xAD33, 0xBE43].each do |function|
      header_size = header_sizes.fetch(function & 0xFF)
      header_only = bodies.fetch(function).byteslice(0, header_size)
      expect { Emf.parse(native_wmf_bytes([native_wmf_record(function, header_only)])) }
        .to raise_error(Emf::ParseError)
    end
  end

  it "edits all six images and preserves unknown records and trailing bytes through reparse" do
    expect(Emf::Wmf::Parser).not_to receive(:call)
    suffix = "more".b
    input_records = bodies.map { |function, body| native_wmf_record(function, body) }
    input = native_wmf_bytes([*input_records, unknown], placeable: true, trailing: trailing)

    parsed = Emf.parse(input)
    expect(parsed.records.take(6).map(&:bitmap)).to eq(Array.new(6, image))
    parsed.records.take(6).each { |record| record.bitmap += suffix }

    edited_records = bodies.map { |function, body| native_wmf_record(function, body + suffix) }
    expected = native_wmf_bytes([*edited_records, unknown], placeable: true, trailing: trailing)
    output = Emf.serialize(parsed)
    expect(output).to eq(expected)

    reparsed = Emf.parse(output)
    expect(reparsed.records.take(6).map(&:bitmap)).to eq(Array.new(6, image + suffix))
    expect(reparsed.records[-2].raw_bytes).to eq(unknown)
    expect(reparsed.trailing).to eq(trailing)
  end
end
