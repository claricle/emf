# frozen_string_literal: true

require_relative "../../bench/support/wmf_workloads"
require_relative "../support/native_wmf_bridge"

RSpec.describe "Native WMF benchmark workloads" do
  include_context "native WMF bridge"

  let(:families) { %i[geometry text bitmap unknown] }
  let(:placeable_options) { [false, true] }
  let(:expected_points) { [[20, -30], [-50, 40]] }
  let(:expected_text) { ["WMF text!", 30, -20] }
  let(:expected_bitmap) { [0x0B41, 44] }
  let(:expected_unknown_bytes) { [7, 0x80FE].pack("Vv") + "\x00\xFFopaque".b }
  let(:record_snapshot) do
    lambda do |record|
      fields = record.instance_variables.reject { |field| field == :@offset }.sort
      [record.class, *fields.map { |field| record.instance_variable_get(field) }]
    end
  end

  it "round trips every generated family in standard and placeable files with Ruby parity" do
    inputs = families.flat_map do |family|
      placeable_options.map do |placeable|
        input = ParserBenchmark::WmfWorkloads.build(family: family, repetitions: 3, placeable: placeable)
        ENV["EMF_BACKEND"] = "ruby"
        ruby_file = Emf.parse(input)
        [input, family, placeable, ruby_file.records.map { |record| record_snapshot.call(record) }]
      end
    end

    expect(Emf::Wmf::Parser).not_to receive(:call)
    ENV["EMF_BACKEND"] = "native"
    inputs.each do |input, family, placeable, ruby_records|
      native_file = Emf.parse(input)
      native_records = native_file.records.map { |record| record_snapshot.call(record) }
      expect(native_records).to eq(ruby_records), "#{family} placeable=#{placeable}"
      case family
      when :geometry
        points = native_file.records.grep(Emf::Model::Wmf::Records::PointRecord).map do |record|
          [record.x, record.y]
        end
        expect(points).to eq(expected_points * 3)
      when :text
        texts = native_file.records.grep(Emf::Model::Wmf::Records::TextOut).map do |record|
          [record.text, record.x, record.y]
        end
        expect(texts).to eq([expected_text] * 3)
      when :bitmap
        bitmaps = native_file.records.grep(Emf::Model::Wmf::Records::DibStretchBlt)
        expect(bitmaps.map { |record| [record.type_id, record.bitmap.bytesize] }).to eq([expected_bitmap] * 3)
      when :unknown
        unknowns = native_file.records.grep(Emf::Model::Wmf::Records::UnknownRecord)
        expect(unknowns.map { |record| [record.type_id, record.raw_bytes] })
          .to eq([[0x80FE, expected_unknown_bytes]] * 3)
      end
      expect(Emf.serialize(native_file)).to eq(input), "#{family} placeable=#{placeable}"
    end
  end

  it "keeps unknown function words and their complete opaque records" do
    input = ParserBenchmark::WmfWorkloads.build(family: :unknown, repetitions: 3)
    ENV["EMF_BACKEND"] = "ruby"
    ruby_file = Emf.parse(input)
    expected = ruby_file.records.grep(Emf::Model::Wmf::Records::UnknownRecord).map do |record|
      [record.type_id, record.raw_bytes]
    end

    expect(expected).not_to be_empty
    expect(Emf::Wmf::Parser).not_to receive(:call)
    ENV["EMF_BACKEND"] = "native"
    native_file = Emf.parse(input)
    actual = native_file.records.grep(Emf::Model::Wmf::Records::UnknownRecord).map do |record|
      [record.type_id, record.raw_bytes]
    end

    expect(actual).to eq(expected)
    expect(Emf.serialize(native_file)).to eq(input)
  end

  it "preserves unrelated records after native geometry and text edits and reparses" do
    cases = [
      [:geometry, Emf::Model::Wmf::Records::LineTo, :x, -321],
      [:text, Emf::Model::Wmf::Records::TextOut, :text, "edited workload"]
    ]
    inputs = cases.map do |family, record_class, field, value|
      input = ParserBenchmark::WmfWorkloads.build(family: family, repetitions: 3)
      ENV["EMF_BACKEND"] = "ruby"
      ruby_file = Emf.parse(input)
      target_position = ruby_file.records.index { |record| record.is_a?(record_class) }
      [input, family, record_class, field, value,
       ruby_file.records.each_with_index.filter_map do |record, index|
         record_snapshot.call(record) unless index == target_position
       end]
    end

    expect(Emf::Wmf::Parser).not_to receive(:call)
    ENV["EMF_BACKEND"] = "native"
    inputs.each do |input, family, record_class, field, value, preserved_records|
      parsed = Emf.parse(input)
      target = parsed.records.find { |record| record.is_a?(record_class) }
      expect(target).not_to be_nil
      actual_target_position = parsed.records.index(target)
      target.public_send("#{field}=", value)
      reparsed = Emf.parse(Emf.serialize(parsed))
      expect(reparsed.records[actual_target_position].public_send(field)).to eq(value), family.to_s
      actual_preserved = reparsed.records.each_with_index.filter_map do |record, index|
        record_snapshot.call(record) unless index == actual_target_position
      end
      expect(actual_preserved)
        .to eq(preserved_records), family.to_s
    end
  end
end
