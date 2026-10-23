# frozen_string_literal: true

require "spec_helper"
require_relative "../support/wmf_resilience"

RSpec.describe WmfResilience do
  let(:root) { File.expand_path("../..", __dir__) }
  let(:paths) { described_class.seed_paths(root) }
  let(:rss_limit) { 1024 * 1024 * 1024 }
  let(:valid_names) { paths.select { |path| File.basename(path).start_with?("valid-") } }

  def run_backend(backend)
    described_class::Runner.new(root: root, backend: backend, wall_seconds: 30, rss_limit_bytes: rss_limit).call(paths)
  end

  def expected_outcome(path)
    name = File.basename(path)
    return "parsed" if name.start_with?("valid-")

    %w[file-size.wmf max-record.wmf negative-text-count.wmf placeable-checksum.wmf].include?(name) ? "recovered" : "rejected"
  end

  def expect_every_seed_defined(results)
    expect(results.size).to eq(16)
    results.each do |result|
      observation = result.fetch("observation")
      label = result.fetch("path")
      expect(result).to include("status" => "exited", "exit_code" => 0, "unchanged" => true), label
      expect(observation.fetch("outcome")).to eq(expected_outcome(label)), "#{label}: #{observation}"
      expect(observation["round_trip"]).to eq("ok") if described_class::KEPT.include?(observation["outcome"])
      expect(observation.fetch("undefined")).to eq([]), "#{label}: #{observation['undefined']}"
      expect(observation.fetch("mutations")).to be > 40, label
    end
  end

  it "selects the 8 valid and 8 malformed committed seeds" do
    expect(paths.size).to eq(16)
    expect(valid_names.size).to eq(8)
  end

  it "terminates every seed and its mutations with a defined outcome on the Ruby backend" do
    expect_every_seed_defined(run_backend("ruby"))
  end

  it "terminates every seed and its mutations with a defined outcome on the native backend" do
    library = ENV.fetch("EMF_TEST_NATIVE_LIBRARY", nil)
    skip "set EMF_TEST_NATIVE_LIBRARY to run native specs" if library.nil?
    expect(File.file?(library)).to be(true), "EMF_TEST_NATIVE_LIBRARY is not a file: #{library}"
    ENV["EMF_NATIVE_LIBRARY"] = library
    expect_every_seed_defined(run_backend("native"))
  ensure
    ENV.delete("EMF_NATIVE_LIBRARY") if library
  end

  it "reports a child that is not defined as undefined, so the oracle can fail" do
    result = described_class.classify("\x00".b)
    expect(result).to include("outcome" => "rejected")
    allow(Emf).to receive(:parse).and_raise(NoMethodError, "boom")
    expect(described_class.classify("x")).to include("outcome" => "undefined", "exception" => "NoMethodError")
    expect(described_class.defined_result?("outcome" => "undefined")).to be(false)
    allow(Emf).to receive(:parse).and_raise(Emf::Native::Unavailable, "no library")
    expect(described_class.classify("x")).to include("outcome" => "undefined", "exception" => "Emf::Native::Unavailable")
  end
end
