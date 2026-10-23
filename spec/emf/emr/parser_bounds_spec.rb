# frozen_string_literal: true

# The Ruby parser checks every declared count and span of a record against its
# nSize before it trusts them, reading the record in place at its offset.
RSpec.describe Emf::Emr::Parser, "bounds on a record read in place" do
  let(:codes) { Emf::Emr::Binary::TypeCodes }
  # Bytes before the record, so a read that ignores the offset sees these
  # (all-ones) values instead of the record's own.
  let(:pad) { ("\xFF".b * 12).freeze }

  def pack(*words) = words.pack("V*")

  def zeros(count) = [0] * count

  # type, nSize, bounds (4), count, then `count` 8-byte points
  def polygon(count, size: 28 + (count * 8))
    pack(codes::POLYGON, size, *zeros(4), count) + ("\x01".b * (count * 8))
  end

  # an ExtTextOutW with nChars `count`, string at `off_string`, Dx at `off_dx`
  def text(count:, off_string:, off_dx:, options: 0, size: 100)
    dx_at = options.anybits?(0x100) ? 56 : 72
    words = zeros((size - 8) / 4)
    words[(44 - 8) / 4] = count
    words[(48 - 8) / 4] = off_string
    words[(52 - 8) / 4] = options
    words[(dx_at - 8) / 4] = off_dx
    pack(codes::EXTTEXTOUTW, size, *words)
  end

  def sane?(type, size, bytes, base: 0)
    described_class.sane_at?(type, size, pad + bytes, pad.bytesize + base)
  end

  describe ".read_uint32" do
    it "reads a little-endian uint32 at an offset" do
      expect(described_class.read_uint32("\x00\x01\x02\x03\x84".b, 1)).to eq(0x84030201)
    end
  end

  describe ".filled_record_at" do
    def filled(data, offset) = described_class.filled_record_at(data, offset, data.bytesize)

    let(:select) { pack(37, 12, 5) }

    it "returns a byte-backed source for a complete fixed record at its offset" do
      source = filled((pad + select).b.freeze, pad.bytesize)
      expect(source.to_binary_s).to eq(select)
      expect(source.wire_class).to eq(Emf::Emr::Binary::Records::SelectObject)
    end

    it "declines when fewer than eight bytes remain" do
      expect(filled(select.byteslice(0, 7).b.freeze, 0)).to be_nil
      expect(filled((pad + select).b.freeze, pad.bytesize + 5)).to be_nil
    end

    it "declines an nSize below eight or past the end of the data" do
      expect(filled(pack(37, 4, 5).b.freeze, 0)).to be_nil
      expect(filled(pack(37, 7, 5).b.freeze, 0)).to be_nil
      expect(filled(pack(37, 16, 5).b.freeze, 0)).to be_nil
    end

    it "declines a type with no byte-backed layout" do
      expect(filled(pack(codes::EOF, 20, 0, 0, 0).b.freeze, 0)).to be_nil
    end

    it "serves a point record whose count fits and declines one whose count overruns" do
      good = polygon(2)
      expect(filled((pad + good).b.freeze, pad.bytesize)&.to_binary_s).to eq(good)
      bad = good.dup.tap { |copy| copy[24, 4] = pack(3) }
      expect(filled((pad + bad).b.freeze, pad.bytesize)).to be_nil
    end
  end

  describe ".variable_array_sane?" do
    it "judges a record sliced out of the stream, as it always has" do
      expect(described_class.variable_array_sane?(codes::POLYGON, 44, polygon(2))).to be(true)
      expect(described_class.variable_array_sane?(codes::POLYGON, 44, polygon(2).dup.tap { |copy| copy[24, 4] = pack(9) })).to be(false)
    end

    it "accepts a record whose arrays fit, read at a nonzero offset" do
      expect(sane?(codes::POLYGON, 44, polygon(2))).to be(true)
      expect(sane?(codes::POLYGON, 44, polygon(2), base: 0)).to be(true)
    end

    it "reads a record at its own base, not at the start of the data" do
      expect(described_class.sane_at?(codes::POLYGON, 44, polygon(2) + pad, 0)).to be(true)
      bad = polygon(2).dup.tap { |copy| copy[24, 4] = pack(9) }
      expect(sane?(codes::POLYGON, 44, bad)).to be(false)
    end

    it "keeps a record too short to hold its count field" do
      expect(sane?(codes::POLYGON, 27, polygon(0).byteslice(0, 27))).to be(true)
      expect(sane?(codes::CREATEPALETTE, 15, pack(codes::CREATEPALETTE, 15, 0, 0).b + ("\x00".b * 7))).to be(true)
    end

    it "rejects a count beyond the sane maximum even when nSize is huge" do
      bad = pack(codes::POLYGON, 28, *zeros(4), 1_000_001)
      expect(sane?(codes::POLYGON, 2**31, bad)).to be(false)
    end

    it "rejects a count whose entries run past nSize and accepts the exact fit" do
      expect(sane?(codes::POLYGON, 36, polygon(1).dup.tap { |copy| copy[24, 4] = pack(2) })).to be(false)
      expect(sane?(codes::POLYGON, 36, polygon(1))).to be(true)
    end

    it "reads a two-byte count for a palette" do
      record = pack(codes::CREATEPALETTE, 24, 0).b + ("\x00".b * 2) + [4].pack("v") + ("\x00".b * 6)
      expect(sane?(codes::CREATEPALETTE, 24, record)).to be(false)
      expect(sane?(codes::CREATEPALETTE, 24, record.dup.tap { |copy| copy[14, 2] = [2].pack("v") })).to be(true)
    end

    it "checks both counts of a multi-polygon record" do
      base = pack(codes::POLYPOLYGON, 44, *zeros(4), 1, 2) + pack(1, 0, 0, 0, 0)
      expect(sane?(codes::POLYPOLYGON, 44, base)).to be(false)
      expect(sane?(codes::POLYPOLYGON, 48, base.dup.tap { |copy| copy[28, 4] = pack(1) } + pack(0, 0, 0))).to be(true)
      fits = pack(codes::POLYPOLYGON, 52, *zeros(4), 1, 0) + pack(0)
      expect(sane?(codes::POLYPOLYGON, 36, fits)).to be(true)
      second_too_many = pack(codes::POLYPOLYGON, 36, *zeros(4), 1, 1_000_001) + pack(0)
      expect(sane?(codes::POLYPOLYGON, 2**31, second_too_many)).to be(false)
      second_overruns = pack(codes::POLYPOLYGON, 36, *zeros(4), 1, 2) + pack(0)
      expect(sane?(codes::POLYPOLYGON, 36, second_overruns)).to be(false)
    end

    it "bounds a region's data size by nSize, at its own offset" do
      region = pack(75, 28, 12) + ("\x00".b * 16)
      expect(sane?(75, 28, region)).to be(true)
      expect(sane?(75, 28, region.dup.tap { |copy| copy[8, 4] = pack(13) })).to be(false)
      expect(sane?(75, 11, region.byteslice(0, 11))).to be(false)
      create = pack(72, 48, *zeros(4), *zeros(4), 0, 0, 8) + ("\x00".b * 8)
      expect(sane?(72, 48, create.byteslice(0, 28) + pack(8) + create.byteslice(32..))).to be(true)
      expect(sane?(72, 27, create.byteslice(0, 27))).to be(false)
    end
  end

  describe "ExtTextOut spans" do
    it "accepts string and Dx spans that lie inside the record, aligned and apart" do
      expect(sane?(codes::EXTTEXTOUTW, 100, text(count: 2, off_string: 76, off_dx: 80))).to be(true)
      expect(sane?(codes::EXTTEXTOUTW, 100, text(count: 0, off_string: 0, off_dx: 0))).to be(true)
    end

    it "rejects a record shorter than its text fields without reading past it" do
      short = pack(codes::EXTTEXTOUTW, 40, *zeros(8))
      expect(described_class.sane_at?(codes::EXTTEXTOUTW, 40, short, 0)).to be(false)
    end

    it "rejects a record too short for its fixed fields" do
      expect(sane?(codes::EXTTEXTOUTW, 59, text(count: 0, off_string: 0, off_dx: 0).byteslice(0, 59))).to be(false)
      expect(sane?(codes::EXTTEXTOUTW, 72, text(count: 0, off_string: 0, off_dx: 0, size: 72))).to be(false)
      expect(sane?(codes::EXTTEXTOUTW, 60, text(count: 0, off_string: 0, off_dx: 0, options: 0x100, size: 60))).to be(true)
    end

    it "takes the Dx offset from the rect-less position when ETO_NO_RECT is set" do
      with_rect = text(count: 1, off_string: 76, off_dx: 88)
      no_rect = text(count: 1, off_string: 76, off_dx: 88, options: 0x100)
      expect(sane?(codes::EXTTEXTOUTW, 100, with_rect)).to be(true)
      expect(sane?(codes::EXTTEXTOUTW, 100, no_rect.dup.tap { |copy| copy[56, 4] = pack(400) })).to be(false)
    end

    it "rejects a span outside the record, before the fixed fields, or misaligned" do
      expect(sane?(codes::EXTTEXTOUTW, 100, text(count: 20, off_string: 76, off_dx: 0))).to be(false)
      expect(sane?(codes::EXTTEXTOUTW, 100, text(count: 1, off_string: 70, off_dx: 0))).to be(false)
      expect(sane?(codes::EXTTEXTOUTW, 100, text(count: 1, off_string: 77, off_dx: 0))).to be(false)
      expect(sane?(codes::EXTTEXTOUTW, 100, text(count: 1, off_string: 76, off_dx: 98))).to be(false)
    end

    it "sizes Dx entries at eight bytes with ETO_PDY and rejects overlapping spans" do
      expect(sane?(codes::EXTTEXTOUTW, 100, text(count: 2, off_string: 76, off_dx: 88))).to be(true)
      expect(sane?(codes::EXTTEXTOUTW, 100, text(count: 2, off_string: 76, off_dx: 88, options: 0x2000))).to be(false)
      expect(sane?(codes::EXTTEXTOUTW, 100, text(count: 2, off_string: 76, off_dx: 78))).to be(false)
      expect(sane?(codes::EXTTEXTOUTW, 100, text(count: 4, off_string: 84, off_dx: 76))).to be(false)
    end
  end

  describe ".read_record_at" do
    let(:errors) { [] }
    let(:select) { pack(37, 12, 5) }

    def read(bytes, offset = 0) = described_class.read_record_at(bytes.b.freeze, offset, errors)

    it "reads a record at its offset and reports nothing" do
      wire, suffix = read(pad + select, pad.bytesize)
      expect(wire.to_binary_s).to eq(select)
      expect(suffix).to be_empty
      expect(errors).to be_empty
    end

    it "returns nil without an error at the end of the data" do
      expect(read(select, select.bytesize)).to be_nil
      expect(errors).to be_empty
    end

    it "reports a short header, an nSize below eight, and a truncated record" do
      expect(read(select.byteslice(0, 5))).to be_nil
      expect(read(pack(37, 4, 5))).to be_nil
      expect(read(pack(37, 20, 5))).to be_nil
      expect(errors.map(&:message)).to eq(["truncated record header at offset 0 (5 bytes)",
                                           "record nSize 4 < 8 bytes (offset 0)",
                                           "truncated record at offset 0 (claimed 20, got 4)"])
      expect(errors.map(&:record_code)).to eq([nil, 37, 37])
    end

    it "keeps a record with an overrunning count as Raw bytes and reports it" do
      bad = polygon(2).dup.tap { |copy| copy[24, 4] = pack(9) }
      wire, suffix = read(pad + bad, pad.bytesize)
      expect(wire).to be_a(Emf::Emr::Binary::Records::Raw)
      expect(wire.to_binary_s).to eq(bad)
      expect(suffix).to be_empty
      expect(errors.map(&:message)).to eq(["variable-array record at offset #{pad.bytesize} declares " \
                                           "more entries than nSize allows; preserving as Raw"])
    end

    it "reads a sane variable-array record typed" do
      wire, = read(pad + polygon(2), pad.bytesize)
      expect(wire).to be_a(Emf::Emr::Binary::Records::Polygon)
      expect(errors).to be_empty
    end
  end
end
