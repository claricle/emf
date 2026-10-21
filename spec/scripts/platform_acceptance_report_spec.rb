# frozen_string_literal: true

require "fileutils"
require "json"
require "rubygems/package"
require "stringio"
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
  let(:emf_workload) do
    <<~LOG
      installed gem: emf-0.1.2-arm64-darwin /isolated/gems/emf
      discovery_without_env=works
      parsed: format=emf records=3
      dump: roundtrip_identical=true
      mutate: SetTextColor color.red 0 -> 171, reparse+reserialize identical
    LOG
  end
  let(:workload) do
    wmf = %w[standard placeable].map do |kind|
      <<~LOG
        parsed: format=wmf kind=#{kind} records=2
        dump: wmf #{kind} roundtrip_identical=true
        mutate: wmf #{kind} MoveTo x 7 -> -123, reparse+reserialize identical
      LOG
    end.join
    "#{emf_workload}#{wmf}ok\n"
  end
  let(:contract) { SourceReleaseGemBuilder.metadata(revision) }
  let(:native_metadata) do
    { "platform" => platform, "target" => metadata_target, "revision" => revision, "gem_version" => "0.1.2",
      "cargo_lock_sha256" => contract.fetch("emf_cargo_lock_sha256"), "crate_version" => contract.fetch("emf_crate_version") }
  end
  let(:source_metadata) { contract.dup }
  let(:source_spec) do
    double(name: "emf", platform: "ruby", version: Gem::Version.new("0.1.2"), metadata: source_metadata)
  end
  let(:real_source_spec) do
    double(name: "emf", platform: "ruby", version: source_spec.version,
           metadata: source_metadata.merge("emf_revision" => real_revision))
  end
  let(:source_package) { double(spec: source_spec) }
  let(:real_source_package) { double(spec: real_source_spec) }
  let(:run_cli) do
    lambda do |*arguments|
      script = File.expand_path("../../script/platform_probe/acceptance_report.rb", __dir__)
      original_program_name = $PROGRAM_NAME
      original_arguments = ARGV.dup
      original_stdout = $stdout
      original_stderr = $stderr
      original_verbose = $VERBOSE
      output = StringIO.new
      errors = StringIO.new
      status = nil
      begin
        allow(Gem::Package).to receive(:new) do |path|
          @cli_package_path = path
          if File.basename(path).include?("source")
            path.include?("/real/") ? real_source_package : source_package
          else
            package
          end
        end
        allow(package).to receive(:extract_files) do |directory, _pattern|
          FileUtils.mkdir_p(File.join(directory, "lib/emf/native"))
          metadata_revision = @cli_package_path.include?("/real/") ? real_revision : revision
          provenance = native_metadata.merge("revision" => metadata_revision)
          File.write(File.join(directory, "lib/emf/native/provenance.json"), JSON.generate(provenance))
        end
        $0 = script
        ARGV.replace(arguments)
        $stdout = output
        $stderr = errors
        $VERBOSE = false
        load script
      rescue SystemExit => e
        status = e.status
      ensure
        $0 = original_program_name
        ARGV.replace(original_arguments)
        $stdout = original_stdout
        $stderr = original_stderr
        $VERBOSE = original_verbose
      end
      clean_errors = errors.string.lines.reject do |line|
        line.include?("warning: already initialized constant") || line.include?("warning: previous definition")
      end.join
      [status, output.string, clean_errors]
    end
  end
  let(:package_spec) { double(name: "emf", platform: platform, version: Gem::Version.new("0.1.2")) }
  let(:package) { double(spec: package_spec) }
  let(:row) { report.fetch(:targets).find { |entry| entry[:target] == target }.fetch(:rubies).last }
  let(:load_record) do
    { intended_platform: platform, ruby_version: "3.4.8", fiddle_available: true, abi_version: 1, round_trip_ok: true, error: nil }
  end

  before do
    allow(PlatformAcceptance::PackageMetadata).to receive(:read) do |path|
      metadata_revision = path.include?("/real/") ? real_revision : revision
      [package, native_metadata.merge("revision" => metadata_revision)]
    end
    allow(Gem::Package).to receive(:new) do |path|
      if File.basename(path).include?("source")
        path.include?("/real/") ? real_source_package : source_package
      else
        package
      end
    end
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
      FileUtils.mkdir_p(File.join(directory, "package"))
      File.write(File.join(directory, "package", "fixture.gem"), "stub package path\n")
      File.write(File.join(directory, "package", "source.gem"), "stub source package path\n")
    end
    File.write(File.join(@directory, "load-direct.jsonl"), "#{JSON.generate(load_record)}\n")
    resolution = { intended_platform: platform, installed_platform: platform, native_gem_selected: true, gem_install_ok: true }
    File.write(File.join(@directory, "platform-gem.jsonl"), "#{JSON.generate(resolution)}\n#{JSON.generate(load_record)}\n")
    File.write(File.join(@real, "workload.log"), workload)
    availability = PlatformAcceptance::AVAILABILITY.flat_map do |name|
      modes.map { |mode| "availability #{name}/#{mode}=native" }
    end
    File.write(File.join(@real, "availability.log"), "#{availability.join("\n")}\navailability matrix passed\n")
  end

  after { FileUtils.rm_rf(@tmp) }

  it "retains complete EMF and both WMF workload evidence and every proposed target/Ruby gap" do
    expect(row).to include(status: "PASS", revision: revision)
    expect(row.fetch(:checks).values.uniq).to eq(["PASS"])
    expect(report.fetch(:targets).size).to eq(8)
    expect(report.fetch(:targets).sum { |entry| entry[:rubies].size }).to eq(16)
    excluded = report.fetch(:targets).last.fetch(:rubies).first
    expect(excluded).to include(status: "OPEN", excluded: true, revision: nil)
    expect(excluded.fetch(:exclusion)).to include("unavailable")
  end

  it "accepts an EMF+ installed fixture alongside both WMF workloads" do
    File.write(File.join(@real, "workload.log"), workload.sub("format=emf records=", "format=emf_plus records="))
    expect(row.fetch(:status)).to eq("PASS")
  end

  %w[probe real].each do |phase|
    context "with #{phase} source/native package evidence" do
      let(:phase_directory) { phase == "probe" ? @directory : @real }
      let(:phase_source_spec) { phase == "probe" ? source_spec : real_source_spec }

      it "keeps a missing source package open without losing the observed native revision" do
        FileUtils.rm(File.join(phase_directory, "package/source.gem"))
        expect(row).to include(status: "OPEN", revision: revision)
        expect(row.fetch(:checks)).to include("#{phase}.source_package" => "OPEN")
        expect(row.fetch(:conflicts)).to be_empty
      end

      it "rejects duplicate source packages" do
        File.write(File.join(phase_directory, "package/duplicate-source.gem"), "stub source duplicate")
        expect(row.fetch(:status)).to eq("FAILED")
        expect(row.fetch(:conflicts)).to include("#{phase}: duplicate source packages")
      end

      it "rejects duplicate native packages" do
        File.write(File.join(phase_directory, "package/duplicate.gem"), "stub native duplicate")
        expect(row.fetch(:status)).to eq("FAILED")
        expect(row.fetch(:conflicts)).to include("#{phase}: duplicate platform packages")
      end

      it "rejects a source revision differing from the native artifact" do
        allow(phase_source_spec).to receive(:metadata).and_return(contract.merge("emf_revision" => "d" * 40))
        expect(row.fetch(:status)).to eq("FAILED")
        expect(report.fetch(:revisions)).to contain_exactly(revision, "d" * 40)
        expect(report.fetch(:conflicts)).to include("mixed revisions within row")
      end

      it "keeps missing source revision metadata open" do
        allow(phase_source_spec).to receive(:metadata).and_return(contract.except("emf_revision"))
        expect(row.fetch(:status)).to eq("OPEN")
        expect(row.fetch(:conflicts)).to be_empty
      end

      it "rejects a source version differing from the platform package" do
        allow(phase_source_spec).to receive(:version).and_return(Gem::Version.new("9.9.9"))
        expect(row.fetch(:status)).to eq("FAILED")
        expect(row.fetch(:conflicts).join).to include("#{phase}: source/native version mismatch")
      end
    end
  end

  { "emf_cargo_lock_sha256" => "0" * 64, "emf_crate_version" => "999.0.0" }.each do |field, wrong|
    context "with stale source #{field}" do
      before { source_metadata[field] = wrong }

      it "rejects the source contract even when its revision matches" do
        expect(row.fetch(:status)).to eq("FAILED")
        expect(row.fetch(:conflicts).join).to include(field)
      end
    end

    context "without source #{field}" do
      before { source_metadata.delete(field) }

      it "keeps the missing source contract open" do
        expect(row.fetch(:status)).to eq("OPEN")
        expect(row.fetch(:conflicts)).to be_empty
      end
    end
  end

  { "cargo_lock_sha256" => "0" * 64, "crate_version" => "999.0.0" }.each do |field, wrong|
    context "with stale native #{field}" do
      before { native_metadata[field] = wrong }

      it "rejects the native contract even when its revision matches" do
        expect(row.fetch(:status)).to eq("FAILED")
        expect(row.fetch(:conflicts).join).to include(field)
      end
    end
  end

  it "keeps absent native provenance open" do
    allow(PlatformAcceptance::PackageMetadata).to receive(:read).and_return([package, nil])
    expect(row).to include(status: "OPEN", revision: revision)
    expect(row.fetch(:checks)).to include("real.revision" => "OPEN", "real.native_contract" => "OPEN")
    expect(row.fetch(:conflicts)).to be_empty
  end

  %w[cargo_lock_sha256 crate_version gem_version revision].each do |field|
    it "keeps missing native #{field} evidence open" do
      allow(PlatformAcceptance::PackageMetadata).to receive(:read).and_return([package, native_metadata.except(field)])
      expect(row.fetch(:status)).to eq("OPEN")
      expect(row.fetch(:conflicts)).to be_empty
    end
  end

  it "rejects malformed recorded revisions rather than treating them as absent" do
    source_metadata["emf_revision"] = "not-a-sha"
    expect(row.fetch(:status)).to eq("FAILED")
    expect(row.fetch(:conflicts).join).to include("invalid package revision")
  end

  it "rejects native versions conflicting with their provenance" do
    native_metadata["gem_version"] = "9.9.9"
    expect(row.fetch(:status)).to eq("FAILED")
    expect(row.fetch(:conflicts).join).to include("package version mismatch")
  end

  it "accepts a consistent declared gem version across the pair" do
    allow(package_spec).to receive(:version).and_return(Gem::Version.new("9.9.9"))
    allow(source_spec).to receive(:version).and_return(Gem::Version.new("9.9.9"))
    native_metadata["gem_version"] = "9.9.9"
    expect(row.fetch(:status)).to eq("PASS")
  end

  it "keeps the old EMF-only installed workload open" do
    File.write(File.join(@real, "workload.log"), "#{emf_workload}ok\n")
    expect(row.fetch(:status)).to eq("OPEN")
    expect(row.fetch(:checks)).to include("real.forced_native_workload" => "OPEN", "real.installed_workload" => "PASS")
    expect(row.fetch(:conflicts)).to be_empty
    expect(row.fetch(:revision)).to eq(revision)
  end

  %w[standard placeable].product(%w[parsed dump mutate], %w[missing failed]).each do |kind, phase, condition|
    it "keeps #{kind} WMF #{phase} #{condition} evidence open despite passing summaries" do
      lines = workload.lines.map do |line|
        next line unless line.start_with?("#{phase}:") && line.include?(kind)

        condition == "missing" ? "" : "#{phase}: wmf #{kind} failed\n"
      end
      File.write(File.join(@real, "workload.log"), lines.join)
      expect(row.fetch(:status)).to eq("OPEN")
      expect(row.fetch(:checks)).to include("real.forced_native_workload" => "OPEN", "real.summary" => "PASS")
      expect(row.fetch(:conflicts)).to be_empty
    end
  end

  %w[parsed dump mutate].each do |phase|
    it "requires the EMF #{phase} evidence alongside both WMF workloads" do
      lines = workload.lines.reject { |line| line.start_with?("#{phase}:") && !line.include?("wmf") }
      File.write(File.join(@real, "workload.log"), lines.join)
      expect(row.fetch(:status)).to eq("OPEN")
      expect(row.fetch(:checks)).to include("real.forced_native_workload" => "OPEN")
    end
  end

  it "keeps an absent real phase open despite a passing throwaway probe" do
    FileUtils.rm_rf(@real)
    expect(row).to include(status: "OPEN", revision: revision)
    expect(row.fetch(:checks)).to include("probe.direct_load" => "PASS", "real.forced_native_workload" => "OPEN")
  end

  it "passes when the requested revision matches every known artifact revision" do
    matching = described_class.new(@tmp, revision: revision).call
    matching_row = matching.fetch(:targets).find { |entry| entry[:target] == target }.fetch(:rubies).last
    expect(matching_row).to include(status: "PASS", revision: revision)
    expect(matching.fetch(:conflicts)).to be_empty
  end

  it "fails a uniformly stale revision with expected and actual identities in JSON" do
    stale = "c" * 40
    stale_report = described_class.new(@tmp, revision: stale).call
    parsed = JSON.parse(JSON.pretty_generate(stale_report))
    expect(parsed.fetch("conflicts")).to include("revision mismatch: expected #{stale}, actual #{revision}")
    expect(parsed.fetch("status")).to eq("FAILED")
  end

  it "rejects malformed expected revisions before scanning inventory" do
    expect { described_class.new("/missing/inventory", revision: "not-a-sha") }
      .to raise_error(ArgumentError, /full lowercase 40-character SHA/)
  end

  it "returns JSON and success exit status for matching and unspecified revisions" do
    matching_status, matching_output, matching_errors = run_cli.call(@tmp, "--revision", revision, "--json")
    expect([matching_status, matching_errors]).to eq([0, ""])
    expect(JSON.parse(matching_output).fetch("conflicts")).to be_empty

    default_status, default_output, default_errors = run_cli.call(@tmp, "--json")
    expect([default_status, default_errors]).to eq([0, ""])
    expect(JSON.parse(default_output).fetch("status")).to eq("OPEN")
  end

  it "returns JSON conflicts and failure exit status for a stale revision" do
    stale = "c" * 40
    status, output, errors = run_cli.call(@tmp, "--revision", stale, "--json")
    expect([status, errors]).to eq([1, ""])
    expect(JSON.parse(output).fetch("conflicts")).to include("revision mismatch: expected #{stale}, actual #{revision}")
  end

  it "rejects a malformed revision through the CLI before inventory collection" do
    status, output, errors = run_cli.call(@tmp, "--revision", "not-a-sha", "--json")
    expect(status).to eq(1)
    expect(output).to be_empty
    expect(errors).to include("revision must be a full lowercase 40-character SHA")
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
    expected = described_class.new(@tmp, revision: revision).call
    expected_row = expected.fetch(:targets).find { |entry| entry[:target] == target }.fetch(:rubies).last
    expect(expected_row.fetch(:status)).to eq("OPEN")
    expect(expected_row.fetch(:revision)).to eq(revision)
    expect(row.fetch(:status)).to eq("OPEN")
    expect(row.fetch(:checks)).to include("probe.summary" => "OPEN", "real.revision" => "OPEN")
  end

  it "keeps invalid direct-load JSON open" do
    File.write(File.join(@directory, "load-direct.jsonl"), '{"round_trip_ok":')
    expect(row.fetch(:checks)).to include("probe.direct_load" => "OPEN")
    expect(row.fetch(:status)).to eq("OPEN")
  end

  it "emits useful JSON and text without interpreting missing rows as success" do
    serialized = JSON.parse(JSON.pretty_generate(report))
    expect(serialized.fetch("targets").size).to eq(8)
    expect(report.fetch(:targets).find { |entry| entry[:target] == target }.fetch(:rubies).last)
      .to include(status: "PASS", revision: revision)
    expect(report.fetch(:targets).first.fetch(:rubies).first).to include(status: "OPEN", excluded: false)
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
      json = JSON.parse(JSON.pretty_generate(report))
      expect(json.fetch("conflicts")).to include("mixed revisions within row")
    end
  end
end
