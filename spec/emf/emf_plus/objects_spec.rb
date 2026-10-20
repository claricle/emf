# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/emf_plus_records"

RSpec.describe Emf::EmfPlus::Objects do
  include Emf::SpecSupport::EmfPlusRecords

  let(:version) { [0xDBC01002].pack("V") }

  def logical(type, data)
    padded = data + ("\0" * (-data.bytesize % 4))
    frame = Emf::EmfPlus::Parser.call(record(0x4008, padded, flags: type << 8, data_size: data.bytesize)).first
    Emf::EmfPlus::ObjectChain::LogicalObject.new([Emf::EmfPlus::Records.decode(frame)])
  end

  def utf16(text) = text.encode(Encoding::UTF_16LE).b

  shared_examples "a lossless object" do
    it "re-encodes to the original ObjectData" do
      expect(subject.to_binary).to eq(data)
    end
  end

  shared_examples "an object that rejects bad data" do
    it "raises ParseError on a truncated body" do
      expect { described_class.decode(logical(type, data.byteslice(0, data.bytesize - 4))) }
        .to raise_error(Emf::ParseError, /malformed/)
    end
  end

  describe ".decode" do
    subject(:body) { described_class.decode(logical(type, data)) }

    context "with a Font" do
      let(:type) { 6 }
      let(:data) { version + [12.5, 2, 3, 0, 5].pack("eVVVV") + utf16("Arial") }

      it { is_expected.to be_a(Emf::EmfPlus::Objects::Font) }

      it "decodes the fields" do
        expect([body.version, body.em_size, body.size_unit, body.style_flags, body.family_name])
          .to eq([0xDBC01002, 12.5, 2, 3, "Arial"])
      end

      it "keeps alignment padding after the name" do
        odd = version + [8.0, 2, 0, 0, 3].pack("eVVVV") + utf16("abc") + "\0\0".b

        expect(described_class.decode(logical(type, odd)).to_binary).to eq(odd)
      end

      it "raises ParseError for a Length larger than the data, without allocating it" do
        huge = version + [8.0, 2, 0, 0, 0x7FFFFFFF].pack("eVVVV") + utf16("ab")

        expect { described_class.decode(logical(type, huge)) }.to raise_error(Emf::ParseError, /FamilyName of 2147483647/)
      end

      it_behaves_like "a lossless object"
      it_behaves_like "an object that rejects bad data"
    end

    context "with a StringFormat" do
      let(:type) { 7 }
      let(:header) { version + [0x1000, 0x0409, 1, 2, 3, 0x0409].pack("VVVVVV") + [4.0, 1, 0.5, 0.25, 1.0].pack("eVeee") + [2].pack("V") }
      let(:data) { header + [2, 1].pack("VV") + [8.0, 16.0].pack("ee") + [3, 4].pack("VV") }

      it { is_expected.to be_a(Emf::EmfPlus::Objects::StringFormat) }

      it "decodes the header, tab stops and character ranges" do
        expect([body.flags, body.tab_stops, body.char_ranges]).to eq([0x1000, [8.0, 16.0], [[3, 4]]])
      end

      it "accepts empty StringFormatData" do
        empty = header + [0, 0].pack("VV")

        expect(described_class.decode(logical(type, empty)).to_binary).to eq(empty)
      end

      it "raises ParseError for counts larger than the data, without allocating them" do
        huge = header + [0x7FFFFFFF, 0x7FFFFFFF].pack("VV")

        expect { described_class.decode(logical(type, huge)) }.to raise_error(Emf::ParseError, /StringFormatData of 2147483647/)
      end

      it "raises ParseError for a negative count" do
        negative = header + [-1, 0].pack("l<l<")

        expect { described_class.decode(logical(type, negative)) }.to raise_error(Emf::ParseError, /negative count/)
      end

      it_behaves_like "a lossless object"
      it_behaves_like "an object that rejects bad data"
    end

    context "with ImageAttributes" do
      let(:type) { 8 }
      let(:data) { version + [0, 4].pack("VV") + [0x11, 0x22, 0x33, 0x44].pack("C4") + [1, 0].pack("VV") }

      it { is_expected.to be_a(Emf::EmfPlus::Objects::ImageAttributes) }

      it "decodes the fields" do
        expect([body.wrap_mode, body.clamp_color.red, body.clamp_color.alpha, body.object_clamp]).to eq([4, 0x33, 0x44, 1])
      end

      it_behaves_like "a lossless object"
      it_behaves_like "an object that rejects bad data"
    end

    context "with any other ObjectType" do
      let(:type) { 12 }
      let(:data) { "\x01\x02\x03\x04\x05".b }

      it { is_expected.to be_a(Emf::EmfPlus::Objects::Opaque) }

      it "keeps the bytes" do
        expect([body.object_type, body.to_binary]).to eq([12, data])
      end
    end
  end

  describe "LogicalObject#body" do
    it "decodes the joined data of a chained object" do
      data = version + [0, 4].pack("VV") + [1, 2, 3, 4].pack("C4") + [1, 0].pack("VV")
      chunks = [data.byteslice(0, 12), data.byteslice(12..)].map do |part|
        body = [data.bytesize].pack("V") + part
        frame = Emf::EmfPlus::Parser.call(record(0x4008, body, flags: 0x8000 | (8 << 8))).first
        Emf::EmfPlus::Records.decode(frame)
      end
      logical = Emf::EmfPlus::ObjectChain::LogicalObject.new(chunks)

      expect(logical.body).to be_a(Emf::EmfPlus::Objects::ImageAttributes).and have_attributes(wrap_mode: 4)
    end
  end

  describe "against the corpus" do
    typed = { 6 => Emf::EmfPlus::Objects::Font, 7 => Emf::EmfPlus::Objects::StringFormat,
              8 => Emf::EmfPlus::Objects::ImageAttributes }
    # The byte check skips parsing the fixtures with no EMF+ comment; parsing them all costs minutes.
    fixtures = Dir[File.expand_path("../../fixtures/{emf,emf-ea,simple}/*.emf", __dir__)].select do |path|
      File.binread(path).include?("EMF+") && Emf.parse(File.binread(path)).emf_plus
    rescue Emf::Error
      false
    end
    objects = fixtures.flat_map do |path|
      records = Emf::EmfPlus::Records.decode_all(Emf::EmfPlus::Parser.call(Emf.parse(File.binread(path)).emf_plus))
      Emf::EmfPlus::ObjectChain.call(records).grep(Emf::EmfPlus::ObjectChain::LogicalObject)
                               .select { |l| typed.key?(l.object_type) }.map { |l| [File.basename(path), l] }
    end

    typed.each do |object_type, klass|
      it "decodes every #{klass.name.split('::').last} object typed and byte-identical" do
        own = objects.select { |(_, l)| l.object_type == object_type }
        warn "corpus #{klass.name.split('::').last}: #{own.size} objects"

        expect(own.map { |(_, l)| l.body }).to all(be_a(klass))
        expect(own.map { |(_, l)| l.body.to_binary }).to eq(own.map { |(_, l)| l.data })
      end
    end
  end
end
