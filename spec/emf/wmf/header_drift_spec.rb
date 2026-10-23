# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/wmf_header_drift"

RSpec.describe "WMF header Size and MaxRecord drift (Ruby backend)" do
  include WmfHeaderDrift

  around do |example|
    previous = ENV.fetch("EMF_BACKEND", nil)
    ENV["EMF_BACKEND"] = "ruby"
    example.run
  ensure
    ENV["EMF_BACKEND"] = previous
  end

  it "records no error for a consistent header" do
    expect(Emf.parse(pristine).errors).to be_empty
  end

  [false, true].each do |placeable|
    WmfHeaderDrift::CASES.each do |name, (offset, value)|
      context "with #{name}#{' (placeable)' if placeable}" do
        let(:good) { pristine(placeable: placeable) }
        let(:bytes) { drifted(good, offset, value, placeable: placeable) }
        let(:metafile) { Emf.parse(bytes) }
        let(:start) { placeable ? 22 : 0 }

        it "keeps every record and records one ParseError with evidence" do
          expect(metafile.records.map(&:type_id)).to eq([0x041B, 0x0214, 0])
          expect(metafile.errors.size).to eq(1)
          error = metafile.errors.first
          expect(error).to be_a(Emf::ParseError)
          check, field, declared, actual = expected_evidence(offset, value)
          expect(error.evidence).to eq(Emf::ParseEvidence.new(check: check, offset: start + field, declared: declared, actual: actual))
          expect(error.offset).to eq(start + field)
        end

        it "serializes to the corrected file with the records unchanged, and reparses clean" do
          expect(Emf.serialize(metafile)).to eq(good)
          expect(Emf.parse(Emf.serialize(metafile)).errors).to be_empty
        end
      end
    end
  end

  it "keeps the bytes after EOF as trailing data when Size is too small" do
    metafile = Emf.parse(drifted(pristine(trailing: "tail".b), 6, 12))
    expect([metafile.trailing, metafile.errors.map { |error| error.evidence.check }]).to eq(["tail".b, [:header_file_size_invalid]])
  end

  it "bounds the walk by the input, not by a huge declared Size" do
    bytes = drifted(pristine, 6, 0xFFFF_FFFF)
    expect(Emf.parse(bytes).records.size).to eq(3)
    truncated = bytes.byteslice(0, bytes.bytesize - 6)
    expect { Emf.parse(truncated) }.to raise_error(Emf::ParseError, /missing EOF record/)
  end
end
