# frozen_string_literal: true

require "spec_helper"
require_relative "support/rule_cases"

RSpec.describe "parse recovery rules" do
  let(:rules) { Emf::Conformance::Registry.default && Emf::Conformance::ParseRecoveryRules }

  # rule id => message of the ParseError the crafted input makes the parser record
  ids = {
    "emf.record.truncated_header" => /truncated record header/,
    "emf.record.size_minimum" => /nSize 4 < 8/,
    "emf.record.size_bounds" => /truncated record at offset/,
    "emf.record.array_exceeds_size" => /declares more entries than nSize allows/,
    "emf.record.undecodable" => /ValidityError/
  }

  ids.each do |id, message|
    it "keeps #{id} for its recovered ParseError and reports no other recovery id" do
      bytes = Emf::SpecSupport::RuleCases.cases.fetch(id)
      error = Emf.parse(bytes).errors.fetch(0)
      expect(error.message).to match(message)
      expect(rules.classify(error).first).to eq(id)

      reported = Emf::Conformance.check(bytes).diagnostics.map(&:requirement_id)
      expect(reported & ids.keys).to eq([id])
    end

    it "reports #{id} through the tolerant profile as a warning with its waiver" do
      diagnostic = Emf::Conformance.check(Emf::SpecSupport::RuleCases.cases.fetch(id), profile: :tolerant)
                                   .diagnostics.find { |d| d.requirement_id == id }
      expect([diagnostic.severity, diagnostic.waiver]).to eq([:warning, rules::RECOVERED])
    end
  end

  # Tripwire for the message-regex classification: recovered errors have no structured evidence today.
  # If this fails, evidence now reaches Metafile#errors; classify from error.evidence.check first.
  it "relies on the message only while recovered ParseErrors carry no evidence" do
    errors = ids.keys.flat_map { |id| Emf.parse(Emf::SpecSupport::RuleCases.cases.fetch(id)).errors }
    expect(errors.size).to eq(ids.size)
    expect(errors.map(&:evidence)).to all(be_nil)
  end

  it "keeps the evidence-carrying FormatError of an unparseable input out of the recovery ids" do
    error = begin
      Emf.parse("abc".b)
    rescue Emf::FormatError => e
      e
    end
    expect(error.evidence.check).to eq(:input_too_short)
    expect(Emf::Conformance.check("abc".b).diagnostics.map(&:requirement_id)).to eq(["emf.parse.unparseable"])
  end
end
