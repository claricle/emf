# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "rubygems/package"
require "tmpdir"
require "spec_helper"
require_relative "../../script/platform_probe/acceptance_report"

RSpec.describe PlatformAcceptance::Report do
  let(:target) { "aarch64-apple-darwin" }
  let(:platform) { "arm64-darwin" }
  let(:revision) { "b" * 40 }
  let(:metadata_target) { target }
  let(:real_revision) { revision }
  let(:real_steps) { %w[build_cdylib install_gem installed_workload availability_matrix] }
  let(:real_logs) { %w[build.log install.log] }
  let(:probe_logs) { %w[build.log linkage.txt] }
  let(:modes) { %w[auto native] }
  let(:report) { described_class.new(@tmp).call }
  let(:row) { report.fetch(:targets).find { |entry| entry[:target] == target }.fetch(:rubies).last }
  let(:load_record) do
    { intended_platform: platform, ruby_version: "3.4.8", fiddle_available: true, abi_version: 1, round_trip_ok: true, error: nil }
  end

  before do
    @tmp = Dir.mktmpdir("emf-acceptance-report")
    @directory = File.join(@tmp, "probe-#{target}-ruby3.4", "#{target}-ruby3.4")
    @real = File.join(@directory, "real")
    [@directory, @real].each do |directory|
      FileUtils.mkdir_p(directory)
      real = directory == @real
      lines = ["#{'real library: ' if real}target=#{target} intended_platform=#{platform} runner_os=local uname=Darwin arm64",
               "ruby=ruby 3.4.8 (revision local) [arm64-darwin]"]
      PlatformAcceptance::PACKAGE_STEPS.each do |step, log|
        lines << "#{step}=ok"
        File.write(File.join(directory, log), "#{step} succeeded\n")
      end
      if real
        real_steps.each { |step| lines << "#{step}=ok" }
        real_logs.each { |log| File.write(File.join(directory, log), "succeeded\n") }
      else
        lines.push("build=ok rustc 1.73.0", "linkage=ok libc")
        probe_logs.each { |log| File.write(File.join(directory, log), "succeeded\n") }
      end
      File.write(File.join(directory, "summary.txt"), "#{lines.join("\n")}\nresult=PASS\n")
      stage = File.join(directory, "stage")
      FileUtils.mkdir_p(File.join(stage, "lib/emf/native"))
      metadata = { platform: platform, target: metadata_target, revision: real ? real_revision : revision, gem_version: "0.1.2" }
      File.write(File.join(stage, "lib/emf/native/provenance.json"), JSON.generate(metadata))
      spec = Gem::Specification.new do |gem|
        gem.name = "emf"
        gem.version = "0.1.2"
        gem.summary = "test evidence"
        gem.authors = ["test"]
        gem.platform = platform
        gem.files = ["lib/emf/native/provenance.json"]
      end
      FileUtils.mkdir_p(File.join(directory, "package"))
      Dir.chdir(stage) do
        Gem::DefaultUserInteraction.use_ui(Gem::SilentUI.new) do
          built = Gem::Package.build(spec, true)
          FileUtils.mv(built, File.join(directory, "package", built))
        end
      end
    end
    File.write(File.join(@directory, "load-direct.jsonl"), "#{JSON.generate(load_record)}\n")
    resolution = { intended_platform: platform, installed_platform: platform, native_gem_selected: true, gem_install_ok: true }
    File.write(File.join(@directory, "platform-gem.jsonl"), "#{JSON.generate(resolution)}\n#{JSON.generate(load_record)}\n")
    File.write(File.join(@real, "workload.log"), <<~LOG)
      installed gem: emf-0.1.2-arm64-darwin /isolated/gems/emf
      discovery_without_env=works
      parsed: format=emf records=3
      dump: roundtrip_identical=true
      mutate: SetTextColor color.red 0 -> 171, reparse+reserialize identical
      ok
    LOG
    availability = PlatformAcceptance::AVAILABILITY.flat_map do |name|
      modes.map { |mode| "availability #{name}/#{mode}=native" }
    end
    File.write(File.join(@real, "availability.log"), "#{availability.join("\n")}\navailability matrix passed\n")
  end

  after { FileUtils.rm_rf(@tmp) }

  it "retains complete existing-format evidence and every proposed target/Ruby gap" do
    expect(row).to include(status: "PASS", revision: revision)
    expect(row.fetch(:checks).values.uniq).to eq(["PASS"])
    expect(report.fetch(:targets).size).to eq(8)
    expect(report.fetch(:targets).sum { |entry| entry[:rubies].size }).to eq(16)
    excluded = report.fetch(:targets).last.fetch(:rubies).first
    expect(excluded).to include(status: "OPEN", excluded: true, revision: nil)
    expect(excluded.fetch(:exclusion)).to include("unavailable")
  end

  it "keeps an absent real phase open despite a passing throwaway probe" do
    FileUtils.rm_rf(@real)
    expect(row).to include(status: "OPEN", revision: revision)
    expect(row.fetch(:checks)).to include("probe.direct_load" => "PASS", "real.forced_native_workload" => "OPEN")
  end

  it "keeps truncated workload and omitted dependency controls open despite PASS summaries" do
    File.write(File.join(@real, "workload.log"), "installed gem: emf-0.1.2-arm64-darwin /isolated\n")
    path = File.join(@real, "availability.log")
    File.write(path, File.read(path).lines.reject { |line| line.include?("missing_dependent_library/") }.join)
    expect(row.fetch(:status)).to eq("OPEN")
    expect(row.fetch(:checks)).to include("real.forced_native_workload" => "OPEN",
                                          "real.availability.missing_dependent_library/native" => "OPEN")
  end

  it "retains explicit blockers even when a stale PASS footer exists" do
    File.open(File.join(@real, "summary.txt"), "a") { |file| file.puts "BLOCKER install_smoke failed: missing Fiddle\nresult=PASS" }
    expect(row.fetch(:status)).to eq("FAILED")
    expect(row.fetch(:blockers).join).to include("missing Fiddle")
  end

  it "rejects duplicate row artifacts" do
    FileUtils.cp_r(File.dirname(@directory), File.join(@tmp, "duplicate"))
    expect { report }.to raise_error(ArgumentError, /duplicate row/)
  end

  it "rejects a directory label inconsistent with the summary" do
    FileUtils.mv(@directory, File.join(File.dirname(@directory), "x86_64-apple-darwin-ruby3.4"))
    expect { report }.to raise_error(ArgumentError, /mislabeled row/)
  end

  it "keeps absent revision metadata and truncated summaries open" do
    FileUtils.rm_rf(File.join(@real, "package"))
    path = File.join(@directory, "summary.txt")
    File.write(path, File.read(path).delete_suffix("result=PASS\n"))
    expect(row.fetch(:status)).to eq("OPEN")
    expect(row.fetch(:checks)).to include("probe.summary" => "OPEN", "real.revision" => "OPEN")
  end

  it "keeps invalid direct-load JSON open" do
    File.write(File.join(@directory, "load-direct.jsonl"), '{"round_trip_ok":')
    expect(row.fetch(:checks)).to include("probe.direct_load" => "OPEN")
    expect(row.fetch(:status)).to eq("OPEN")
  end

  it "emits useful JSON and text without interpreting missing rows as success" do
    script = File.expand_path("../../script/platform_probe/acceptance_report.rb", __dir__)
    json, err, status = Open3.capture3(RbConfig.ruby, script, @tmp, "--json")
    expect([status.exitstatus, err]).to eq([0, ""])
    expect(JSON.parse(json).fetch("targets").size).to eq(8)
    text, = Open3.capture3(RbConfig.ruby, script, @tmp)
    expect(text).to include("#{target} Ruby 3.4 PASS", "x86_64-unknown-linux-gnu Ruby 3.1 OPEN", "excluded")
  end

  context "with a package belonging to another target" do
    let(:metadata_target) { "x86_64-apple-darwin" }

    it "rejects mislabeled package provenance" do
      expect(row.fetch(:status)).to eq("FAILED")
      expect(report.fetch(:conflicts)).to include("real: package target/platform mismatch")
    end
  end

  context "with mixed package revisions" do
    let(:metadata_target) { target }
    let(:real_revision) { "c" * 40 }

    it "rejects mixing tested revisions and exits nonzero while retaining JSON evidence" do
      expect(row.fetch(:status)).to eq("FAILED")
      expect(report.fetch(:conflicts)).to include("mixed revisions within row", "mixed revisions across artifacts")
      expect(report.fetch(:revisions)).to contain_exactly(revision, real_revision)
      script = File.expand_path("../../script/platform_probe/acceptance_report.rb", __dir__)
      json, _err, status = Open3.capture3(RbConfig.ruby, script, @tmp, "--json")
      expect(status.exitstatus).to eq(1)
      expect(JSON.parse(json).fetch("conflicts")).to include("mixed revisions within row")
    end
  end
end
