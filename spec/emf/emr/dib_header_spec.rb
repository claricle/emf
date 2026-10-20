# frozen_string_literal: true

require "spec_helper"
require "emf/emr/binary/dib_header"

RSpec.describe Emf::Emr::Binary::DibHeader do
  let(:fixture) { File.binread(File.expand_path("../../fixtures/emf/test-000.emf", __dir__)) }
  let(:parsed) { Emf::Emr::Parser.call(fixture) }
  let(:wires) { parsed.records.map(&:wire) }

  def info_header(width: 4, height: 2, bit_count: 8, compression: 0, used: 0, size: 40)
    [size, width, height, 1, bit_count, compression, 0, 0, 0, used, 0].pack("Vl<2v2V2l<2V2")
  end

  def stretch_dibits(bmi, offset: 80, size: bmi.bytesize)
    raw = [81, 80 + bmi.bytesize].pack("V2") + ("\x00" * 16) + ("\x00" * 56) + bmi
    raw[48, 8] = [offset, size].pack("V2")
    Emf::Emr::Binary::Records::StretchDIBits.read(raw)
  end

  def with_bits(bmi, bits, offset: 80 + bmi.bytesize, size: bits.bytesize)
    wire = stretch_dibits(bmi + bits)
    wire.cb_bmi_src = bmi.bytesize
    wire.off_bits_src = offset
    wire.cb_bits_src = size
    wire
  end

  context "with a real fixture" do
    it "exposes typed fields for STRETCHDIBITS and keeps bytes identical" do
      wire = wires.find { |w| w.is_a?(Emf::Emr::Binary::Records::StretchDIBits) }
      header = wire.dib_header_view.header
      bmi = wire.trailing.to_s.byteslice(wire.off_bmi_src.to_i - 80, wire.cb_bmi_src.to_i)
      expect(header.header_size).to eq(bmi.unpack1("V"))
      expect(header.width).to eq(bmi.unpack1("x4l<"))
      expect(header.bit_count).to eq(bmi.unpack1("x14v"))
      expect(header.color_table_offset).to eq(header.header_size)
      expect(header.header_size + header.color_table_bytes).to be <= wire.cb_bmi_src.to_i
      expect(Emf::Emr::Serializer.call(parsed)).to eq(fixture)
    end

    it "returns an absent view for a BITBLT without a source bitmap" do
      blt = wires.find { |w| w.is_a?(Emf::Emr::Binary::Records::BitBlt) }
      expect(blt.cb_bmi_src.to_i).to eq(0)
      expect(blt.dib_header_view.reason).to eq(:absent)
    end

    it "locates the pixel array of every STRETCHDIBITS inside the record" do
      views = wires.grep(Emf::Emr::Binary::Records::StretchDIBits).map(&:dib_header_view)
      expect(views.map(&:bits_valid?)).to all(be(true))
      expect(views.map(&:bits_size)).to all(be_positive)
    end
  end

  context "with synthetic records" do
    it "reads an info header and counts the colour table" do
      header = stretch_dibits(info_header + ("\x00" * 1024)).dib_header_view.header
      expect(header).to have_attributes(kind: :info, header_size: 40, width: 4, height: 2, planes: 1, bit_count: 8,
                                        compression: 0, color_table_entries: 256, color_table_bytes: 1024)
    end

    it "honours biClrUsed and the bitfield masks" do
      expect(stretch_dibits(info_header(used: 2) + ("\x00" * 8)).dib_header_view.header.color_table_entries).to eq(2)
      masks = stretch_dibits(info_header(bit_count: 32, compression: 3) + ("\x00" * 12)).dib_header_view.header
      expect(masks).to have_attributes(bitfield_mask_count: 3, color_table_offset: 52, color_table_entries: 0, color_table_bytes: 0)
    end

    it "counts bitfield masks apart from a palette that follows them" do
      header = info_header(bit_count: 16, compression: 6, used: 2)
      view = stretch_dibits(header + ("\x00" * 24)).dib_header_view
      expect(view.header).to have_attributes(bitfield_mask_count: 4, color_table_offset: 56, color_table_entries: 2, color_table_bytes: 8)
      expect(stretch_dibits(header + ("\x00" * 23)).dib_header_view.reason).to eq(:color_table_past_bmi)
    end

    it "keeps V4/V5 masks inside the header" do
      v5 = info_header(bit_count: 32, compression: 3, size: 124) + ("\x00" * 84)
      expect(stretch_dibits(v5).dib_header_view.header).to have_attributes(kind: :v5, bitfield_mask_count: 0, color_table_offset: 124)
    end

    it "reads a core header with RGBTRIPLE entries" do
      core = [12, 5, 6, 1, 1].pack("Vv4") + ("\x00" * 6)
      expect(stretch_dibits(core).dib_header_view.header).to have_attributes(kind: :core, width: 5, height: 6, color_table_bytes: 6)
    end

    it "reports a reason instead of raising for malformed records" do
      expect(stretch_dibits("", offset: 0, size: 0).dib_header_view.reason).to eq(:absent)
      expect(stretch_dibits(info_header, offset: 40).dib_header_view.reason).to eq(:offset_in_fixed_part)
      expect(stretch_dibits(info_header, size: 400).dib_header_view.reason).to eq(:past_record)
      expect(stretch_dibits(info_header, size: 20).dib_header_view.reason).to eq(:bmi_smaller_than_header)
      expect(stretch_dibits(info_header(size: 41)).dib_header_view.reason).to eq(:unsupported_header_size)
      expect(stretch_dibits(info_header).dib_header_view.reason).to eq(:color_table_past_bmi)
    end

    it "still serializes after editing a non-DIB field and leaves the view intact" do
      wire = stretch_dibits(info_header(bit_count: 24))
      before = wire.to_binary_s
      wire.x_dest = 9
      expect(wire.to_binary_s).to eq(before.dup.tap { |b| b[24, 4] = [9].pack("V") })
      expect(wire.dib_header_view.header.bit_count).to eq(24)
    end
  end

  context "with pixel-array bounds" do
    let(:bmi) { info_header(width: 4, height: 2, bit_count: 8, used: 1) + ("\x00" * 4) }

    it "accepts bits that fit the stride and tolerates padding" do
      expect(with_bits(bmi, "\x00" * 8).dib_header_view).to have_attributes(bits_valid?: true, bits_reason: nil, bits_size: 8)
      expect(with_bits(bmi, "\x00" * 64).dib_header_view.bits_reason).to be_nil
    end

    it "reports bits that are absent, early, past the record or overlapping the BMI" do
      expect(with_bits(bmi, "", offset: 0, size: 0).dib_header_view.bits_reason).to eq(:bits_absent)
      expect(with_bits(bmi, "\x00" * 8, offset: 40).dib_header_view.bits_reason).to eq(:bits_in_fixed_part)
      expect(with_bits(bmi, "\x00" * 8, size: 800).dib_header_view.bits_reason).to eq(:bits_past_record)
      expect(with_bits(bmi, "\x00" * 8, offset: 90).dib_header_view.bits_reason).to eq(:bits_overlap_bmi)
    end

    it "reports bits smaller than stride * height" do
      expect(with_bits(bmi, "\x00" * 7).dib_header_view.bits_reason).to eq(:bits_smaller_than_image)
      wide = info_header(width: 33, height: -3, bit_count: 1, used: 1) + ("\x00" * 4)
      expect(with_bits(wide, "\x00" * 23).dib_header_view.bits_reason).to eq(:bits_smaller_than_image)
      expect(with_bits(wide, "\x00" * 24).dib_header_view.bits_reason).to be_nil
    end

    it "keeps the header verdict when the bits are bad" do
      view = with_bits(bmi, "\x00" * 7).dib_header_view
      expect(view).to be_valid
      expect(view.reason).to be_nil
    end

    it "skips the stride check for RLE8 and RLE4 runs shorter than stride * height" do
      [[1, 8], [2, 4]].each do |compression, bit_count|
        rle = info_header(width: 64, height: 64, bit_count: bit_count, compression: compression, used: 2) + ("\x00" * 8)
        view = with_bits(rle, "\x00\x01".b * 2).dib_header_view
        expect(view).to have_attributes(bits_valid?: true, bits_size: 4)
        expect(with_bits(rle, "\x00" * 4, size: 900).dib_header_view.bits_reason).to eq(:bits_past_record)
      end
    end

    it "treats BI_JPEG and BI_PNG data as compressed: no stride check and no colour table" do
      [4, 5].each do |compression|
        jpeg = info_header(width: 100, height: 100, bit_count: 24, compression: compression)
        view = with_bits(jpeg, "\xFF".b * 10).dib_header_view
        expect(view.header).to have_attributes(compression: compression, color_table_entries: 0, color_table_bytes: 0)
        expect(view.bits_reason).to be_nil
      end
    end
  end
end
