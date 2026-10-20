# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/wmf_objects"

RSpec.describe "WMF object records" do
  include WmfObjectsSupport

  let(:pen_payload) { [0xF005, -32_768, 32_767, 0xFE563412].pack("vs<2V") }
  let(:brush_payload) { [0x8002, 0xABEFCD89, 0xFEDC].pack("vVv") }
  let(:pen) { object_record(0x02FA, pen_payload) }
  let(:brush) { object_record(0x02FC, brush_payload) }
  let(:select_zero) { object_record(0x012D, [0].pack("v")) }
  let(:delete_zero) { object_record(0x01F0, [0].pack("v")) }
  let(:unknown) { object_record(0x7FFE, "\xAA\xBB".b) }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("EMF_BACKEND", "auto").and_return("ruby")
  end

  it "decodes mixed signed fields and preserves every COLORREF byte" do
    bytes = object_file([pen, brush, select_zero, delete_zero])
    records = Emf.parse(bytes).records
    expect(records.take(4).map { |record| record.class.name.split("::").last })
      .to eq(%w[CreatePenIndirect CreateBrushIndirect SelectObject DeleteObject])
    expect(records[0].then { |record| [record.pen_style, record.width_x, record.width_y, record.color_ref] })
      .to eq([0xF005, -32_768, 32_767, 0xFE563412])
    expect(records[1].then { |record| [record.brush_style, record.color_ref, record.brush_hatch] })
      .to eq([0x8002, 0xABEFCD89, 0xFEDC])
    expect(records.values_at(2, 3).map(&:object_index)).to eq([0, 0])
    expect(records.take(4).map(&:offset)).to eq([18, 34, 48, 56])
    expect(Emf.serialize(Emf.parse(bytes))).to eq(bytes)
  end

  it "constructs canonical records and writes scalar edits in their exact wire positions" do
    records = Emf::Model::Wmf::Records
    metafile = Emf.parse(object_file([], capacity: 2, placeable: true, trailing: "tail"))
    pen_model = records::CreatePenIndirect.new(pen_style: 1, width_x: 2, width_y: 3, color_ref: 4)
    brush_model = records::CreateBrushIndirect.new(brush_style: 0, color_ref: 1, brush_hatch: 2)
    select_model = records::SelectObject.new(object_index: 0)
    delete_model = records::DeleteObject.new(object_index: 0)
    expect([pen_model, brush_model, select_model, delete_model].map(&:type_id)).to eq([0x02FA, 0x02FC, 0x012D, 0x01F0])
    pen_model.pen_style = 0xFFFF
    pen_model.width_x = 32_767
    pen_model.width_y = -32_768
    pen_model.color_ref = 0xFF563412
    brush_model.brush_style = 0xFFFF
    brush_model.color_ref = 0xFFEFCD89
    brush_model.brush_hatch = 0xFFFF
    select_model.object_index = 1
    delete_model.object_index = 1
    edited = geometry_with_records(metafile, [pen_model, brush_model, select_model, delete_model, metafile.records.last])
    expected = object_file([object_record(0x02FA, [0xFFFF, 32_767, -32_768, 0xFF563412].pack("vs<2V")),
                            object_record(0x02FC, [0xFFFF, 0xFFEFCD89, 0xFFFF].pack("vVv")),
                            object_record(0x012D, [1].pack("v")), object_record(0x01F0, [1].pack("v"))],
                           placeable: true, trailing: "tail")
    expect(Emf.serialize(edited)).to eq(expected)
    expect(Emf.parse(expected).records[0].color_ref).to eq(0xFF563412)
  end

  it "preserves standard and placeable framing, function high bytes, unknown siblings and tails" do
    stock_selector = object_record(0x7F2D, [0xFFFF].pack("v"))
    delete = object_record(0x7FF0, [0].pack("v"))
    [false, true].each do |placeable|
      bytes = object_file([unknown, object_record(0x7FFA, pen_payload), object_record(0x7FFC, brush_payload),
                           stock_selector, delete, unknown],
                          placeable: placeable, trailing: "\xFFtail".b)
      metafile = Emf.parse(bytes)
      expect(metafile.records[1].type_id).to eq(0x7FFA)
      expect(metafile.records[2].type_id).to eq(0x7FFC)
      expect(metafile.records[3].object_index).to eq(0xFFFF)
      expect(metafile.records.values_at(0, 5).map(&:raw_bytes)).to eq([unknown, unknown])
      expect(Emf.serialize(metafile)).to eq(bytes)
    end
  end

  it "preserves stock selectors without allocating or deleting a table object" do
    selector = object_record(0x012D, [0x8007].pack("v"))
    bytes = object_file([selector], capacity: 0)
    expect(Emf.parse(bytes).records.first.object_index).to eq(0x8007)
    expect(Emf.serialize(Emf.parse(bytes))).to eq(bytes)
    expect { Emf.parse(object_file([object_record(0x01F0, [0x8007].pack("v"))], capacity: 0)) }
      .to raise_error(Emf::ParseError, /invalid object reference/)
  end

  it "rejects typed object functions disguised as opaque records" do
    metafile = Emf.parse(object_file([]))
    [pen, brush, select_zero, delete_zero].each do |raw|
      record = Emf::Model::Wmf::Records::UnknownRecord.new(type_id: raw.byteslice(4, 2).unpack1("v"), raw_bytes: raw)
      edited = geometry_with_records(metafile, [record, metafile.records.last])
      expect { Emf.serialize(edited) }.to raise_error(Emf::SerializeError, /invalid raw WMF record/)
    end
  end

  it "allocates the lowest free handle and reuses deleted handles within declared capacity" do
    bytes = object_file([pen, brush, delete_zero, pen, select_zero, delete_zero,
                         object_record(0x012D, [1].pack("v"))], capacity: 2)
    expect(Emf.serialize(Emf.parse(bytes))).to eq(bytes)
  end

  it "reserves handles for opaque object creators without decoding their payloads" do
    select_one = object_record(0x012D, [1].pack("v"))
    [0x00F7, 0x01F9, 0x02FB, 0x06FF, 0x0142].each do |function|
      creator = object_record(function, "\x00\x00".b)
      bytes = object_file([creator, pen, select_one, delete_zero, brush, select_zero])
      metafile = Emf.parse(bytes)
      expect(metafile.records.first.raw_bytes).to eq(creator)
      expect(Emf.serialize(metafile)).to eq(bytes)
    end
  end

  it "rejects nonexistent, deleted and out-of-capacity handles with the record location" do
    [[[], select_zero, 0], [[pen], object_record(0x012D, [1].pack("v")), 1],
     [[pen, delete_zero], select_zero, 1], [[pen, delete_zero], delete_zero, 1],
     [[], delete_zero, 2], [[], pen, 0], [[pen], brush, 1]].each do |prefix, invalid, capacity|
      bytes = object_file(prefix + [invalid], capacity: capacity)
      expect { Emf.parse(bytes) }.to raise_error(Emf::ParseError) do |error|
        expect(error.offset).to eq(18 + prefix.sum(&:bytesize))
        expect(error.record_code).to eq(invalid.byteslice(4, 2).unpack1("v"))
        expect(error.message).to match(/object (reference|table capacity)/)
      end
    end
  end

  it "rejects malformed object payload lengths before object-table processing" do
    [[0x02FA, pen_payload], [0x02FC, brush_payload], [0x012D, [0].pack("v")], [0x01F0, [0].pack("v")]].each do |function, payload|
      [payload.byteslice(0...-2), "#{payload}\x00\x00"].each do |invalid|
        expect { Emf.parse(object_file([object_record(function, invalid)])) }.to raise_error(Emf::ParseError) do |error|
          expect(error.offset).to eq(18)
          expect(error.record_code).to eq(function)
          expect(error.message).to include("invalid object record length")
        end
      end
    end
  end

  it "rejects scalar overflow, function mismatches and lifecycle edits during serialization" do
    metafile = Emf.parse(object_file([pen, brush, select_zero, delete_zero]))
    [[0, :pen_style, -1], [0, :width_x, 32_768], [0, :width_y, -32_769], [0, :color_ref, 0x100000000],
     [1, :brush_style, 65_536], [1, :color_ref, -1], [1, :brush_hatch, 65_536],
     [2, :object_index, -1], [2, :object_index, 2], [3, :object_index, 65_536]].each do |index, field, value|
      record = metafile.records[index]
      original = record.public_send(field)
      record.public_send("#{field}=", value)
      expect { Emf.serialize(metafile) }.to raise_error(Emf::SerializeError)
      record.public_send("#{field}=", original)
    end
    overflowing = geometry_with_records(metafile, [metafile.records[0], metafile.records[1],
                                                   metafile.records[0], metafile.records.last])
    expect { Emf.serialize(overflowing) }.to raise_error(Emf::SerializeError, /capacity/)
    mismatched = Emf::Model::Wmf::Records::SelectObject.new(object_index: 0, type_id: 0x01F0)
    invalid = geometry_with_records(metafile, [metafile.records.first, mismatched, metafile.records.last])
    expect { Emf.serialize(invalid) }.to raise_error(Emf::SerializeError, /RecordFunction mismatch/)
  end
end
