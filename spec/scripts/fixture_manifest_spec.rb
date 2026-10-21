# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "tmpdir"
require_relative "../support/fixture_manifest"
require_relative "../support/process_supervisor_helpers"

RSpec.describe FixtureManifest do
  include ProcessSupervisorHelpers

  let(:rss_limit) { 512 * 1024 * 1024 }
  let(:root) { File.expand_path("../..", __dir__) }
  let(:inventory) { described_class::Inventory.new(root) }
  let(:manifest) { JSON.parse(File.read(File.join(root, "spec/fixtures/manifest.json"))) }
  let(:current_manifest) do
    entries = described_class.fixtures(root).map do |entry|
      entry.merge("detected_format" => entry.fetch("expected_format") == "wmf" ? "wmf" : "emf",
                  "outcome" => "parsed")
    end
    {
      "schema_version" => described_class::SCHEMA_VERSION,
      "capture" => described_class::CAPTURE_METADATA,
      "backend" => { "name" => "ruby", "bindata_version" => Gem.loaded_specs.fetch("bindata").version.to_s,
                     "parser_source_sha256" => described_class.source_sha256(root) },
      "counts" => described_class.counts(entries), "fixtures" => entries
    }
  end

  describe "benchmark series safety contract" do
    it "runs a short observation with the explicit series deadline" do
      runner = described_class::Runner.new(timeout: 1200, rss_limit_bytes: rss_limit, benchmark_series: true,
                                           command: ruby('puts %q({"outcome":"parsed"})'))

      expect(runner.call("unused")).to eq("outcome" => "parsed")
    end

    it "rejects a series-sized deadline without opt-in" do
      expect { described_class::Runner.new(timeout: 61, rss_limit_bytes: rss_limit) }
        .to raise_error(ArgumentError, /wall_seconds/)
    end

    it "rejects invalid series deadlines through the runner" do
      [nil, "1200", Float::NAN, Float::INFINITY, 0, 1201].each do |timeout|
        expect { described_class::Runner.new(timeout: timeout, rss_limit_bytes: rss_limit, benchmark_series: true) }
          .to raise_error(ArgumentError, /wall_seconds/)
      end
    end

    it "forwards the series opt-in and exact safety limits" do
      supervisor = instance_double(ProcessSupervisor)
      expect(ProcessSupervisor).to receive(:new)
        .with(wall_seconds: 1200, rss_limit_bytes: rss_limit, output_limit: 123, benchmark_series: true)
        .and_return(supervisor)

      described_class::Runner.new(timeout: 1200, rss_limit_bytes: rss_limit, output_limit: 123, benchmark_series: true)
    end

    it "keeps each series safety failure separate from valid observations" do
      supervisor = instance_double(ProcessSupervisor)
      allow(ProcessSupervisor).to receive(:new).and_return(supervisor)
      runner = described_class::Runner.new(timeout: 1200, rss_limit_bytes: rss_limit, benchmark_series: true)
      { timed_out: "timeout", rss_exceeded: "rss_exceeded", output_limit: "output_limit",
        monitor_failed: "monitor_failed", cleanup_failed: "process_failure" }.each do |status, kind|
        result = ProcessSupervisor::Result.new(status: status, exit_code: 0, output: '{"outcome":"parsed"}')
        allow(supervisor).to receive(:call).and_return(result)

        expect(runner.call("unused")).to eq(
          "detected_format" => nil, "outcome" => nil, "safety_failure" => { "kind" => kind }
        )
      end
    end
  end

  it "inventories every existing fixture in deterministic path order without parsing" do
    entries = described_class.fixtures(root)
    expect(entries.size).to eq(231)
    expect(described_class.counts(entries)).to eq(
      "emf" => 186, "emf-ea" => 21, "simple" => 1, "emf-corrupted" => 21, "wmf" => 2
    )
    expect(entries.count { |entry| entry.fetch("expected_format") == "emf" }).to eq(229)
    wmf_entries = entries.select { |entry| entry.fetch("expected_format") == "wmf" }
    expect(wmf_entries.map { |entry| entry.fetch("path") }).to eq(
      %w[spec/fixtures/wmf/placeable-line.wmf spec/fixtures/wmf/standard-line.wmf]
    )
    expect(wmf_entries).to all(include("provenance" => "synthetic"))
    wmf_entries.each do |entry|
      fixture_path = File.join(root, entry.fetch("path"))
      expect(entry.fetch("sha256")).to eq(Digest::SHA256.file(fixture_path).hexdigest)
      expect(entry.fetch("size_bytes")).to eq(File.size(fixture_path))
    end
    expect(entries.map { |entry| entry.fetch("path") }).to eq(entries.map { |entry| entry.fetch("path") }.sort)
    expect(entries.first.fetch("sha256")).to eq(Digest::SHA256.file(File.join(root, entries.first.fetch("path"))).hexdigest)
  end

  it "rejects a legacy schema without starting parser processes" do
    expect(described_class::Runner).not_to receive(:new)
    expect(inventory.check(current_manifest.merge("schema_version" => 1))).to be(false)
  end

  it "rejects fixture, source, schema, observation and safety drift" do
    mutations = [
      ->(data) { data["fixtures"].first["sha256"] = "changed" },
      ->(data) { data["backend"]["parser_source_sha256"] = "changed" },
      ->(data) { data["schema_version"] = 99 },
      ->(data) { data["capture"]["limits"]["timeout_seconds"] = 5 },
      ->(data) { data["capture"].delete("limits") },
      ->(data) { data["fixtures"].first["outcome"] = "unknown" },
      ->(data) { data["fixtures"].first["safety_failure"] = { "kind" => "timeout" } },
      ->(data) { data["fixtures"].pop },
      ->(data) { data["fixtures"].first["backend_exception"] = {} },
      ->(data) { data["fixtures"].first["detected_format"] = "unknown" },
      ->(data) { data["fixtures"].find { |entry| entry["outcome"] == "parsed" }["outcome"] = "format_error" },
      ->(data) { data["fixtures"] = nil },
      ->(data) { data["backend"] = nil }
    ]
    mutations.each do |mutate|
      altered = Marshal.load(Marshal.dump(current_manifest))
      mutate.call(altered)
      expect(inventory.check(altered)).to be(false)
    end
  end

  it "checks capture limits exactly" do
    saved = current_manifest
    expect(inventory.check(saved)).to be(true)

    altered = Marshal.load(Marshal.dump(saved))
    altered.fetch("capture").fetch("limits")["timeout_seconds"] = 5
    expect(inventory.check(altered)).to be(false)
  end

  it "observes successful parsing, recovery and format rejection through the public parser" do
    parsed = described_class.observe(File.join(root, "spec/fixtures/simple/image1.emf"))
    expect(parsed).to eq("detected_format" => "emf", "outcome" => "parsed")
    recovered = manifest.fetch("fixtures").find { |entry| entry["outcome"] == "recovered" }
    expect(described_class::Runner.new(rss_limit_bytes: rss_limit).call(File.join(root, recovered.fetch("path")))).to eq(
      "detected_format" => "emf", "outcome" => "recovered"
    )
    Tempfile.create("invalid-emf") do |file|
      file.write("bad")
      file.flush
      rejected = described_class.observe(file.path)
      expect(rejected).to include("detected_format" => nil, "outcome" => "format_error")
      expect(rejected.fetch("format_error")).to include("class" => "Emf::FormatError", "message" => "input too short (3 bytes)")
    end
  end

  it "forces Ruby observation regardless of the ambient backend setting" do
    previous_backend = ENV.fetch("EMF_BACKEND", nil)
    ENV["EMF_BACKEND"] = "invalid-backend"
    result = described_class.observe(File.join(root, "spec/fixtures/simple/image1.emf"))
    expect(result).to eq("detected_format" => "emf", "outcome" => "parsed")
    expect(ENV.fetch("EMF_BACKEND")).to eq("invalid-backend")
  ensure
    previous_backend.nil? ? ENV.delete("EMF_BACKEND") : ENV["EMF_BACKEND"] = previous_backend
  end

  it "generates schema metadata with the explicit baseline observation limits" do
    observation = { "detected_format" => "emf", "outcome" => "parsed" }
    runner = instance_double(described_class::Runner, call: observation)
    inventory = described_class::Inventory.new(root, rss_limit_bytes: rss_limit)
    expect(described_class::Runner).to receive(:new).with(timeout: 15, output_limit: 16_384, rss_limit_bytes: rss_limit).and_return(runner)

    generated = inventory.generate
    expect(generated.fetch("schema_version")).to eq(2)
    expect(generated.fetch("capture")).to eq(
      "backend" => "ruby", "limits" => { "timeout_seconds" => 15, "output_limit_bytes" => 16_384 }
    )
  end

  it "records incidental backend exceptions separately from format errors" do
    allow(Emf).to receive(:parse).and_raise(IOError, "backend broke")
    result = described_class.observe(File.join(root, "spec/fixtures/simple/image1.emf"))
    expect(result).to eq("detected_format" => "emf", "outcome" => nil,
                         "backend_exception" => { "class" => "IOError", "message" => "backend broke" })
  end

  it "bounds hanging children, including children that close their output early" do
    ["sleep 10", "$stdout.close; $stderr.close; sleep 10"].each do |code|
      runner = described_class::Runner.new(timeout: 1, rss_limit_bytes: rss_limit, command: ruby(code))
      expect(runner.call("unused")).to include("outcome" => nil, "safety_failure" => { "kind" => "timeout" })
    end
  end

  it "bounds output and distinguishes crashes and invalid child observations" do
    cases = {
      "loop { STDOUT.write('x' * 4096) }" => "output_limit",
      "exit 9" => "process_failure",
      "puts 'not json'" => "invalid_observation"
    }
    cases.each do |code, kind|
      runner = described_class::Runner.new(timeout: 2, output_limit: 1024, rss_limit_bytes: rss_limit, command: ruby(code))
      expect(runner.call("unused").fetch("safety_failure")).to include("kind" => kind)
    end
  end

  it "passes a leading environment hash in the command to the supervised child" do
    code = 'puts JSON.generate("outcome" => ENV["EMF_RUNNER_PROBE"], "unset" => ENV.key?("EMF_RUNNER_GONE"))'
    command = [{ "EMF_RUNNER_PROBE" => "seen", "EMF_RUNNER_GONE" => nil }, RbConfig.ruby, "-rjson", "-e", code]
    runner = described_class::Runner.new(timeout: 5, rss_limit_bytes: rss_limit, command: command)
    ENV["EMF_RUNNER_GONE"] = "present"
    expect(runner.call("unused")).to eq("outcome" => "seen", "unset" => false)
  ensure
    ENV.delete("EMF_RUNNER_GONE")
  end

  describe "supervised capture" do
    it "records an over-RSS child as a safety failure, not an observation" do
      code = "a = 'x' * 120_000_000; sleep 30"
      runner = described_class::Runner.new(timeout: 5, rss_limit_bytes: 64 * 1024 * 1024, command: ruby(code))
      expect(runner.call("unused")).to eq(
        "detected_format" => nil, "outcome" => nil, "safety_failure" => { "kind" => "rss_exceeded" }
      )
    end

    it "records a failed RSS probe as a safety failure" do
      Dir.mktmpdir("emf-failing-ps-") do |dir|
        File.write(File.join(dir, "ps"), "#!/bin/sh\nexit 1\n")
        File.chmod(0o700, File.join(dir, "ps"))
        runner = described_class::Runner.new(timeout: 5, rss_limit_bytes: rss_limit,
                                             command: [RbConfig.ruby, "--disable-gems", "-e", "sleep 30"])
        result = with_path(dir) { runner.call("unused") }
        expect(result).to include("outcome" => nil, "safety_failure" => { "kind" => "monitor_failed" })
      end
    end

    it "does not launder a clean zero exit with valid JSON when a limit was breached" do
      code = "a = 'x' * 120_000_000; sleep 0.3; puts '{\"detected_format\":\"emf\",\"outcome\":\"parsed\"}'"
      runner = described_class::Runner.new(timeout: 5, rss_limit_bytes: 64 * 1024 * 1024, command: ruby(code))
      expect(runner.call("unused").fetch("safety_failure")).to eq("kind" => "rss_exceeded")
    end

    it "reports exit status and signal for crashed children" do
      runner = described_class::Runner.new(timeout: 2, rss_limit_bytes: rss_limit, command: ruby("exit 9"))
      expect(runner.call("unused").fetch("safety_failure")).to eq(
        "kind" => "process_failure", "exit_status" => 9, "signal" => nil
      )
    end

    it "requires an explicit RSS ceiling and never invents one" do
      expect { described_class::Runner.new(rss_limit_bytes: nil) }.to raise_error(ArgumentError, /rss_limit_bytes/)
      expect(described_class.rss_limit_bytes_from_env({})).to be_nil
      expect(described_class.rss_limit_bytes_from_env("EMF_MANIFEST_RSS_LIMIT_MB" => "0")).to be_nil
      expect(described_class.rss_limit_bytes_from_env("EMF_MANIFEST_RSS_LIMIT_MB" => "256")).to eq(256 * 1024 * 1024)
      expect { described_class::Inventory.new(root, rss_limit_bytes: nil).generate }
        .to raise_error(ArgumentError, /EMF_MANIFEST_RSS_LIMIT_MB/)
    end

    it "captures real fixtures exactly as the unsupervised runner did" do
      runner = described_class::Runner.new(timeout: 15, rss_limit_bytes: rss_limit)
      expected = {
        "spec/fixtures/simple/image1.emf" => { "detected_format" => "emf", "outcome" => "parsed" },
        "spec/fixtures/emf-corrupted/bad_corrupted_2014-12-13-105759.emf" => { "detected_format" => "emf", "outcome" => "recovered" },
        "spec/fixtures/wmf/placeable-line.wmf" => { "detected_format" => "wmf", "outcome" => "parsed" },
        "spec/fixtures/emf-ea/EA-test-file-001.emf" => { "detected_format" => "emf", "outcome" => "parsed" }
      }
      expect(expected.keys.to_h { |path| [path, runner.call(File.join(root, path))] }).to eq(expected)
    end
  end
end
