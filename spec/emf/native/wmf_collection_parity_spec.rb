# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/native_wmf"

RSpec.describe "WMF public record collection edits" do
  include NativeWmfSupport

  let(:opaque) do
    [native_wmf_record(0x80FE, "\xDE\xAD\xBE\xEF".b), native_wmf_record(0xAB00, "\x00\xFF\x17\xE2".b)]
  end
  let(:rectangle) { native_wmf_record(0x041B, [-10, 20, 30, -40].pack("s<4")) }
  let(:move) { native_wmf_record(0x0214, [-3, 7].pack("s<2")) }
  let(:polygon) { native_wmf_record(0x0324, [3].pack("s<") + [-1, 2, 3, -4, 5, 6].pack("s<6")) }
  let(:input) { native_wmf_bytes([opaque.first, rectangle, opaque.last, move], placeable: placeable, trailing: "\x91\x00tail".b) }
  let(:donor_input) { native_wmf_bytes([polygon], placeable: placeable) }
  let(:library) { ENV.fetch("EMF_TEST_NATIVE_LIBRARY", nil) }
  let(:expected_words) { expected_records.map { |raw| raw.bytesize / 2 } + [3] }
  let(:original_types) { [0x80FE, 0x041B, 0xAB00, 0x0214, 0] }

  around do |example|
    previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
    example.run
  ensure
    %w[EMF_BACKEND EMF_NATIVE_LIBRARY].each { |key| ENV[key] = previous[key] }
  end

  shared_examples "a structural edit" do
    it "preserves the public collection contract and two serialized generations" do
      skip "set EMF_TEST_NATIVE_LIBRARY for native collection parity" if backends.include?("native") && library.to_s.empty?

      oracle = nil
      backends.each do |backend|
        ENV["EMF_BACKEND"] = backend
        ENV["EMF_NATIVE_LIBRARY"] = library if backend == "native"
        expect(Emf::Wmf::Parser).not_to receive(:call) if backend == "native"
        parsed = Emf.parse(input)
        donor = Emf.parse(donor_input).records.first
        expect(parsed.records).to be_frozen
        expect(donor).to be_a(Emf::Model::Wmf::Records::Polygon)
        expect(donor.points.map(&:to_a)).to eq([[-1, 2], [3, -4], [5, 6]])
        records = parsed.records.dup
        case operation
        when :remove then expect(records.delete_at(1)).to equal(parsed.records[1])
        when :insert then records.insert(1, donor)
        when :replace then records[1] = donor
        end
        expect(parsed.records.map(&:type_id)).to eq(original_types)
        edited = Emf::Model::Metafile.new(format: parsed.format, header: parsed.header, records: records, trailing: parsed.trailing)
        expected_bytes = native_wmf_bytes(expected_records, placeable: placeable, trailing: parsed.trailing)

        2.times do
          bytes = Emf.serialize(edited)
          expect(bytes).to eq(expected_bytes)
          expect(bytes).to eq(oracle) if backend == "native"
          oracle ||= bytes
          edited = Emf.parse(bytes)
          expect(edited.records.map(&:type_id)).to eq([*expected_records.map { |raw| raw.unpack("Vv").last }, 0])
          expect(edited.records.grep(Emf::Model::Wmf::Records::UnknownRecord).map(&:raw_bytes)).to eq(opaque)
          expect(edited.trailing).to eq("\x91\x00tail".b)
          expect(edited.header.size_words).to eq(9 + expected_words.sum)
          expect(edited.header.max_record_words).to eq(expected_words.max)
          expect(edited.header.number_of_objects).to eq(parsed.header.number_of_objects)
          expect(edited.header.number_of_members).to eq(7)
          offset = placeable ? 22 : 0
          expect(bytes.byteslice(offset, 18).unpack("v3VvVv")).to eq([2, 9, 0x300, 9 + expected_words.sum, 2, expected_words.max, 7])
          if placeable
            expect(bytes.byteslice(0, 22)).to eq(input.byteslice(0, 22))
            expect(edited.header.placeable.checksum).to eq(Emf::Wmf::Binary.checksum(bytes.byteslice(0, 20)))
          else
            expect(edited.header.placeable).to be_nil
          end
        end
      end
    end
  end

  backend_cases = { "Ruby" => ["ruby"], "native against Ruby" => %w[ruby native] }

  [false, true].each do |placeable_container|
    context(placeable_container ? "with placeable WMF" : "with standard WMF") do
      let(:placeable) { placeable_container }

      backend_cases.each do |label, selected_backends|
        context "through #{label}" do
          let(:backends) { selected_backends }

          context "when removing the largest record" do
            let(:operation) { :remove }
            let(:expected_records) { [opaque.first, opaque.last, move] }

            include_examples "a structural edit"
          end

          context "when inserting a parsed larger record" do
            let(:operation) { :insert }
            let(:expected_records) { [opaque.first, polygon, rectangle, opaque.last, move] }

            include_examples "a structural edit"
          end

          context "when replacing a record with a parsed larger record" do
            let(:operation) { :replace }
            let(:expected_records) { [opaque.first, polygon, opaque.last, move] }

            include_examples "a structural edit"
          end
        end
      end
    end
  end
end
