# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/emf/native/wmf_fields"

RSpec.describe Emf::Native::WmfFields do
  let(:type) { 0x0102 }
  let(:offset) { 22 }
  let(:payload) { [2].pack("V") }
  let(:raw) { [4, type, 2].pack("Vvv") }
  let(:descriptor) { { type: type, offset: offset, payload: payload, family: 6 } }
  let(:font_type) { 0x02FB }
  let(:font_payload) do
    ([12, 0, 0, 0, 400] + Array.new(8, 0) + ["Example".b.ljust(32, "\x00".b)]).then do |values|
      [values.first(5).pack("l<5"), values[5, 8].pack("V8"), values.last].join.b
    end
  end
  let(:font_wire_payload) do
    [12, 0, 0, 0, 400].pack("s<5") + Array.new(8, 0).pack("C8") + "Example".b.ljust(32, "\x00".b)
  end
  let(:font_raw) { [28].pack("V") + [font_type].pack("v") + font_wire_payload }
  let(:font_descriptor) { { type: font_type, offset: offset, payload: font_payload, family: 7 } }
  let(:palette_type) { 0x00F7 }
  let(:palette_payload) { [0x0300, 2, 1, 2, 3, 4, 5, 6, 7, 8].pack("V*") }
  let(:palette_raw) { [9, palette_type].pack("Vv") + [0x0300, 2].pack("v2") + [1, 2, 3, 4, 5, 6, 7, 8].pack("C*") }
  let(:palette_descriptor) { { type: palette_type, offset: offset, payload: palette_payload, family: 8 } }
  let(:region_type) { 0x06FF }
  let(:region_payload) do
    [0xABCD, 0x12345678].pack("V2") + [-2, -32_768, 300, 400].pack("l<4") +
      [2, 32_769, 65_534, 1, 32_770, 65_535, 30, 40, 2, 10, 20, 50, 60].pack("V*")
  end
  let(:region_raw) do
    body = [0xABCD, 6, 0x5678, 0x1234, 50, 2, 4, 0xFFFE, 0x8000, 300, 400,
            2, 0x8001, 0xFFFE, 0x8002, 0xFFFF, 2, 4, 30, 40, 10, 20, 50, 60, 4].pack("v*")
    [28, region_type].pack("Vv") + body
  end
  let(:region_descriptor) { { type: region_type, offset: offset, payload: region_payload, family: 9 } }
  let(:pattern_type) { 0x01F9 }
  let(:pattern_bytes) { "\xAA\xBB".b }
  let(:pattern_payload) do
    [-2, 3, 1, 2, 1, 1].pack("V6") + "\x10\x20\x30\x40".b + ("\x55".b * 18) + [pattern_bytes.bytesize].pack("V") + pattern_bytes
  end
  let(:pattern_raw) do
    [20, pattern_type].pack("Vv") + [-2, 3, 1, 2].pack("s<4") + [1, 1].pack("C2") +
      "\x10\x20\x30\x40".b + ("\x55".b * 18) + pattern_bytes
  end
  let(:pattern_descriptor) { { type: pattern_type, offset: offset, payload: pattern_payload, family: 10 } }
  let(:dib_pattern_type) { 0x0142 }
  let(:dib_target) { "\xDE\xAD\xBE\xEF".b }
  let(:dib_pattern_payload) { [3, 0, dib_target.bytesize].pack("V3") + dib_target }
  let(:dib_pattern_raw) { [8, dib_pattern_type].pack("Vv") + [3, 0].pack("v2") + dib_target }
  let(:dib_pattern_descriptor) { { type: dib_pattern_type, offset: offset, payload: dib_pattern_payload, family: 10 } }
  let(:bitmap_type) { 0x0122 }
  let(:bitmap_bytes) { "\xDE\xAD\xBE\xEF".b }

  let(:bitmap_descriptor) do
    lambda do |type, scalars, present:, bytes: "".b|
      payload = [*scalars, present ? 1 : 0, bytes.bytesize].pack("V*") + bytes
      { type: type, offset: offset, payload: payload, family: 11 }
    end
  end
  let(:bitmap_raw) do
    lambda do |type, body, suffix: "".b|
      bytes = body + suffix
      [3 + (bytes.bytesize / 2), type].pack("Vv") + bytes
    end
  end

  it "rejects a supported state with a non-state native family" do
    record = descriptor.merge(family: 4)

    expect { described_class.new(record, raw).call }.to raise_error(Emf::Error)
  end

  it "rejects a state payload whose LE-u32 field count is wrong" do
    record = descriptor.merge(payload: "".b)

    expect { described_class.new(record, raw).call }.to raise_error(Emf::Error)
  end

  it "rejects a u16 state value that exceeds its unsigned range" do
    record = descriptor.merge(payload: [0x10000].pack("V"))

    expect { described_class.new(record, raw).call }.to raise_error(Emf::Error)
  end

  it "rejects a raw state record shorter than its fixed prefix" do
    expect { described_class.new(descriptor, raw.byteslice(0, 6)).call }.to raise_error(Emf::Error)
  end

  it "decodes a native font descriptor and preserves its raw wire suffix" do
    suffix = "\xAA\xBB".b
    record = described_class.new(font_descriptor, font_raw + suffix).call

    expect(record).to be_a(Emf::Model::Wmf::Records::CreateFontIndirect)
    expect(record.height).to eq(12)
    expect(record.weight).to eq(400)
    expect(record.face_name).to eq("Example".b.ljust(32, "\x00".b))
    expect(record.suffix).to eq(suffix)
  end

  it "rejects malformed native font descriptors" do
    invalid = [
      [font_descriptor.merge(family: 6), font_raw],
      [font_descriptor.merge(payload: font_payload.byteslice(0, 83)), font_raw],
      [font_descriptor.merge(payload: [-32_769, 0, 0, 0, 400].pack("l<5") + font_payload.byteslice(20..)), font_raw],
      [font_descriptor.merge(payload: [32_768, 0, 0, 0, 400].pack("l<5") + font_payload.byteslice(20..)), font_raw],
      [font_descriptor.merge(payload: font_payload.byteslice(0, 20) + [256].pack("V") + font_payload.byteslice(24..)), font_raw],
      [font_descriptor, font_raw.byteslice(0, 55)]
    ]

    invalid.each do |record, raw_bytes|
      expect { described_class.new(record, raw_bytes).call }.to raise_error(Emf::Error)
    end
  end

  it "decodes native palette entries and preserves the raw suffix" do
    suffix = "\xAA\xBB".b
    record = described_class.new(palette_descriptor, palette_raw + suffix).call

    expect(record).to be_a(Emf::Model::Wmf::Records::CreatePalette)
    expect(record.start).to eq(0x0300)
    expect(record.entries.map { |entry| [entry.red, entry.green, entry.blue, entry.flags] })
      .to eq([[1, 2, 3, 4], [5, 6, 7, 8]])
    expect(record.suffix).to eq(suffix)
  end

  it "rejects malformed family 8 payload lengths, ranges and raw bounds" do
    invalid = [
      [palette_descriptor.merge(family: 7), palette_raw],
      [palette_descriptor.merge(payload: palette_payload.byteslice(0, 31)), palette_raw],
      [palette_descriptor.merge(payload: [0x10000, 0].pack("V2")), [6, palette_type].pack("Vv")],
      [palette_descriptor.merge(payload: [0, 2, 1, 2, 3, 4, 256, 0, 0, 0].pack("V*")), palette_raw],
      [palette_descriptor, palette_raw.byteslice(0, 17)]
    ]

    invalid.each do |record, raw_bytes|
      expect { described_class.new(record, raw_bytes).call }.to raise_error(Emf::Error)
    end
  end

  it "decodes native CreateRegion scan data and preserves its raw suffix" do
    suffix = "\xAA\xBB".b
    raw_with_suffix = [29, region_type].pack("Vv") + region_raw.byteslice(6..) + suffix
    record = described_class.new(region_descriptor, raw_with_suffix).call

    expect(record).to be_a(Emf::Model::Wmf::Records::CreateRegion)
    expect([record.next_in_chain, record.object_count, record.bounds.to_a]).to eq([0xABCD, 0x12345678, [-2, -32_768, 300, 400]])
    expect(record.scans.map { |scan| [scan.top, scan.bottom, scan.lines.map(&:to_a)] })
      .to eq([[32_769, 65_534, [[32_770, 65_535]]], [30, 40, [[10, 20], [50, 60]]]])
    expect(record.suffix).to eq(suffix)
  end

  it "rejects malformed family 9 fields, scan counts and raw bounds" do
    invalid = [
      [region_descriptor.merge(family: 8), region_raw],
      [region_descriptor.merge(payload: region_payload.byteslice(0, 59)), region_raw],
      [region_descriptor.merge(payload: [0x10000].pack("V") + region_payload.byteslice(4..)), region_raw],
      [region_descriptor.merge(payload: [0xABCD, 0x12345678].pack("V2") +
        [32_768, -32_768, 300, 400].pack("l<4") + region_payload.byteslice(24..)), region_raw],
      [region_descriptor.merge(payload: [0xABCD, 0x12345678].pack("V2") + [-2, -32_768, 300, 400].pack("l<4") +
        [2, 32_769, 65_534, 1, 65_536, 65_535, 30, 40, 2, 10, 20, 50, 60].pack("V*")), region_raw],
      [region_descriptor, region_raw.byteslice(0, 12)]
    ]

    invalid.each do |record, raw_bytes|
      expect { described_class.new(record, raw_bytes).call }.to raise_error(Emf::Error)
    end
  end

  it "decodes native pattern brush fields and preserves exact bitmap bytes" do
    record = described_class.new(pattern_descriptor, pattern_raw).call

    expect(record).to be_a(Emf::Model::Wmf::Records::CreatePatternBrush)
    expect([record.bitmap_type, record.width, record.height, record.width_bytes, record.planes, record.bits_pixel])
      .to eq([-2, 3, 1, 2, 1, 1])
    expect(record.bits).to eq("\x10\x20\x30\x40".b)
    expect(record.reserved).to eq("\x55".b * 18)
    expect(record.pattern).to eq(pattern_bytes)
  end

  it "rejects malformed family 10 pattern payloads, narrowing and raw bounds" do
    invalid = [
      [pattern_descriptor.merge(family: 9), pattern_raw],
      [pattern_descriptor.merge(payload: pattern_payload.byteslice(0, 49)), pattern_raw],
      [pattern_descriptor.merge(payload: [32_768].pack("V") + pattern_payload.byteslice(4..)), pattern_raw],
      [pattern_descriptor.merge(payload: pattern_payload.byteslice(0, 16) + [256].pack("V") +
        pattern_payload.byteslice(20..)), pattern_raw],
      [pattern_descriptor.merge(payload: pattern_payload.byteslice(0, 46) + [3].pack("V") + pattern_bytes + "\x00\x00".b), pattern_raw],
      [pattern_descriptor, pattern_raw.byteslice(0, 39)]
    ]

    invalid.each do |record, raw_bytes|
      expect { described_class.new(record, raw_bytes).call }.to raise_error(Emf::Error)
    end
  end

  it "decodes DIB pattern brush fields while preserving the opaque target" do
    record = described_class.new(dib_pattern_descriptor, dib_pattern_raw).call

    expect(record).to be_a(Emf::Model::Wmf::Records::DibCreatePatternBrush)
    expect([record.style, record.color_usage, record.target]).to eq([3, 0, dib_target])
  end

  it "rejects malformed family 10 DIB pattern lengths and raw bounds" do
    invalid = [
      [dib_pattern_descriptor.merge(family: 8), dib_pattern_raw],
      [dib_pattern_descriptor.merge(payload: dib_pattern_payload.byteslice(0, 11)), dib_pattern_raw],
      [dib_pattern_descriptor.merge(payload: [65_536, 0, dib_target.bytesize].pack("V3") + dib_target), dib_pattern_raw],
      [dib_pattern_descriptor, dib_pattern_raw.byteslice(0, 9)]
    ]

    invalid.each do |record, raw_bytes|
      expect { described_class.new(record, raw_bytes).call }.to raise_error(Emf::Error)
    end
  end

  it "decodes family 11 optional blits and retains absent reserved words and suffixes" do
    cases = [
      [0x0922, Emf::Model::Wmf::Records::BitBlt, [0xCCBBAA99, -32_768, 32_767, -1, 2, -3, 4, 0xBEEF],
       [0xAA99, 0xCCBB, 0x8000, 0x7FFF, 0xBEEF, 0xFFFF, 2, 0xFFFD, 4].pack("v*"), :bitmap],
      [0x0940, Emf::Model::Wmf::Records::DibBitBlt, [0xCCBBAA99, -32_768, 32_767, -1, 2, -3, 4, 0xBEEF],
       [0xAA99, 0xCCBB, 0x8000, 0x7FFF, 0xBEEF, 0xFFFF, 2, 0xFFFD, 4].pack("v*"), :bitmap],
      [0x0B23, Emf::Model::Wmf::Records::StretchBlt, [0xCCBBAA99, -32_768, 32_767, -1, 2, -3, 4, -5, 6, 0xBEEF],
       [0xAA99, 0xCCBB, 0x8000, 0x7FFF, 0xFFFF, 2, 0xBEEF, 0xFFFD, 4, 0xFFFB, 6].pack("v*"), :bitmap],
      [0x0B41, Emf::Model::Wmf::Records::DibStretchBlt, [0xCCBBAA99, -32_768, 32_767, -1, 2, -3, 4, -5, 6, 0xBEEF],
       [0xAA99, 0xCCBB, 0x8000, 0x7FFF, 0xFFFF, 2, 0xBEEF, 0xFFFD, 4, 0xFFFB, 6].pack("v*"), :bitmap]
    ]

    cases.each do |function, klass, scalars, absent_body, _present|
      reserved = scalars.last
      suffix = "\xAA\xBB".b
      absent_type = (((absent_body.bytesize + suffix.bytesize) / 2) << 8) | (function & 0xFF)
      raw_bytes = bitmap_raw.call(absent_type, absent_body, suffix: suffix)
      record = described_class.new(bitmap_descriptor.call(absent_type, scalars, present: false), raw_bytes).call

      expect(record).to be_a(klass)
      expect(record.type_id).to eq(absent_type)
      expect(record.reserved).to eq(reserved)
      expect(record.bitmap).to be_nil
      expect(record.suffix).to eq(suffix)
    end
  end

  it "decodes family 11 present blits and mandatory DIB transfers, including opaque DIB bytes" do
    cases = [
      [0x0922, Emf::Model::Wmf::Records::BitBlt, [0xCCBBAA99, -32_768, 32_767, -1, 2, -3, 4, 0],
       [0xAA99, 0xCCBB, 0x8000, 0x7FFF, 0xFFFF, 2, 0xFFFD, 4].pack("v*"), :optional],
      [0x0940, Emf::Model::Wmf::Records::DibBitBlt, [0xCCBBAA99, -32_768, 32_767, -1, 2, -3, 4, 0],
       [0xAA99, 0xCCBB, 0x8000, 0x7FFF, 0xFFFF, 2, 0xFFFD, 4].pack("v*"), :optional],
      [0x0B23, Emf::Model::Wmf::Records::StretchBlt, [0xCCBBAA99, -32_768, 32_767, -1, 2, -3, 4, -5, 6, 0],
       [0xAA99, 0xCCBB, 0x8000, 0x7FFF, 0xFFFF, 2, 0xFFFD, 4, 0xFFFB, 6].pack("v*"), :optional],
      [0x0B41, Emf::Model::Wmf::Records::DibStretchBlt, [0xCCBBAA99, -32_768, 32_767, -1, 2, -3, 4, -5, 6, 0],
       [0xAA99, 0xCCBB, 0x8000, 0x7FFF, 0xFFFF, 2, 0xFFFD, 4, 0xFFFB, 6].pack("v*"), :optional],
      [0x0D33, Emf::Model::Wmf::Records::SetDibToDev, [2, 65_535, 32_768, 65_534, 1, 2, 3, 4, 5],
       [2, 0xFFFF, 0x8000, 0xFFFE, 1, 2, 3, 4, 5].pack("v*"), :mandatory],
      [0x0F43, Emf::Model::Wmf::Records::StretchDib, [0xCCBBAA99, 2, -32_768, 32_767, -1, 2, -3, 4, -5, 6],
       [0xAA99, 0xCCBB, 2, 0x8000, 0x7FFF, 0xFFFF, 2, 0xFFFD, 4, 0xFFFB, 6].pack("v*"), :mandatory]
    ]

    cases.each do |function, klass, scalars, wire_prefix, _presence|
      raw_bytes = bitmap_raw.call(function, wire_prefix + bitmap_bytes)
      record = described_class.new(bitmap_descriptor.call(function, scalars, present: true, bytes: bitmap_bytes), raw_bytes).call

      expect(record).to be_a(klass)
      expect(record.bitmap).to eq(bitmap_bytes)
      expect(record.type_id).to eq(function)
      expect(record.suffix).to eq("".b)
    end
  end

  it "rejects malformed family 11 payloads, narrowing, flags, raw bounds and source discriminators" do
    blt_scalars = [0xCCBBAA99, -1, 2, -3, 4, -5, 6, 0]
    blt_body = [0xAA99, 0xCCBB, 0xFFFF, 2, 0xFFFD, 4, 0xFFFB, 6].pack("v*") + bitmap_bytes
    good = bitmap_descriptor.call(bitmap_type, blt_scalars, present: true, bytes: bitmap_bytes)
    raw_bytes = bitmap_raw.call(bitmap_type, blt_body)
    expect { described_class.new(good, raw_bytes).call }.not_to raise_error
    invalid = [
      [good.merge(family: 10), raw_bytes],
      [good.merge(payload: good[:payload].byteslice(0, good[:payload].bytesize - 1)), raw_bytes],
      [good.merge(payload: [*blt_scalars, 2, bitmap_bytes.bytesize].pack("V*") + bitmap_bytes), raw_bytes],
      [good.merge(payload: [*blt_scalars, 1, bitmap_bytes.bytesize + 2].pack("V*") + bitmap_bytes), raw_bytes],
      [good.merge(payload: [blt_scalars.first, 32_768, *blt_scalars.drop(2), 1, bitmap_bytes.bytesize].pack("V*") + bitmap_bytes),
       raw_bytes],
      [good.merge(payload: [*blt_scalars, 1, bitmap_bytes.bytesize].pack("V*") + bitmap_bytes), raw_bytes.byteslice(0, 17)],
      [good, bitmap_raw.call(0x0A22, blt_body)],
      [bitmap_descriptor.call(bitmap_type, blt_scalars, present: false), bitmap_raw.call(0x0922, blt_body)]
    ]

    mandatory_type = 0x0D33
    mandatory_scalars = [2, 1, 0, 0, 0, 1, 1, 0, 0]
    mandatory_body = [2, 1, 0, 0, 0, 1, 1, 0, 0].pack("v*") + bitmap_bytes
    invalid << [bitmap_descriptor.call(mandatory_type, mandatory_scalars, present: false),
                bitmap_raw.call(mandatory_type, mandatory_body)]
    invalid << [bitmap_descriptor.call(mandatory_type, [0x10000, *mandatory_scalars.drop(1)], present: true, bytes: bitmap_bytes),
                bitmap_raw.call(mandatory_type, [2, 1, 0, 0, 0, 1, 1, 0, 0].pack("v*") + bitmap_bytes)]

    invalid.each do |record, raw_record|
      expect { described_class.new(record, raw_record).call }.to raise_error(Emf::Error)
    end
  end
end
