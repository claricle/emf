# frozen_string_literal: true

require "digest"
require "json"
require "rbconfig"
require_relative "process_supervisor"

# Runs manifest fixtures one per supervised child and records a verdict for each.
# A fixture passes only when its child exited 0 within every limit, reported the manifest's baseline outcome,
# completed the round trip, and the fixture file was byte-identical before and after the child ran.
module NativeResilience
  SCHEMA_VERSION = 1
  CORRUPT_PREFIX = "spec/fixtures/emf-corrupted/"
  BACKENDS = %w[native ruby].freeze
  SCOPES = %w[corrupted all].freeze
  # Measured per-fixture RSS ceilings in MiB (arm64 macOS, 2026-10-20): native children peaked at
  # 195.5 MiB over all 229 fixtures, Ruby children at ~957 MiB for the full parse/serialize/reparse
  # pipeline on the largest corrupt fixture. The flag stays required; these are the values CI passes.
  MEASURED_RSS_LIMIT_MB = { "native" => 1024, "ruby" => 2048 }.freeze

  class ConfigurationError < ArgumentError; end

  module_function

  def entries(manifest, scope)
    fixtures = manifest.fetch("fixtures")
    return fixtures if scope == "all"

    fixtures.select { |entry| entry.fetch("path").start_with?(CORRUPT_PREFIX) }
  end

  # The child reports the same vocabulary as the manifest: parsed, recovered or format_error.
  # Anything else, including a native library that is not installed, is an unexpected outcome and fails the fixture.
  # A format_error fixture yields no document, so its round trip is not_applicable. Every other fixture is serialized,
  # reparsed and serialized again; the oracle is that none of those steps raises and the two serializations are
  # byte-identical. Equality with the original bytes is not required because recovered input is rewritten.
  def observe(path)
    require "emf"
    outcome, first = parse_and_serialize(File.binread(path))
    { "outcome" => outcome }.merge(first.is_a?(Hash) ? first : round_trip(first))
  rescue Emf::FormatError => e
    { "outcome" => "format_error", "round_trip" => "not_applicable", "exception" => e.class.name }
  rescue StandardError, NotImplementedError => e
    { "outcome" => nil, "exception" => e.class.name, "message" => e.message.byteslice(0, 512) }
  end

  # The first document is local to this method, so it can be collected before
  # the reparse instead of doubling the live heap for large fixtures.
  def parse_and_serialize(bytes)
    metafile = Emf.parse(bytes)
    [metafile.errors? ? "recovered" : "parsed", serialize_first(metafile)]
  end

  def serialize_first(metafile)
    Emf.serialize(metafile)
  rescue StandardError, NotImplementedError => e
    stage_failure("serialize_failed", e)
  end

  def round_trip(first)
    stage = "reparse_failed"
    reparsed = Emf.parse(first)
    stage = "reserialize_failed"
    second = Emf.serialize(reparsed)
    { "round_trip" => first == second ? "ok" : "not_idempotent" }
  rescue StandardError, NotImplementedError => e
    stage_failure(stage, e)
  end

  def stage_failure(stage, error)
    { "round_trip" => stage, "exception" => error.class.name, "message" => error.message.byteslice(0, 512) }
  end

  class Runner
    def initialize(root:, backend:, wall_seconds:, rss_limit_bytes:, child: nil)
      raise ConfigurationError, "backend must be one of #{BACKENDS.join(', ')}" unless BACKENDS.include?(backend)
      raise ConfigurationError, "an RSS limit must be configured before any fixture runs" unless rss_limit_bytes

      @root = root
      @backend = backend
      @child = child || method(:default_child)
      @supervisor = ProcessSupervisor.new(wall_seconds: wall_seconds, rss_limit_bytes: rss_limit_bytes)
      @wall_seconds = wall_seconds
      @rss_limit_bytes = rss_limit_bytes
    end

    def call(entries)
      results = entries.map { |entry| verdict(entry) }
      { "schema_version" => SCHEMA_VERSION, "backend" => @backend, "ruby_version" => RUBY_VERSION,
        "platform" => RUBY_PLATFORM, "limits" => { "wall_seconds" => @wall_seconds, "rss_limit_bytes" => @rss_limit_bytes },
        "totals" => totals(results), "results" => results }
    end

    private

    def default_child(path)
      [RbConfig.ruby, "-I", File.join(@root, "lib"), __FILE__, "--observe", path]
    end

    def verdict(entry)
      file = File.join(@root, entry.fetch("path"))
      before = digest(file)
      result = @supervisor.call(@child.call(file), env: { "EMF_BACKEND" => @backend })
      judge(entry, result, before, digest(file))
    end

    def digest(file)
      Digest::SHA256.file(file).hexdigest
    rescue SystemCallError
      nil
    end

    def judge(entry, result, before, after)
      expected = entry.fetch("outcome")
      observed = result.success? ? parse_observation(result.output) : {}
      reason = failure_reason(entry, result, expected, observed, [before, after])
      { "path" => entry.fetch("path"), "verdict" => reason ? "failed" : "passed", "reason" => reason,
        "expected_outcome" => expected, "observed_outcome" => observed["outcome"],
        "round_trip" => observed["round_trip"], "sha256_before" => before, "sha256_after" => after,
        "exception" => observed["exception"], "status" => result.status.to_s, "exit_code" => result.exit_code,
        "signal" => result.signal, "elapsed_seconds" => result.elapsed.round(3), "peak_rss_bytes" => result.peak_rss_bytes }
    end

    def failure_reason(entry, result, expected, observed, hashes)
      identity = identity_failure(entry, *hashes)
      return identity if identity
      return result.status.to_s unless result.success?
      return "invalid_observation" unless observed.key?("outcome")
      return "outcome_mismatch" unless observed["outcome"] == expected

      round_trip_failure(expected, observed["round_trip"])
    end

    def identity_failure(entry, before, after)
      return "fixture_unreadable" unless before && after
      return "fixture_mismatch" if entry["sha256"] && entry["sha256"] != before

      "fixture_mutated" unless before == after
    end

    def round_trip_failure(expected, round_trip)
      wanted = expected == "format_error" ? "not_applicable" : "ok"
      round_trip || "missing_round_trip" unless round_trip == wanted
    end

    def parse_observation(output)
      line = output.lines.map(&:strip).reject(&:empty?).last
      parsed = JSON.parse(line.to_s)
      parsed.is_a?(Hash) ? parsed : {}
    rescue JSON::ParserError
      {}
    end

    def totals(results)
      failed = results.count { |result| result["verdict"] == "failed" }
      { "fixtures" => results.size, "passed" => results.size - failed, "failed" => failed }
    end
  end
end

if $PROGRAM_NAME == __FILE__ && ARGV.shift == "--observe"
  output = $stdout.dup
  $stdout.reopen(File::NULL, "w")
  $stderr.reopen(File::NULL, "w")
  output.write(JSON.generate(NativeResilience.observe(ARGV.fetch(0))))
  output.close
end
