# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require_relative "support/crafted_emf"

RSpec.describe Emf::Conformance do
  let(:bytes) { Emf::SpecSupport::CraftedEmf.build }

  it "accepts bytes, a path, a Pathname and a parsed Metafile alike" do
    path = File.join(Dir.mktmpdir, "ok.emf")
    File.binwrite(path, bytes)
    reports = [bytes, path, Pathname.new(path), Emf.parse(bytes)].map { |input| described_class.check(input).to_h }
    expect(reports.map { |r| r.fetch("valid") }).to all(be(true))
  end

  it "skips the length rule when only a parsed Metafile is given" do
    short = Emf::SpecSupport::CraftedEmf.build(bytes: 999)
    expect(described_class.check(short).errors.map(&:requirement_id)).to eq(["emf.header.bytes"])
    expect(described_class.check(Emf.parse(short)).errors).to be_empty
  end

  it "defaults to the strict profile" do
    expect(described_class.check(bytes).to_h["profile"]).to eq("strict")
  end

  it "reports unparseable input as a diagnostic instead of raising" do
    report = described_class.check("junk".b)
    expect(report.errors.map(&:requirement_id)).to eq(["emf.parse.unparseable"])
  end

  it "lets a missing native backend raise instead of reporting the file as unparseable" do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("EMF_BACKEND", "auto").and_return("native")
    allow(Emf::Native).to receive(:backend).and_raise(Emf::Native::Unavailable, "not installed")
    expect { described_class.check(bytes) }.to raise_error(Emf::Native::Unavailable)
  end

  it "checks an alternative registry" do
    registry = Emf::Conformance::Registry.new
    registry.register(id: "x.always", formats: [:emf], citation: "MS-EMF 2.3", kind: :always) { [{ message: "hi" }] }
    expect(described_class.check(bytes, registry: registry).errors.map(&:requirement_id)).to eq(["x.always"])
  end
end
