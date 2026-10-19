# frozen_string_literal: true

require "spec_helper"
require "digest"
require "json"
require "tmpdir"
require_relative "../../bench/support/parser_benchmark"

RSpec.describe ParserBenchmark::CLI do
  let(:tmpdir) { Dir.mktmpdir("parser-benchmark") }
  let(:result_path) { File.join(tmpdir, "result.json") }
  let(:manifest) { File.join(ParserBenchmark::ROOT, "spec/fixtures/manifest.json") }
  let(:report) { JSON.parse(File.read(result_path)) }
  let(:fast_args) do
    ["--manifest", manifest, "--backend", "ruby", "--output", result_path, "--fixture", "spec/fixtures/simple/*",
     "--iterations", "2", "--warmups", "0", "--cold-runs", "1"]
  end

  after { FileUtils.remove_entry(tmpdir) }

  def run_cli(args)
    described_class.new(args).run
  end

  context "with a parsed fixture" do
    # One real run (with child processes) is shared by the examples below.
    before(:context) do
      @dir = Dir.mktmpdir("parser-benchmark-shared")
      path = File.join(@dir, "result.json")
      manifest = File.join(ParserBenchmark::ROOT, "spec/fixtures/manifest.json")
      @status = described_class.new(["--manifest", manifest, "--backend", "ruby", "--output", path, "--fixture",
                                     "spec/fixtures/simple/*", "--iterations", "2", "--warmups", "0", "--cold-runs", "1"]).run
      @report = JSON.parse(File.read(path))
    end

    after(:context) { FileUtils.remove_entry(@dir) }

    let(:report) { @report }

    it "exits successfully" do
      expect(@status).to eq(0)
    end

    it "records a valid result with identities and a verified round trip" do
      fixture = report.fetch("fixtures").fetch(0)
      expect(fixture).to include("status" => "ok", "path" => "spec/fixtures/simple/image1.emf")
      expect(fixture.fetch("validity")).to include("round_trip_identical" => true, "parse_error_count" => 0)
      expect(fixture.fetch("sha256")).to eq(Digest::SHA256.file(File.join(ParserBenchmark::ROOT, fixture.fetch("path"))).hexdigest)
      expect(report.fetch("revision")).to include("git_sha", "parser_source_sha256", "manifest_matches_sources")
      expect(report.fetch("environment")).to include("ruby", "gems", "os", "cpu_count")
      expect(report.fetch("method")).to include("iterations" => 2, "warmups" => 0)
    end

    it "reports exactly the declared stages with one sample per iteration" do
      stages = report.fetch("fixtures").fetch(0).fetch("stages")
      expect(stages.keys).to eq(ParserBenchmark::STAGES.keys)
      stages.each_value do |stage|
        summary = stage.fetch("summary_ns")
        expect(stage.fetch("samples_ns").size).to eq(2)
        expect(summary.values_at("min", "median", "max")).to eq(summary.values_at("min", "median", "max").sort)
      end
    end

    it "explains inseparable boundaries instead of inventing stages" do
      method = report.fetch("method")
      expect(method.fetch("stages").keys).not_to include("wire_parse", "model_creation")
      expect(method.fetch("inseparable_boundaries").join).to match(/wire parsing and model creation/i)
      expect(method.dig("timing", "unit")).to eq("nanoseconds")
      expect(report.fetch("cold_load").fetch("runs").fetch(0)).to include("status" => "ok", "require_emf_ns" => be_positive)
    end

    it "names the slowest measured case without claiming it is the issue's file" do
      slowest = report.fetch("slowest_measured_case")
      expect(slowest).to include("path" => "spec/fixtures/simple/image1.emf", "issue_15_fixture_identified" => false)
    end
  end

  it "rejects an unsupported backend without writing a result" do
    args = fast_args.dup.tap { |a| a[a.index("--backend") + 1] = "native" }
    expect { expect(run_cli(args)).to eq(2) }.to output(/unsupported backend "native"/).to_stderr
    expect(File).not_to exist(result_path)
  end

  it "requires the manifest and output options" do
    expect { expect(run_cli(["--backend", "ruby"])).to eq(2) }.to output(/--manifest is required/).to_stderr
  end

  it "records a failure for a fixture that is not a valid EMF instead of crashing" do
    garbage = File.join(tmpdir, "garbage.emf")
    File.binwrite(garbage, "not an emf")
    entry = { "path" => garbage, "sha256" => Digest::SHA256.file(garbage).hexdigest, "size_bytes" => 10, "outcome" => "parsed" }
    custom = File.join(tmpdir, "manifest.json")
    File.write(custom, JSON.generate("schema_version" => 1, "backend" => { "name" => "ruby" }, "fixtures" => [entry]))
    args = fast_args.dup.tap { |a| a[a.index("--manifest") + 1] = custom }
    args.slice!(args.index("--fixture"), 2)

    expect(run_cli(args)).to eq(1)
    expect(report.fetch("failures")).to contain_exactly(include("path" => garbage, "status" => "error"))
    expect(report.fetch("slowest_measured_case")).to be_nil
  end
end
