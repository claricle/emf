# frozen_string_literal: true

require "spec_helper"
require "digest"
require "json"
require "tmpdir"
require_relative "../../bench/support/parser_benchmark"
require_relative "../support/fixture_manifest"

RSpec.describe ParserBenchmark::CLI do
  let(:tmpdir) { Dir.mktmpdir("parser-benchmark") }
  let(:result_path) { File.join(tmpdir, "result.json") }
  let(:manifest) do
    source = JSON.parse(File.read(File.join(ParserBenchmark::ROOT, "spec/fixtures/manifest.json")))
    source["schema_version"] = FixtureManifest::SCHEMA_VERSION
    File.join(tmpdir, "current-manifest.json").tap { |path| File.write(path, JSON.generate(source)) }
  end
  let(:report) { JSON.parse(File.read(result_path)) }
  let(:fast_args) do
    ["--manifest", manifest, "--backend", "ruby", "--output", result_path, "--fixture", "spec/fixtures/simple/*",
     "--iterations", "2", "--warmups", "0", "--cold-runs", "1"]
  end

  after { FileUtils.remove_entry(tmpdir) }

  context "with a parsed fixture" do
    # One real run (with child processes) is shared by the examples below.
    before(:context) do
      @dir = Dir.mktmpdir("parser-benchmark-shared")
      path = File.join(@dir, "result.json")
      source = JSON.parse(File.read(File.join(ParserBenchmark::ROOT, "spec/fixtures/manifest.json")))
      source["schema_version"] = FixtureManifest::SCHEMA_VERSION
      manifest = File.join(@dir, "manifest.json")
      File.write(manifest, JSON.generate(source))
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
    args = fast_args.dup.tap { |a| a[a.index("--backend") + 1] = "other" }
    expect { expect(described_class.new(args).run).to eq(2) }.to output(/unsupported backend "other"/).to_stderr
    expect(File).not_to exist(result_path)
  end

  it "forces native in both warm and cold children and reports unavailable libraries" do
    previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
    ENV["EMF_BACKEND"] = "ruby"
    ENV["EMF_NATIVE_LIBRARY"] = File.join(tmpdir, "missing-library")
    args = fast_args.dup.tap { |a| a[a.index("--backend") + 1] = "native" }

    expect(described_class.new(args).run).to eq(1)
    expect(report.fetch("backend")).to eq("native")
    expect(report.fetch("failures").size).to eq(2)
    expect(report.fetch("failures").map { |failure| failure.dig("failure", "class") }).to eq(
      ["Emf::Native::Unavailable", "Emf::Native::Unavailable"]
    )
    expect(report.fetch("slowest_measured_case")).to be_nil
    expect(report.dig("method", "stages", "parse")).to include("ABI", "hydration")
    expect(report.dig("method", "inseparable_boundaries").join).not_to include("Emr::Parser.call")
    expect(report.fetch("native_library")).to include("path" => ENV.fetch("EMF_NATIVE_LIBRARY"), "sha256" => nil)
  ensure
    previous.each_key { |key| ENV[key] = previous[key] }
    %w[EMF_BACKEND EMF_NATIVE_LIBRARY].each { |key| ENV.delete(key) unless previous.key?(key) }
  end

  it "records the exact library identity even when the library cannot load" do
    previous = ENV.fetch("EMF_NATIVE_LIBRARY", nil)
    library = File.join(tmpdir, "invalid-library")
    File.binwrite(library, "not a native library")
    ENV["EMF_NATIVE_LIBRARY"] = library
    args = fast_args.dup.tap { |a| a[a.index("--backend") + 1] = "native" }

    expect(described_class.new(args).run).to eq(1)
    expect(report.fetch("native_library")).to include(
      "path" => library, "resolved_path" => File.realpath(library),
      "sha256" => Digest::SHA256.file(library).hexdigest, "size_bytes" => File.size(library)
    )
    expect(report.dig("native_library", "build_metadata")).to include("profile" => nil, "rustc_version" => nil)
    expect(report.fetch("failures").size).to eq(2)
  ensure
    ENV["EMF_NATIVE_LIBRARY"] = previous
  end

  it "rejects stale manifest schemas without writing results" do
    source = JSON.parse(File.read(manifest))
    source["schema_version"] = FixtureManifest::SCHEMA_VERSION - 1
    File.write(manifest, JSON.generate(source))

    expect { expect(described_class.new(fast_args).run).to eq(2) }.to output(/schema/).to_stderr
    expect(File).not_to exist(result_path)
  end

  it "defaults to forced Ruby even when the caller requests native" do
    previous = ENV.fetch("EMF_BACKEND", nil)
    ENV["EMF_BACKEND"] = "native"
    args = fast_args.dup
    args.slice!(args.index("--backend"), 2)

    expect(described_class.new(args).run).to eq(0)
    expect(report.fetch("backend")).to eq("ruby")
    expect(report.fetch("fixtures").fetch(0).fetch("status")).to eq("ok")
    expect(report.dig("cold_load", "runs", 0, "status")).to eq("ok")
    expect(ENV.fetch("EMF_BACKEND")).to eq("native")
  ensure
    ENV["EMF_BACKEND"] = previous
  end

  it "requires the manifest and output options" do
    expect { expect(described_class.new(["--backend", "ruby"]).run).to eq(2) }.to output(/--manifest is required/).to_stderr
  end

  it "keeps fixture selections independent between CLI invocations" do
    expect(described_class.new(fast_args).run).to eq(0)
    args = fast_args.dup.tap { |a| a[a.index("--fixture") + 1] = "no-such-fixture/*" }
    expect { expect(described_class.new(args).run).to eq(2) }.to output(/no fixtures selected/).to_stderr
  end

  it "records a failure for a fixture that is not a valid EMF instead of crashing" do
    garbage = File.join(tmpdir, "garbage.emf")
    File.binwrite(garbage, "not an emf")
    entry = { "path" => garbage, "sha256" => Digest::SHA256.file(garbage).hexdigest, "size_bytes" => 10, "outcome" => "parsed" }
    custom = File.join(tmpdir, "manifest.json")
    File.write(custom, JSON.generate("schema_version" => FixtureManifest::SCHEMA_VERSION,
                                     "backend" => { "name" => "ruby" }, "fixtures" => [entry]))
    args = fast_args.dup.tap { |a| a[a.index("--manifest") + 1] = custom }
    args.slice!(args.index("--fixture"), 2)

    expect(described_class.new(args).run).to eq(1)
    expect(report.fetch("failures")).to contain_exactly(
      include("path" => garbage, "status" => "error"),
      include("path" => garbage, "status" => "failed", "stage" => "cold_load", "run" => 0)
    )
    expect(report.fetch("slowest_measured_case")).to be_nil
  end
