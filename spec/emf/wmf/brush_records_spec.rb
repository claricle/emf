# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/native_wmf"

RSpec.describe "WMF pattern brush records" do
  include NativeWmfSupport

  let(:bits) { "\xDE\xAD\xBE\xEF".b }
  let(:reserved) { (1..18).to_a.pack("C*") }
  let(:pattern) { "\x80\x00\xFF\x01".b }
  let(:suffix) { "\xAA\xBB".b }
  let(:prefix) { [-32_768, 9, 2, -1].pack("s<4") + [1, 1].pack("C2") + bits + reserved }
  let(:create) { native_wmf_record(0xABF9, prefix + pattern + suffix) }
  let(:target) { "\x00\xFF\x01\x80".b }
  let(:dib) { native_wmf_record(0xCD42, [3, 65_535].pack("v2") + target) }
  let(:unknown) { native_wmf_record(0x7FFE, "raw!") }
  let(:select_zero) { native_wmf_record(0x012D, [0].pack("v")) }
  let(:delete_zero) { native_wmf_record(0x01F0, [0].pack("v")) }
  let(:invalid_headers) { { 2 => 0, 4 => 0xFFFF, 8 => 2, 9 => 0 } }
  let(:invalid_edits) do
    { bitmap_type: [32_768, nil], width: [0, -1, 32_768], height: [0, -1], width_bytes: [-32_769],
      planes: [0, 2, 256], bits_pixel: [0, 256], bits: ["x", nil], reserved: ["x", nil],
      pattern: ["x", "", nil], suffix: ["x", nil], type_id: [0x0142, 65_536] }
  end
  let(:invalid_dib_edits) do
    { style: [-1, 65_536], color_usage: [-1, 65_536], target: ["", "x", nil], type_id: [0x01F9] }
  end
  let(:grown_prefix) { [-32_768, 17, 2, -1].pack("s<4") + [1, 1].pack("C2") + bits + reserved }
  let(:new_pattern) { "\x01\x02\x03\x04\x05\x06\x07\x08".b }
  let(:signed_fields) { %i[bitmap_type width height width_bytes] }
  let(:header_options) { [false, true] }
  let(:dib_prefix) { [3, 65_535].pack("v2") }
  let(:invalid_dib_bodies) { [[0, 3].pack("v2") + target, [3, 0].pack("v2"), "\0\0".b] }

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

      it "preserves bitmap headers, ignored bytes, suffixes and both file headers exactly" do
        header_options.each do |placeable|
          bytes = native_wmf_bytes([create, dib, unknown], placeable: placeable)
          parsed = Emf.parse(bytes)
          brush = parsed.records.first
          expect(brush).to be_a(Emf::Model::Wmf::Records::CreatePatternBrush)
          expect(signed_fields.map { |field| brush.public_send(field) }).to eq([-32_768, 9, 2, -1])
          expect([brush.type_id, brush.planes, brush.bits_pixel, brush.bits, brush.reserved, brush.pattern, brush.suffix])
            .to eq([0xABF9, 1, 1, bits, reserved, pattern, suffix])
          expect(parsed.records[1]).to be_a(Emf::Model::Wmf::Records::DibCreatePatternBrush)
          expect([parsed.records[1].style, parsed.records[1].color_usage, parsed.records[1].target]).to eq([3, 65_535, target])
          expect(parsed.records[-2].raw_bytes).to eq(unknown)
          expect(Emf.serialize(parsed)).to eq(bytes)
        end
      end

      it "edits pattern dimensions and raw bytes while recalculating framing" do
        parsed = Emf.parse(native_wmf_bytes([create, unknown], placeable: true))
        brush = parsed.records.first
        brush.width = 17
        brush.pattern = new_pattern
        brush.suffix += "more"
        output = Emf.serialize(parsed)
        expect(output).to eq(native_wmf_bytes([native_wmf_record(0xABF9, "#{grown_prefix}#{new_pattern}#{suffix}more"), unknown],
                                              placeable: true))
        expect(Emf.parse(output).records.first.pattern).to eq(new_pattern)
        brush.height = 1
        brush.pattern = pattern
        expect(Emf.parse(Emf.serialize(parsed)).records.first.height).to eq(1)
      end

      it "retains opaque DIB targets and applies the stored style usage rule" do
        parsed = Emf.parse(native_wmf_bytes([dib, unknown]))
        brush = parsed.records.first
        brush.target += "more"
        expect(Emf.serialize(parsed)).to eq(native_wmf_bytes([native_wmf_record(0xCD42, "#{dib_prefix}#{target}more"),
                                                              unknown]))
        brush.style = 65_535
        expect { Emf.serialize(parsed) }.to raise_error(Emf::SerializeError)
        (0..2).each do |usage|
          brush.color_usage = usage
          expect(Emf.parse(Emf.serialize(parsed)).records.first.color_usage).to eq(usage)
        end
      end

      it "constructs canonical pattern records without original source bytes" do
        parsed = Emf.parse(native_wmf_bytes([]))
        pattern_brush = Emf::Model::Wmf::Records::CreatePatternBrush.new(
          bitmap_type: -32_768, width: 9, height: 2, width_bytes: -1, planes: 1, bits_pixel: 1,
          bits: bits, reserved: reserved, pattern: pattern, suffix: suffix
        )
        dib_brush = Emf::Model::Wmf::Records::DibCreatePatternBrush.new(style: 3, color_usage: 65_535, target: target)
        parsed = Emf::Model::Metafile.new(format: :wmf, header: parsed.header,
                                          records: [pattern_brush, dib_brush, *parsed.records], trailing: parsed.trailing)
        expect(Emf.serialize(parsed)).to eq(native_wmf_bytes([
                                                               native_wmf_record(0x01F9, prefix + pattern + suffix),
                                                               native_wmf_record(0x0142, dib_prefix + target)
                                                             ]))
      end

      it "retains brush handles through selection, deletion and slot reuse" do
        bytes = native_wmf_bytes([create, select_zero, delete_zero, dib, select_zero], capacity: 1)
        expect(Emf.serialize(Emf.parse(bytes))).to eq(bytes)
        expect { Emf.parse(native_wmf_bytes([create, dib], capacity: 1)) }.to raise_error(Emf::ParseError)
        expect { Emf.parse(native_wmf_bytes([dib, delete_zero, select_zero])) }.to raise_error(Emf::ParseError)
        parsed = Emf.parse(native_wmf_bytes([create, select_zero]))
        records = parsed.records.dup
        records.insert(1, Emf::Model::Wmf::Records::DeleteObject.new(object_index: 0))
        parsed = Emf::Model::Metafile.new(format: :wmf, header: parsed.header, records: records)
        expect { Emf.serialize(parsed) }.to raise_error(Emf::SerializeError)
      end

      it "rejects truncated and invalid headers before reading calculated pattern bytes" do
        invalid_headers.each do |offset, value|
          body = (prefix + pattern).dup
          body[offset, offset < 8 ? 2 : 1] = [value].pack(offset < 8 ? "v" : "C")
          expect { Emf.parse(native_wmf_bytes([native_wmf_record(0x01F9, body)])) }.to raise_error(Emf::ParseError)
        end
        [prefix.byteslice(0, 30), prefix + pattern.byteslice(0, 2)].each do |body|
          expect { Emf.parse(native_wmf_bytes([native_wmf_record(0x01F9, body)])) }.to raise_error(Emf::ParseError)
        end
        invalid_dib_bodies.each do |body|
          expect { Emf.parse(native_wmf_bytes([native_wmf_record(0x0142, body)])) }.to raise_error(Emf::ParseError)
        end
      end

      it "rejects invalid edited widths, dimensions, byte containers and function identities" do
        invalid_edits.each do |field, values|
          values.each do |value|
            parsed = Emf.parse(native_wmf_bytes([create]))
            if field == :type_id
              parsed.records.first.instance_variable_set(:@type_id, value)
            else
              parsed.records.first.public_send("#{field}=", value)
            end
            expect { Emf.serialize(parsed) }.to raise_error(Emf::SerializeError)
          end
        end
        invalid_dib_edits.each do |field, values|
          values.each do |value|
            parsed = Emf.parse(native_wmf_bytes([dib]))
            if field == :type_id
              parsed.records.first.instance_variable_set(:@type_id, value)
            else
              parsed.records.first.public_send("#{field}=", value)
            end
            expect { Emf.serialize(parsed) }.to raise_error(Emf::SerializeError)
          end
        end
      end
    end
  end
end
