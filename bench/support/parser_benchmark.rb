# frozen_string_literal: true

require "English"
require "digest"
require "etc"
require "fileutils"
require "json"
require "optparse"
require "rbconfig"
require "time"

# Stage timings through the public parser API. The parent process never parses a
# fixture: every fixture runs in its own child with an external deadline and a
# bounded output pipe, so a corrupt input cannot crash or hang the benchmark.
# Workers must not load `emf` (or bindata) before timing starts, because the
# cold-load measurement includes those requires.
module ParserBenchmark
  SCHEMA_VERSION = 1
  SUPPORTED_BACKENDS = %w[ruby native].freeze
  ROOT = File.expand_path("../..", __dir__)
  SCRIPT = File.join(ROOT, "bench/parser.rb")
  SLOWEST_STAGE = "parse_to_serialize"

  STAGES = {
    "detect_format" => "Emf.detect_format(bytes)",
    "parse" => "Emf.parse(bytes): detection, header wire read, per-record wire reads, WireAdapter creation, Metafile construction",
    "wire_first_traversal" => "snapshot of every record wire on a freshly parsed metafile",
    "wire_repeated_traversal" => "the same snapshot traversal repeated on the same metafile",
    "dump" => "Emf::Visitors::Dump over a freshly parsed, untraversed metafile, rendered to a string",
    "serialize" => "Emf.serialize(metafile) of a freshly parsed, untraversed metafile",
    "mutation_to_serialize" => "SetMapMode wire.map_mode assignment and Emf.serialize on a fresh model; " \
                               "parsing, candidate selection and output/reparse verification are outside timing",
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
  class MutationError < StandardError; end

  # One representative public wire edit, not a claim of arbitrary edit support.
  class WireMutation
    attr_reader :metadata

    def initialize(metafile)
      index = metafile.records.index { |record| record.type_id == 17 } if %i[emf emf_plus].include?(metafile.format)
      @metadata = if index
                    before = metafile.records.fetch(index).wire.map_mode.to_i
                    { "status" => "supported", "record_index" => index, "type_id" => 17, "field" => "map_mode",
                      "before" => before, "after" => before == 8 ? 1 : 8 }
                  else
                    { "status" => "unsupported", "reason" => "No EMF SetMapMode record for the representative wire edit" }
                  end
    end

    def supported?
      metadata["status"] == "supported"
    end

    def apply(metafile)
      metafile.records.fetch(metadata.fetch("record_index")).wire.map_mode = metadata.fetch("after")
    end

    def verify(bytes, original)
      raise MutationError, "wire edit did not change serialized bytes" if bytes == original

      reparsed = Emf.parse(bytes)
      record = reparsed.records.fetch(metadata.fetch("record_index"))
      value = record.wire.map_mode.to_i
      unless reparsed.errors.empty? && record.type_id == metadata.fetch("type_id") && value == metadata.fetch("after")
        raise MutationError, "serialized wire edit did not survive reparsing"
      end

      metadata.merge!("output_changed" => true, "output_sha256" => Digest::SHA256.hexdigest(bytes), "reparsed_value" => value)
    end
  end

  # Runs in a fresh child with a warm process: untimed warmups, then timed trials.
  class WarmWorker
    def initialize(path:, sha256:, iterations:, warmups:, backend: "ruby")
      @path = path
      @sha256 = sha256
      @iterations = iterations
      @warmups = warmups
      @backend = backend
    end

    def call
      ENV["EMF_BACKEND"] = @backend
      require "emf"
      @bytes = File.binread(@path)
      raise InputMismatch, "sha256 differs from the manifest" unless Digest::SHA256.hexdigest(@bytes) == @sha256

      result = { "status" => "ok", "validity" => validity }
      @warmups.times { trial }
      memory = [Memory.sample]
      samples = Array.new(@iterations) { trial.tap { memory << Memory.sample } }
      result.merge("mutation" => @mutation.metadata, "stages" => collect(samples), "memory" => memory_report(memory))
    rescue StandardError => e
      { "status" => "error", "error" => { "class" => e.class.name, "message" => e.message.byteslice(0, 2048).scrub } }
    end

    private

    def validity
      metafile = Emf.parse(@bytes)
      @mutation = WireMutation.new(metafile)
      { "record_count" => metafile.records.size, "parse_error_count" => metafile.errors.size,
        "format" => metafile.format.to_s, "round_trip_identical" => Emf.serialize(metafile) == @bytes }
    end

    def trial
      results = {}
      measure(results, "detect_format") { Emf.detect_format(@bytes) }
      metafile = measure(results, "parse") { Emf.parse(@bytes) }
      2.times { |pass| measure(results, pass.zero? ? "wire_first_traversal" : "wire_repeated_traversal") { traverse(metafile) } }
      dump_model = Emf.parse(@bytes)
      measure(results, "dump") { Emf::Visitors::Dump.new.visit_all(dump_model).to_s }
      serialize_model = Emf.parse(@bytes)
      measure(results, "serialize") { Emf.serialize(serialize_model) }
      measure(results, "parse_to_serialize") { Emf.serialize(Emf.parse(@bytes)) }
      measure(results, "parse_file") { Emf.parse_file(@path) }
      measure_mutation(results) if @mutation.supported?
      results
    end

    def measure_mutation(results)
      metafile = Emf.parse(@bytes)
      bytes = measure(results, "mutation_to_serialize") do
        @mutation.apply(metafile)
        Emf.serialize(metafile)
      end
      @mutation.verify(bytes, @bytes)
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
        if stage == "mutation_to_serialize" && !@mutation.supported?
          next [stage, @mutation.metadata.merge("samples_ns" => [], "allocated_objects" => [])]
        end

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
    def initialize(path:, backend: "ruby")
      @path = path
      @backend = backend
    end

    def call
      ENV["EMF_BACKEND"] = @backend
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
                       :cold_runs, :worker, :sha256, :path, :rss_limit_bytes, keyword_init: true)

  class CLI
    TIMEOUT_RANGE = (1..60)
    DEFAULTS = { backend: "ruby", iterations: 20, warmups: 5, timeout: 60, fixtures: [], outcomes: %w[parsed], cold_runs: 3 }.freeze

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
      options = Options.new(**DEFAULTS, fixtures: [])
      rest = parser(options).parse(argv)
      options.worker ? options.tap { options.path = rest.fetch(0) { raise UsageError, "worker needs a path" } } : validate(options, rest)
    end

    def validate(options, rest)
      raise UsageError, "unexpected arguments: #{rest.join(' ')}" unless rest.empty?
      raise UsageError, "--manifest is required" unless options.manifest
      raise UsageError, "--output is required" unless options.output
      raise UsageError, "--rss-limit-mb is required" unless options.rss_limit_bytes
      unless SUPPORTED_BACKENDS.include?(options.backend)
        raise UsageError, "unsupported backend #{options.backend.inspect} (supported: #{SUPPORTED_BACKENDS.join(', ')})"
      end

      check_positive(options)
      options
    end

    def check_positive(options)
      raise UsageError, "--iterations must be a positive integer" unless options.iterations.is_a?(Integer) && options.iterations.positive?
      raise UsageError, "--timeout must be within #{TIMEOUT_RANGE} seconds" unless TIMEOUT_RANGE.cover?(options.timeout)
      raise UsageError, "--warmups must be >= 0" unless options.warmups.is_a?(Integer) && options.warmups >= 0
      raise UsageError, "--cold-runs must be >= 0" unless options.cold_runs.is_a?(Integer) && options.cold_runs >= 0
      raise UsageError, "--limit must be a positive integer" unless options.limit.nil? || options.limit.positive?
    end

    def parser(options)
      OptionParser.new do |opts|
        opts.banner = "Usage: bundle exec ruby bench/parser.rb --manifest FILE --backend NAME --output FILE --rss-limit-mb MB [options]"
        opts.on("--manifest FILE", "Fixture manifest (spec/fixtures/manifest.json)") { |v| options.manifest = v }
        opts.on("--backend NAME", "Forced backend to measure (default ruby): #{SUPPORTED_BACKENDS.join(', ')}") { |v| options.backend = v }
        opts.on("--output FILE", "JSON result path") { |v| options.output = v }
        opts.on("--rss-limit-mb MB", Integer, "Required; per-child RSS ceiling in MiB (no default: measure the target runner)") do |v|
          raise UsageError, "--rss-limit-mb must be a positive integer" unless v.positive?

          options.rss_limit_bytes = v * 1024 * 1024
        end
        opts.on("--iterations N", Integer, "Timed trials per fixture (default #{DEFAULTS[:iterations]})") { |v| options.iterations = v }
        opts.on("--warmups N", Integer, "Untimed warmup trials per fixture (default #{DEFAULTS[:warmups]})") { |v| options.warmups = v }
        opts.on("--timeout SECONDS", Integer, "Fixture child deadline, #{TIMEOUT_RANGE} (default #{DEFAULTS[:timeout]})") do |v|
          options.timeout = v
        end
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
                 ColdWorker.new(path: options.path, backend: options.backend)
               else
                 WarmWorker.new(path: options.path, sha256: options.sha256, iterations: options.iterations,
                                warmups: options.warmups, backend: options.backend)
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

  def self.runner(options, output_limit, command)
    FixtureManifest::Runner.new(timeout: options.timeout, rss_limit_bytes: options.rss_limit_bytes,
                                output_limit: output_limit, command: command)
  end

  def self.cold_failures(cold)
    cold.fetch("runs").each_with_index.filter_map do |result, index|
      next if result["status"] == "ok"

      { "stage" => "cold_load", "path" => cold.fetch("fixture"), "run" => index,
        "status" => "failed", "failure" => result["safety_failure"] || result["error"] }
    end
  end

  # Describes the public backend boundaries and identifies the selected library.
  class BackendDescription
    def initialize(backend)
      @backend = backend
    end

    def native_library
      return nil unless @backend == "native"

      path = ENV.fetch("EMF_NATIVE_LIBRARY", nil)
      identity = { "path" => path, "sha256" => nil,
                   "build_metadata" => { "profile" => nil, "rustc_version" => nil,
                                         "note" => "The library exposes no build metadata; profile and compiler are unknown." } }
      return identity if path.nil? || path.empty?

      identity.merge("resolved_path" => File.realpath(path), "sha256" => Digest::SHA256.file(path).hexdigest,
                     "size_bytes" => File.size(path), "mtime" => File.mtime(path).utc.iso8601)
    rescue SystemCallError => e
      identity.merge("identity_error" => e.message)
    end

    def stage_descriptions
      return STAGES if @backend == "ruby"

      STAGES.merge("parse" => "Emf.parse(bytes): backend selection/loading, native parse, " \
                              "ABI snapshot transfer and Ruby model hydration with deferred wires",
                   "serialize" => "Emf.serialize(metafile): native adapter selection/loading and Ruby Emr::Serializer",
                   "parse_to_serialize" => "Emf.serialize(Emf.parse(bytes)) through the forced native adapter as one region")
    end

    def inseparable_boundaries
      return INSEPARABLE_BOUNDARIES if @backend == "ruby"

      ["Native parse, ABI snapshot transfer and Ruby model hydration with deferred wires share the public Emf.parse region; " \
       "raw Rust parse, ABI transfer and hydration are not measured separately.",
       "Backend selection currently loads the native adapter on each parse and serialize call; that cost is included. " \
       "Native serialization currently delegates to the Ruby Emr::Serializer.",
       "First traversal includes deferred BinData wire materialization and snapshots; repeated traversal reuses those wires. " \
       "Ruby allocated_objects excludes Rust allocations."]
    end
  end

  # Parent: selects fixtures, launches bounded children, assembles the report.
  class Run
    OUTPUT_LIMIT = 4 * 1024 * 1024

    def initialize(options, argv)
      @options = options
      @argv = argv
      @backend_description = BackendDescription.new(options.backend)
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
      cold = cold_load(selected)
      failures = fixtures.reject { |f| f["status"] == "ok" }.map { |f| f.slice("path", "status", "failure") }
      { "schema_version" => SCHEMA_VERSION, "kind" => "emf-parser-stage-baseline", "backend" => @options.backend,
        "generated_at" => Time.now.utc.iso8601, "command" => ["ruby", "bench/parser.rb", *@argv],
        **Provenance.new(@manifest).to_h, "native_library" => @backend_description.native_library, "inputs" => inputs(selected),
        "method" => method_description, "cold_load" => cold, "fixtures" => fixtures,
        "slowest_measured_case" => slowest_case(fixtures), "failures" => failures + ParserBenchmark.cold_failures(cold) }
    end

    def measure_fixture(entry)
      path = File.expand_path(entry.fetch("path"), ROOT)
      result = child(["--worker", "warm", "--sha256", entry.fetch("sha256"), "--iterations", @options.iterations.to_s,
                      "--warmups", @options.warmups.to_s], path)
      identity = entry.slice("path", "sha256", "size_bytes", "outcome")
      return identity.merge("status" => "failed", "failure" => result["safety_failure"]) if result["safety_failure"]
      return identity.merge("status" => "error", "failure" => result["error"]) unless result["status"] == "ok"

      identity.merge("status" => "ok", "validity" => result["validity"], "memory" => result["memory"], "mutation" => result["mutation"],
                     "stages" => result["stages"].transform_values { |data| stage_report(data) })
    end

    def stage_report(data)
      return data.slice("status", "reason", "samples_ns").merge("summary_ns" => nil) if data["status"] == "unsupported"

      { "samples_ns" => data["samples_ns"], "summary_ns" => Stats.summarize(data["samples_ns"]),
        "allocated_objects_median" => Stats.median(data["allocated_objects"].sort) }
    end

    def child(args, path)
      ParserBenchmark.runner(@options, self.class::OUTPUT_LIMIT,
                             [RbConfig.ruby, "-I", File.join(ROOT, "lib"), SCRIPT, "--backend", @options.backend, *args]).call(path)
    end

    def cold_load(selected)
      smallest = selected.min_by { |e| e.fetch("size_bytes") }
      runs = Array.new(@options.cold_runs) { child(%w[--worker cold], File.expand_path(smallest.fetch("path"), ROOT)) }
      { "fixture" => smallest.fetch("path"), "runs" => runs,
        "note" => "Each run is a fresh process; require_emf_ns includes loading bindata. Smallest selected fixture, so " \
                  "first-call costs include autoload/class setup and, for native, initial library loading, ABI transfer and hydration." }
    end

    def slowest_case(fixtures)
      best = fixtures.select { |f| f["status"] == "ok" }.max_by { |f| f.dig("stages", SLOWEST_STAGE, "summary_ns", "median") }
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
        "child_rss_limit_bytes" => @options.rss_limit_bytes,
        "timing" => { "clock" => "Process.clock_gettime(CLOCK_MONOTONIC, :nanosecond)", "unit" => "nanoseconds" },
        "gc_policy" => "GC.start before each stage, outside timed regions, so no stage pays for earlier garbage; " \
                       "GC stays enabled inside them",
        "isolation" => "one child process per fixture (process group, external deadline, #{OUTPUT_LIMIT}-byte output cap); " \
                       "warmup trials run in the same child and are discarded",
        "file_io" => "excluded from every stage except parse_file; bytes are read once per child",
        "stages" => @backend_description.stage_descriptions,
        "inseparable_boundaries" => @backend_description.inseparable_boundaries, "memory" => ParserBenchmark::Memory.description }
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
