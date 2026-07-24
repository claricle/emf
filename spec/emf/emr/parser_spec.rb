# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emf::Emr::Parser do
  describe ".call on real fixtures" do
    let(:simple_fixture) { Emf::SpecSupport::FixturePath.read_fixture("simple", "image1.emf") }

    it "parses the simple EMF fixture without errors" do
      mf = described_class.call(simple_fixture)
      expect(mf).to be_a(Emf::Model::Metafile)
      expect(mf.format).to eq(:emf_plus) # simple/image1.emf carries EMF+
      expect(mf.records).not_to be_empty
      expect(mf.errors).to be_empty
    end

    it "preserves the header bounds" do
      mf = described_class.call(simple_fixture)
      expect(mf.header.bounds.left).to eq(13)
      expect(mf.header.bounds.right).to eq(641)
    end

    it "round-trips byte-identically" do
      mf = described_class.call(simple_fixture)
      bytes = Emf::Emr::Serializer.call(mf)
      expect(bytes).to eq(simple_fixture)
    end
  end

  describe ".call against a sample of the emf/ corpus" do
    # The first 20 fixtures are a stable sample. Full corpus coverage in
    # TODO 16 (round-trip harness). This spec guards against regressions
    # in the most common record types.
    Dir.glob(Emf::SpecSupport::FixturePath.fixture("emf", "*.emf")).first(20).each do |path|
      it "parses #{File.basename(path)} without raising" do
        bytes = File.read(path, mode: "rb")
        mf = described_class.call(bytes)
        expect(mf).to be_a(Emf::Model::Metafile)
        expect(mf.header.signature).to eq(0x464D4520)
      end
    end
  end

  describe "format detection via Emf.parse" do
    it "dispatches EMF files to the EMF parser" do
      bytes = Emf::SpecSupport::FixturePath.read_fixture("simple", "image1.emf")
      mf = Emf.parse(bytes)
      expect(mf.format).to be(:emf).or be(:emf_plus)
    end
  end
end
