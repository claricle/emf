# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/wmf_dc_escape_validation"

RSpec.describe "WMF DC and Escape records" do
  include WmfDcEscapeValidationSupport

  let(:suffix) { "\xFE\xAD".b }
  let(:unknown) { native_wmf_record(0x7FFE, "raw!") }
  let(:dc_functions) { { SaveDc: 0x001E, SetRelAbs: 0x0105 } }
  let(:minimum_signed) { [-32_768].pack("s<") }
  let(:edited_signed) { [-1, 0, 32_767] }
  let(:edited_escape_prefix) { [0xFFFF, 4].pack("v2") }
  let(:empty_escape_prefix) { [0xFFFF, 0].pack("v2") }
  let(:invalid_data) { [nil, 123, "x" * 65_536] }
  let(:invalid_signed) { [-32_769, 32_768, nil, "1"] }
  let(:invalid_words) { [-1, 65_536, nil, "1"] }
  let(:invalid_padding) { [-1, 256, nil, "x"] }
  let(:invalid_suffixes) { [nil, "x"] }
  let(:opaque_data) { "\x00\xFF\x26".b }
  let(:escape_body) { [0x11D8, 3].pack("v2") + opaque_data + "\xA5".b }
  let(:malformed_escape_bodies) { ["".b, [1].pack("v"), [1, 1].pack("v2"), "#{[1, 3].pack('v2')}xx"] }

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

      it "preserves and edits zero-prefix DC records including every SetRelAbs body byte" do
        dc_functions.each do |name, function|
          ["".b, suffix, "\xFF\xFFmore".b].each do |body|
            bytes = native_wmf_bytes([native_wmf_record(function | 0xAB00, body), unknown], placeable: true)
            parsed = Emf.parse(bytes)
            record = parsed.records.first
            expect(record).to be_a(Emf::Model::Wmf::Records.const_get(name))
            expect(record.type_id).to eq(function | 0xAB00)
            expect(record.suffix).to eq(body)
            expect(Emf.serialize(parsed)).to eq(bytes)
            record.suffix += "edit"
            expected = native_wmf_bytes([native_wmf_record(function | 0xAB00, "#{body}edit"), unknown], placeable: true)
            expect(Emf.serialize(parsed)).to eq(expected)
            expect(Emf.parse(expected).records.first.suffix).to eq("#{body}edit")
          end
          expect(Emf::Model::Wmf::Records.const_get(name).new.type_id).to eq(function)
        end
      end

      it "edits signed RestoreDc values and retains high function bytes and suffix" do
        bytes = native_wmf_bytes([native_wmf_record(0xAB27, minimum_signed + suffix), unknown])
        parsed = Emf.parse(bytes)
        record = parsed.records.first
        expect(record).to be_a(Emf::Model::Wmf::Records::RestoreDc)
        expect(record.saved_dc).to eq(-32_768)
        expect(record.suffix).to eq(suffix)
        expect(Emf.serialize(parsed)).to eq(bytes)
        edited_signed.each do |value|
          record.saved_dc = value
          expected = native_wmf_bytes([native_wmf_record(0xAB27, [value].pack("s<") + suffix), unknown])
          expect(Emf.serialize(parsed)).to eq(expected)
          expect(Emf.parse(expected).records.first.saved_dc).to eq(value)
        end
        expect(Emf::Model::Wmf::Records::RestoreDc.new(saved_dc: -1).type_id).to eq(0x0127)
      end

      it "retains inert Escape bytes, alignment, suffix and full function through edits" do
        bytes = native_wmf_bytes([native_wmf_record(0xAB26, escape_body + suffix), unknown], placeable: true)
        parsed = Emf.parse(bytes)
        record = parsed.records.first
        expect(record).to be_a(Emf::Model::Wmf::Records::Escape)
        expect([record.type_id, record.escape_function, record.data, record.padding, record.suffix])
          .to eq([0xAB26, 0x11D8, opaque_data, 0xA5, suffix])
        expect(Emf.serialize(parsed)).to eq(bytes)
        record.data = "xyz"
        odd_output = Emf.serialize(parsed)
        odd_body = [record.escape_function, 3].pack("v2") + "xyz\xA5".b + suffix
        expect(odd_output).to eq(native_wmf_bytes([native_wmf_record(0xAB26, odd_body), unknown], placeable: true))
        expect(Emf.parse(odd_output).records.first.padding).to eq(0xA5)
        record.escape_function = 0xFFFF
        record.data = "\xFF\x00\x80\x26".b
        record.padding = nil
        edited_body = edited_escape_prefix + record.data + suffix
        output = Emf.serialize(parsed)
        expect(output).to eq(native_wmf_bytes([native_wmf_record(0xAB26, edited_body), unknown], placeable: true))
        expect(Emf.parse(output).records.first.data).to eq(record.data)
        record.data = "".b
        expected = native_wmf_record(0xAB26, empty_escape_prefix + suffix)
        expect(Emf.serialize(parsed)).to eq(native_wmf_bytes([expected, unknown], placeable: true))
        expect(Emf::Model::Wmf::Records::Escape.new(escape_function: 1, data: "").type_id).to eq(0x0626)
      end

      it "derives the maximum Escape byte count while preserving odd alignment" do
        data = "x" * 65_535
        body = [0xFFFF, data.bytesize].pack("v2") + data + "\xFF".b + suffix
        bytes = native_wmf_bytes([native_wmf_record(0x0626, body), unknown])
        parsed = Emf.parse(bytes)
        expect(parsed.records.first.data).to eq(data)
        expect(parsed.records.first.padding).to eq(255)
        expect(Emf.serialize(parsed)).to eq(bytes)
      end

      it "rejects truncated DC prefixes and Escape counts before exposing a record" do
        expect { Emf.parse(native_wmf_bytes([native_wmf_record(0x0127, "")])) }.to raise_error(Emf::ParseError)
        malformed_escape_bodies.each do |body|
          expect { Emf.parse(native_wmf_bytes([native_wmf_record(0x0626, body)])) }.to raise_error(Emf::ParseError)
        end
      end

      it "rejects invalid signed edits, Escape transport values and suffixes" do
        invalid_signed.each do |value|
          record = Emf::Model::Wmf::Records::RestoreDc.new(saved_dc: value)
          expect { serialize_dc_escape_record(record) }.to raise_error(Emf::SerializeError)
        end
        invalid_words.each do |value|
          record = Emf::Model::Wmf::Records::Escape.new(escape_function: value, data: "")
          expect { serialize_dc_escape_record(record) }.to raise_error(Emf::SerializeError)
        end
        invalid_padding.each do |value|
          record = Emf::Model::Wmf::Records::Escape.new(escape_function: 1, data: "x", padding: value)
          expect { serialize_dc_escape_record(record) }.to raise_error(Emf::SerializeError)
        end
        invalid_data.each do |value|
          record = Emf::Model::Wmf::Records::Escape.new(escape_function: 1, data: value)
          expect { serialize_dc_escape_record(record) }.to raise_error(Emf::SerializeError)
        end
        record = Emf::Model::Wmf::Records::Escape.new(escape_function: 1, data: "", padding: 0)
        expect { serialize_dc_escape_record(record) }.to raise_error(Emf::SerializeError)
        invalid_suffixes.each do |value|
          record = Emf::Model::Wmf::Records::SaveDc.new(suffix: value)
          expect { serialize_dc_escape_record(record) }.to raise_error(Emf::SerializeError)
        end
        record = Emf::Model::Wmf::Records::SaveDc.new(type_id: 0x0105)
        expect { serialize_dc_escape_record(record) }.to raise_error(Emf::SerializeError)
      end
    end
  end
end
