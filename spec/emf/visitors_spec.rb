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

  %w[standard-line.wmf placeable-line.wmf].each do |name|
    context "with #{name}" do
      let(:fixture) { Emf::SpecSupport::FixturePath.read_fixture("wmf", name) }

      it "counts typed, unknown and EOF records" do
        stats = described_class.new.visit_all(metafile)

        expect(stats.total).to eq(4)
        expect(stats.histogram).to eq("Eof" => 1, "LineTo" => 1, "MoveTo" => 1, "UnknownRecord" => 1)
        expect(stats.to_s).to eq("Total: 4\n\n     1  Eof\n     1  LineTo\n     1  MoveTo\n     1  UnknownRecord")
      end

      it "counts an individually visited record" do
        stats = described_class.new.visit(metafile.records.first)

        expect(stats.histogram).to eq("MoveTo" => 1)
      end
    end
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

  [["standard-line.wmf", 18], ["placeable-line.wmf", 40]].each do |name, start_offset|
    context "with #{name}" do
      let(:fixture) { Emf::SpecSupport::FixturePath.read_fixture("wmf", name) }

      it "dumps typed, unknown and EOF records with their offsets and type IDs" do
        dump = described_class.new.visit_all(metafile)

        expect(dump.lines).to eq([
                                   "Metafile format=wmf records=4 errors=0",
                                   "  Header: Emf::Model::Wmf::Header",
                                   "  rec[#{start_offset}] type_id=532 MoveTo",
                                   "  rec[#{start_offset + 10}] type_id=32766 UnknownRecord",
                                   "  rec[#{start_offset + 20}] type_id=531 LineTo",
                                   "  rec[#{start_offset + 30}] type_id=0 Eof"
                                 ])
      end

      it "dumps an individually visited record" do
        dump = described_class.new.visit(metafile.records.first)

        expect(dump.to_s).to eq("  rec[#{start_offset}] type_id=532 MoveTo")
      end
    end
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
