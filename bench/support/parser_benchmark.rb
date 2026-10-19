# frozen_string_literal: true

require "English"
require "digest"
require "etc"
require "fileutils"
require "json"
require "optparse"
require "rbconfig"
require "time"

# Stage timing baseline for the Ruby parser. The parent process never parses a
# fixture: every fixture runs in its own child with an external deadline and a
# bounded output pipe, so a corrupt input cannot crash or hang the benchmark.
# Workers must not load `emf` (or bindata) before timing starts, because the
# cold-load measurement includes those requires.
module ParserBenchmark
  SCHEMA_VERSION = 1
  SUPPORTED_BACKENDS = %w[ruby].freeze
  ROOT = File.expand_path("../..", __dir__)
  SCRIPT = File.join(ROOT, "bench/parser.rb")
  SLOWEST_STAGE = "parse_to_serialize"

  STAGES = {
    "detect_format" => "Emf.detect_format(bytes)",
    "parse" => "Emf.parse(bytes): detection, header wire read, per-record wire reads, WireAdapter creation, Metafile construction",
    "wire_first_traversal" => "snapshot of every record wire on a freshly parsed metafile",
    "wire_repeated_traversal" => "the same snapshot traversal repeated on the same metafile",
    "dump" => "Emf::Visitors::Dump over the parsed metafile, rendered to a string",
    "serialize" => "Emf.serialize(metafile) of the parsed metafile",
    "parse_to_serialize" => "Emf.serialize(Emf.parse(bytes)) as one region",
    "parse_file" => "Emf.parse_file(path): includes the file read"
  }.freeze

  INSEPARABLE_BOUNDARIES = [
    "Wire parsing and model creation are interleaved in Emf::Emr::Parser.call: each loop turn reads a record " \
    "wire, builds its WireAdapter and may extract EMF+ bytes before the next read. No boundary exists to time " \
    "them apart without reimplementing the parser, so only the combined `parse` stage is reported.",
    "Emf.parse runs format detection twice (Emf.parse and Emr::Parser.call); the `parse` stage includes both, " \
    "so `detect_format` is a component of `parse`, not an addend.",
    "BinData reads each record eagerly inside `parse`; the traversal stages measure snapshotting already-read " \
    "wires, not first-time byte decoding."
  ].freeze

  class UsageError < StandardError; end

  module Clock
    module_function

    def now
      Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
    end
  end

  module Stats
    module_function

    def summarize(samples)
      sorted = samples.sort
      {
        "count" => sorted.size, "min" => sorted.first, "median" => median(sorted),
        "p95" => sorted[((sorted.size * 0.95).ceil - 1).clamp(0, sorted.size - 1)],
        "mean" => (sorted.sum.to_f / sorted.size).round(1), "max" => sorted.last
      }
    end

    def median(sorted)
      mid = sorted.size / 2
      sorted.size.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0
    end
  end

  # Process memory: /proc gives a true high-water mark on Linux; elsewhere
  # `ps` gives only the current RSS, so the peak is the largest sample taken
  # between timed regions and can miss short spikes.
  module Memory
    module_function

    def method_name
      File.readable?("/proc/self/status") ? "proc_status_vmrss_vmhwm" : "ps_rss_sampled_between_regions"
    end

    def description
      { "method" => method_name,
        "limitations" => "RSS is per child process. Without /proc the peak is the largest RSS sampled between timed " \
                         "trials and can miss short spikes; allocated_objects is a Ruby object count, not bytes." }
    end

    def sample
      return proc_sample if File.readable?("/proc/self/status")

      rss = IO.popen(["ps", "-o", "rss=", "-p", Process.pid.to_s], err: File::NULL, &:read).to_i
      { "rss_kb" => rss.positive? ? rss : nil }
    rescue SystemCallError
      { "rss_kb" => nil }
    end

    def proc_sample
      status = File.read("/proc/self/status")
      { "rss_kb" => status[/^VmRSS:\s+(\d+)/, 1]&.to_i, "peak_rss_kb" => status[/^VmHWM:\s+(\d+)/, 1]&.to_i }
    end
  end

  class InputMismatch < StandardError; end

  # Runs in a fresh child with a warm process: untimed warmups, then timed trials.
  class WarmWorker
    def initialize(path:, sha256:, iterations:, warmups:)
      @path = path
      @sha256 = sha256
      @iterations = iterations
      @warmups = warmups
    end

    def call
      require "emf"
      @bytes = File.binread(@path)
      raise InputMismatch, "sha256 differs from the manifest" unless Digest::SHA256.hexdigest(@bytes) == @sha256

      result = { "status" => "ok", "validity" => validity }
      @warmups.times { trial }
      memory = [Memory.sample]
      samples = Array.new(@iterations) { trial.tap { memory << Memory.sample } }
      result.merge("stages" => collect(samples), "memory" => memory_report(memory))
    rescue StandardError => e
      { "status" => "error", "error" => { "class" => e.class.name, "message" => e.message.byteslice(0, 2048).scrub } }
    end

    private

    def validity
      metafile = Emf.parse(@bytes)
      { "record_count" => metafile.records.size, "parse_error_count" => metafile.errors.size,
        "format" => metafile.format.to_s, "round_trip_identical" => Emf.serialize(metafile) == @bytes }
    end

    def trial
      results = {}
      measure(results, "detect_format") { Emf.detect_format(@bytes) }
      metafile = measure(results, "parse") { Emf.parse(@bytes) }
      2.times { |pass| measure(results, pass.zero? ? "wire_first_traversal" : "wire_repeated_traversal") { traverse(metafile) } }
      measure(results, "dump") { Emf::Visitors::Dump.new.visit_all(metafile).to_s }
      measure(results, "serialize") { Emf.serialize(metafile) }
      measure(results, "parse_to_serialize") { Emf.serialize(Emf.parse(@bytes)) }
      measure(results, "parse_file") { Emf.parse_file(@path) }
      results
    end

    def measure(results, stage)
      GC.start
      before = GC.stat(:total_allocated_objects)
      started = Clock.now
      value = yield
      elapsed = Clock.now - started
      results[stage] = { "ns" => elapsed, "allocated_objects" => GC.stat(:total_allocated_objects) - before }
      value
    end

    def traverse(metafile)
      metafile.records.each { |record| record.wire.snapshot }
    end

    def collect(samples)
      STAGES.keys.to_h do |stage|
        [stage, { "samples_ns" => samples.map { |s| s.fetch(stage).fetch("ns") },
                  "allocated_objects" => samples.map { |s| s.fetch(stage).fetch("allocated_objects") } }]
      end
    end

    def memory_report(samples)
      rss = samples.filter_map { |s| s["rss_kb"] }
      peaks = samples.filter_map { |s| s["peak_rss_kb"] }
      { "method" => Memory.method_name, "rss_kb_before" => rss.first, "rss_kb_after" => rss.last,
        "peak_rss_kb" => peaks.max || rss.max }
    end
  end

  # Runs in a fresh child before anything is loaded: require cost plus the
  # first (autoload-heavy) calls of one fixture.
  class ColdWorker
    def initialize(path:)
      @path = path
    end

    def call
      loaded = time { require "emf" }
      bytes = File.binread(@path)
      detect = time { Emf.detect_format(bytes) }
      parse = time { @metafile = Emf.parse(bytes) }
      serialize = time { Emf.serialize(@metafile) }
      { "status" => "ok", "require_emf_ns" => loaded, "first_detect_format_ns" => detect, "first_parse_ns" => parse,
        "first_serialize_ns" => serialize, "emf_loaded_from" => Emf.method(:parse).source_location.first,
        "rss_kb_after" => Memory.sample["rss_kb"] }
    rescue StandardError => e
      { "status" => "error", "error" => { "class" => e.class.name, "message" => e.message.byteslice(0, 2048).scrub } }
    end

    private

    def time
      started = Clock.now
      yield
      Clock.now - started
    end
  end

  Options = Struct.new(:manifest, :backend, :output, :iterations, :warmups, :timeout, :fixtures, :limit, :outcomes,
                       :cold_runs, :worker, :sha256, :path, keyword_init: true)

  class CLI
    DEFAULTS = { backend: "ruby", iterations: 20, warmups: 5, timeout: 120, fixtures: [], outcomes: %w[parsed], cold_runs: 3 }.freeze

    def initialize(argv)
      @argv = argv.dup
    end

    def run
      options = parse(@argv)
      options.worker ? run_worker(options) : Run.new(options, @argv).run
    rescue UsageError, OptionParser::ParseError => e
      warn "bench/parser.rb: #{e.message}"
      2
    end

    private

    def parse(argv)
      options = Options.new(**DEFAULTS)
      rest = parser(options).parse(argv)
      options.worker ? options.tap { options.path = rest.fetch(0) { raise UsageError, "worker needs a path" } } : validate(options, rest)
    end

    def validate(options, rest)
      raise UsageError, "unexpected arguments: #{rest.join(' ')}" unless rest.empty?
      raise UsageError, "--manifest is required" unless options.manifest
      raise UsageError, "--output is required" unless options.output
      unless SUPPORTED_BACKENDS.include?(options.backend)
        raise UsageError, "unsupported backend #{options.backend.inspect} (supported: #{SUPPORTED_BACKENDS.join(', ')})"
      end

      check_positive(options)
      options
    end

    def check_positive(options)
      { "--iterations" => options.iterations, "--timeout" => options.timeout }.each do |name, value|
        raise UsageError, "#{name} must be a positive integer" unless value.is_a?(Integer) && value.positive?
      end
      raise UsageError, "--warmups must be >= 0" unless options.warmups.is_a?(Integer) && options.warmups >= 0
      raise UsageError, "--cold-runs must be >= 0" unless options.cold_runs.is_a?(Integer) && options.cold_runs >= 0
      raise UsageError, "--limit must be a positive integer" unless options.limit.nil? || options.limit.positive?
    end

    def parser(options)
      OptionParser.new do |opts|
        opts.banner = "Usage: bundle exec ruby bench/parser.rb --manifest FILE --backend ruby --output FILE [options]"
        opts.on("--manifest FILE", "Fixture manifest (spec/fixtures/manifest.json)") { |v| options.manifest = v }
        opts.on("--backend NAME", "Backend to measure; only: #{SUPPORTED_BACKENDS.join(', ')}") { |v| options.backend = v }
        opts.on("--output FILE", "JSON result path") { |v| options.output = v }
        opts.on("--iterations N", Integer, "Timed trials per fixture (default #{DEFAULTS[:iterations]})") { |v| options.iterations = v }
        opts.on("--warmups N", Integer, "Untimed warmup trials per fixture (default #{DEFAULTS[:warmups]})") { |v| options.warmups = v }
        opts.on("--timeout SECONDS", Integer, "Deadline for each fixture child (default #{DEFAULTS[:timeout]})") { |v| options.timeout = v }
        opts.on("--fixture GLOB", "Manifest path glob (File.fnmatch); repeatable") { |v| options.fixtures << v }
        opts.on("--limit N", Integer, "Keep only the first N selected fixtures") { |v| options.limit = v }
        opts.on("--outcomes LIST", Array, "Manifest outcomes to run (default parsed)") { |v| options.outcomes = v }
        opts.on("--cold-runs N", Integer, "Fresh-process cold-load runs (default #{DEFAULTS[:cold_runs]})") { |v| options.cold_runs = v }
        opts.on("--worker KIND", %w[warm cold], "Internal: run one child measurement") { |v| options.worker = v }
        opts.on("--sha256 HEX", "Internal: expected input digest") { |v| options.sha256 = v }
      end
    end

    def run_worker(options)
      output = $stdout.dup
      $stdout.reopen(File::NULL, "w")
      $stderr.reopen(File::NULL, "w")
      worker = if options.worker == "cold"
                 ColdWorker.new(path: options.path)
               else
                 WarmWorker.new(path: options.path, sha256: options.sha256, iterations: options.iterations, warmups: options.warmups)
               end
      output.write(JSON.generate(worker.call))
      output.close
      0
    end
  end

  # Where the numbers came from: runtime, machine and source identities.
  class Provenance
    def initialize(manifest)
      @manifest = manifest
    end

    def to_h
      { "environment" => environment, "revision" => revision }
    end

    private

    def environment
      uname = Etc.uname
      { "ruby" => { "version" => RUBY_VERSION, "engine" => RUBY_ENGINE, "description" => RUBY_DESCRIPTION,
                    "platform" => RUBY_PLATFORM, "executable" => RbConfig.ruby },
        "gems" => gem_versions, "os" => uname.transform_keys(&:to_s), "host" => RbConfig::CONFIG["host"],
        "cpu_count" => Etc.nprocessors, "cpu_model" => cpu_model }
    end

    def gem_versions
      require "emf"
      { "emf" => Emf::VERSION, "bindata" => Gem.loaded_specs.fetch("bindata").version.to_s,
        "bundler" => defined?(Bundler) ? Bundler::VERSION : nil }
    end

    def cpu_model
      if File.readable?("/proc/cpuinfo")
        File.read("/proc/cpuinfo")[/^model name\s*:\s*(.+)$/, 1]
      elsif RbConfig::CONFIG["host_os"].include?("darwin")
        IO.popen(["sysctl", "-n", "machdep.cpu.brand_string"], err: File::NULL, &:read).strip
      end
    rescue SystemCallError
      nil
    end

    def revision
      source = FixtureManifest.source_sha256(ROOT)
      saved = @manifest.dig("backend", "parser_source_sha256")
      { "git_sha" => git("rev-parse", "HEAD"), "git_tracked_changes" => git("status", "--porcelain", "--untracked-files=no"),
        "parser_source_sha256" => source, "manifest_parser_source_sha256" => saved, "manifest_matches_sources" => source == saved }
    end

    def git(*args)
      output = IO.popen(["git", *args], chdir: ROOT, err: File::NULL, &:read)
      $CHILD_STATUS.success? ? output.strip : nil
    rescue SystemCallError
      nil
    end
  end

  # Parent: selects fixtures, launches bounded children, assembles the report.
  class Run
    OUTPUT_LIMIT = 4 * 1024 * 1024

    def initialize(options, argv)
      @options = options
      @argv = argv
      @manifest_path = File.expand_path(options.manifest)
    end

    def run
      require_relative "../../spec/support/fixture_manifest"
      @manifest = JSON.parse(File.read(@manifest_path))
      raise UsageError, "unsupported manifest schema_version" unless @manifest["schema_version"] == FixtureManifest::SCHEMA_VERSION

      selected = select_fixtures
      report = build_report(selected)
      FileUtils.mkdir_p(File.dirname(File.expand_path(@options.output)))
      File.write(@options.output, "#{JSON.pretty_generate(report)}\n")
      summarize(report)
      report["failures"].empty? ? 0 : 1
    rescue Errno::ENOENT, JSON::ParserError => e
      raise UsageError, "cannot read manifest: #{e.message}"
    end

    private

    def select_fixtures
      entries = @manifest.fetch("fixtures").select { |e| @options.outcomes.include?(e["outcome"].to_s) }
      globs = @options.fixtures
      entries = entries.select { |e| globs.any? { |g| File.fnmatch?(g, e["path"], File::FNM_PATHNAME) } } unless globs.empty?
      entries = entries.first(@options.limit) if @options.limit
      raise UsageError, "no fixtures selected" if entries.empty?

      entries
    end

    def build_report(selected)
      fixtures = selected.map { |entry| measure_fixture(entry) }
      slowest = slowest_case(fixtures)
      { "schema_version" => SCHEMA_VERSION, "kind" => "emf-parser-stage-baseline", "backend" => @options.backend,
        "generated_at" => Time.now.utc.iso8601, "command" => ["ruby", "bench/parser.rb", *@argv],
        **Provenance.new(@manifest).to_h, "inputs" => inputs(selected),
        "method" => method_description, "cold_load" => cold_load(selected), "fixtures" => fixtures,
        "slowest_measured_case" => slowest,
        "failures" => fixtures.reject { |f| f["status"] == "ok" }.map { |f| f.slice("path", "status", "failure") } }
    end

    def measure_fixture(entry)
      path = File.expand_path(entry.fetch("path"), ROOT)
      result = child(["--worker", "warm", "--sha256", entry.fetch("sha256"), "--iterations", @options.iterations.to_s,
                      "--warmups", @options.warmups.to_s], path)
      identity = entry.slice("path", "sha256", "size_bytes", "outcome")
      return identity.merge("status" => "failed", "failure" => result["safety_failure"]) if result["safety_failure"]
      return identity.merge("status" => "error", "failure" => result["error"]) unless result["status"] == "ok"

      identity.merge("status" => "ok", "validity" => result["validity"], "memory" => result["memory"],
                     "stages" => result["stages"].transform_values { |data| stage_report(data) })
    end

    def stage_report(data)
      { "samples_ns" => data["samples_ns"], "summary_ns" => Stats.summarize(data["samples_ns"]),
        "allocated_objects_median" => Stats.median(data["allocated_objects"].sort) }
    end

    def child(args, path)
      command = [RbConfig.ruby, "-I", File.join(ROOT, "lib"), SCRIPT, *args]
      FixtureManifest::Runner.new(timeout: @options.timeout, output_limit: OUTPUT_LIMIT, command: command).call(path)
    end

    def cold_load(selected)
      smallest = selected.min_by { |e| e.fetch("size_bytes") }
      runs = Array.new(@options.cold_runs) { child(%w[--worker cold], File.expand_path(smallest.fetch("path"), ROOT)) }
      { "fixture" => smallest.fetch("path"), "runs" => runs,
        "note" => "Each run is a fresh process; require_emf_ns includes loading bindata. Smallest selected fixture, so " \
                  "first-call costs are dominated by autoload and class setup rather than input size." }
    end

    def slowest_case(fixtures)
      candidates = fixtures.select { |f| f["status"] == "ok" }
      best = candidates.max_by { |f| f.dig("stages", SLOWEST_STAGE, "summary_ns", "median") }
      return nil unless best

      best.slice("path", "sha256", "size_bytes").merge(
        "stage" => SLOWEST_STAGE, "median_ns" => best.dig("stages", SLOWEST_STAGE, "summary_ns", "median"),
        "issue_15_fixture_identified" => false,
        "note" => "Slowest case measured in this run only. The roughly 12-second file reported in issue #15 is not " \
                  "identified; this result must not be read as that file."
      )
    end

    def inputs(selected)
      { "manifest_path" => @options.manifest, "manifest_sha256" => Digest::SHA256.file(@manifest_path).hexdigest,
        "manifest_schema_version" => @manifest["schema_version"], "selected_outcomes" => @options.outcomes,
        "fixture_globs" => @options.fixtures, "fixture_limit" => @options.limit, "fixture_count" => selected.size,
        "excluded_by_default" => "recovered and format_error fixtures; run with --outcomes to include them" }
    end

    def method_description
      { "iterations" => @options.iterations, "warmups" => @options.warmups, "child_timeout_seconds" => @options.timeout,
        "timing" => { "clock" => "Process.clock_gettime(CLOCK_MONOTONIC, :nanosecond)", "unit" => "nanoseconds" },
        "gc_policy" => "GC.start before each stage, outside timed regions, so no stage pays for earlier garbage; " \
                       "GC stays enabled inside them",
        "isolation" => "one child process per fixture (process group, external deadline, #{OUTPUT_LIMIT}-byte output cap); " \
                       "warmup trials run in the same child and are discarded",
        "file_io" => "excluded from every stage except parse_file; bytes are read once per child",
        "stages" => STAGES, "inseparable_boundaries" => INSEPARABLE_BOUNDARIES, "memory" => ParserBenchmark::Memory.description }
    end

    def summarize(report)
      slow = report["slowest_measured_case"]
      puts "Wrote #{@options.output}: #{report['fixtures'].size} fixtures, #{report['failures'].size} failures"
      return unless slow

      puts "Slowest measured (#{SLOWEST_STAGE} median): #{slow['path']} #{(slow['median_ns'] / 1e6).round(2)} ms " \
           "(not identified as the issue #15 file)"
    end
  end
end
