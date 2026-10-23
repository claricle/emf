# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/native_wmf"

RSpec.describe "WMF CreateFontIndirect" do
  include NativeWmfSupport

  let(:metrics) { { height: -32_768, width: 32_767, escapement: -1234, orientation: 2345, weight: -1 } }
  let(:attributes) do
    { italic: 0xFF, underline: 0x80, strike_out: 3, char_set: 0xFE,
      out_precision: 5, clip_precision: 6, quality: 7, pitch_and_family: 0xF8 }
  end
  let(:face_name) { "\xFFFace\0retained".b.ljust(32, "\xA5".b) }
  let(:fields) { metrics.merge(attributes).merge(face_name: face_name) }
  let(:prefix) { [*metrics.values, *attributes.values, face_name].pack("s<5C8a32") }
  let(:suffix) { "\xFE\xAD".b }
  let(:unknown) { native_wmf_record(0x7FFE, "raw!") }
  let(:placeable_options) { [false, true] }
  let(:invalid_names) { [nil, "x" * 31, "x" * 33] }
  let(:invalid_suffixes) { [nil, "x"] }
  let(:invalid_metrics) { [-32_769, 32_768] }
  let(:invalid_attributes) { [-1, 256] }
  let(:zero_handle) { "\x00\x00".b }

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

      it "types signed metrics and unsigned attributes while retaining all face-name and suffix bytes" do
        placeable_options.each do |placeable|
          bytes = native_wmf_bytes([native_wmf_record(0xABFB, prefix + suffix), unknown], placeable: placeable)
          parsed = Emf.parse(bytes)
          font = parsed.records.first
          expect(font).to be_a(Emf::Model::Wmf::Records::CreateFontIndirect)
          expect(font.type_id).to eq(0xABFB)
          expect(fields.keys.map { |field| font.public_send(field) }).to eq(fields.values)
          expect(font.suffix).to eq(suffix)
          expect(parsed.records[-2].raw_bytes).to eq(unknown)
          expect(Emf.serialize(parsed)).to eq(bytes)
        end
      end

      it "constructs canonical fonts and serializes edits in wire order with updated framing" do
        font = Emf::Model::Wmf::Records::CreateFontIndirect.new(**fields)
        expect(font.type_id).to eq(0x02FB)
        bytes = native_wmf_bytes([native_wmf_record(0xABFB, prefix + suffix), unknown], placeable: true)
        parsed = Emf.parse(bytes)
        edited = parsed.records.first
        new_metrics = metrics.transform_values { |value| value ^ 1 }
        new_attributes = attributes.transform_values { |value| value ^ 1 }
        new_face = "N\0new raw face".b.ljust(32, "\xFE".b)
        new_fields = new_metrics.merge(new_attributes).merge(face_name: new_face)
        new_fields.each { |field, value| edited.public_send("#{field}=", value) }
        edited.suffix += "more"
        expected_prefix = [*new_metrics.values, *new_attributes.values, new_face].pack("s<5C8a32")
        expected = native_wmf_record(0xABFB, "#{expected_prefix}#{suffix}more")
        output = Emf.serialize(parsed)
        expect(output).to eq(native_wmf_bytes([expected, unknown], placeable: true))
        reparsed = Emf.parse(output).records.first
        expect(new_fields.keys.map { |field| reparsed.public_send(field) }).to eq(new_fields.values)
        expect(reparsed.suffix).to eq("#{suffix}more")
      end

      it "rejects truncated font bodies and retains font object allocation and slot reuse" do
        truncated = native_wmf_record(0x02FB, prefix.byteslice(0, 10))
        expect { Emf.parse(native_wmf_bytes([truncated])) }.to raise_error(Emf::ParseError)
        # Holding the 18 fixed bytes, a font short of its face name is recovered: the name is zero-padded (701).
        short = Emf.parse(native_wmf_bytes([native_wmf_record(0x02FB, prefix.byteslice(0, 48))]))
        expect(short.errors.map { |error| error.evidence.check }).to eq([:font_record_length_invalid])
        font = native_wmf_record(0x02FB, prefix)
        select = native_wmf_record(0x012D, zero_handle)
        delete = native_wmf_record(0x01F0, zero_handle)
        bytes = native_wmf_bytes([font, select, delete, font, select], capacity: 1)
        expect(Emf.serialize(Emf.parse(bytes))).to eq(bytes)
        expect { Emf.parse(native_wmf_bytes([font, font], capacity: 1)) }.to raise_error(Emf::ParseError)
        dangling = Emf.parse(native_wmf_bytes([font, delete, select], capacity: 1))
        expect(dangling.errors.map { |error| error.evidence.check }).to eq([:object_reference_invalid])
      end

      it "rejects invalid edited field widths, face names, suffixes and function identities" do
        bytes = native_wmf_bytes([native_wmf_record(0x02FB, prefix)])
        metrics.each_key do |field|
          invalid_metrics.each do |invalid|
            parsed = Emf.parse(bytes)
            parsed.records.first.public_send("#{field}=", invalid)
            expect { Emf.serialize(parsed) }.to raise_error(Emf::SerializeError)
          end
        end
        attributes.each_key do |field|
          invalid_attributes.each do |invalid|
            parsed = Emf.parse(bytes)
            parsed.records.first.public_send("#{field}=", invalid)
            expect { Emf.serialize(parsed) }.to raise_error(Emf::SerializeError)
          end
        end
        invalid_names.each do |invalid|
          parsed = Emf.parse(bytes)
          parsed.records.first.face_name = invalid
          expect { Emf.serialize(parsed) }.to raise_error(Emf::SerializeError)
        end
        invalid_suffixes.each do |invalid|
          parsed = Emf.parse(bytes)
          parsed.records.first.suffix = invalid
          expect { Emf.serialize(parsed) }.to raise_error(Emf::SerializeError)
        end
        parsed = Emf.parse(bytes)
        invalid_font = parsed.records.first.class.new(**fields, type_id: 0x7FFE)
        invalid = Emf::Model::Metafile.new(format: :wmf, header: parsed.header, records: [invalid_font, parsed.records.last])
        expect { Emf.serialize(invalid) }.to raise_error(Emf::SerializeError)
        opaque = Emf::Model::Wmf::Records::UnknownRecord.new(type_id: 0x02FB, raw_bytes: native_wmf_record(0x02FB, prefix))
        disguised = Emf::Model::Metafile.new(format: :wmf, header: parsed.header, records: [opaque, parsed.records.last])
        expect { Emf.serialize(disguised) }.to raise_error(Emf::SerializeError)
      end
    end
  end
end
