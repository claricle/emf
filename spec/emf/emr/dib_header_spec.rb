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
      expect(masks.color_table_bytes).to eq(12)
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
end
