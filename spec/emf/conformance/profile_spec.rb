# frozen_string_literal: true

require "spec_helper"
require_relative "support/rule_cases"

RSpec.describe Emf::Conformance::Profile do
  let(:bytes) { Emf::SpecSupport::RuleCases.cases.fetch("emf.header.bytes") }

  it "resolves names and rejects unknown ones" do
    expect(described_class.fetch(:strict).name).to eq(:strict)
    expect(described_class.fetch("tolerant").name).to eq(:tolerant)
    expect { described_class.fetch(:lenient) }.to raise_error(ArgumentError, /unknown conformance profile/)
  end

  it "reports a corpus-legit rule as an error under strict" do
    report = Emf::Conformance.check(bytes, profile: :strict)
    expect(report.valid?).to be(false)
    expect(report.errors.map(&:requirement_id)).to eq(["emf.header.bytes"])
  end

  it "downgrades the same rule to a warning under tolerant and records why" do
    report = Emf::Conformance.check(bytes, profile: :tolerant)
    expect(report.valid?).to be(true)
    expect(report.warnings.first.waiver).to include("advisory")
    expect(report.to_h.dig("warnings", "issues", 0, "context", "waiver")).to include("advisory")
  end

  it "waives a rule with a tolerant reason for every input, not only for the fixture that motivated it" do
    other_inputs = [1_000, 123_456].map { |n| Emf::SpecSupport::CraftedEmf.build(bytes: n) }
    [bytes, *other_inputs].each do |input|
      strict = Emf::Conformance.check(input, profile: :strict)
      tolerant = Emf::Conformance.check(input, profile: :tolerant)
      expect(strict.errors.map(&:requirement_id)).to eq(["emf.header.bytes"])
      expect(tolerant.warnings.map(&:requirement_id)).to eq(["emf.header.bytes"])
      expect(tolerant.valid?).to be(true)
    end
  end

  it "keeps a rule without a tolerant reason an error under both profiles" do
    unparseable = Emf::SpecSupport::RuleCases.cases.fetch("emf.parse.unparseable")
    expect(%i[strict tolerant].map { |p| Emf::Conformance.check(unparseable, profile: p).valid? }).to eq([false, false])
  end

  it "gives every downgradable rule a written reason" do
    reasons = Emf::Conformance::Registry.default.filter_map(&:tolerant_reason)
    expect(reasons).to all(satisfy { |reason| reason.length > 20 })
  end
end
