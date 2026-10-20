# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/native_wmf"

RSpec.describe "WMF bitmap transfer records" do
  include NativeWmfSupport

  let(:image) { "\xDE\xAD\xBE\xEF".b }
  let(:rop) { 0xFEDCBA98 }
  let(:blt_geometry) { [-32_768, 32_767, -3, 4, -5, 6] }
  let(:stretch_geometry) { [-32_768, 32_767, -3, 4, -5, 6, -7, 8] }
  let(:device_geometry) { [65_535, 65_534, 65_533, 65_532, 65_531, 65_530, 65_529, 65_528, 65_527] }
  let(:optional_kinds) { { 0x0922 => "BitBlt", 0x0940 => "DibBitBlt", 0x0B23 => "StretchBlt", 0x0B41 => "DibStretchBlt" } }
  let(:present_bodies) do
    blt = [rop].pack("V") + blt_geometry.pack("s<*") + image
    stretch = [rop].pack("V") + stretch_geometry.pack("s<*") + image
    { 0x0922 => blt, 0x0940 => blt, 0x0B23 => stretch, 0x0B41 => stretch,
      0xAD33 => device_geometry.pack("v*") + image,
      0xBE43 => [rop, 65_535].pack("Vv") + stretch_geometry.pack("s<*") + image }
  end
  let(:absent_bodies) do
    blt = [rop].pack("V") + blt_geometry.first(2).pack("s<*") + [0xCAFE].pack("v") + blt_geometry.drop(2).pack("s<*")
    stretch = [rop].pack("V") + stretch_geometry.first(4).pack("s<*") + [0xCAFE].pack("v") + stretch_geometry.drop(4).pack("s<*")
    { 0x0922 => blt, 0x0940 => blt, 0x0B23 => stretch, 0x0B41 => stretch }
  end
  let(:unknown) { native_wmf_record(0x7FFE, "raw!") }
  let(:headers) { [false, true] }
  let(:invalid_images) { ["", "x", nil, []] }
  let(:invalid_rops) { [-1, 0x1_0000_0000, nil] }
  let(:invalid_coordinates) { [-32_769, 32_768, nil] }
  let(:invalid_unsigned_coordinates) { [-1, 65_536, nil] }

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

      it "types all six variants and preserves opaque images, high function bytes and surrounding bytes" do
        records = present_bodies.map { |function, body| native_wmf_record(function, body) }
        headers.each do |placeable|
          bytes = native_wmf_bytes([*records, unknown], capacity: 0, placeable: placeable)
          parsed = Emf.parse(bytes)
          expect(parsed.records.take(6).map { |record| record.class.name.split("::").last })
            .to eq(%w[BitBlt DibBitBlt StretchBlt DibStretchBlt SetDibToDev StretchDib])
          expect(parsed.records.take(6).map(&:bitmap)).to eq(Array.new(6, image))
          expect(parsed.records[0].source_y).to eq(-32_768)
          expect(parsed.records[0].raster_operation).to eq(rop)
          expect(parsed.records[4].color_usage).to eq(65_535)
          expect(parsed.records[4].source_y).to eq(65_532)
          expect(parsed.records[5].color_usage).to eq(65_535)
          expect(Emf.serialize(parsed)).to eq(bytes)
        end
      end

      it "preserves absent source reserved words and noncanonical function suffixes" do
        absent_bodies.each do |function, body|
          bytes = native_wmf_bytes([native_wmf_record(function + 0x100, "#{body}xx"), unknown])
          parsed = Emf.parse(bytes)
          record = parsed.records.first
          expect(record.bitmap).to be_nil
          expect(record.reserved).to eq(0xCAFE)
          expect(record.suffix).to eq("xx")
          expect(Emf.serialize(parsed)).to eq(bytes)
          record.suffix = ""
          expect { Emf.serialize(parsed) }.to raise_error(Emf::SerializeError)
        end
      end

      it "edits every image and unsigned device coordinates while updating file framing" do
        present_bodies.each do |function, body|
          parsed = Emf.parse(native_wmf_bytes([native_wmf_record(function, body), unknown], placeable: true))
          parsed.records.first.bitmap += "more"
          expected = native_wmf_bytes([native_wmf_record(function, "#{body}more"), unknown], placeable: true)
          expect(Emf.serialize(parsed)).to eq(expected)
          expect(Emf.parse(expected).records.first.bitmap).to eq("#{image}more")
        end
        parsed = Emf.parse(native_wmf_bytes([native_wmf_record(0xAD33, present_bodies.fetch(0xAD33))]))
        parsed.records.first.destination_x = 65_535
        expect(Emf.parse(Emf.serialize(parsed)).records.first.destination_x).to eq(65_535)
      end

      it "rejects edits that silently change optional source discrimination" do
        optional_kinds.each_key do |function|
          parsed = Emf.parse(native_wmf_bytes([native_wmf_record(function, present_bodies.fetch(function))]))
          parsed.records.first.bitmap = "xx"
          expect { Emf.serialize(parsed) }.to raise_error(Emf::SerializeError)
          parsed = Emf.parse(native_wmf_bytes([native_wmf_record(function, absent_bodies.fetch(function))]))
          parsed.records.first.bitmap = image
          parsed.records.first.reserved = 0
          expect(Emf.parse(Emf.serialize(parsed)).records.first.bitmap).to eq(image)
        end
      end

      it "constructs mandatory DIB records and absent optional sources" do
        bodies = absent_bodies.merge(present_bodies.select do |function, _body|
          (function & 0xFF) == 0x33 || (function & 0xFF) == 0x43
        end)
        bodies.each do |function, body|
          parsed = Emf.parse(native_wmf_bytes([native_wmf_record(function, body)]))
          original = parsed.records.first
          fields = case function & 0xFF
                   when 0x33
                     %i[color_usage scan_count start_scan source_y source_x height width destination_y destination_x bitmap]
                   when 0x43
                     %i[raster_operation color_usage source_height source_width source_y source_x
                        destination_height destination_width destination_y destination_x bitmap]
                   when 0x22, 0x40
                     %i[raster_operation source_y source_x height width destination_y destination_x reserved bitmap]
                   else
                     %i[raster_operation source_height source_width source_y source_x
                        destination_height destination_width destination_y destination_x reserved bitmap]
                   end
          record = original.class.new(**fields.to_h { |field| [field, original.public_send(field)] }, type_id: function)
          metafile = Emf::Model::Metafile.new(format: :wmf, header: parsed.header, records: [record, parsed.records.last],
                                              trailing: parsed.trailing)
          expect(Emf.serialize(metafile)).to eq(native_wmf_bytes([native_wmf_record(function, body)]))
        end
      end

      it "serializes newly constructed records without source bytes" do
        optional_kinds.each do |function, name|
          parsed = Emf.parse(native_wmf_bytes([native_wmf_record(function, present_bodies.fetch(function))]))
          original = parsed.records.first
          fields = if name.include?("Stretch")
                     %i[source_height source_width source_y source_x destination_height destination_width destination_y destination_x]
                   else
                     %i[source_y source_x height width destination_y destination_x]
                   end
          values = fields.to_h { |field| [field, original.public_send(field)] }
          record = Emf::Model::Wmf::Records.const_get(name).new(**values, raster_operation: rop, bitmap: image)
          metafile = Emf::Model::Metafile.new(format: :wmf, header: parsed.header, records: [record, parsed.records.last],
                                              trailing: parsed.trailing)
          expect(Emf.serialize(metafile)).to eq(native_wmf_bytes([native_wmf_record(function, present_bodies.fetch(function))]))
        end
      end

      it "rejects truncated known headers, missing required images and disguised raw records" do
        present_bodies.each do |function, body|
          header_size = case function & 0xFF
                        when 0x22, 0x40 then 16
                        when 0x23, 0x41 then 20
                        when 0x33 then 18
                        else 22
                        end
          expect { Emf.parse(native_wmf_bytes([native_wmf_record(function, body.byteslice(0, header_size - 2))])) }
            .to raise_error(Emf::ParseError)
          expect { Emf.parse(native_wmf_bytes([native_wmf_record(function, body.byteslice(0, header_size))])) }
            .to raise_error(Emf::ParseError)
          parsed = Emf.parse(native_wmf_bytes([]))
          opaque = Emf::Model::Wmf::Records::UnknownRecord.new(type_id: function, raw_bytes: native_wmf_record(function, body))
          metafile = Emf::Model::Metafile.new(format: :wmf, header: parsed.header, records: [opaque, parsed.records.last])
          expect { Emf.serialize(metafile) }.to raise_error(Emf::SerializeError)
        end
      end

      it "rejects invalid edited byte containers, scalar widths and function identities" do
        present_bodies.each do |function, body|
          parsed = Emf.parse(native_wmf_bytes([native_wmf_record(function, body)]))
          record = parsed.records.first
          invalid_images.each do |value|
            next if value.nil? && optional_kinds.key?(function)

            record.bitmap = value
            expect { Emf.serialize(parsed) }.to raise_error(Emf::SerializeError)
          end
          record.bitmap = image
          values = function & 0xFF == 0x33 ? invalid_unsigned_coordinates : invalid_coordinates
          values.each do |value|
            record.destination_x = value
            expect { Emf.serialize(parsed) }.to raise_error(Emf::SerializeError)
          end
          record.destination_x = 0
          if record.respond_to?(:raster_operation=)
            invalid_rops.each do |value|
              record.raster_operation = value
              expect { Emf.serialize(parsed) }.to raise_error(Emf::SerializeError)
            end
            record.raster_operation = rop
          end
          record.instance_variable_set(:@type_id, 0x7FFE)
          expect { Emf.serialize(parsed) }.to raise_error(Emf::SerializeError)
        end
      end
    end
  end
end
