# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/wmf_mutation"

RSpec.describe "WMF mutation parity between the native and Ruby backends" do
  let(:library) { ENV.fetch("EMF_TEST_NATIVE_LIBRARY", nil) }
  let(:seeds) { WmfMutation.seeds }

  before { skip "set EMF_TEST_NATIVE_LIBRARY for native WMF mutation parity" if library.to_s.empty? }

  def mismatches(cases)
    cases.filter_map do |label, bytes|
      ruby = WmfMutation.observe(bytes, "ruby", library)
      native = WmfMutation.observe(bytes, "native", library)
      "#{label}\n  ruby:   #{ruby.inspect[0, 240]}\n  native: #{native.inspect[0, 240]}" unless ruby == native
    end
  end

  it "mutates every seed and fixture" do
    expect(seeds.keys).to include("standard-line", "placeable-line", "zero-record", "valid-text-placeable")
    expect(seeds.length).to eq(18)
  end

  it "keeps the corpus deterministic and bounded" do
    corpus = WmfMutation.corpus(seeds)
    expect(corpus.map(&:last)).to eq(WmfMutation.corpus(seeds).map(&:last))
    expect(corpus.length).to be_between(3_000, 12_000)
    expect(corpus.map(&:first).uniq.length).to eq(corpus.length)
  end

  it "reaches every outcome the contract has" do
    outcomes = WmfMutation.corpus(seeds).map { |_label, bytes| WmfMutation.observe(bytes, "ruby", library).first(2) }.tally
    expect(outcomes.keys).to contain_exactly(%i[parsed wmf], [:parse_error, "Emf::ParseError"], [:error, "Emf::FormatError"])
    expect(outcomes.values).to all(be >= 500)
  end

  WmfMutation.seeds.each_key do |name|
    it "agrees on outcome, records, error, trailing bytes and serialization for #{name}" do
      cases = WmfMutation.corpus(name => seeds.fetch(name))
      expect(mismatches(cases)).to be_empty
    end
  end

  it "answers a native rejection with the contract's own message, offset and record code" do
    bytes = seeds.fetch("zero-record")
    native = WmfMutation.observe(bytes, "native", library)
    expect(native).to eq(WmfMutation.observe(bytes, "ruby", library))
    expect(native).to start_with(:parse_error, "Emf::ParseError", 18, 0x214)
    expect(native.last).to eq("WMF invalid record length 0 at offset 18")
  end

  it "does not consult the Ruby parser for input the native backend accepts" do
    accepted = WmfMutation.corpus(seeds).map(&:last).select { |bytes| WmfMutation.observe(bytes, "ruby", library).first == :parsed }
    expect(accepted.length).to be > 1_000
    allow(Emf::Wmf::Parser).to receive(:call).and_call_original
    accepted.each { |bytes| WmfMutation.observe(bytes, "native", library) }
    expect(Emf::Wmf::Parser).not_to have_received(:call)
  end

  it "answers native rejections without running any phase of the Ruby parser" do
    rejected = WmfMutation.corpus(seeds).map(&:last).reject { |bytes| WmfMutation.observe(bytes, "ruby", library).first == :parsed }
    expect(rejected.length).to be > 5_000
    phases = %i[call read_placeable read_header read_records decode_record parse_error]
    phases.each { |phase| allow(Emf::Wmf::Parser).to receive(phase).and_call_original }
    rejected.each { |bytes| expect(%i[parse_error error]).to include(WmfMutation.observe(bytes, "native", library).first) }
    phases.each { |phase| expect(Emf::Wmf::Parser).not_to have_received(phase) }
  end

  it "no longer carries a Ruby replay of the parser phases" do
    expect(Emf::Native.const_defined?(:WmfDiagnosis)).to be(false)
  end
end
