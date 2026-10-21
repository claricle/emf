# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/native_wmf"

# Vectors mirror emf-rs/crates/emf-core/tests/wmf_dib.rs so both sides agree on semantics.
RSpec.describe "WMF Bitmap16 and DIB views" do
  include NativeWmfSupport

  def info(width, height, bits, compression, image_size, used)
    [40, width, height].pack("Vl<2") + [1, bits].pack("v2") + [compression, image_size, 123, 456, used, 0].pack("V2l<2V2")
  end

  let(:core_pixels) { [0xA0, 0x91, 0x82, 0x73, 0x60, 0x51, 0x42, 0x33, 0xCC, 0xDD].pack("C*") }
  let(:masks) { [0xF800, 0x7E0, 0x1F].pack("V3") }
  let(:masked_pixels) { [0x1F, 0, 0xAB, 0xCD, 0xEF, 0].pack("C*") }
  let(:rle_payload) { [0xFF, 0, 0x98, 0x76, 0x54, 0xAA].pack("C*") }

  def core
    [12, 3, 2, 1, 1].pack("Vv4")
  end

  def dib(bytes, usage = 0)
    Emf::Wmf::Dib.parse(bytes, usage)
  end

  it "separates core RGB triples, palette words and absent tables" do
    [[0, [1, 2, 3, 4, 5, 6], :rgb_triples, [[1, 2, 3], [4, 5, 6]]],
     [1, [5, 0, 9, 0], :palette_indices, [5, 9]],
     [2, [], :none, []]].each do |usage, table, kind, entries|
      bytes = core + table.pack("C*") + core_pixels
      view = dib(bytes, usage)

      expect([view.colors.kind, view.colors.rows, view.pixels.bytesize, view.trailing]).to eq([kind, entries, 8, "\xCC\xDD".b])
      expect(view.header.to_h).to eq(width: 3, height: 2, planes: 1, bit_count: 1)
    end
  end

  it "uses dword stride and signed height, ignoring the declared size" do
    bytes = info(3, -2, 24, 0, 0xFFFFFFFF, 0) + (0...24).to_a.pack("C*") + "\xFE\xED".b
    view = dib(bytes)

    expect([view.pixels.bytes, view.trailing, view.header.height, view.header.image_size])
      .to eq([(0...24).to_a, "\xFE\xED".b, -2, 0xFFFFFFFF])
  end

  it "reads RGB quads and palette indices from colors_used" do
    quads = dib(info(1, 1, 8, 0, 0, 2) + [1, 2, 3, 4, 5, 6, 7, 8, 0, 0xEE, 0xDD, 0xCC].pack("C*"))
    palette = dib(info(1, 1, 8, 0, 0, 2) + [7, 0, 8, 0, 0, 0xEE, 0xDD, 0xCC].pack("C*"), 1)

    expect(quads.colors.to_h).to eq(kind: :rgb_quads, rows: [[1, 2, 3, 4], [5, 6, 7, 8]])
    expect(palette.colors.to_h).to eq(kind: :palette_indices, rows: [7, 8])
    expect([quads.pixels.bytes, palette.pixels.bytes]).to eq([[0, 0xEE, 0xDD, 0xCC]] * 2)
  end

  it "keeps external and embedded bitfield masks apart from pixels" do
    [40, 52, 108, 124, 128].each do |size|
      bytes = info(1, 1, 16, 3, 99, 0)
      bytes[0, 4] = [size].pack("V")
      bytes += masks
      bytes = bytes.ljust(size, "\x59".b) if size > 40
      bytes += masked_pixels
      view = dib(bytes)

      expect(view.bitfield_masks).to eq(size == 40 ? [0xF800, 0x7E0, 0x1F] : nil)
      expect([view.pixels.bytes, view.trailing.bytes]).to eq([[0x1F, 0, 0xAB, 0xCD], [0xEF, 0]])
    end
  end

  it "takes compressed payloads from the declared extent without decoding" do
    [[1, 8], [2, 4], [4, 0], [5, 0], [12, 8], [13, 4]].each do |compression, bits|
      view = dib(info(10, 20, bits, compression, 5, 0) + rle_payload, 2)

      expect([view.pixels.bytes, view.trailing.bytes]).to eq([[0xFF, 0, 0x98, 0x76, 0x54], [0xAA]])
    end
  end

  it "returns nil for every truncation and for unsupported layouts" do
    valid = info(1, 1, 24, 0, 0, 0) + [1, 2, 3, 0].pack("C*")
    (0...valid.bytesize).each { |length| expect(dib(valid.byteslice(0, length))).to be_nil }
    mutated = [[0, 39], [0, 0xFFFFFFFF], [4, 0], [8, 0], [16, 100], [32, 0xFFFFFFFF]].map do |offset, value|
      valid.dup.tap { |bytes| bytes[offset, 4] = [value].pack("V") }
    end
    shapes = [[8, 3], [4, 1], [8, 2], [0, 0]].map { |bits, compression| info(1, 1, bits, compression, 4, 0) + ("\0" * 4) }
    shapes << (info(1, -1, 8, 1, 4, 0) + ("\0" * 4)) << (info((2**31) - 1, -(2**31), 32, 0, 0, 0) + ("\0" * 4))

    expect((mutated + shapes).filter_map { |bytes| dib(bytes) }).to be_empty
    expect(dib(valid, 3)).to be_nil
  end

  it "keeps a V5 profile after the pixels and rejects overlap" do
    bytes = info(1, 1, 24, 0, 0, 0)
    bytes[0, 4] = [124].pack("V")
    bytes = bytes.ljust(124, "\0".b)
    bytes[56, 4] = [0x4D424544].pack("V")
    bytes[112, 8] = [130, 3].pack("V2")
    bytes += [1, 2, 3, 0, 0xFE, 0xED, 7, 8, 9].pack("C*")

    expect(dib(bytes).trailing.bytes).to eq([0xFE, 0xED, 7, 8, 9])
    [40, 125, 131].each do |offset|
      bytes[112, 4] = [offset].pack("V")
      expect(dib(bytes)).to be_nil
    end
  end

  describe "Bitmap16" do
    let(:bytes) { [-7, 9, 2, 2].pack("s<4") + [1, 1, 0xAA, 0x80, 0x55, 0, 0xBE, 0xEF].pack("C*") }

    it "uses the word stride and keeps padding" do
      view = Emf::Wmf::Bitmap16.parse(bytes)

      expect([view.bitmap_type, view.pixels.bytes, view.trailing.bytes]).to eq([-7, [0xAA, 0x80, 0x55, 0], [0xBE, 0xEF]])
      expect((0...14).filter_map { |length| Emf::Wmf::Bitmap16.parse(bytes.byteslice(0, length)) }).to be_empty
    end

    it "preserves WidthBytes independently of the derived extent" do
      other = bytes.dup.tap { |data| data[6, 2] = [4].pack("s<") }
      view = Emf::Wmf::Bitmap16.parse(other)
      odd = [0, 9, 2, 999].pack("s<4") + [1, 3, 0, 1, 2, 3, 4, 5, 6, 7, 0xFE].pack("C*")

      expect([view.width_bytes, view.pixels.bytesize]).to eq([4, 4])
      expect(Emf::Wmf::Bitmap16.parse(odd).to_h).to include(width_bytes: 999, bits_pixel: 3, pixels: [0, 1, 2, 3, 4, 5, 6, 7].pack("C*"))
    end
  end

  describe "record typed_image" do
    let(:rop) { 0xFEDCBA98 }
    let(:blt_geometry) { [-5, 4, -3, 2, 1, 0].pack("s<*") }
    let(:stretch_geometry) { [-7, 8, -5, 4, -3, 2, 1, 0].pack("s<*") }
    let(:bitmap16) { [0, 1, 1, 2].pack("s<4") + [1, 1, 0xAB, 0xCD].pack("C*") }
    let(:packed) { info(1, 1, 24, 0, 0, 0) + [1, 2, 3, 0].pack("C*") }
    let(:records) do
      blt = [rop].pack("V") + blt_geometry
      stretch = [rop].pack("V") + stretch_geometry
      absent = [rop].pack("V") + [-5, 4].pack("s<2") + [0xCAFE].pack("v") + [-3, 2, 1, 0].pack("s<*")
      bytes = native_wmf_bytes([
                                 native_wmf_record(0x0922, blt + bitmap16), native_wmf_record(0x0B23, stretch + bitmap16),
                                 native_wmf_record(0x0940, blt + packed), native_wmf_record(0x0B41, stretch + packed),
                                 native_wmf_record(0x0D33, ([1] * 9).pack("v*") + packed),
                                 native_wmf_record(0x0F43, [rop, 2].pack("Vv") + stretch_geometry + packed),
                                 native_wmf_record(0x0922, absent), native_wmf_record(0x0940, blt + "junk".b)
                               ])
      Emf::Wmf::Parser.call(bytes).records.first(8)
    end

    it "gives Bitmap16 for non-DIB blits and DIB for the rest" do
      views = records.first(6).map(&:typed_image)

      expect(views.map(&:class)).to eq(([Emf::Wmf::Bitmap16::Image] * 2) + ([Emf::Wmf::Dib::Image] * 4))
      expect(views[0].pixels.bytes).to eq([0xAB, 0xCD])
      expect(views[5].colors.kind).to eq(:none)
    end

    it "distinguishes an absent optional source from a malformed interior and keeps raw bytes authoritative" do
      expect(records[6].typed_image).to be(Emf::Wmf::BitmapImage::ABSENT)
      expect(records.last.typed_image).to be_nil
      expect(records.first.bitmap).to eq(bitmap16)
    end
  end
end
