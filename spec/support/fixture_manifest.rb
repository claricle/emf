# frozen_string_literal: true

require "bindata"
require "digest"
require "json"
require "rbconfig"
require_relative "process_supervisor"

module FixtureManifest
  SCHEMA_VERSION = 2
  CAPTURE_METADATA = {
    "backend" => "ruby",
    "limits" => { "timeout_seconds" => 15, "output_limit_bytes" => 16_384 }
  }.freeze
  EXPECTED_COUNTS = { "emf" => 186, "emf-ea" => 21, "simple" => 1, "emf-corrupted" => 21, "wmf" => 2 }.freeze

  module_function

  def fixtures(root)
    paths = Dir.glob(File.join(root, "spec/fixtures/**/*.{emf,wmf}"), sort: false).sort
    paths.map do |path|
      relative_path = path.delete_prefix("#{root}/")
      format = File.extname(path).delete_prefix(".")
      entry = { "path" => relative_path, "sha256" => Digest::SHA256.file(path).hexdigest,
                "size_bytes" => File.size(path), "expected_format" => format }
      entry["provenance"] = "synthetic" if format == "wmf"
      entry
    end
  end

  def counts(entries)
    entries.each_with_object(Hash.new(0)) { |entry, result| result[entry.fetch("path").split("/")[2]] += 1 }.sort.to_h
  end

  def source_sha256(root)
    digest = Digest::SHA256.new
    Dir.glob(File.join(root, "lib/**/*.rb"), sort: false).sort.each do |path|
      digest << path.delete_prefix("#{root}/") << "\0" << File.binread(path) << "\0"
    end
    digest.hexdigest
  end

  def observe(path)
    previous_backend = ENV.fetch("EMF_BACKEND", nil)
    require "emf"
    ENV["EMF_BACKEND"] = "ruby"
    bytes = File.binread(path)
    detected = Emf.detect_format(bytes).to_s
    metafile = Emf.parse(bytes)
    { "detected_format" => detected, "outcome" => metafile.errors? ? "recovered" : "parsed" }
  rescue Emf::FormatError => e
    { "detected_format" => detected, "outcome" => "format_error", "format_error" => exception(e) }
  rescue StandardError => e
    { "detected_format" => detected, "outcome" => nil, "backend_exception" => exception(e) }
  ensure
    if defined?(previous_backend)
      previous_backend.nil? ? ENV.delete("EMF_BACKEND") : ENV["EMF_BACKEND"] = previous_backend
    end
  end

  # The ceiling has no default: choose it by measuring the valid corpus on the target runner.
  def rss_limit_bytes_from_env(env = ENV)
    megabytes = env.fetch("EMF_MANIFEST_RSS_LIMIT_MB", nil)
    megabytes.to_i * 1024 * 1024 if megabytes&.match?(/\A[1-9]\d*\z/)
  end

  def exception(error)
    { "class" => error.class.name, "message" => error.message.byteslice(0, 2048).encode("UTF-8", invalid: :replace, undef: :replace) }
  end

  # Captures one fixture in a child run under ProcessSupervisor's wall, RSS and output limits.
  class Runner
    FAILURE_KINDS = { timed_out: "timeout", output_limit: "output_limit",
                      rss_exceeded: "rss_exceeded", monitor_failed: "monitor_failed" }.freeze

    def initialize(rss_limit_bytes:, timeout: 5, output_limit: 16_384, command: nil, benchmark_series: false)
      @supervisor = ProcessSupervisor.new(wall_seconds: timeout, rss_limit_bytes: rss_limit_bytes,
                                          output_limit: output_limit, benchmark_series: benchmark_series)
      @command = command || [RbConfig.ruby, "-I", File.expand_path("../../lib", __dir__), __FILE__, "--observe"]
    end

    def call(path)
      env, *argv = @command.first.is_a?(Hash) ? @command : [{}, *@command]
      result = @supervisor.call([*argv, path], env: env)
      return failure(FAILURE_KINDS.fetch(result.status, "process_failure"), details(result)) unless result.success?

      JSON.parse(result.output)
    rescue JSON::ParserError
      failure("invalid_observation")
    end

    private

    def details(result)
      return {} unless %i[exited signaled].include?(result.status)

      { "exit_status" => result.exit_code, "signal" => result.signal }
    end

    def failure(kind, details = {})
      { "detected_format" => nil, "outcome" => nil, "safety_failure" => { "kind" => kind }.merge(details) }
    end
  end

  class Inventory
    def initialize(root, rss_limit_bytes: FixtureManifest.rss_limit_bytes_from_env)
      @root = File.expand_path(root)
      @rss_limit_bytes = rss_limit_bytes
    end

    def generate
      entries = FixtureManifest.fixtures(@root)
      verify_counts(entries)
      raise ArgumentError, "set EMF_MANIFEST_RSS_LIMIT_MB to the per-fixture RSS ceiling in MiB" unless @rss_limit_bytes

      runner = Runner.new(timeout: 15, output_limit: 16_384, rss_limit_bytes: @rss_limit_bytes)
      {
        "schema_version" => SCHEMA_VERSION,
        "capture" => CAPTURE_METADATA,
        "backend" => { "name" => "ruby", "ruby_version" => RUBY_VERSION,
                       "bindata_version" => Gem.loaded_specs.fetch("bindata").version.to_s,
                       "parser_source_sha256" => FixtureManifest.source_sha256(@root) },
        "counts" => FixtureManifest.counts(entries),
        "fixtures" => entries.map { |entry| entry.merge(runner.call(File.join(@root, entry.fetch("path")))) }
      }
    end

    def check(manifest)
      return false unless valid_structure?(manifest)
      return false unless manifest["capture"] == CAPTURE_METADATA

      entries = FixtureManifest.fixtures(@root)
      verify_counts(entries)
      return false unless current_backend?(manifest)
      return false unless manifest["counts"] == FixtureManifest.counts(entries)

      saved = manifest.fetch("fixtures")
      metadata = saved.map { |entry| entry.slice("path", "sha256", "size_bytes", "expected_format", "provenance") }
      metadata == entries && saved.all? { |entry| valid_observation?(entry) }
    end

    private

    def valid_structure?(manifest)
      manifest.is_a?(Hash) && manifest["backend"].is_a?(Hash) &&
        manifest["capture"].is_a?(Hash) && manifest["fixtures"].is_a?(Array) && manifest["fixtures"].all?(Hash)
    end

    def current_backend?(manifest)
      manifest["schema_version"] == SCHEMA_VERSION && manifest.dig("backend", "name") == "ruby" &&
        manifest.dig("backend", "bindata_version") == Gem.loaded_specs.fetch("bindata").version.to_s &&
        manifest.dig("backend", "parser_source_sha256") == FixtureManifest.source_sha256(@root)
    end

    def verify_counts(entries)
      return if FixtureManifest.counts(entries) == EXPECTED_COUNTS.sort.to_h

      raise ArgumentError, "fixture counts differ: #{FixtureManifest.counts(entries).inspect}; expected #{EXPECTED_COUNTS.inspect}"
    end

    def valid_observation?(entry)
      return false if entry.key?("safety_failure")
      return false unless observation_shape?(entry)
      return entry["outcome"].nil? && diagnostic?(entry["backend_exception"]) if entry.key?("backend_exception")
      if entry["outcome"] == "format_error"
        return diagnostic?(entry["format_error"]) && entry.dig("format_error", "class") == "Emf::FormatError"
      end

      %w[parsed recovered].include?(entry["outcome"]) && !entry["detected_format"].nil? && !entry.key?("format_error")
    end

    def observation_shape?(entry)
      entry.key?("outcome") && entry.key?("detected_format") && [nil, "emf", "wmf"].include?(entry["detected_format"])
    end

    def diagnostic?(value)
      value.is_a?(Hash) && value["class"].is_a?(String) && value["message"].is_a?(String)
    end
  end
end

if $PROGRAM_NAME == __FILE__ && ARGV.shift == "--observe"
  output = $stdout.dup
  $stdout.reopen(File::NULL, "w")
  $stderr.reopen(File::NULL, "w")
  output.write(JSON.generate(FixtureManifest.observe(ARGV.fetch(0))))
  output.close
end
