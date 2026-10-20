# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/native_wmf"

RSpec.describe "WMF region and clipping records" do
  include NativeWmfSupport

  let(:suffix) { "\xAA\xBB".b }
  let(:unknown) { native_wmf_record(0x7FFE, "raw!") }
  let(:region_body) do
    [0xABCD, 6, 0x5678, 0x1234, 50, 2, 4, 0xFFFE, 0x8000, 300, 400,
     2, 0x8001, 0xFFFE, 0x8002, 0xFFFF, 2, 4, 30, 40, 10, 20, 50, 60, 4].pack("v*")
  end
  let(:create) { native_wmf_record(0xABFF, region_body + suffix) }
  let(:brush) { native_wmf_record(0x02FC, [0, 0, 0, 0].pack("v4")) }
  let(:delete) { native_wmf_record(0x01F0, [0].pack("v")) }
  let(:consumers) do
    {
      FillRegion: [0x0228, [0, 1].pack("v2")],
      FrameRegion: [0x0429, [0, 1, -1, -32_768].pack("v2s<2")],
      InvertRegion: [0x012A, [0].pack("v")],
      PaintRegion: [0x012B, [0].pack("v")],
      SelectClipRegion: [0x012C, [0].pack("v")]
    }
  end
  let(:clipping) do
    {
      OffsetClipRgn: [0x0220, [-32_768, 32_767].pack("s<2"), { y_offset: -32_768, x_offset: 32_767 }],
      ExcludeClipRect: [0x0415, [-32_768, 32_767, -1, 0].pack("s<4"),
                        { bottom: -32_768, right: 32_767, top: -1, left: 0 }],
      IntersectClipRect: [0x0416, [32_767, -32_768, 0, -1].pack("s<4"),
                          { bottom: 32_767, right: -32_768, top: 0, left: -1 }]
    }
  end
  let(:placeable_options) { [false, true] }
  let(:grown_body) do
    [0xABCD, 6, 0x5678, 0x1234, 62, 3, 4, 0xFFF7, 0x8000, 300, 400,
     4, 0x8001, 0xFFFE, 0x8002, 0xFFFF, 4, 5, 4,
     4, 30, 40, 10, 20, 50, 60, 4, 0, 80, 90, 0].pack("v*")
  end
  let(:empty_body) { [0xABCD, 6, 0x5678, 0x1234, 22, 0, 0, 0xFFF7, 0x8000, 300, 400].pack("v*") }
  let(:edited_frame) { [0, 1, 32_767, -2].pack("v2s<2") }
  let(:zero_index) { [0].pack("v") }
  let(:fill_indices) { [0, 1].pack("v2") }
  let(:stock_index) { [0x8000].pack("v") }
  let(:invalid_arrays) { [nil, "scans", [nil]] }
  let(:invalid_words) { [-1, 65_536, nil, "1"] }
  let(:invalid_signed_words) { [-32_769, 32_768, nil, "1"] }
  let(:malformed_fields) do
    { 2 => 5, 8 => 21, 10 => 3, 12 => 2, 22 => 3, 32 => 4 }
  end

  %w[ruby native].each do |backend|
    context "with the #{backend} backend" do
      around do |example|
        previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
        ENV["EMF_BACKEND"] = backend
        ENV["EMF_NATIVE_LIBRARY"] = ENV.fetch("EMF_TEST_NATIVE_LIBRARY", "") if backend == "native"
        example.run
      ensure
        ENV["EMF_BACKEND"] = previous["EMF_BACKEND"]
        ENV["EMF_NATIVE_LIBRARY"] = previous["EMF_NATIVE_LIBRARY"]
      end

      before do
        skip "set EMF_TEST_NATIVE_LIBRARY to test native WMF" if backend == "native" && !File.file?(ENV.fetch("EMF_NATIVE_LIBRARY"))
      end

      it "preserves signed bounds, unsigned scans, ignored fields, suffix and surrounding bytes" do
        placeable_options.each do |placeable|
          bytes = native_wmf_bytes([create, unknown], placeable: placeable)
          parsed = Emf.parse(bytes)
          region = parsed.records.first
          expect(region).to be_a(Emf::Model::Wmf::Records::CreateRegion)
          expect([region.type_id, region.next_in_chain, region.object_count]).to eq([0xABFF, 0xABCD, 0x12345678])
          expect(region.bounds.to_h).to eq(left: -2, top: -32_768, right: 300, bottom: 400)
          expect(region.scans.map { |scan| [scan.top, scan.bottom, scan.lines.map(&:to_h)] }).to eq(
            [[32_769, 65_534, [{ left: 32_770, right: 65_535 }]],
             [30, 40, [{ left: 10, right: 20 }, { left: 50, right: 60 }]]]
          )
          expect(region.suffix).to eq(suffix)
          expect(parsed.records[-2].raw_bytes).to eq(unknown)
          expect(Emf.serialize(parsed)).to eq(bytes)
        end
      end

      it "derives nested counts, maximum scan size and region size after growth and shrinkage" do
        parsed = Emf.parse(native_wmf_bytes([create, unknown], placeable: true))
        region = parsed.records.first
        region.bounds.left = -9
        region.scans.first.lines << Emf::Model::Wmf::Records::RegionScanLine.new(left: 4, right: 5)
        region.scans << Emf::Model::Wmf::Records::RegionScan.new(top: 80, bottom: 90, lines: [])
        region.suffix += "more"
        output = Emf.serialize(parsed)
        expect(output).to eq(native_wmf_bytes([native_wmf_record(0xABFF, "#{grown_body}#{suffix}more"), unknown], placeable: true))
        expect(Emf.parse(output).records.first.scans.map { |scan| scan.lines.length }).to eq([2, 2, 0])
        region.scans.clear
        expect(Emf.serialize(parsed)).to eq(native_wmf_bytes([native_wmf_record(0xABFF, "#{empty_body}#{suffix}more"), unknown],
                                                             placeable: true))
      end

      it "edits region drawing and clipping fields while preserving suffixes and function high bytes" do
        consumers.each do |name, (function, body)|
          bytes = native_wmf_bytes([create, brush, native_wmf_record(function | 0xAB00, body + suffix)])
          parsed = Emf.parse(bytes)
          record = parsed.records[2]
          expect(record).to be_a(Emf::Model::Wmf::Records.const_get(name))
          expect(record.suffix).to eq(suffix)
          expect(Emf.serialize(parsed)).to eq(bytes)
          record.suffix += "more"
          expected_body = body
          if name == :FrameRegion
            record.height = 32_767
            record.width = -2
            expected_body = edited_frame
          end
          expect(Emf.serialize(parsed)).to eq(native_wmf_bytes([create, brush,
                                                                native_wmf_record(function | 0xAB00, "#{expected_body}#{suffix}more")]))
        end
        clipping.each do |name, (function, body, fields)|
          bytes = native_wmf_bytes([native_wmf_record(function | 0xAB00, body + suffix), unknown])
          parsed = Emf.parse(bytes)
          record = parsed.records.first
          expect(record).to be_a(Emf::Model::Wmf::Records.const_get(name))
          fields.each { |field, value| expect(record.public_send(field)).to eq(value) }
          expect(Emf.serialize(parsed)).to eq(bytes)
          fields.each_key { |field| record.public_send("#{field}=", -7) }
          record.suffix += "more"
          edited = "#{Array.new(fields.length, -7).pack('s<*')}#{suffix}more"
          expect(Emf.serialize(parsed)).to eq(native_wmf_bytes([native_wmf_record(function | 0xAB00, edited), unknown]))
        end
      end

      it "requires live regions and brushes through deletion, capacity and slot reuse" do
        select = native_wmf_record(0x012C, zero_index)
        bytes = native_wmf_bytes([create, select, delete, create, select], capacity: 1)
        expect(Emf.serialize(Emf.parse(bytes))).to eq(bytes)
        expect { Emf.parse(native_wmf_bytes([create, create], capacity: 1)) }.to raise_error(Emf::ParseError)
        consumers.each_value do |function, body|
          record = native_wmf_record(function, body)
          expect { Emf.parse(native_wmf_bytes([record])) }.to raise_error(Emf::ParseError)
          expect { Emf.parse(native_wmf_bytes([create, brush, delete, record])) }.to raise_error(Emf::ParseError)
          expect { Emf.parse(native_wmf_bytes([brush, create, record])) }.to raise_error(Emf::ParseError)
        end
        expect { Emf.parse(native_wmf_bytes([create, create, native_wmf_record(0x0228, fill_indices)])) }.to raise_error(Emf::ParseError)
        expect { Emf.parse(native_wmf_bytes([create, native_wmf_record(0x012C, stock_index)])) }.to raise_error(Emf::ParseError)
      end

      it "rejects malformed nested structures and truncated fixed prefixes" do
        malformed_fields.each do |offset, value|
          body = region_body.dup
          body[offset, 2] = [value].pack("v")
          expect { Emf.parse(native_wmf_bytes([native_wmf_record(0x06FF, body)])) }.to raise_error(Emf::ParseError)
        end
        ["".b, region_body.byteslice(0, 20)].each do |body|
          expect { Emf.parse(native_wmf_bytes([native_wmf_record(0x06FF, body)])) }.to raise_error(Emf::ParseError)
        end
        (consumers.values + clipping.values).each do |function, body|
          expect { Emf.parse(native_wmf_bytes([native_wmf_record(function, body.byteslice(0, body.bytesize - 2))])) }.to raise_error(Emf::ParseError)
        end
      end

      it "validates edited nested values and rejects oversized scans before serialization" do
        invalid_words.each do |value|
          parsed = Emf.parse(native_wmf_bytes([create]))
          parsed.records.first.scans.first.lines.first.left = value
          expect { Emf.serialize(parsed) }.to raise_error(Emf::SerializeError)
        end
        invalid_signed_words.each do |value|
          parsed = Emf.parse(native_wmf_bytes([create]))
          parsed.records.first.bounds.top = value
          expect { Emf.serialize(parsed) }.to raise_error(Emf::SerializeError)
        end
        parsed = Emf.parse(native_wmf_bytes([create]))
        region = parsed.records.first
        region.scans.first.lines = Array.new(8190, region.scans.first.lines.first)
        expect { Emf.serialize(parsed) }.to raise_error(Emf::SerializeError)
        invalid_arrays.each do |value|
          region.scans = value
          expect { Emf.serialize(parsed) }.to raise_error(Emf::SerializeError)
        end
      end

      it "rejects invalid scalar edits, odd suffixes and disguised typed functions" do
        clipping.each_value do |function, body, fields|
          invalid_signed_words.each do |value|
            parsed = Emf.parse(native_wmf_bytes([native_wmf_record(function, body)]))
            parsed.records.first.public_send("#{fields.keys.first}=", value)
            expect { Emf.serialize(parsed) }.to raise_error(Emf::SerializeError)
          end
        end
        parsed = Emf.parse(native_wmf_bytes([create]))
        parsed.records.first.suffix = "x"
        expect { Emf.serialize(parsed) }.to raise_error(Emf::SerializeError)
        opaque = Emf::Model::Wmf::Records::UnknownRecord.new(type_id: 0x06FF, raw_bytes: create)
        disguised = Emf::Model::Metafile.new(format: :wmf, header: parsed.header, records: [opaque, parsed.records.last])
        expect { Emf.serialize(disguised) }.to raise_error(Emf::SerializeError)
      end
    end
  end
end
