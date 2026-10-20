# frozen_string_literal: true

# Offline evidence inventory, not build attestation or a support declaration.
# Usage: ruby script/platform_probe/acceptance_report.rb ARTIFACT_DIRECTORY [--json]
# Exit 0: report collected (OPEN rows are expected); exit 1: conflicting identity.
require "json"
require "optparse"
require "rubygems/package"
require "tmpdir"

module PlatformAcceptance
  TARGETS = {
    "x86_64-unknown-linux-gnu" => "x86_64-linux-gnu", "aarch64-unknown-linux-gnu" => "aarch64-linux-gnu",
    "x86_64-unknown-linux-musl" => "x86_64-linux-musl", "aarch64-unknown-linux-musl" => "aarch64-linux-musl",
    "x86_64-apple-darwin" => "x86_64-darwin", "aarch64-apple-darwin" => "arm64-darwin",
    "x86_64-pc-windows-gnu" => "x64-mingw-ucrt", "aarch64-pc-windows-gnullvm" => "aarch64-mingw-ucrt"
  }.freeze
  RUBIES = %w[3.1 3.4].freeze
  PACKAGE_STEPS = {
    "build_platform_gem" => "package-build-platform.log", "build_source_gem" => "package-build-source.log",
    "package_check" => "package-check.log", "fetch_dependency" => "package-fetch.log", "install_smoke" => "package-install.log"
  }.freeze
  AVAILABILITY = %w[working_library missing_library corrupt_library wrong_architecture missing_dependent_library
                    wrong_abi_version missing_fiddle malformed_garbage malformed_truncated library_not_configured
                    installed_checksum_mismatch installed_abi_mismatch
                    installed_platform_mismatch
                    installed_library_missing].freeze

  class Summary
    attr_reader :checks, :conflicts, :blockers

    def initialize(directory, name, target, platform, ruby)
      @directory = directory
      @name = name
      @target = target
      @platform = platform
      @ruby = ruby
      @checks = {}
      @conflicts = []
      @blockers = []
    end

    def call(prefix)
      text = read("summary.txt")
      headers = text.lines.grep(/^#{Regexp.escape(prefix)}/)
      versions = text.scan(/^ruby=ruby (\d+\.\d+)\./).flatten
      identity(headers, versions)
      @blockers.concat(text.lines.grep(/^BLOCKER /).map { |line| "#{@name}: #{line.strip}" })
      check("summary", headers.size == 1 && versions == [@ruby] && text.lines.last == "result=PASS\n")
      steps(text)
      text
    end

    private

    def read(path)
      absolute = File.join(@directory, path)
      File.file?(absolute) ? File.read(absolute) : ""
    end

    def check(name, passed) = @checks["#{@name}.#{name}"] = passed ? "PASS" : "OPEN"

    def identity(headers, versions)
      @conflicts << "#{@name}: duplicate or mislabeled summary" if headers.size > 1
      unless headers.empty?
        parsed = /target=(\S+) intended_platform=(\S+)/.match(headers.first)
        @conflicts << "#{@name}: target/platform mismatch" unless parsed && parsed.captures == [@target, @platform]
      end
      @conflicts << "#{@name}: Ruby mismatch" if versions.any? { |v| v != @ruby } || versions.size > 1
    end

    def steps(text)
      required = PACKAGE_STEPS.dup
      required["install_gem"] = "install.log" if @name == "real"
      required.each { |step, log| check(step, text.lines.include?("#{step}=ok\n") && !read(log).strip.empty?) }
      return unless @name == "real"

      check("installed_workload", text.lines.include?("installed_workload=ok\n"))
      check("availability_matrix", text.lines.include?("availability_matrix=ok\n"))
    end
  end

  module PackageMetadata
    def self.read(path)
      package = Gem::Package.new(path)
      Dir.mktmpdir("emf-probe-metadata") do |tmp|
        package.extract_files(tmp, "lib/emf/native/*.json")
        path = File.join(tmp, "lib/emf/native/provenance.json")
        return [package, nil] unless File.file?(path)

        provenance = JSON.parse(File.read(path))
        raise JSON::ParserError, "provenance is not an object" unless provenance.is_a?(Hash)

        [package, provenance]
      end
    end
  end

  module RealEvidence
    def self.checks(directory)
      workload = File.join(directory, "real/workload.log")
      log = File.file?(workload) ? File.read(workload) : ""
      checks = { "real.forced_native_workload" => workload_passes?(log) ? "PASS" : "OPEN" }
      availability = File.join(directory, "real/availability.log")
      log = File.file?(availability) ? File.read(availability) : ""
      checks["real.availability_result"] = log.lines.last == "availability matrix passed\n" && !log.include?("MISMATCH ") ? "PASS" : "OPEN"
      %w[auto native].each do |mode|
        AVAILABILITY.each do |name|
          checks["real.availability.#{name}/#{mode}"] = log.match?(%r{^availability #{name}/#{mode}=\S+}) ? "PASS" : "OPEN"
        end
      end
      checks
    end

    def self.workload_passes?(log)
      log.match?(/^installed gem: emf-/) && log.match?(/^parsed: format=.+ records=\d+$/) &&
        log.lines.include?("discovery_without_env=works\n") && log.lines.include?("dump: roundtrip_identical=true\n") &&
        log.match?(/^mutate: SetTextColor color.red \d+ -> \d+, reparse\+reserialize identical$/) && log.lines.last == "ok\n"
    end
  end

  class Row
    def initialize(directory, target, ruby, expected_revision = nil)
      @directory = directory
      @target = target
      @ruby = ruby
      @expected_revision = expected_revision
      @platform = TARGETS.fetch(target)
      @checks = {}
      @conflicts = []
      @blockers = []
    end

    def call
      probe = phase(@directory, "probe", "target=")
      real = phase(File.join(@directory, "real"), "real", "real library: target=")
      check("probe.build", probe.match?(/^build=ok .+/) && present?("build.log"))
      check("probe.linkage", probe.match?(/^linkage=ok .+/) && present?("linkage.txt"))
      check_loads
      check("real.build", real.lines.include?("build_cdylib=ok\n") && present?("real/build.log"))
      @checks.merge!(RealEvidence.checks(@directory))
      read_packages
      result
    end

    private

    def read(path) = File.file?(path) ? File.read(path) : ""
    def present?(path) = !read(File.join(@directory, path)).strip.empty?
    def check(name, passed) = @checks[name] = passed ? "PASS" : "OPEN"

    def phase(directory, name, prefix)
      summary = Summary.new(directory, name, @target, @platform, @ruby)
      text = summary.call(prefix)
      @checks.merge!(summary.checks)
      @conflicts.concat(summary.conflicts)
      @blockers.concat(summary.blockers)
      text
    end

    def json_lines(file)
      read(File.join(@directory, file)).lines.map { |line| JSON.parse(line) }
    rescue JSON::ParserError
      []
    end

    def load_ok?(record)
      record.is_a?(Hash) && record["intended_platform"] == @platform && record["ruby_version"].to_s.start_with?("#{@ruby}.") &&
        record["fiddle_available"] == true && record["abi_version"] == 1 && record["round_trip_ok"] == true && record["error"].nil?
    end

    def check_loads
      direct = json_lines("load-direct.jsonl")
      installed = json_lines("platform-gem.jsonl")
      resolution = installed.first.is_a?(Hash) ? installed.first : {}
      check("probe.direct_load", direct.size == 1 && load_ok?(direct.first))
      check("probe.gem_resolution", installed.size == 2 && resolution["intended_platform"] == @platform &&
        resolution["installed_platform"] == @platform && resolution["native_gem_selected"] == true && resolution["gem_install_ok"] == true)
      check("probe.installed_load", installed.size == 2 && load_ok?(installed.last))
    end

    def read_packages
      @revisions = %w[probe real].filter_map do |name|
        directory = name == "probe" ? @directory : File.join(@directory, "real")
        paths = Dir.glob(File.join(directory, "package/*.gem")).reject { |path| Gem::Package.new(path).spec.platform.to_s == "ruby" }
        @conflicts << "#{name}: duplicate platform packages" if paths.size > 1
        metadata = paths.size == 1 && package_metadata(paths.first, name)
        check("#{name}.revision", metadata && metadata.match?(/\A[0-9a-f]{40}\z/))
        metadata
      end
      @conflicts << "mixed revisions within row" if @revisions.uniq.size > 1
      @revision = @revisions.uniq.size == 1 ? @revisions.first : nil
      validate_expected_revisions
    rescue Gem::Package::Error, JSON::ParserError, Errno::ENOENT => e
      @blockers << "package metadata unreadable: #{e.message}"
    end

    def package_metadata(path, name)
      package, provenance = PackageMetadata.read(path)
      return unless provenance

      identity = [package.spec.name, package.spec.platform.to_s, provenance["platform"], provenance["target"]]
      @conflicts << "#{name}: package target/platform mismatch" unless identity == ["emf", @platform, @platform, @target]
      @conflicts << "#{name}: package version mismatch" unless provenance["gem_version"] == package.spec.version.to_s
      provenance["revision"] if provenance["revision"].is_a?(String)
    end

    def validate_expected_revisions
      return unless @expected_revision

      @revisions.compact.uniq.each do |actual|
        next if actual == @expected_revision

        @conflicts << "revision mismatch: expected #{@expected_revision}, actual #{actual}"
      end
    end

    def result
      status = @checks.value?("OPEN") ? "OPEN" : "PASS"
      status = "FAILED" unless @conflicts.empty? && @blockers.empty?
      { ruby: @ruby, revision: @revision, package_revisions: @revisions || [], status: status,
        artifact: @directory, checks: @checks,
        blockers: @blockers, conflicts: @conflicts }
    end
  end

  class Report
    def initialize(directory, revision: nil)
      raise ArgumentError, "revision must be a full lowercase 40-character SHA" if revision && !revision.match?(/\A[0-9a-f]{40}\z/)

      @directory = File.expand_path(directory)
      @expected_revision = revision
    end

    def call
      rows = inventory
      conflicts = rows.values.flat_map { |row| row.fetch(:conflicts, []) }
      revisions = rows.values.flat_map { |row| row.fetch(:package_revisions, []) }.uniq
      conflicts << "mixed revisions across artifacts" if revisions.size > 1
      matrix = targets(rows)
      failed = matrix.any? { |target| target[:rubies].any? { |row| row[:status] == "FAILED" } }
      { schema_version: 1, status: conflicts.empty? && !failed ? "OPEN" : "FAILED",
        scope: "Observed probe evidence only; no build attestation or platform support claim",
        revisions: revisions.sort, conflicts: conflicts, targets: matrix }
    end

    private

    def inventory
      rows = {}
      Dir.glob(File.join(@directory, "**/summary.txt")).each do |summary|
        directory = File.dirname(summary)
        if File.basename(directory) == "real"
          directory = File.dirname(directory)
          next if File.file?(File.join(directory, "summary.txt"))
        end

        text = File.read(summary)
        key = identity(summary, text)
        next unless key

        raise ArgumentError, "duplicate row #{key.join('/')}" if rows.key?(key)

        target, ruby = key
        rows[key] = Row.new(directory, target, ruby, @expected_revision).call
      end
      rows
    end

    def identity(summary, text)
      target = text[/^(?:real library: )?target=(\S+)/, 1]
      return unless target # Unrelated summaries are not probe rows.

      ruby = text[/^ruby=ruby (\d+\.\d+)\./, 1] || summary[%r{ruby(3\.[14])(?:/|$)}, 1]
      raise ArgumentError, "unknown target/Ruby in #{summary}" unless TARGETS.key?(target) && RUBIES.include?(ruby)

      key = [target, ruby]
      labels = summary.scan(%r{(?:probe-)?([a-z0-9_]+-(?:unknown|apple|pc)-[a-z0-9-]+)-ruby(3\.[14])(?:/|$)})
      raise ArgumentError, "mislabeled row #{summary}" if labels.any? { |label| label != key }

      key
    end

    def targets(rows)
      TARGETS.map do |target, platform|
        { target: target, platform: platform, rubies: RUBIES.map do |ruby|
          excluded = target == "aarch64-pc-windows-gnullvm" && ruby == "3.1"
          row = rows.fetch([target, ruby]) { { ruby: ruby, revision: nil, status: "OPEN", checks: {}, blockers: ["artifact missing"] } }
          row = row.merge(status: "OPEN") if excluded && row[:status] == "PASS"
          reason = "ruby/setup-ruby Windows ARM64 Ruby 3.1 unavailable; acceptance remains open" if excluded
          row.merge(excluded: excluded, exclusion: reason)
        end }
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  options = {}
  parser = OptionParser.new do |o|
    o.on("--json") { options[:json] = true }
    o.on("--revision FULL_SHA") { |value| options[:revision] = value }
  end
  parser.parse!
  usage = "usage: ruby #{$PROGRAM_NAME} ARTIFACT_DIRECTORY [--revision FULL_SHA] [--json]"
  abort usage unless ARGV.size == 1 && File.directory?(ARGV.first)
  begin
    report = PlatformAcceptance::Report.new(ARGV.first, revision: options[:revision]).call
    if options[:json]
      puts JSON.pretty_generate(report)
    else
      puts report[:scope]
      report[:targets].each do |target|
        target[:rubies].each do |row|
          label = "#{target[:target]} Ruby #{row[:ruby]} #{row[:status]}"
          puts "#{label} revision=#{row[:revision] || 'unknown'}#{' excluded' if row[:excluded]}"
        end
      end
      report[:conflicts].each { |conflict| warn conflict }
    end
    exit(report[:status] == "FAILED" ? 1 : 0)
  rescue ArgumentError => e
    warn e.message
    exit 1
  end
end