end

RSpec.describe ParserBenchmark::Run do
  let(:tmpdir) { Dir.mktmpdir("parser-benchmark-cold") }
  let(:result_path) { File.join(tmpdir, "result.json") }
  let(:manifest) do
    source = JSON.parse(File.read(File.join(ParserBenchmark::ROOT, "spec/fixtures/manifest.json")))
    source["schema_version"] = FixtureManifest::SCHEMA_VERSION
    File.join(tmpdir, "current-manifest.json").tap { |path| File.write(path, JSON.generate(source)) }
  end
  let(:options) do
    ParserBenchmark::Options.new(**ParserBenchmark::CLI::DEFAULTS,
                                 manifest: manifest,
                                 output: result_path, fixtures: ["spec/fixtures/simple/*"],
                                 iterations: 1, warmups: 0, cold_runs: 2)
  end
  let(:runner) { described_class.new(options, []) }

  after { FileUtils.remove_entry(tmpdir) }

  it "includes cold child failures in the report and exit status" do
    failure = { "safety_failure" => { "kind" => "timeout" } }
    error = { "status" => "error", "error" => { "class" => "Emf::FormatError", "message" => "invalid input" } }
    allow(runner).to receive(:child).and_call_original
    allow(runner).to receive(:child).with(%w[--worker cold], anything).and_return(failure, error)

    expect(runner.run).to eq(1)
    report = JSON.parse(File.read(result_path))
    expect(report.fetch("fixtures").fetch(0)).to include("status" => "ok")
    expect(report.dig("cold_load", "runs")).to eq([failure, error])
    expect(report.fetch("failures")).to contain_exactly(
      include("stage" => "cold_load", "run" => 0, "failure" => { "kind" => "timeout" }),
      include("stage" => "cold_load", "run" => 1, "failure" => error.fetch("error"))
    )
  end
end
