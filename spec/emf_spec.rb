# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emf do
  it "exposes a VERSION constant" do
    expect(Emf::VERSION).to match(/\A\d+\.\d+\.\d+/)
  end

  it "is a module" do
    expect(Emf).to be_a(Module)
  end

  describe "error hierarchy" do
    it "has Emf::Error as the base" do
      expect(Emf::Error).to be < StandardError
    end

    it "has Emf::FormatError as a subclass" do
      expect(Emf::FormatError).to be < Emf::Error
    end

    it "has Emf::ParseError as a subclass with offset and record_code" do
      expect(Emf::ParseError).to be < Emf::Error
      err = Emf::ParseError.new(offset: 100, record_code: 99, message: "boom")
      expect(err.offset).to eq(100)
      expect(err.record_code).to eq(99)
      expect(err.message).to eq("boom")
    end

    it "has Emf::SerializeError as a subclass" do
      expect(Emf::SerializeError).to be < Emf::Error
    end
  end

  describe ".parse" do
    it "parses a real EMF fixture" do
      bytes = Emf::SpecSupport::FixturePath.read_fixture("simple", "image1.emf")
      mf = described_class.parse(bytes)
      expect(mf).to be_a(Emf::Model::Metafile)
    end

    it "raises FormatError for non-EMF/WMF input" do
      expect { described_class.parse("hello, world!") }.to raise_error(Emf::FormatError)
    end
  end

  describe ".serialize" do
    it "round-trips a real EMF fixture byte-identically" do
      bytes = Emf::SpecSupport::FixturePath.read_fixture("simple", "image1.emf")
      mf = described_class.parse(bytes)
      expect(described_class.serialize(mf)).to eq(bytes)
    end
  end
end
