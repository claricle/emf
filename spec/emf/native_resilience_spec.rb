# frozen_string_literal: true

require "spec_helper"
require "json"
require "open3"
require "tmpdir"
require_relative "../support/native_resilience"
require_relative "../support/process_supervisor_helpers"

RSpec.describe NativeResilience do
  include ProcessSupervisorHelpers

  let(:root) { File.expand_path("../..", __dir__) }
  let(:manifest) { JSON.parse(File.read(File.join(root, "spec/fixtures/manifest.json"))) }
  let(:fixture_dir) { Dir.mktmpdir }
  let(:fixture_file) { File.join(fixture_dir, "stub.emf").tap { |file| File.binwrite(file, "original") } }
  let(:entry) { { "path" => fixture_file, "outcome" => "recovered" } }
  let(:ok) { %({"outcome":"recovered","round_trip":"ok"}) }

  after { FileUtils.remove_entry(fixture_dir) }
  let(:rss_limit) { 64 * 1024 * 1024 }

  def run_stub(code, wall_seconds: 1, rss_limit_bytes: rss_limit)
    runner = described_class::Runner.new(root: "/", backend: "ruby", wall_seconds: wall_seconds,
                                         rss_limit_bytes: rss_limit_bytes, child: ->(_path) { ruby(code) })
    runner.call([entry.merge("path" => fixture_file.delete_prefix("/"))])
  end

  def only_result(report)
    expect(report.fetch("results").size).to eq(1)
    report.fetch("results").first
  end

  describe ".entries" do
    it "selects exactly the 21 corrupt EMF fixtures by directory" do
      paths = described_class.entries(manifest, "corrupted").map { |item| item.fetch("path") }

      expect(paths.size).to eq(21)
      expect(paths).to all(start_with("spec/fixtures/emf-corrupted/"))
    end

    it "selects every fixture for the all scope" do
      expect(described_class.entries(manifest, "all").size).to eq(manifest.fetch("fixtures").size)
    end
  end

  describe "configuration" do
    it "refuses to build a runner without an RSS limit" do
      expect { described_class::Runner.new(root: root, backend: "native", wall_seconds: 60, rss_limit_bytes: nil) }
        .to raise_error(described_class::ConfigurationError, /RSS limit/)
    end

    it "refuses an unknown backend" do
      expect { described_class::Runner.new(root: root, backend: "auto", wall_seconds: 60, rss_limit_bytes: 1) }
        .to raise_error(described_class::ConfigurationError, /backend/)
    end
  end

  describe "verdicts from stub children" do
    it "passes a child that exits 0 with the baseline outcome" do
      report = run_stub(%(puts '#{ok}'))

      expect(only_result(report)).to include("verdict" => "passed", "reason" => nil, "observed_outcome" => "recovered")
      expect(report.fetch("totals")).to eq("fixtures" => 1, "passed" => 1, "failed" => 0)
    end

    it "fails an outcome that differs from the baseline" do
      result = only_result(run_stub(%(puts '{"outcome":"parsed"}')))

      expect(result).to include("verdict" => "failed", "reason" => "outcome_mismatch", "observed_outcome" => "parsed")
    end

    it "fails an unexpected exception reported by the child" do
      result = only_result(run_stub(%(puts '{"outcome":null,"exception":"Emf::Native::Unavailable"}')))

      expect(result).to include("verdict" => "failed", "reason" => "outcome_mismatch", "exception" => "Emf::Native::Unavailable")
    end

    it "fails output that is not an observation" do
      expect(only_result(run_stub(%(puts "garbage")))).to include("verdict" => "failed", "reason" => "invalid_observation")
    end

    it "fails a nonzero exit even when the right outcome was printed" do
      result = only_result(run_stub(%(puts '#{ok}'; exit 3)))

      expect(result).to include("verdict" => "failed", "reason" => "exited", "exit_code" => 3)
    end

    it "fails a child killed by a signal" do
      result = only_result(run_stub(%(puts '#{ok}'; $stdout.flush; Process.kill("KILL", Process.pid))))

      expect(result).to include("verdict" => "failed", "reason" => "signaled")
    end

    it "fails a stalled child at the wall deadline and reaps it" do
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = only_result(run_stub(%(sleep 30)))

      expect(result).to include("verdict" => "failed", "reason" => "timed_out", "observed_outcome" => nil)
      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 10
    end

    it "does not record success for a stalled child that printed the right outcome first" do
      result = only_result(run_stub(%(puts '#{ok}'; $stdout.flush; sleep 30)))

      expect(result).to include("verdict" => "failed", "reason" => "timed_out", "observed_outcome" => nil)
    end

    it "fails a child that exceeds the RSS ceiling" do
      code = %(hog = "x" * (200 * 1024 * 1024); hog.hash; puts '#{ok}'; $stdout.flush; sleep 30)
      result = only_result(run_stub(code, wall_seconds: 10))

      expect(result).to include("verdict" => "failed", "reason" => "rss_exceeded", "observed_outcome" => nil)
      expect(result.fetch("peak_rss_bytes")).to be > rss_limit
    end
  end

  describe "round trip verdicts" do
    it "fails a recovered fixture whose child reports a failed round trip" do
      result = only_result(run_stub(%(puts '{"outcome":"recovered","round_trip":"serialize_failed"}')))

      expect(result).to include("verdict" => "failed", "reason" => "serialize_failed", "round_trip" => "serialize_failed")
    end

    it "fails an observation with no round trip" do
      result = only_result(run_stub(%(puts '{"outcome":"recovered"}')))

      expect(result).to include("verdict" => "failed", "reason" => "missing_round_trip")
    end

    it "requires format_error fixtures to skip the round trip" do
      entry["outcome"] = "format_error"

      expect(only_result(run_stub(%(puts '{"outcome":"format_error","round_trip":"not_applicable"}'))))
        .to include("verdict" => "passed")
      expect(only_result(run_stub(%(puts '{"outcome":"format_error","round_trip":"ok"}'))))
        .to include("verdict" => "failed", "reason" => "ok")
    end
  end

  describe "fixture identity" do
    it "fails a child that mutates the fixture even when it reports success" do
      result = only_result(run_stub(%(File.binwrite(#{fixture_file.inspect}, "changed"); puts '#{ok}')))

      expect(result).to include("verdict" => "failed", "reason" => "fixture_mutated")
      expect(result.fetch("sha256_before")).not_to eq(result.fetch("sha256_after"))
    end

    it "fails a fixture that no longer matches its manifest sha256" do
      entry["sha256"] = "0" * 64

      expect(only_result(run_stub(%(puts '#{ok}')))).to include("verdict" => "failed", "reason" => "fixture_mismatch")
    end

    it "passes a fixture whose hash matches the manifest and is unchanged" do
      entry["sha256"] = Digest::SHA256.file(fixture_file).hexdigest

      expect(only_result(run_stub(%(puts '#{ok}')))).to include("verdict" => "passed")
    end

    it "fails a fixture that cannot be read" do
      FileUtils.rm(fixture_file)

      expect(only_result(run_stub(%(puts '#{ok}')))).to include("verdict" => "failed", "reason" => "fixture_unreadable")
    end
  end

  describe ".observe" do
    let(:corrupt) { described_class.entries(manifest, "corrupted") }

    def fixture_with(outcome)
      File.join(root, corrupt.find { |item| item["outcome"] == outcome }.fetch("path"))
    end

    def parsed_fixture
      File.join(root, "spec/fixtures/emf-corrupted/bad_corrupted_2014-12-02-215400.emf")
    end

    around do |example|
      previous = ENV.fetch("EMF_BACKEND", nil)
      ENV["EMF_BACKEND"] = "ruby"
      example.run
    ensure
      ENV["EMF_BACKEND"] = previous
    end

    it "round-trips a parsed fixture" do
      expect(described_class.observe(parsed_fixture)).to eq("outcome" => "parsed", "round_trip" => "ok")
    end

    it "skips the round trip for a format_error fixture" do
      expect(described_class.observe(fixture_with("format_error")))
        .to include("outcome" => "format_error", "round_trip" => "not_applicable")
    end

    it "reports a serialize failure" do
      allow(Emf).to receive(:serialize).and_raise(Emf::SerializeError, "boom")

      expect(described_class.observe(parsed_fixture))
        .to include("outcome" => "parsed", "round_trip" => "serialize_failed", "exception" => "Emf::SerializeError")
    end

    it "reports a reparse failure" do
      allow(Emf).to receive(:parse).and_call_original
      allow(Emf).to receive(:parse).with("rewritten").and_raise(Emf::FormatError, "bad")
      allow(Emf).to receive(:serialize).and_return("rewritten")

      expect(described_class.observe(parsed_fixture)).to include("round_trip" => "reparse_failed")
    end

    it "reports a reserialize failure" do
      calls = 0
      allow(Emf).to receive(:serialize) { (calls += 1) == 1 ? Emf::Backend.serialize(Emf.parse(File.binread(parsed_fixture))) : raise(Emf::SerializeError, "again") }

      expect(described_class.observe(parsed_fixture)).to include("round_trip" => "reserialize_failed")
    end

    it "reports serializations that differ after a reparse" do
      outputs = %w[first second].each
      allow(Emf).to receive(:serialize) { outputs.next }
      allow(Emf).to receive(:parse).and_call_original
      allow(Emf).to receive(:parse).with("first").and_return(Emf.parse(File.binread(parsed_fixture)))

      expect(described_class.observe(parsed_fixture)).to include("round_trip" => "not_idempotent")
    end
  end

  describe "report shape" do
    it "records the limits, platform and per-fixture measurements" do
      report = run_stub(%(puts '#{ok}'))

      expect(report).to include("schema_version" => 1, "backend" => "ruby", "ruby_version" => RUBY_VERSION,
                                "limits" => { "wall_seconds" => 1, "rss_limit_bytes" => rss_limit })
      expect(only_result(report).keys).to contain_exactly(
        "path", "verdict", "reason", "expected_outcome", "observed_outcome", "round_trip", "sha256_before",
        "sha256_after", "exception",
        "status", "exit_code", "signal", "elapsed_seconds", "peak_rss_bytes"
      )
    end
  end

  describe "script/native_resilience" do
    let(:script) { File.join(root, "script/native_resilience") }

    def run_script(*args)
      Open3.capture3(RbConfig.ruby, script, *args, chdir: root)
    end

    it "refuses to run without an RSS limit and exits 2" do
      _out, err, status = run_script("--backend", "ruby")

      expect(status.exitstatus).to eq(2)
      expect(err).to include("--rss-limit-mb")
    end

    it "exits 1 and writes a report when a fixture fails, with the pass/fail counts" do
      Dir.mktmpdir do |dir|
        report_path = File.join(dir, "nested/report.json")
        _out, err, status = run_script("--backend", "ruby", "--rss-limit-mb", "2048", "--wall-seconds", "30",
                                       "--manifest", stale_manifest(dir), "--report", report_path)
        report = JSON.parse(File.read(report_path))

        expect(status.exitstatus).to eq(1)
        expect(err).to include("FAILED spec/fixtures/emf-corrupted/")
        expect(report.fetch("totals")).to include("fixtures" => 3, "failed" => 3)
      end
    end

    it "exits 0 when every selected fixture matches its baseline" do
      Dir.mktmpdir do |dir|
        out, _err, status = run_script("--backend", "ruby", "--rss-limit-mb", "2048", "--wall-seconds", "30",
                                       "--manifest", matching_manifest(dir))

        expect(status.exitstatus).to eq(0)
        expect(out).to include("2/2 fixtures passed")
      end
    end

    def stale_manifest(dir)
      fixtures = described_class.entries(manifest, "corrupted").first(3).map { |item| item.merge("outcome" => "not_an_outcome") }
      write_manifest(dir, fixtures)
    end

    def matching_manifest(dir)
      corrupt = described_class.entries(manifest, "corrupted")
      chosen = [corrupt.find { |item| item["outcome"] == "format_error" },
                corrupt.find { |item| item["path"].end_with?("215400.emf") }]
      write_manifest(dir, chosen)
    end

    def write_manifest(dir, fixtures)
      File.join(dir, "manifest.json").tap { |path| File.write(path, JSON.generate("fixtures" => fixtures)) }
    end
  end

  describe "real native corpus" do
    it "parses every corrupt fixture under supervision" do
      library = ENV.fetch("EMF_NATIVE_LIBRARY", "")
      limit_mb = ENV.fetch("EMF_NATIVE_RSS_LIMIT_MB", nil)
      skip "EMF_NATIVE_LIBRARY is not set: the native library is not built here" if library.empty?
      skip "EMF_NATIVE_RSS_LIMIT_MB is not set: the ceiling must come from measuring the valid corpus" unless limit_mb

      runner = described_class::Runner.new(root: root, backend: "native", wall_seconds: 60,
                                           rss_limit_bytes: Integer(limit_mb) * 1024 * 1024)
      report = runner.call(described_class.entries(manifest, "corrupted"))

      expect(report.fetch("totals")).to include("fixtures" => 21, "failed" => 0)
    end
  end
end
