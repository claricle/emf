# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/native_wmf"

RSpec.describe "WMF scalar state records" do
  include NativeWmfSupport

  let(:cases) do
    [
      ["SetBkColor", 0x0201, { color_ref: 0xFE563412 }, "V"],
      ["SetBkMode", 0x0102, { mode: 2 }, "v"],
      ["SetMapMode", 0x0103, { mode: 8 }, "v"],
      ["SetMapperFlags", 0x0231, { flags: 0xF1234567 }, "V"],
      ["SetPolyFillMode", 0x0106, { mode: 2 }, "v"],
      ["SetRop2", 0x0104, { mode: 16 }, "v"],
      ["SetStretchBltMode", 0x0107, { mode: 4 }, "v"],
      ["SetTextAlign", 0x012E, { alignment: 0x011F }, "v"],
      ["SetTextCharExtra", 0x0108, { char_extra: 0xFFFF }, "v"],
      ["SetTextColor", 0x0209, { color_ref: 0xABEFCD89 }, "V"],
      ["SetTextJustification", 0x020A, { break_count: 0x1234, break_extra: 0xFEDC }, "v2"],
      ["SetLayout", 0x0149, { layout: 0x8001, reserved: 0xFEDC }, "v2"]
    ]
  end
  let(:unknown) { native_wmf_record(0x7FFE, "raw!") }
  let(:suffix) { "\xA5\xFE".b }
  let(:placeable_options) { [false, true] }
  let(:invalid_suffixes) { [nil, "x"] }

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

      it "types every scalar setter and preserves unsigned values, reserved words and source bytes" do
        raw = cases.map { |_name, type, fields, format| native_wmf_record(type, fields.values.pack(format) + suffix) }
        placeable_options.each do |placeable|
          bytes = native_wmf_bytes([*raw, unknown], placeable: placeable)
          parsed = Emf.parse(bytes)
          cases.zip(parsed.records).each do |(name, type, fields, _format), record|
            expect(record).to be_a(Emf::Model::Wmf::Records.const_get(name))
            expect(record.type_id).to eq(type)
            expect(fields.keys.map { |field| record.public_send(field) }).to eq(fields.values)
            expect(record.suffix).to eq(suffix)
          end
          expect(parsed.records[-2].raw_bytes).to eq(unknown)
          expect(Emf.serialize(parsed)).to eq(bytes)
        end
      end

      it "constructs and edits every state field with exact wire order and preserves advisory function bytes" do
        cases.each do |name, type, fields, format|
          klass = Emf::Model::Wmf::Records.const_get(name)
          record = klass.new(**fields)
          expect(record.type_id).to eq(type)
          original = native_wmf_record(0xAB00 | (type & 0xFF), fields.values.pack(format) + suffix)
          bytes = native_wmf_bytes([original, unknown], placeable: true)
          parsed = Emf.parse(bytes)
          edited = parsed.records.first
          new_fields = fields.transform_values { |value| value ^ 1 }
          new_fields.each { |field, value| edited.public_send("#{field}=", value) }
          edited.suffix += "more"
          expected_record = native_wmf_record(edited.type_id, "#{new_fields.values.pack(format)}#{suffix}more")
          output = Emf.serialize(parsed)
          expect(output).to eq(native_wmf_bytes([expected_record, unknown], placeable: true))
          reparsed = Emf.parse(output).records.first
          expect(new_fields.keys.map { |field| reparsed.public_send(field) }).to eq(new_fields.values)
          expect(reparsed.suffix).to eq("#{suffix}more")
        end
      end

      it "rejects truncated known state prefixes rather than treating them as opaque" do
        cases.each do |_name, type, fields, format|
          payload = fields.values.pack(format)
          truncated = native_wmf_record(type, payload.byteslice(0, payload.bytesize - 2))
          expect { Emf.parse(native_wmf_bytes([truncated])) }.to raise_error(Emf::ParseError)
        end
      end

      it "rejects invalid edited ranges, mismatched function IDs and malformed suffixes" do
        cases.each do |_name, type, fields, format|
          bytes = native_wmf_bytes([native_wmf_record(type, fields.values.pack(format))])
          fields.each_key do |field|
            [-1, format == "V" ? 0x100000000 : 0x10000].each do |value|
              parsed = Emf.parse(bytes)
              parsed.records.first.public_send("#{field}=", value)
              expect { Emf.serialize(parsed) }.to raise_error(Emf::SerializeError)
            end
          end
          invalid_suffixes.each do |invalid|
            parsed = Emf.parse(bytes)
            parsed.records.first.suffix = invalid
            expect { Emf.serialize(parsed) }.to raise_error(Emf::SerializeError)
          end
          parsed = Emf.parse(bytes)
          klass = parsed.records.first.class
          invalid = Emf::Model::Metafile.new(format: :wmf, header: parsed.header,
                                             records: [klass.new(**fields, type_id: 0x7FFE), parsed.records.last])
          expect { Emf.serialize(invalid) }.to raise_error(Emf::SerializeError)
        end
      end
    end
  end
end
