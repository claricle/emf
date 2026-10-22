# frozen_string_literal: true

require "spec_helper"
require "timeout"
require_relative "support/corpus_oracle"

RSpec.describe "Emf::Conformance corrupted-corpus oracle" do
  dir = File.expand_path("../../fixtures/emf-corrupted", __dir__)
  oracle = Emf::SpecSupport::CorpusOracle

  def check(path, profile) = Emf::Conformance.check(path, profile: profile)

  it "covers exactly the corrupted fixtures" do
    expect(oracle::FILES.keys.sort).to eq(Dir[File.join(dir, "*.emf")].map { |p| File.basename(p) }.sort)
  end

  it "never leaves a strict list empty without a not_checkable manifest row behind it" do
    empty = oracle::FILES.select { |_, row| row.strict.empty? }
    expect(empty.reject { |_, row| row.undetectable }.keys).to eq([])
    expect(oracle::FILES.select { |_, row| row.strict.any? && row.undetectable }.keys).to eq([])
    empty.each_value do |row|
      manifest = Emf::Conformance::Manifest.rows.find { |m| m.id == row.undetectable }
      expect([row.undetectable, manifest&.status]).to eq([row.undetectable, "not_checkable"])
    end
  end

  it "names only registered rules, and a rule that is registered never stands in for an undetectable corruption" do
    registered = Emf::Conformance::Registry.default.map(&:id) + oracle::UNPARSEABLE
    expect(oracle::FILES.values.flat_map(&:strict) - registered).to eq([])
    expect(oracle::FILES.values.filter_map(&:undetectable) & registered).to eq([])
  end

  oracle::FILES.each do |name, row|
    path = File.join(dir, name)

    it "strict: #{name} names its malformation#{" (precise rule pending: #{row.pending})" if row.pending}" do
      diagnostics = check(path, :strict).diagnostics
      expect(row.strict - diagnostics.map(&:requirement_id)).to eq([])
      next unless row.evidence

      expect(diagnostics.select { |d| row.strict.include?(d.requirement_id) }.map(&:message)).to include(match(row.evidence))
    end

    it "tolerant: #{name} is #{row.tolerant_valid ? 'valid' : 'invalid'}" do
      expect(check(path, :tolerant).valid?).to be(row.tolerant_valid)
    end
  end

  it "checks the 1.5 MiB recovery file within a bounded time under both profiles" do
    path = File.join(dir, oracle::LARGE_FILE)
    expect(File.size(path)).to be > 1_500_000
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    reports = Timeout.timeout(oracle::LARGE_FILE_BUDGET_SECONDS) { %i[strict tolerant].map { |profile| check(path, profile) } }
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    expect(elapsed).to be < oracle::LARGE_FILE_BUDGET_SECONDS
    expect(reports.map(&:valid?)).to eq([false, true])
  end

  it "keeps checking records after a recovered record (Raw preservation)" do
    ids = check(File.join(dir, "bad_corrupted_2014-12-02-215425.emf"), :strict).diagnostics.map(&:requirement_id)
    expect(ids).to include("emf.record.array_exceeds_size", "emf.object.pen_cosmetic_width")
  end
end
