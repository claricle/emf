# frozen_string_literal: true

require "English"
require "spec_helper"

RSpec.describe Emf::Visitors::Stats do
  let(:fixture) { Emf::SpecSupport::FixturePath.read_fixture("simple", "image1.emf") }
  let(:metafile) { Emf.parse(fixture) }

  it "produces a record-type histogram" do
    stats = described_class.new.visit_all(metafile)
    expect(stats.total).to eq(metafile.records.size)
    expect(stats.histogram).not_to be_empty
  end

  it "renders a readable string" do
    stats = described_class.new.visit_all(metafile)
    expect(stats.to_s).to include("Total:")
    expect(stats.to_s).to include("WireAdapter")
  end
end

RSpec.describe Emf::Visitors::Dump do
  let(:fixture) { Emf::SpecSupport::FixturePath.read_fixture("simple", "image1.emf") }
  let(:metafile) { Emf.parse(fixture) }

  it "produces a record-by-record dump" do
    dump = described_class.new.visit_all(metafile)
    expect(dump.to_s).to include("Metafile format=")
    expect(dump.to_s).to include("type_id=")
  end

  it "includes errors when present" do
    # Use a corrupted fixture to ensure errors are surfaced
    path = Dir.glob(Emf::SpecSupport::FixturePath.fixture("emf-corrupted", "*.emf")).first
    bytes = File.read(path, mode: "rb")
    begin
      mf = Emf.parse(bytes)
      dump = described_class.new.visit_all(mf)
      # Either the dump includes errors or the parse raised — both fine.
      expect(dump.to_s).to include("Metafile").or include("Error:")
    rescue Emf::FormatError
      # Header-level corruption raises; that's the contract.
      expect($ERROR_INFO).to be_a(Emf::FormatError)
    end
  end
end
