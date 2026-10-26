# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/wmf_point_arrays"

RSpec.describe "WMF point-array drawing records" do
  include WmfPointArraysSupport

  let(:coordinates) { [[-32_768, 32_767], [123, -456]] }
  let(:families) { { 0x0324 => [2], 0x0325 => [2], 0x0538 => [2, 0, 2] } }
  let(:unknown) { geometry_record(0x7FFE, [-12, 34]) }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("EMF_BACKEND", "auto").and_return("ruby")
  end

  it "exposes typed mutable PointS arrays in X/Y order and polygon counts" do
    families.each do |function, counts|
      record = Emf.parse(geometry_file([point_array_record(function, counts, coordinates)])).records.first
      expect(record).to be_a(point_array_class(function))
      expect(record.offset).to eq(18)
      expect(record.points.map { |point| [point.x, point.y] }).to eq(coordinates)
      expect(record.points.first).to be_a(Emf::Model::Wmf::Records::PointS)
      record.points.first.x = 42
      expect(record.points.first.x).to eq(42)
      expect(record.points_per_polygon).to eq([0, 2]) if function == 0x0538
    end
  end

  it "preserves high function bytes, unknown siblings, placeable checksum and trailing data" do
    families.each do |function, counts|
      function = 0x7F00 | (function & 0xFF)
      raw = point_array_record(function, counts, coordinates)
      bytes = geometry_file([unknown, raw, unknown], placeable: true, trailing: "\xFFtail".b)
      metafile = Emf.parse(bytes)
      expect(metafile.records[1]).to be_a(point_array_class(function))
      expect(metafile.records[1].type_id).to eq(function)
      expect(metafile.records.values_at(0, 2).map(&:raw_bytes)).to eq([unknown, unknown])
      expect(Emf.serialize(metafile)).to eq(bytes)
    end
  end

  it "serializes point edits, growth and shrinkage while recalculating framing" do
    families.each do |function, counts|
      metafile = Emf.parse(geometry_file([unknown, point_array_record(function, counts, coordinates)],
                                         placeable: true, trailing: "tail"))
      record = metafile.records[1]
      record.points.first.y = -7
      record.points << point_array_points([[6, -8]]).first
      record.points_per_polygon = [1, 2] if function == 0x0538
      expected_coordinates = [[-32_768, -7], [123, -456], [6, -8]]
      expected_counts = function == 0x0538 ? [2, 1, 2] : [3]
      expected = geometry_file([unknown, point_array_record(function, expected_counts, expected_coordinates)],
                               placeable: true, trailing: "tail")
      expect(Emf.serialize(metafile)).to eq(expected)
      reparsed = Emf.parse(Emf.serialize(metafile))
      expect(reparsed.header.max_record_words).to eq(3 + expected_counts.length + 6)
      expect(reparsed.header.size_words).to eq(9 + 5 + reparsed.header.max_record_words + 3)
      record.points.pop
      record.points_per_polygon = [2] if function == 0x0538
      expected_counts = function == 0x0538 ? [1, 2] : [2]
      expected = geometry_file([unknown, point_array_record(function, expected_counts, expected_coordinates.take(2))],
                               placeable: true, trailing: "tail")
      expect(Emf.serialize(metafile)).to eq(expected)
      expect(Emf.parse(expected).records[1].points.length).to eq(2)
    end
  end

  it "accepts the documented zero and minimum counts" do
    [[0x0324, [2], coordinates], [0x0325, [0], []], [0x0325, [1], [[1, -2]]],
     [0x0538, [0], []], [0x0538, [2, 0, 1], [[1, -2]]]].each do |function, counts, points|
      bytes = geometry_file([point_array_record(function, counts, points)])
      expect(Emf.parse(bytes).records.first.points.length).to eq(points.length)
      expect(Emf.serialize(Emf.parse(bytes))).to eq(bytes)
    end
  end

  it "rejects missing, signed-negative, undersized and mismatched payload counts with record context" do
    malformed = [[0x0324, [], []], [0x0324, [1], [[1, 2]]],
                 [0x0325, [], []], [0x0325, [0xFFFF], []], [0x0324, [0x8000], []],
                 [0x0324, [2], [[1, 2]]], [0x0325, [1], coordinates],
                 [0x0538, [], []], [0x0538, [0xFFFF], []], [0x0538, [2, 1], []],
                 [0x0538, [1, 2], [[1, 2]]], [0x0538, [1, 1], coordinates],
                 [0x0538, [0], [[1, 2]]], [0x0538, [1, 0xFFFF], []]]
    malformed.each do |function, counts, points|
      bytes = geometry_file([point_array_record(function, counts, points)])
      expect { Emf.parse(bytes) }.to raise_error(Emf::ParseError) do |error|
        expect(error.offset).to eq(18)
        expect(error.record_code).to eq(function)
      end
    end
  end

  it "keeps a zero-point polygon in an 8-byte record and records it as a parse error" do
    metafile = Emf.parse(geometry_file([point_array_record(0x0324, [0], [])]))
    expect(metafile.records.first.points).to eq([])
    expect(metafile.errors.map { |error| [error.offset, error.record_code] }).to eq([[18, 0x0324]])
  end

  it "honors signed simple counts and unsigned polygon counts at their upper boundaries" do
    [[0x0325, [32_767], Array.new(32_767, [1, -2])],
     [0x0538, [1, 65_535], Array.new(65_535, [-3, 4])],
     [0x0538, [65_535, *Array.new(65_535, 0)], []]].each do |function, counts, points|
      bytes = geometry_file([point_array_record(function, counts, points)])
      record = Emf.parse(bytes).records.first
      expect(record.points.length).to eq(points.length)
      expect(Emf.serialize(Emf.parse(bytes))).to eq(bytes)
    end
  end

  it "validates typed point coordinates, collection counts and family functions on serialization" do
    fields_to_check = %i[x y]
    invalid_coordinates = [-32_769, 32_768, 1.5, nil]
    wrong_functions = [-1, 65_536, 0x0213]
    families.each do |function, counts|
      metafile = Emf.parse(geometry_file([point_array_record(function, counts, coordinates)]))
      record = metafile.records.first
      fields_to_check.each do |field|
        invalid_coordinates.each do |value|
          record.points = point_array_points(coordinates)
          record.points.first.public_send("#{field}=", value)
          expect { Emf.serialize(metafile) }.to raise_error(Emf::SerializeError)
        end
      end
      record.points = point_array_points(coordinates)
      wrong_functions.each do |wrong|
        fields = { points: record.points, type_id: wrong }
        fields[:points_per_polygon] = [2] if function == 0x0538
        invalid = point_array_class(function).new(**fields)
        expect { Emf.serialize(geometry_with_records(metafile, [invalid, metafile.records.last])) }.to raise_error(Emf::SerializeError)
      end
      record.points = []
      expect { Emf.serialize(metafile) }.to raise_error(Emf::SerializeError) unless function == 0x0325
    end
  end

  it "rejects invalid polygon counts and excessive signed point counts" do
    metafile = Emf.parse(geometry_file([point_array_record(0x0538, [1, 2], coordinates)]))
    record = metafile.records.first
    [[-1], [65_536], [nil], [1.5], [1], [3], Array.new(65_536, 0)].each do |counts|
      record.points_per_polygon = counts
      expect { Emf.serialize(metafile) }.to raise_error(Emf::SerializeError)
    end
    record = Emf::Model::Wmf::Records::Polyline.new(points: Array.new(32_768, point_array_points([[1, 2]]).first))
    expect { Emf.serialize(geometry_with_records(metafile, [record, metafile.records.last])) }.to raise_error(Emf::SerializeError)
  end

  it "rejects invalid point and polygon-count containers with serialization errors" do
    metafile = Emf.parse(geometry_file([point_array_record(0x0538, [1, 2], coordinates)]))
    record = metafile.records.first
    [nil, "points", [nil, nil], [[1, 2], [3, 4]]].each do |points|
      record.points = points
      expect { Emf.serialize(metafile) }.to raise_error(Emf::SerializeError)
    end
    record.points = point_array_points(coordinates)
    [nil, "counts"].each do |counts|
      record.points_per_polygon = counts
      expect { Emf.serialize(metafile) }.to raise_error(Emf::SerializeError)
    end
  end

  it "rejects known low-byte functions disguised as unknown records" do
    families.each do |function, counts|
      function = 0x7F00 | (function & 0xFF)
      raw = point_array_record(function, counts, coordinates)
      record = Emf::Model::Wmf::Records::UnknownRecord.new(type_id: function, raw_bytes: raw)
      metafile = Emf.parse(geometry_file([]))
      expect { Emf.serialize(geometry_with_records(metafile, [record, *metafile.records])) }.to raise_error(Emf::SerializeError)
    end
  end
end
