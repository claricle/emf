# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require_relative "../../bench/support/emfsvg_comparison"

RSpec.describe EmfsvgComparison::CLI do
  let(:directory) { Dir.mktmpdir("emfsvg-comparison") }
  let(:ruby_path) { File.join(directory, "ruby.json") }
  let(:native_path) { File.join(directory, "native.json") }
  let(:output_path) { File.join(directory, "comparison.json") }
  let(:arguments) { ["--ruby", ruby_path, "--native", native_path, "--output", output_path] }
  let(:sha) { "a" * 64 }
  let(:validity) { { "golden_identical" => true, "svg_sha256" => sha, "svg_size_bytes" => 10 } }
  let(:worker) do
    { "status" => "ok", "validity" => validity,
      "resolved_sources" => { "emf" => "/parser/lib/emf.rb", "emfsvg" => "/consumer/lib/emfsvg.rb" },
      "gems" => { "bindata" => "2.5.1" } }
  end
  let(:stage) { { "samples_ns" => [10, 30], "summary_ns" => { "count" => 2, "median" => 20.0 }, "allocated_objects_median" => 4 } }
  let(:ruby_report) do
    {
      "schema_version" => 1, "kind" => "emfsvg-conversion-baseline", "backend" => "ruby", "failures" => [],
      "revision" => { "git_sha" => "b" * 40, "parser_source_sha256" => sha, "manifest_parser_source_sha256" => sha,
                      "manifest_matches_sources" => true, "git_tracked_changes" => " M bench/emfsvg.md" },
      "consumer" => { "git_sha" => "c" * 40, "source_sha256" => sha, "golden_spec_sha256" => sha,
                      "git_tracked_changes" => "", "path" => "/consumer",
                      "dependency_override" => "/parser/lib", "golden_spec" => "spec/golden_spec.rb" },
      "environment" => { "ruby" => %w[version engine description platform executable].to_h { |key| [key, "ruby"] },
                         "os" => %w[sysname nodename release version machine].to_h { |key| [key, "os"] },
                         "host" => "host", "gems" => { "bindata" => "2.5.1" } },
      "inputs" => { "manifest_sha256" => sha, "manifest_schema_version" => 2, "selected_outcomes" => ["parsed"],
                    "fixture_globs" => [], "fixture_limit" => nil, "fixture_count" => 1 },
      "method" => { "iterations" => 2, "warmups" => 0, "child_timeout_seconds" => 60,
                    "timing" => { "clock" => "monotonic", "unit" => "nanoseconds" },
                    "stages" => { "from_bytes" => "bytes", "from_file" => "file" }, "inseparable_boundaries" => [] }
        .merge(%w[gc_policy isolation file_io golden_policy dependencies].to_h { |key| [key, key] }),
      "fixtures" => [worker.merge("path" => "a.emf", "sha256" => sha, "size_bytes" => 10, "outcome" => "parsed",
                                  "stages" => { "from_bytes" => stage, "from_file" => Marshal.load(Marshal.dump(stage)) })],
      "golden_inventory" => [{ "fixture" => "a.emf", "path" => "a.svg", "sha256" => sha, "size_bytes" => 10 }],
      "cold_load" => { "fixture" => "a.emf", "runs" => [worker.merge("require_emfsvg_ns" => 10,
                                                                     "first_call" => %w[from_bytes from_file].to_h do |key|
                                                                       [key, { "ns" => 20, "allocated_objects" => 4 }]
                                                                     end)] }
    }
  end
  let(:native_report) do
    report = Marshal.load(Marshal.dump(ruby_report))
    report["backend"] = "native"
    report["native_library"] = { "sha256" => "d" * 64 }
    report["environment"]["gems"]["fiddle"] = "1.1.8"
    report["method"]["inseparable_boundaries"] = ["Ruby allocations exclude Rust allocations"]
    report["fixtures"][0]["stages"].each_value do |entry|
      entry["samples_ns"] = [20, 60]
      entry["summary_ns"]["median"] = 40.0
      entry["allocated_objects_median"] = 6
    end
    report
  end
  let(:write_reports) do
    File.write(ruby_path, JSON.generate(ruby_report))
    File.write(native_path, JSON.generate(native_report))
  end

  after { FileUtils.remove_entry(directory) }

  it "reports descriptive medians and ratios while preserving both input reports and tracked provenance" do
    write_reports
    before = [ruby_path, native_path].map { |path| File.binread(path) }
    expect(described_class.new(arguments).run).to eq(0)
    report = JSON.parse(File.read(output_path))
    expect(report).to include("status" => "informational", "native_library" => { "sha256" => "d" * 64 })
    expect(report.dig("fixtures", 0, "stages", "from_bytes")).to include("ruby_median_ns" => 20, "native_median_ns" => 40,
                                                                         "native_over_ruby_time" => 2.0,
                                                                         "native_over_ruby_allocated_objects" => 1.5)
    expect(report.dig("provenance", "revision", "git_tracked_changes")).to eq(" M bench/emfsvg.md")
    expect(report.dig("reports", "ruby", "sha256")).to eq(Digest::SHA256.hexdigest(before[0]))
    expect([ruby_path, native_path].map { |path| File.binread(path) }).to eq(before)
  end

  it "reports an undefined allocation ratio when the Ruby baseline is zero" do
    native_report
    ruby_report["fixtures"][0]["stages"]["from_bytes"]["allocated_objects_median"] = 0
    write_reports
    expect(described_class.new(arguments).run).to eq(0)
    entry = JSON.parse(File.read(output_path)).dig("fixtures", 0, "stages", "from_bytes")
    expect(entry).to include("native_over_ruby_allocated_objects" => nil, "allocation_ratio_reason" => /zero/)
  end

  it "preserves explicitly selected outcomes" do
    [ruby_report, native_report].each do |report|
      report["inputs"]["selected_outcomes"] = %w[parsed recovered]
      report["fixtures"][0]["outcome"] = "recovered"
    end
    write_reports
    expect(described_class.new(arguments).run).to eq(0)
    report = JSON.parse(File.read(output_path))
    expect(report.dig("fixtures", 0, "outcome")).to eq("recovered")
    expect(report.dig("provenance", "inputs", "selected_outcomes")).to eq(%w[parsed recovered])
  end

  {
    "unsupported schema" => ->(_ruby, native) { native["schema_version"] = 2 },
    "wrong backend" => ->(_ruby, native) { native["backend"] = "ruby" },
    "unverified sources" => ->(_ruby, native) { native["revision"]["manifest_matches_sources"] = false },
    "missing shared identity" => ->(ruby, native) { [ruby, native].each { |report| report["revision"].delete("git_sha") } },
    "missing parser digest" => ->(ruby, native) { [ruby, native].each { |report| report["revision"].delete("parser_source_sha256") } },
    "missing manifest selection" => ->(ruby, native) { [ruby, native].each { |report| report["inputs"].delete("fixture_limit") } },
    "unselected outcome" => lambda do |ruby, native|
      [ruby, native].each { |report| report["fixtures"][0]["outcome"] = "recovered" }
    end,
    "missing method control" => ->(ruby, native) { [ruby, native].each { |report| report["method"].delete("gc_policy") } },
    "noninteger count" => ->(_ruby, native) { native["fixtures"][0]["stages"]["from_bytes"]["summary_ns"]["count"] = 2.0 },
    "manifest mismatch" => ->(_ruby, native) { native["inputs"]["manifest_sha256"] = "e" * 64 },
    "method mismatch" => ->(_ruby, native) { native["method"]["warmups"] = 1 },
    "environment mismatch" => ->(_ruby, native) { native["environment"]["ruby"]["version"] = "different" },
    "gem mismatch" => ->(_ruby, native) { native["fixtures"][0]["gems"]["bindata"] = "different" },
    "fixture mismatch" => ->(_ruby, native) { native["fixtures"][0]["sha256"] = "e" * 64 },
    "dirty consumer" => ->(_ruby, native) { native["consumer"]["git_tracked_changes"] = " M lib/emfsvg.rb" },
    "missing library" => ->(_ruby, native) { native.delete("native_library") },
    "failed fixture" => ->(_ruby, native) { native["fixtures"][0]["status"] = "error" },
    "reported failure" => ->(_ruby, native) { native["failures"] = ["failure"] },
    "golden mismatch" => ->(_ruby, native) { native["fixtures"][0]["validity"]["golden_identical"] = false },
    "SVG digest mismatch" => ->(_ruby, native) { native["fixtures"][0]["validity"]["svg_sha256"] = "e" * 64 },
    "inventory mismatch" => ->(_ruby, native) { native["golden_inventory"][0]["path"] = "other.svg" },
    "cold failure" => ->(_ruby, native) { native["cold_load"]["runs"][0]["status"] = "error" },
    "cold golden drift" => ->(_ruby, native) { native["cold_load"]["runs"][0]["validity"] = { "golden_identical" => false } },
    "cold run count" => ->(_ruby, native) { native["cold_load"]["runs"] = [] },
    "invalid sample" => ->(_ruby, native) { native["fixtures"][0]["stages"]["from_bytes"]["samples_ns"][0] = 0 },
    "sample count" => ->(_ruby, native) { native["fixtures"][0]["stages"]["from_bytes"]["samples_ns"] = [40] },
    "fabricated median" => ->(_ruby, native) { native["fixtures"][0]["stages"]["from_bytes"]["summary_ns"]["median"] = 99 },
    "negative allocations" => ->(_ruby, native) { native["fixtures"][0]["stages"]["from_bytes"]["allocated_objects_median"] = -1 }
  }.each do |name, mutate|
    it "rejects #{name} without emitting ratios" do
      mutate.call(ruby_report, native_report)
      write_reports
      expect { expect(described_class.new(arguments).run).to eq(2) }.to output(/emfsvg comparison:/).to_stderr
      expect(File.exist?(output_path)).to be(false)
    end
  end

  %w[direct symlink hardlink].each do |alias_type|
    it "rejects a #{alias_type} output alias and preserves input bytes" do
      write_reports
      before = File.binread(ruby_path)
      case alias_type
      when "direct" then arguments[-1] = ruby_path
      when "symlink" then File.symlink(ruby_path, output_path)
      when "hardlink" then File.link(ruby_path, output_path)
      end
      expect { expect(described_class.new(arguments).run).to eq(2) }.to output(/must not overwrite/).to_stderr
      expect(File.binread(ruby_path)).to eq(before)
    end
  end

  it "rejects malformed JSON" do
    write_reports
    File.write(native_path, "{")
    expect { expect(described_class.new(arguments).run).to eq(2) }.to output(/emfsvg comparison:/).to_stderr
    expect(File.exist?(output_path)).to be(false)
  end
end
