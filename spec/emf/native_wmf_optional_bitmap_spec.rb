# frozen_string_literal: true

require "spec_helper"
require "emf/wmf/text_codec"
require_relative "../support/native_wmf_bridge"

RSpec.describe "Native WMF optional bitmap bridge" do
  include_context "native WMF bridge"

  it "matches Ruby fields and exact bytes for optional DIB and stretch blits" do
    bitmap = "\xDE\xAD\xBE\xEF".b
    suffix = "\xAA\xBB".b
    cases = [
      {
        function: 0x0940,
        present_body: [0xFEDCBA98].pack("V") + [-32_768, 32_767, -1, 2, -3, 32_767].pack("s<6") + bitmap,
        absent_function: 0x0A40,
        absent_body: [0xFEDCBA98].pack("V") + [-32_768, 32_767].pack("s<2") + [0xFFFF].pack("v") +
          [-1, 2, -3, 32_767].pack("s<4") + suffix,
        fields: %i[type_id raster_operation source_y source_x height width destination_y destination_x reserved bitmap suffix],
        klass: Emf::Model::Wmf::Records::DibBitBlt,
        coordinates: { source_y: -32_768, source_x: 32_767, height: -1, width: 2, destination_y: -3, destination_x: 32_767 },
        absent: { reserved: 0xFFFF, bitmap: nil, suffix: suffix }
      },
      {
        function: 0x0B23,
        present_body: [0xFEDCBA98].pack("V") + [-32_768, 32_767, -1, 2, -3, 4, -5, 32_767].pack("s<8") + bitmap,
        absent_function: 0x0C23,
        absent_body: [0xFEDCBA98].pack("V") + [-32_768, 32_767, -1, 2].pack("s<4") + [0xFFFF].pack("v") +
          [-3, 4, -5, 32_767].pack("s<4") + suffix,
        fields: %i[type_id raster_operation source_height source_width source_y source_x destination_height destination_width
                   destination_y destination_x reserved bitmap suffix],
        klass: Emf::Model::Wmf::Records::StretchBlt,
        coordinates: {
          source_height: -32_768, source_width: 32_767, source_y: -1, source_x: 2,
          destination_height: -3, destination_width: 4, destination_y: -5, destination_x: 32_767
        },
        absent: { reserved: 0xFFFF, bitmap: nil, suffix: suffix }
      },
      {
        function: 0x0B41,
        present_body: [0xFEDCBA98].pack("V") + [-32_768, 32_767, -1, 2, -3, 4, -5, 32_767].pack("s<8") + bitmap,
        absent_function: 0x0C41,
        absent_body: [0xFEDCBA98].pack("V") + [-32_768, 32_767, -1, 2].pack("s<4") + [0xFFFF].pack("v") +
          [-3, 4, -5, 32_767].pack("s<4") + suffix,
        fields: %i[type_id raster_operation source_height source_width source_y source_x destination_height destination_width
                   destination_y destination_x reserved bitmap suffix],
        klass: Emf::Model::Wmf::Records::DibStretchBlt,
        coordinates: {
          source_height: -32_768, source_width: 32_767, source_y: -1, source_x: 2,
          destination_height: -3, destination_width: 4, destination_y: -5, destination_x: 32_767
        },
        absent: { reserved: 0xFFFF, bitmap: nil, suffix: suffix }
      }
    ]
    inputs = cases.flat_map do |entry|
      [
        native_wmf_bytes([native_wmf_record(entry.fetch(:function), entry.fetch(:present_body))]),
        native_wmf_bytes([native_wmf_record(entry.fetch(:absent_function), entry.fetch(:absent_body))])
      ]
    end

    ENV["EMF_BACKEND"] = "ruby"
    ruby_results = inputs.map do |input|
      parsed = Emf.parse(input)
      [parsed.records.first, Emf.serialize(parsed)]
    end

    expect(Emf::Wmf::Parser).not_to receive(:call)
    ENV["EMF_BACKEND"] = "native"
    cases.zip(inputs.each_slice(2).to_a, ruby_results.each_slice(2).to_a).each do |entry, pair_inputs, pair_results|
      pairs = [entry.fetch(:present_body), entry.fetch(:absent_body)].zip(pair_inputs, pair_results)
      pairs.each_with_index do |(_body, input, ruby_result), index|
        ruby_record, ruby_bytes = ruby_result
        native = Emf.parse(input)
        native_record = native.records.first
        native_bytes = Emf.serialize(native)

        expect(ruby_record).to be_a(entry.fetch(:klass))
        expect(native_record).to be_a(entry.fetch(:klass))
        expect(entry.fetch(:fields).map { |field| native_record.public_send(field) })
          .to eq(entry.fetch(:fields).map { |field| ruby_record.public_send(field) })
        expect(entry.fetch(:coordinates).to_h { |field, _value| [field, native_record.public_send(field)] })
          .to eq(entry.fetch(:coordinates))
        expect(native_record.reserved).to eq(index.zero? ? 0 : entry.fetch(:absent).fetch(:reserved))
        expect(native_record.bitmap).to eq(index.zero? ? bitmap : entry.fetch(:absent).fetch(:bitmap))
        expect(native_record.suffix).to eq(index.zero? ? "".b : entry.fetch(:absent).fetch(:suffix))
        expect([ruby_bytes, native_bytes]).to eq([input, input])
      end
    end
  end
end
