# frozen_string_literal: true

require "spec_helper"
require "emf/native/wmf_rejection"
require_relative "../support/native_library_context"
require_relative "../support/wmf_mutation"
require_relative "../support/wmf_rejection_cases"

RSpec.describe "Parse failure evidence" do
  include_context "with native library"

  let(:nsizes) { [0, 1, 7, 8, 9, 40, 80, 87, 88, 100, 200, 0xFFFFFFFF] }

  def observe(bytes, backend)
    previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
    ENV["EMF_BACKEND"] = backend
    ENV["EMF_NATIVE_LIBRARY"] = library if backend == "native"
    metafile = Emf.parse(bytes)
    [:parsed, metafile.records.map { |record| [record.offset, (record.declared_size_words if record.respond_to?(:declared_size_words))] }]
  rescue Emf::Error => e
    [:rejected, e.class.name, e.message, e.evidence&.to_h]
  ensure
    %w[EMF_BACKEND EMF_NATIVE_LIBRARY].each { |key| previous[key] ? ENV[key] = previous[key] : ENV.delete(key) }
  end

  def outcome(observation)
    return :parsed if observation.first == :parsed

    observation.last ? :evidence : :no_evidence
  end

  def compare(cases)
    counts = Hash.new(0)
    cases.each do |label, bytes|
      ruby = observe(bytes, "ruby")
      expect(observe(bytes, "native")).to eq(ruby), label
      counts[outcome(ruby)] += 1
    end
    counts
  end

  it "gives every crafted WMF rejection reason equal, non-empty evidence on both backends" do
    counts = compare(WmfRejectionCases.cases.map { |reason, bytes| ["reason #{reason}", bytes] })
    expect(counts).to eq(evidence: WmfRejectionCases.cases.length)
    checks = WmfRejectionCases.cases.keys.map { |reason| Emf::Wmf::Evidence::REASONS.fetch(reason).first }
    expect(checks.uniq.length).to eq(checks.length)
  end

  it "names the failed check, where, and declared against actual" do
    bytes = WmfRejectionCases.cases.fetch(403)
    expect { Emf.parse(bytes) }.to raise_error(Emf::ParseError) do |error|
      expect(error.evidence).to eq(Emf::ParseEvidence.new(check: :record_length_invalid, offset: 18, declared: 2, actual: 3))
    end
  end

  it "keeps the evidence table in step with the native rejection table" do
    native = Emf::Native::WmfRejection
    resource_reasons = {
      101 => [:input_too_large, "WMF input too large"],
      401 => [:record_limit_exceeded, "record limit exceeded"]
    }
    reasons = Emf::Wmf::Evidence::REASONS.except(*Emf::Wmf::Evidence::DRIFT_REASONS, *Emf::Wmf::Evidence::RETIRED_REASONS)
    expect(reasons.keys).to match_array(native::INPUT.keys + native::RECORD.keys + resource_reasons.keys)
    expect(reasons.slice(*resource_reasons.keys)).to eq(resource_reasons)
    texts = reasons.transform_values(&:last)
    expect(texts.slice(*native::INPUT.keys)).to eq(native::INPUT)
    expect(texts.slice(*native::RECORD.keys)).to eq(native::RECORD)
  end

  it "agrees on every WMF seed mutation, truncation and append" do
    cases = WmfMutation.corpus
    counts = compare(cases)
    expect(counts.values.sum).to eq(cases.length)
    expect(counts[:parsed]).to be_positive
    expect(counts[:evidence]).to be_positive
    puts "wmf corpus: #{counts}"
  end

  it "agrees on truncated and nSize-corrupted EMF headers and the corrupt EMF fixtures" do
    fixtures = Dir["spec/fixtures/emf-corrupted/*.emf"]
    cases = fixtures.map { |path| [File.basename(path), File.binread(path)] }
    cases += fixtures.first(3).flat_map do |path|
      bytes = File.binread(path)
      (0..120).map { |length| ["#{File.basename(path)} truncate #{length}", bytes.byteslice(0, length)] } +
        nsizes.map do |size|
          mutated = bytes.dup
          mutated[4, 4] = [size].pack("V")
          ["#{File.basename(path)} nSize #{size}", mutated]
        end
    end
    counts = compare(cases)
    expect(counts[:evidence]).to be_positive
    puts "emf corpus: #{counts}"
  end
end
