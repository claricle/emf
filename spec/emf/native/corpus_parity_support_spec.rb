# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/native_corpus_parity"

RSpec.describe NativeCorpusParity::Runner do
  subject(:verdict) { runner.call("unused.emf") }

  let(:runner) { described_class.new(root: "/unused", library: "/unused/library") }
  let(:supervisor) { instance_double(ProcessSupervisor) }
  let(:prefixes) { [] }
  let(:report) { JSON.generate("records" => 1, "model_sha256" => "a" * 64) }
  let(:status) { :exited }
  let(:exit_code) { 0 }
  let(:sidecars) { { "ruby" => '{"records":[{"offset":108}]}', "native" => '{"records":[{"offset":108}]}' } }

  before do
    allow(ProcessSupervisor).to receive(:new).and_return(supervisor)
    allow(supervisor).to receive(:call) do |command, env:|
      expect(env).to eq("EMF_NATIVE_LIBRARY" => "/unused/library")
      backend, prefix = command.values_at(6, 7)
      prefixes << prefix
      File.write("#{prefix}.json", sidecars.fetch(backend))
      ProcessSupervisor::Result.new(status: status, exit_code: exit_code, peak_rss_bytes: 123, output: report)
    end
  end

  it "compares independent backend observations and removes their temporary files" do
    expect(verdict).to eq("records" => 1, "model_sha256" => "a" * 64)
    expect(prefixes.size).to eq(2)
    expect(prefixes.map { |prefix| File.dirname(prefix) }.uniq.size).to eq(1)
    expect(prefixes.none? { |prefix| File.exist?(File.dirname(prefix)) }).to be(true)
  end

  context "when a child exceeds its time limit" do
    let(:status) { :timed_out }
    let(:exit_code) { nil }

    it "rejects a valid-looking report and cleans its observation" do
      expect(verdict.fetch("failure")).to include("ruby child timed_out", "peak_rss=123")
      expect(prefixes.size).to eq(1)
      expect(File.exist?(File.dirname(prefixes.first))).to be(false)
    end
  end

  context "when a child exits unsuccessfully" do
    let(:exit_code) { 7 }

    it "rejects the report" do
      expect(verdict.fetch("failure")).to include("ruby child exited exit=7")
    end
  end

  context "when the child report is malformed" do
    let(:report) { "partial JSON" }

    it "reports the parse failure and cleans the observation" do
      expect(verdict.fetch("failure")).to include("JSON::ParserError")
      expect(File.exist?(File.dirname(prefixes.first))).to be(false)
    end
  end

  context "when an observation is malformed" do
    let(:sidecars) { super().merge("native" => "partial JSON") }

    it "rejects the observation and cleans both backend files" do
      expect(verdict.fetch("failure")).to include("JSON::ParserError")
      expect(prefixes.none? { |prefix| File.exist?(File.dirname(prefix)) }).to be(true)
    end
  end

  context "when canonical observations differ despite matching verdict digests" do
    let(:sidecars) { super().merge("native" => '{"records":[{"offset":112}]}') }

    it "reports the indexed difference and cleans both backend files" do
      expect(verdict.fetch("failure")).to include("Ruby/native model", "records[0].offset")
      expect(prefixes.none? { |prefix| File.exist?(File.dirname(prefix)) }).to be(true)
    end
  end
end
