# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Conformance citation and report hardening" do
  let(:header_size_seed) { File.binread(File.expand_path("../../../emf-rs/fuzz/seeds/wmf-resilience/header-size.wmf", __dir__)) }

  def ids(bytes) = Emf::Conformance.check(bytes, profile: :strict).errors.map { |d| [d.requirement_id, d.spec_citation] }

  it "cites MS-WMF for a WMF META_HEADER whose HeaderSize is not 9" do
    expect(ids(header_size_seed)).to eq([["wmf.header.unrecognised", "MS-WMF 2.3.2.2"]])
  end

  it "cites MS-WMF for a WMF META_HEADER whose Type is not 1 or 2" do
    bytes = header_size_seed.dup
    bytes[0, 4] = [3, 9].pack("vv")
    expect(ids(bytes)).to eq([["wmf.header.unrecognised", "MS-WMF 2.3.2.2"]])
  end

  it "keeps emf.parse.unparseable for input that is not WMF-shaped" do
    expect(ids("\xFF".b * 64)).to eq([["emf.parse.unparseable", "MS-EMF 2.3.4.2"]])
  end

  it "leaves a frozen caller-supplied timestamp untouched" do
    now = Time.new(2026, 10, 26, 18, 0, 0, "+05:00").freeze
    report = Emf::Conformance.check(header_size_seed, profile: :strict, now: now)
    expect(report.to_h["timestamp"]).to eq("2026-10-26T13:00:00Z")
    expect(now.utc_offset).to eq(5 * 3600)
  end
end
