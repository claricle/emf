# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/native_wmf"

RSpec.describe "WMF palette records" do
  include NativeWmfSupport

  let(:array_functions) { { CreatePalette: 0x00F7, SetPalEntries: 0x0037, AnimatePalette: 0x0436 } }
  let(:channels) { { red: 255, green: 128, blue: 0, flags: 254 } }
  let(:entry) { Emf::Model::Wmf::Records::PaletteEntry.new(**channels) }
  let(:prefix) { [0xFFFF, 1].pack("v2") + channels.values.pack("C4") }
  let(:suffix) { "\xFE\xAD".b }
  let(:unknown) { native_wmf_record(0x7FFE, "raw!") }
  let(:placeable_options) { [false, true] }
  let(:invalid_words) { [-1, 65_536, nil, "1"] }
  let(:invalid_bytes) { [-1, 256, nil, "1"] }
  let(:invalid_arrays) { [nil, "entries", [nil], Array.new(65_536, entry)] }
  let(:invalid_suffixes) { [nil, "x"] }
  let(:malformed_bodies) { ["".b, [0].pack("v"), [0, 1].pack("v2"), [0, 2, 0, 0].pack("v4")] }
  let(:zero_handle) { [0].pack("v") }
  let(:one_handle) { [1].pack("v") }
  let(:invalid_handle) { [2].pack("v") }
  let(:maximum_word) { [65_535].pack("v") }
  let(:grown_prefix) { [0, 2].pack("v2") }
  let(:empty_prefix) { [0, 0].pack("v2") }
  let(:edited_channels) { [17, 17, 17, 17].pack("C4") }
  let(:brush_body) { [0, 0, 0, 0].pack("v4") }

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

      it "preserves palette channels, noncanonical start, function high bytes and suffixes" do
        array_functions.each do |name, function|
          placeable_options.each do |placeable|
            bytes = native_wmf_bytes([native_wmf_record(function | 0xAB00, prefix + suffix), unknown], placeable: placeable)
            parsed = Emf.parse(bytes)
            record = parsed.records.first
            expect(record).to be_a(Emf::Model::Wmf::Records.const_get(name))
            expect(record.type_id).to eq(function | 0xAB00)
            expect(record.start).to eq(0xFFFF)
            expect(record.entries.map(&:to_h)).to eq([channels])
            expect(record.suffix).to eq(suffix)
            expect(parsed.records[-2].raw_bytes).to eq(unknown)
            expect(Emf.serialize(parsed)).to eq(bytes)
          end
        end
      end

      it "constructs canonical records and derives entry counts after growth and shrinkage" do
        array_functions.each do |name, function|
          klass = Emf::Model::Wmf::Records.const_get(name)
          expect(klass.new(start: 0, entries: []).type_id).to eq(function)
          bytes = native_wmf_bytes([native_wmf_record(function, prefix + suffix), unknown], placeable: true)
          parsed = Emf.parse(bytes)
          record = parsed.records.first
          record.start = 0
          channels.each_key { |field| record.entries.first.public_send("#{field}=", 17) }
          record.entries << entry
          record.suffix += "more"
          body = "#{grown_prefix}#{edited_channels}#{channels.values.pack('C4')}#{suffix}more"
          output = Emf.serialize(parsed)
          expect(output).to eq(native_wmf_bytes([native_wmf_record(function, body), unknown], placeable: true))
          expect(Emf.parse(output).records.first.entries.map(&:to_h)).to eq([channels.transform_values { 17 }, channels])
          record.entries.clear
          empty = "#{empty_prefix}#{suffix}more"
          expect(Emf.serialize(parsed)).to eq(native_wmf_bytes([native_wmf_record(function, empty), unknown], placeable: true))
        end
      end

      it "edits scalar palette records and retains their suffixes" do
        create = native_wmf_record(0x00F7, prefix)
        select = native_wmf_record(0xAB34, zero_handle + suffix)
        resize = native_wmf_record(0xAB39, maximum_word + suffix)
        realize = native_wmf_record(0xAB35, suffix)
        parsed = Emf.parse(native_wmf_bytes([create, create, select, resize, realize], capacity: 2))
        selection, sizing, realization = parsed.records[2, 3]
        expect(selection).to be_a(Emf::Model::Wmf::Records::SelectPalette)
        expect(sizing.entry_count).to eq(65_535)
        expect(realization).to be_a(Emf::Model::Wmf::Records::RealizePalette)
        expect([selection.suffix, sizing.suffix, realization.suffix]).to eq([suffix] * 3)
        selection.object_index = 1
        sizing.entry_count = 0
        realization.suffix += "more"
        expected = [create, create, native_wmf_record(0xAB34, one_handle + suffix),
                    native_wmf_record(0xAB39, zero_handle + suffix), native_wmf_record(0xAB35, "#{suffix}more")]
        expect(Emf.serialize(parsed)).to eq(native_wmf_bytes(expected, capacity: 2))
        expect(Emf::Model::Wmf::Records::SelectPalette.new(object_index: 0).type_id).to eq(0x0234)
        expect(Emf::Model::Wmf::Records::ResizePalette.new(entry_count: 0).type_id).to eq(0x0139)
        expect(Emf::Model::Wmf::Records::RealizePalette.new.type_id).to eq(0x0035)
      end

      it "enforces palette selection kind, capacity, deletion and slot reuse" do
        create = native_wmf_record(0x00F7, prefix)
        select = native_wmf_record(0x0234, zero_handle)
        delete = native_wmf_record(0x01F0, zero_handle)
        bytes = native_wmf_bytes([create, select, delete, create, select], capacity: 1)
        expect(Emf.serialize(Emf.parse(bytes))).to eq(bytes)
        # A palette selection naming no live object is recovered (the reference is ignored and recorded), not rejected.
        [[select], [create, delete, select], [create, native_wmf_record(0x0234, invalid_handle)]].each do |records|
          file = native_wmf_bytes(records)
          expect(Emf.parse(file).errors.map { |error| error.evidence.check }).to eq([:object_reference_invalid])
          expect(Emf.serialize(Emf.parse(file))).to eq(file)
        end
        expect { Emf.parse(native_wmf_bytes([create, create], capacity: 1)) }.to raise_error(Emf::ParseError)
        brush = native_wmf_record(0x02FC, brush_body)
        expect { Emf.parse(native_wmf_bytes([brush, select])) }.to raise_error(Emf::ParseError)
      end

      it "rejects truncated prefixes and entry arrays before hydration" do
        array_functions.each_value do |function|
          malformed_bodies.each do |body|
            expect { Emf.parse(native_wmf_bytes([native_wmf_record(function, body)])) }.to raise_error(Emf::ParseError)
          end
        end
        expect { Emf.parse(native_wmf_bytes([native_wmf_record(0x0139, "".b)])) }.to raise_error(Emf::ParseError)
        expect { Emf.parse(native_wmf_bytes([native_wmf_record(0x0234, "".b)])) }.to raise_error(Emf::ParseError)
      end

      it "rejects invalid edited palette words, channels, arrays, suffixes and function identities" do
        bytes = native_wmf_bytes([native_wmf_record(0x00F7, prefix)])
        invalid_words.each do |value|
          parsed = Emf.parse(bytes)
          parsed.records.first.start = value
          expect { Emf.serialize(parsed) }.to raise_error(Emf::SerializeError)
        end
        channels.each_key do |field|
          invalid_bytes.each do |value|
            parsed = Emf.parse(bytes)
            parsed.records.first.entries.first.public_send("#{field}=", value)
            expect { Emf.serialize(parsed) }.to raise_error(Emf::SerializeError)
          end
        end
        invalid_arrays.each do |value|
          parsed = Emf.parse(bytes)
          parsed.records.first.entries = value
          expect { Emf.serialize(parsed) }.to raise_error(Emf::SerializeError)
        end
        invalid_suffixes.each do |value|
          parsed = Emf.parse(bytes)
          parsed.records.first.suffix = value
          expect { Emf.serialize(parsed) }.to raise_error(Emf::SerializeError)
        end
        parsed = Emf.parse(bytes)
        invalid = Emf::Model::Wmf::Records::CreatePalette.new(start: 0, entries: [], type_id: 0x7FFE)
        invalid_file = Emf::Model::Metafile.new(format: :wmf, header: parsed.header, records: [invalid, parsed.records.last])
        expect { Emf.serialize(invalid_file) }.to raise_error(Emf::SerializeError)
        opaque = Emf::Model::Wmf::Records::UnknownRecord.new(type_id: 0x00F7, raw_bytes: native_wmf_record(0x00F7, prefix))
        disguised = Emf::Model::Metafile.new(format: :wmf, header: parsed.header, records: [opaque, parsed.records.last])
        expect { Emf.serialize(disguised) }.to raise_error(Emf::SerializeError)
      end

      it "rejects scalar edits outside their unsigned word width" do
        invalid_words.each do |value|
          parsed = Emf.parse(native_wmf_bytes([native_wmf_record(0x0139, zero_handle)]))
          parsed.records.first.entry_count = value
          expect { Emf.serialize(parsed) }.to raise_error(Emf::SerializeError)
          parsed = Emf.parse(native_wmf_bytes([native_wmf_record(0x00F7, prefix), native_wmf_record(0x0234, zero_handle)]))
          parsed.records[1].object_index = value
          expect { Emf.serialize(parsed) }.to raise_error(Emf::SerializeError)
        end
      end
    end
  end
end
