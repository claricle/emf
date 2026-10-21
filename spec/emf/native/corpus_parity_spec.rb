# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/native_corpus_parity"

RSpec.describe "Native valid-EMF corpus acceptance" do
  root = File.expand_path("../../..", __dir__)
  manifest = JSON.parse(File.read(File.join(root, "spec/fixtures/manifest.json")))
  fixtures = NativeCorpusParity.entries(manifest)

  let(:library) do
    ENV.fetch("EMF_TEST_NATIVE_LIBRARY") do
      extension = RbConfig::CONFIG.fetch("host_os").include?("darwin") ? "dylib" : "so"
      File.join(root, "emf-rs/target/debug/libemf_ffi.#{extension}")
    end
  end
  let(:runner) { NativeCorpusParity::Runner.new(root: root, library: library) }

  before do
    skip "native library not built: #{library}" unless File.file?(library)
  end

  it "covers all 208 valid manifest fixtures and excludes recovery inputs" do
    expect(fixtures.size).to eq(208)
    expect(fixtures.map { |entry| entry.fetch("path") }.uniq.size).to eq(208)
    expect(fixtures.map { |entry| entry.fetch("outcome") }).to all(eq("parsed"))
    expect(fixtures.map { |entry| entry.fetch("expected_format") }).to all(eq("emf"))
    expect(fixtures.group_by { |entry| entry.fetch("path").split("/")[2] }.transform_values(&:size))
      .to eq("emf" => 186, "emf-ea" => 21, "simple" => 1)
  end

  fixtures.each do |entry|
    it "matches Ruby fields, diagnostics and exact round trips for #{entry.fetch('path')}" do
      path = File.join(root, entry.fetch("path"))
      bytes = File.binread(path)
      expect(bytes.bytesize).to eq(entry.fetch("size_bytes"))
      expect(Digest::SHA256.hexdigest(bytes)).to eq(entry.fetch("sha256"))
      verdict = runner.call(path)
      expect(verdict).not_to have_key("failure"), verdict["failure"]
      expect(verdict.fetch("records")).to be_positive
      expect(verdict.fetch("model_sha256")).to match(/\A[0-9a-f]{64}\z/)
      expect(File.binread(path)).to eq(bytes)
    end
  end

  NativeCorpusParity::EDIT_FIXTURES.each do |shape, fixture|
    it "matches live #{shape} wire edits, equality and sibling preservation" do
      verdict = runner.call(File.join(root, "spec/fixtures", fixture), shape)
      expect(verdict).not_to have_key("failure"), verdict["failure"]
      expect(verdict.fetch("shape")).to eq(shape)
      expect(verdict.fetch("sha256")).to match(/\A[0-9a-f]{64}\z/)
    end
  end
end
