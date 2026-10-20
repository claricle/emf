# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/wmf_geometry"

RSpec.describe "WMF arcs, rounded rectangles and origin offsets" do
  include WmfGeometrySupport

  let(:families) do
    {
      0x0817 => ["Arc", %i[y_end_arc x_end_arc y_start_arc x_start_arc bottom right top left]],
      0x081A => ["Pie", %i[y_radial2 x_radial2 y_radial1 x_radial1 bottom right top left]],
      0x0830 => ["Chord", %i[y_radial2 x_radial2 y_radial1 x_radial1 bottom right top left]],
      0x061C => ["RoundRect", %i[height width bottom right top left]],
      0x020F => ["OffsetWindowOrg", %i[y_offset x_offset]],
      0x0211 => ["OffsetViewportOrg", %i[y_offset x_offset]]
    }
  end
  let(:values) { [-32_768, 32_767, -123, 456, -789, 1234, -2345, 3456] }
  let(:unknown) { geometry_record(0x7FFE, [-123, 456]) }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("EMF_BACKEND", "auto").and_return("ruby")
  end

  it "decodes the specified endpoint, radial, corner ellipse and offset fields in wire order" do
    families.each do |function, (name, fields)|
      wire_values = values.take(fields.length)
      bytes = geometry_file([geometry_record(function, wire_values)])
      record = Emf.parse(bytes).records.first
      expect(record.class.name).to eq("Emf::Model::Wmf::Records::#{name}")
      expect(record.offset).to eq(18)
      expect(fields.map { |field| record.public_send(field) }).to eq(wire_values)
      expect(Emf.serialize(Emf.parse(bytes))).to eq(bytes)
    end
  end

  it "constructs canonical functions and serializes edits to every signed field" do
    signed_limits = [-32_768, 32_767]
    families.each do |function, (name, fields)|
      klass = Emf::Model::Wmf::Records.const_get(name)
      metafile = Emf.parse(geometry_file([unknown], placeable: true, trailing: "tail"))
      record = klass.new(**fields.zip(values).to_h)
      expect(record.type_id).to eq(function)
      metafile = geometry_with_records(metafile, [metafile.records.first, record, metafile.records.last])
      fields.each do |field|
        signed_limits.each do |value|
          record.public_send("#{field}=", value)
          wire_values = fields.map { |item| record.public_send(item) }
          expected = geometry_file([unknown, geometry_record(function, wire_values)], placeable: true, trailing: "tail")
          expect(Emf.serialize(metafile)).to eq(expected)
          reparsed = Emf.parse(expected)
          expect(reparsed.records[1].public_send(field)).to eq(value)
          expect(reparsed.header.max_record_words).to eq([5, 3 + fields.length].max)
          expect(reparsed.header.size_words).to eq(9 + 5 + 3 + fields.length + 3)
        end
      end
    end
  end

  it "preserves full function words, unknown siblings, placeable framing and trailing bytes" do
    families.each do |function, (name, fields)|
      function = 0x7F00 | (function & 0xFF)
      bytes = geometry_file([unknown, geometry_record(function, values.take(fields.length)), unknown],
                            placeable: true, trailing: "\xFFtail".b)
      metafile = Emf.parse(bytes)
      expect(metafile.records[1].class.name).to eq("Emf::Model::Wmf::Records::#{name}")
      expect(metafile.records[1].type_id).to eq(function)
      expect(metafile.records.values_at(0, 2).map(&:raw_bytes)).to eq([unknown, unknown])
      expect(Emf.serialize(metafile)).to eq(bytes)
    end
  end

  it "rejects truncated and overlong payloads with their record location and function" do
    families.each do |function, (_name, fields)|
      [fields.length - 1, fields.length + 1].each do |length|
        bytes = geometry_file([unknown, geometry_record(function, Array.new(length, 0))])
        expect { Emf.parse(bytes) }.to raise_error(Emf::ParseError) do |error|
          expect(error.offset).to eq(28)
          expect(error.record_code).to eq(function)
          expect(error.message).to include("invalid fixed record length")
        end
      end
    end
  end

  it "validates every signed field and family function during serialization" do
    invalid_values = [-32_769, 32_768, nil, 1.5]
    wrong_functions = [-1, 65_536, 0x041B]
    families.each_value do |name, fields|
      klass = Emf::Model::Wmf::Records.const_get(name)
      attributes = fields.zip(values).to_h
      metafile = Emf.parse(geometry_file([]))
      fields.each do |field|
        invalid_values.each do |value|
          record = klass.new(**attributes, field => value)
          expect { Emf.serialize(geometry_with_records(metafile, [record, *metafile.records])) }
            .to raise_error(Emf::SerializeError, /out of range/)
        end
      end
      wrong_functions.each do |function|
        record = klass.new(**attributes, type_id: function)
        expect { Emf.serialize(geometry_with_records(metafile, [record, *metafile.records])) }
          .to raise_error(Emf::SerializeError)
      end
    end
  end

  it "rejects typed functions disguised as raw unknown records" do
    families.each do |function, (_name, fields)|
      [function, 0x7F00 | (function & 0xFF)].each do |type_id|
        raw = geometry_record(type_id, values.take(fields.length))
        record = Emf::Model::Wmf::Records::UnknownRecord.new(type_id: type_id, raw_bytes: raw)
        metafile = Emf.parse(geometry_file([]))
        expect { Emf.serialize(geometry_with_records(metafile, [record, *metafile.records])) }
          .to raise_error(Emf::SerializeError, /raw WMF/)
      end
    end
  end
end
