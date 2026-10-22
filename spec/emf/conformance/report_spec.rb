# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "yaml"
require_relative "support/rule_cases"

RSpec.describe Emf::Conformance::Report do
  let(:bytes) { Emf::SpecSupport::RuleCases.cases.fetch("emf.record.undefined_type") }
  let(:now) { Time.utc(2026, 1, 2, 3, 4, 5) }
  let(:report) { Emf::Conformance.check(bytes, now: now) }
  let(:hash) { report.to_h }

  it "uses svg_conform's top-level keys" do
    expect(hash.keys).to eq(%w[filename profile tool version timestamp valid errors warnings])
    expect(hash).to include("tool" => "emf", "version" => Emf::VERSION, "profile" => "strict",
                            "timestamp" => "2026-01-02T03:04:05Z", "valid" => false)
  end

  it "summarises errors and warnings like svg_conform" do
    expect(hash["errors"].keys).to eq(%w[total_count by_requirement issues])
    expect(hash["errors"]).to include("total_count" => 1, "by_requirement" => { "emf.record.undefined_type" => 1 })
    expect(hash["warnings"]).to eq("total_count" => 0, "by_requirement" => {}, "issues" => [])
  end

  it "carries svg_conform's issue keys with offset in place of line, column and xpath" do
    issue = hash.dig("errors", "issues", 0)
    expect(issue.keys).to eq(%w[type requirement_id message element attribute value offset severity kind category
                                spec_citation remediation_available context])
    expect(issue).to include("type" => "error", "severity" => "error", "offset" => 88, "element" => "emf:0x0045",
                             "kind" => "undefined_type", "category" => "undefined_type", "remediation_available" => false)
    expect(issue["context"]).to include("spec_citation" => "MS-EMF 2.1.1", "format" => "emf", "record_index" => 1)
  end

  it "gives each issue kind and spec_citation at the top level, equal to the compatibility copies" do
    reports = [report, Emf::Conformance.check(bytes, profile: :tolerant, now: now),
               Emf::Conformance.check(Emf::SpecSupport::RuleCases.cases.fetch("emf.comment.data_size"), now: now)]
    issues = reports.flat_map { |r| r.to_h.values_at("errors", "warnings").flat_map { |part| part["issues"] } }
    expect(issues).not_to be_empty
    issues.each do |issue|
      expect(issue["kind"]).to eq(issue["category"])
      expect(issue["spec_citation"]).to eq(issue.dig("context", "spec_citation"))
      expect(issue["spec_citation"]).to match(/\AMS-/)
    end
    expect(hash.dig("errors", "issues", 0)).to include("kind" => "undefined_type", "spec_citation" => "MS-EMF 2.1.1")
  end

  it "names the file when given a path" do
    path = File.join(Dir.mktmpdir, "x.emf")
    File.binwrite(path, bytes)
    expect(Emf::Conformance.check(path).to_h["filename"]).to eq(path)
  end

  it "round-trips through YAML" do
    expect(YAML.safe_load(report.to_yaml)).to eq(hash)
  end

  it "names known records by their MS-EMF constant" do
    comment = Emf::Conformance.check(Emf::SpecSupport::RuleCases.cases.fetch("emf.comment.data_size"))
    expect(comment.to_h.dig("errors", "issues", 0, "element")).to eq("emf:COMMENT")
  end

  describe "contract" do
    let(:messy_path) { File.join(__dir__, "../../fixtures/emf-corrupted/bad_corrupted_2014-12-13-132605.emf") }
    let(:messy_bytes) { File.binread(messy_path) }
    let(:strict) { Emf::Conformance.check(messy_bytes, now: now) }
    let(:tolerant) { Emf::Conformance.check(messy_bytes, profile: :tolerant, now: now) }

    let(:flatten) do
      walk = lambda do |value|
        case value
        when Hash then value.flat_map { |key, item| [[:key, key]] + walk.call(item) }
        when Array then value.flat_map { |item| walk.call(item) }
        else [[:leaf, value]]
        end
      end
    end

    it "orders issues by offset with offset-less findings first, then by requirement id" do
      issues = strict.to_h.dig("errors", "issues")
      keys = issues.map { |issue| [issue["offset"] || -1, issue["requirement_id"]] }
      expect(issues.size).to be > 5
      expect(keys).to eq(keys.sort)
    end

    it "orders by_requirement lexically and counts each requirement's issues" do
      errors = strict.to_h["errors"]
      expect(errors["by_requirement"].keys).to eq(errors["by_requirement"].keys.sort)
      expect(errors["by_requirement"]).to eq(errors["issues"].map { |i| i["requirement_id"] }.tally.sort.to_h)
      expect(errors["total_count"]).to eq(errors["issues"].size)
    end

    it "keeps by_requirement lexical even when the first issue's id sorts last" do
      ids = strict.to_h.dig("errors", "issues").map { |issue| issue["requirement_id"] }.uniq
      expect(ids).not_to eq(ids.sort)
      expect(strict.to_h.dig("errors", "by_requirement").keys).to eq(ids.sort)
    end

    it "splits findings into errors and warnings by profile severity, valid exactly when no errors" do
      expect(strict.to_h).to include("valid" => false)
      expect(strict.to_h.dig("warnings", "total_count")).to eq(0)
      relaxed = tolerant.to_h
      expect(relaxed["warnings"]["total_count"]).to be > 0
      expect(relaxed["valid"]).to eq(relaxed.dig("errors", "total_count").zero?)
      expect(relaxed.dig("warnings", "issues").map { |i| i["type"] }.uniq).to eq(["warning"])
      expect(relaxed.dig("warnings", "issues", 0, "context")).to include("waiver")
    end

    it "emits only string keys and primitive values" do
      [strict, tolerant].each do |report|
        flatten.call(report.to_h).each do |role, value|
          expected = role == :key ? [String] : [String, Integer, TrueClass, FalseClass, NilClass]
          expect(expected).to include(value.class)
        end
      end
    end

    it "returns fresh hashes so mutating one never changes the report" do
      first = strict.to_h
      first["errors"]["issues"].clear
      expect(strict.to_h.dig("errors", "issues")).not_to be_empty
      expect { strict.diagnostics << :x }.to raise_error(FrozenError)
    end

    it "does not freeze or mutate the diagnostics array it was given" do
      list = []
      described_class.new(filename: nil, profile: :strict, timestamp: now, diagnostics: list)
      expect(list).not_to be_frozen
    end

    it "writes the timestamp as UTC ISO-8601 whatever zone and precision `now:` has" do
      zoned = Time.new(2026, 1, 2, 5, 4, 5.75, "+02:00")
      expect(Emf::Conformance.check(bytes, now: zoned).to_h["timestamp"]).to eq("2026-01-02T03:04:05Z")
    end

    it "gives identical reports for the same input and the same injected now" do
      a = Emf::Conformance.check(messy_bytes, now: now)
      b = Emf::Conformance.check(messy_bytes.dup, now: now)
      expect(a.to_yaml).to eq(b.to_yaml.sub("filename: \n", "filename: \n"))
    end

    it "gives a timestamp-free report that does not depend on when the check ran" do
      early = Emf::Conformance.check(messy_bytes, now: Time.utc(2000, 1, 1))
      late = Emf::Conformance.check(messy_bytes, now: Time.utc(2030, 1, 1))
      expect(early.to_h).not_to eq(late.to_h)
      expect(early.to_h(timestamp: false)).to eq(late.to_h(timestamp: false))
      expect(early.to_h(timestamp: false)).not_to have_key("timestamp")
      expect(early.to_h(timestamp: false).keys).to eq(%w[filename profile tool version valid errors warnings])
      expect(early.to_yaml(timestamp: false)).to eq(late.to_yaml(timestamp: false))
    end

    it "round-trips both profiles through YAML.safe_load, which rejects non-primitive values" do
      [strict, tolerant].each do |report|
        expect(YAML.safe_load(report.to_yaml)).to eq(report.to_h)
        expect(YAML.safe_load(report.to_yaml(timestamp: false))).to eq(report.to_h(timestamp: false))
      end
    end
  end
end
