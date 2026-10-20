# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/wmf_geometry"

RSpec.describe "WMF fixed geometry and mapping records" do
  include WmfGeometrySupport

  let(:families) do
    { 0x041B => "Rectangle", 0x0418 => "Ellipse", 0x020B => "SetWindowOrg", 0x020C => "SetWindowExt",
      0x020D => "SetViewportOrg", 0x020E => "SetViewportExt" }
  end
  let(:unknown) { geometry_record(0x7FFE, [-123, 456]) }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("EMF_BACKEND", "auto").and_return("ruby")
  end

  it "parses each typed family with signed coordinates in reverse wire order" do
    families.each do |function, name|
      values = function > 0x300 ? [-32_768, 32_767, -123, 456] : [-32_768, 32_767]
      bytes = geometry_file([geometry_record(function, values)])
      record = Emf.parse(bytes).records.first
      expect(record).to be_a(Emf::Model::Wmf::Records.const_get(name))
      expect(record.offset).to eq(18)
      if values.length == 4
        expect([record.bottom, record.right, record.top, record.left]).to eq(values)
      else
        expect([record.y, record.x]).to eq(values)
      end
      expect(Emf.serialize(Emf.parse(bytes))).to eq(bytes)
    end
  end

  it "preserves noncanonical function bytes, unknown siblings, placeable framing and trailing data" do
    families.each do |function, name|
      values = function > 0x300 ? [-4, 3, -2, 1] : [-2, 1]
      bytes = geometry_file([unknown, geometry_record(0x7F00 | (function & 0xFF), values), unknown],
                            placeable: true, trailing: "\xFFtail".b)
      metafile = Emf.parse(bytes)
      expect(metafile.records[1]).to be_a(Emf::Model::Wmf::Records.const_get(name))
      expect(metafile.records[1].type_id).to eq(0x7F00 | (function & 0xFF))
      expect(metafile.records.values_at(0, 2).map(&:raw_bytes)).to eq([unknown, unknown])
      expect(Emf.serialize(metafile)).to eq(bytes)
    end
  end

  it "serializes edits in wire order and recalculates file and maximum record sizes" do
    families.each do |function, name|
      klass = Emf::Model::Wmf::Records.const_get(name)
      fields = function > 0x300 ? { left: 456, top: -123, right: 32_767, bottom: -32_768 } : { x: 32_767, y: -32_768 }
      values = fields.values.reverse
      metafile = Emf.parse(geometry_file([unknown], placeable: true, trailing: "tail"))
      record = klass.new(**fields)
      function > 0x300 ? record.left = -321 : record.x = -321
      values[-1] = -321
      metafile = geometry_with_records(metafile, [metafile.records.first, record, metafile.records.last])
      expected = geometry_file([unknown, geometry_record(function, values)], placeable: true, trailing: "tail")
      bytes = Emf.serialize(metafile)
      expect(bytes).to eq(expected)
      reparsed = Emf.parse(bytes)
      expect(reparsed.header.size_words).to eq(9 + 5 + 3 + values.length + 3)
      expect(reparsed.header.max_record_words).to eq(3 + values.length)
    end
  end

  it "rejects short and overlong typed records with record location and function" do
    families.each_key do |function|
      length = function > 0x300 ? 4 : 2
      [length - 1, length + 1].each do |count|
        bytes = geometry_file([geometry_record(function, Array.new(count, 0))])
        expect { Emf.parse(bytes) }.to raise_error(Emf::ParseError) do |error|
          expect(error.offset).to eq(18)
          expect(error.record_code).to eq(function)
        end
      end
    end
  end

  it "checks every serialized field and rejects functions belonging to another family" do
    invalid_values = [-32_769, 32_768, 1.5, nil]
    wrong_functions = [0x0213, -1, 0x1_0000]
    families.each do |function, name|
      klass = Emf::Model::Wmf::Records.const_get(name)
      fields = function > 0x300 ? { left: 1, top: 2, right: 3, bottom: 4 } : { x: 1, y: 2 }
      fields.each_key do |field|
        invalid_values.each do |value|
          metafile = Emf.parse(geometry_file([]))
          metafile = geometry_with_records(metafile, [klass.new(**fields, field => value), *metafile.records])
          expect { Emf.serialize(metafile) }.to raise_error(Emf::SerializeError, /out of range/)
        end
      end
      wrong_functions.each do |wrong_function|
        metafile = Emf.parse(geometry_file([]))
        metafile = geometry_with_records(metafile, [klass.new(**fields, type_id: wrong_function), *metafile.records])
        expect { Emf.serialize(metafile) }.to raise_error(Emf::SerializeError)
      end
    end
  end

  it "rejects typed record functions disguised as unknown raw records" do
    families.each_key do |function|
      raw = geometry_record(function, function > 0x300 ? [4, 3, 2, 1] : [2, 1])
      metafile = Emf.parse(geometry_file([]))
      record = Emf::Model::Wmf::Records::UnknownRecord.new(type_id: function, raw_bytes: raw)
      metafile = geometry_with_records(metafile, [record, *metafile.records])
      expect { Emf.serialize(metafile) }.to raise_error(Emf::SerializeError, /raw WMF/)
    end
  end
end
