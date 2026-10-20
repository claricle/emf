# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/wmf_geometry"
require_relative "../../support/wmf_geometry_remaining"

RSpec.describe "WMF scale, pixel and pattern geometry" do
  include WmfGeometrySupport
  include WmfGeometryRemainingSupport

  let(:families) do
    [
      [0x0410, "ScaleWindowExt", { y_denom: -32_768, y_num: 32_767, x_denom: 0, x_num: -123 }, "s<4"],
      [0x0412, "ScaleViewportExt", { y_denom: 32_767, y_num: -32_768, x_denom: -3, x_num: 0 }, "s<4"],
      [0x0419, "FloodFill", { color: 0xFFFFFFFF, y: -32_768, x: 32_767 }, "Vs<2"],
      [0x041F, "SetPixel", { color: 0xFEDCBA98, y: 32_767, x: -32_768 }, "Vs<2"],
      [0x0548, "ExtFloodFill", { mode: 1, color: 0x80000000, y: -32_768, x: 32_767 }, "vVs<2"],
      [0x061D, "PatBlt", { raster_operation: 0xFFFFFFFF, height: -32_768, width: 32_767, y_left: -3, x_left: 4 }, "Vs<4"]
    ]
  end
  let(:unknown) { geometry_record(0x7FFE, [-123, 456]) }
  let(:suffix) { "\xDE\xAD\x00\xFF".b }
  let(:backend) { ENV.fetch("EMF_GEOMETRY_TEST_BACKEND", "ruby") }
  let(:unsigned_fields) { %i[color raster_operation] }
  let(:invalid_suffixes) { [nil, [], "x"] }
  let(:invalid_functions) { [-1, 0x1_0000, 0x0213] }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("EMF_BACKEND", "auto").and_return(backend)
  end

  it "parses all six typed variants with signed coordinates and unsigned DWORDs" do
    families.each do |function, name, fields, format|
      bytes = geometry_file([remaining_geometry_record(function, fields, format)])
      metafile = Emf.parse(bytes)
      record = metafile.records.first
      expect(record).to be_a(Emf::Model::Wmf::Records.const_get(name))
      expect(record.offset).to eq(18)
      expect(fields.keys.map { |field| record.public_send(field) }).to eq(fields.values)
      expect(record.suffix).to eq("".b)
      expect(Emf.serialize(metafile)).to eq(bytes)
    end
  end

  it "preserves noncanonical function words, opaque suffixes, unknown siblings and framing" do
    families.each do |function, name, fields, format|
      high_function = 0x7F00 | (function & 0xFF)
      raw = remaining_geometry_record(high_function, fields, format, suffix)
      bytes = geometry_file([unknown, raw, unknown], placeable: true, trailing: "\xFFtail".b)
      metafile = Emf.parse(bytes)
      record = metafile.records[1]
      expect(record).to be_a(Emf::Model::Wmf::Records.const_get(name))
      expect(record.type_id).to eq(high_function)
      expect(record.suffix).to eq(suffix)
      expect(metafile.records.values_at(0, 2).map(&:raw_bytes)).to eq([unknown, unknown])
      expect(Emf.serialize(metafile)).to eq(bytes)

      fields.each_key { |field| record.public_send("#{field}=", 0) }
      edited = fields.transform_values { 0 }
      expected = geometry_file([unknown, remaining_geometry_record(high_function, edited, format, suffix), unknown],
                               placeable: true, trailing: "\xFFtail".b)
      expect(Emf.serialize(metafile)).to eq(expected)
      reparsed = Emf.parse(expected).records[1]
      expect(edited.keys.map { |field| reparsed.public_send(field) }).to eq(edited.values)
    end
  end

  it "serializes newly constructed records and mutable suffixes with recalculated sizes" do
    families.each do |function, name, fields, format|
      record = Emf::Model::Wmf::Records.const_get(name).new(**fields)
      metafile = remaining_geometry_metafile(record)
      record.suffix = suffix
      expected = geometry_file([remaining_geometry_record(function, fields, format, suffix)])
      expect(Emf.serialize(metafile)).to eq(expected)
      reparsed = Emf.parse(expected)
      expect(reparsed.header.size_words).to eq(expected.bytesize / 2)
      expect(reparsed.header.max_record_words).to eq((expected.bytesize - 24) / 2)
      expect(reparsed.records.first.suffix).to eq(suffix)
    end
  end

  it "rejects every truncated typed prefix with its record location and function" do
    families.each do |function, _name, fields, format|
      payload = fields.values.pack(format)
      (0...payload.bytesize).step(2) do |length|
        raw = [3 + (length / 2), function].pack("Vv") + payload.byteslice(0, length)
        expect { Emf.parse(geometry_file([raw])) }.to raise_error(Emf::ParseError) do |error|
          expect(error.offset).to eq(18)
          expect(error.record_code).to eq(function)
        end
      end
    end
  end

  it "rejects invalid extended flood fill modes on parse and after mutation" do
    [2, 0xFFFF].each do |mode|
      fields = { mode: mode, color: 0xFFFFFFFF, y: -1, x: 2 }
      raw = remaining_geometry_record(0x0548, fields, "vVs<2", suffix)
      expect { Emf.parse(geometry_file([raw])) }.to raise_error(Emf::ParseError)
      record = Emf::Model::Wmf::Records::ExtFloodFill.new(**fields)
      expect { Emf.serialize(remaining_geometry_metafile(record)) }.to raise_error(Emf::SerializeError, /flood fill mode/)
    end
  end

  it "validates every scalar range and integer type before packing" do
    families.each do |_function, name, fields, _format|
      fields.each_key do |field|
        bounds = if unsigned_fields.include?(field)
                   [-1, 0x1_00000000]
                 elsif field == :mode
                   [-1, 0x1_0000]
                 else
                   [-32_769, 32_768]
                 end
        [*bounds, 1.5, nil, "1"].each do |value|
          record = Emf::Model::Wmf::Records.const_get(name).new(**fields)
          record.public_send("#{field}=", value)
          expect { Emf.serialize(remaining_geometry_metafile(record)) }.to raise_error(Emf::SerializeError, /out of range/)
        end
      end
    end
  end

  it "rejects invalid suffixes and mismatched record functions" do
    families.each do |_function, name, fields, _format|
      invalid_suffixes.each do |value|
        record = Emf::Model::Wmf::Records.const_get(name).new(**fields, suffix: value)
        expect { Emf.serialize(remaining_geometry_metafile(record)) }.to raise_error(Emf::SerializeError, /suffix/)
      end
      invalid_functions.each do |function|
        record = Emf::Model::Wmf::Records.const_get(name).new(**fields, type_id: function)
        expect { Emf.serialize(remaining_geometry_metafile(record)) }.to raise_error(Emf::SerializeError)
      end
    end
  end

  it "rejects typed geometry disguised as opaque raw records" do
    families.each do |function, _name, fields, format|
      raw = remaining_geometry_record(function, fields, format, suffix)
      record = Emf::Model::Wmf::Records::UnknownRecord.new(type_id: function, raw_bytes: raw)
      expect { Emf.serialize(remaining_geometry_metafile(record)) }.to raise_error(Emf::SerializeError, /raw WMF/)
    end
  end
end
