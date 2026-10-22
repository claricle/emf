# frozen_string_literal: true

require "spec_helper"
require_relative "support/rule_cases"

RSpec.describe "Emf::Conformance rules" do
  let(:clean) { Emf::SpecSupport::CraftedEmf.build }
  let(:cases) { Emf::SpecSupport::RuleCases.cases }

  def ids(bytes, profile: :strict) = Emf::Conformance.check(bytes, profile: profile).diagnostics.map(&:requirement_id)

  it "finds the crafted baseline clean" do
    expect(Emf::Conformance.check(clean).to_h).to include("valid" => true)
    expect(ids(clean)).to be_empty
  end

  it "has a crafted case for every core rule except the header rules a parser never lets through" do
    unreachable = %w[emf.header.signature emf.header.size_bounds]
    sources = %w[emf_core.yml emf_plus_core.yml]
    core = Emf::Conformance::Manifest.rows.select { |row| sources.include?(row.source) }
    expect(core.select(&:implemented?).map(&:id) - unreachable).to match_array(cases.keys)
  end

  it "names only registered rules in its crafted cases" do
    expect(cases.keys - Emf::Conformance::Registry.default.map(&:id)).to be_empty
  end

  Emf::SpecSupport::RuleCases.cases.each_key do |id|
    it "#{id}: silent on the baseline, fires on the crafted file with its citation" do
      expect(ids(clean)).not_to include(id)
      diagnostic = Emf::Conformance.check(cases.fetch(id)).diagnostics.find { |d| d.requirement_id == id }
      expect(diagnostic).not_to be_nil
      expect(diagnostic.spec_citation).to match(/\AMS-EMF(PLUS)? \d+(\.\d+)+\z/)
      expect(diagnostic.message).not_to be_empty
    end
  end

  describe "header rules the parser never lets through" do
    let(:header) { Struct.new(:signature, :n_size, keyword_init: true) }

    def findings(id, header_fields)
      context = Emf::Conformance::Context.new(metafile: Struct.new(:header, :format).new(header.new(**header_fields), :emf))
      Emf::Conformance::Registry.default[id].findings(context)
    end

    it "flags a wrong signature and passes the right one" do
      expect(findings("emf.header.signature", signature: 0x12345678, n_size: 88).first[:message]).to include("0x12345678")
      expect(findings("emf.header.signature", signature: 0x464D4520, n_size: 88)).to be_empty
    end

    it "flags a header smaller than 88 bytes and one that is not a multiple of 4" do
      expect(findings("emf.header.size_bounds", signature: 0, n_size: 84).size).to eq(1)
      expect(findings("emf.header.size_bounds", signature: 0, n_size: 90).size).to eq(1)
      expect(findings("emf.header.size_bounds", signature: 0, n_size: 100)).to be_empty
    end
  end

  describe "offsets" do
    it "point at the offending record in the file" do
      diagnostic = Emf::Conformance.check(cases.fetch("emf.record.undefined_type")).diagnostics.first
      expect(diagnostic.offset).to eq(88)
      expect(diagnostic.record_index).to eq(1)
      expect(diagnostic.record_type).to eq(69)
    end

    it "reports the oversized comment DataSize at the comment record" do
      diagnostic = Emf::Conformance.check(cases.fetch("emf.comment.data_size")).diagnostics.first
      expect([diagnostic.offset, diagnostic.record_type]).to eq([88, 70])
    end
  end
end
