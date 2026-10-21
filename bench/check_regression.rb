#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "optparse"

# Informational comparator for bench/parser.rb reports. Compares candidate
# medians against baseline medians under bench/performance-policy.json.
# Exit status: 0 compared (alerts included while the policy is informational),
# 1 a blocking policy found a blocking alert or inconclusive workload,
# 2 malformed input, 3 incomparable reports.
module CheckRegression
  class Malformed < StandardError; end

  DEFAULT_POLICY = File.expand_path("performance-policy.json", __dir__)
  SCHEMA_VERSION = 1
  NS_PER_MS = 1_000_000.0

  module_function

  def median(values)
    sorted = values.sort
    mid = sorted.size / 2
    sorted.size.odd? ? sorted[mid].to_f : (sorted[mid - 1] + sorted[mid]) / 2.0
  end

  def p95(values)
    sorted = values.sort
    sorted[((sorted.size * 0.95).ceil - 1).clamp(0, sorted.size - 1)].to_f
  end

  # Validates the policy and returns it. A blocking policy must be fully calibrated.
  class Policy
    STATUSES = %w[informational blocking].freeze

    attr_reader :data

    def initialize(data)
      @data = data
      validate
    end

    def blocking? = data["status"] == "blocking"
    def min_samples = data.dig("sampling", "min_samples")
    def min_baseline_runs = data.dig("sampling", "min_baseline_runs")
    def alert_ratio = data["alert_ratio"]
    def noise_bound = data.dig("noise_bound", "max_relative_spread")

    def floor_ns(workload)
      ms = data.dig("absolute_floor_ms", "per_workload", workload) || data.dig("absolute_floor_ms", "default")
      ms && (ms * NS_PER_MS)
    end

    private

    def validate
      raise Malformed, "policy is not an object" unless data.is_a?(Hash)
      raise Malformed, "unsupported policy schema_version" unless data["schema_version"] == SCHEMA_VERSION
      raise Malformed, "policy status must be informational or blocking" unless STATUSES.include?(data["status"])

      numbers = { "alert_ratio" => alert_ratio, "sampling.min_samples" => min_samples,
                  "sampling.min_baseline_runs" => min_baseline_runs }
      numbers.each { |name, value| raise Malformed, "policy #{name} must be a positive number" unless positive?(value) }
      raise Malformed, "policy noise bound must be null or positive" unless noise_bound.nil? || positive?(noise_bound)

      validate_blocking if blocking?
    end

    def validate_blocking
      unset = data.fetch("runner", {}).select { |_, v| v.nil? }.keys
      raise Malformed, "blocking policy has unset runner fields: #{unset.join(', ')}" unless unset.empty?
      raise Malformed, "blocking policy needs a calibrated noise bound" if noise_bound.nil?
      return if data.dig("absolute_floor_ms", "default")

      raise Malformed, "blocking policy needs a default absolute floor"
    end

    def positive?(value) = value.is_a?(Numeric) && value.positive?
  end

  # A parsed bench/parser.rb report reduced to what is compared.
  class Report
    attr_reader :label, :data

    def initialize(data, label)
      @label = label
      @data = data
      raise Malformed, "#{label}: not a parser stage baseline report" unless data.is_a?(Hash) && data["kind"] == "emf-parser-stage-baseline"
      raise Malformed, "#{label}: fixtures must be an array" unless data["fixtures"].is_a?(Array)
    end

    # Run-level identity that must match for any comparison to mean something.
    def identity
      env = data["environment"] || {}
      { "backend" => data["backend"], "timing" => data.dig("method", "timing"), "file_io" => data.dig("method", "file_io"),
        "gc_policy" => data.dig("method", "gc_policy"), "os" => env.dig("os", "sysname"), "arch" => env.dig("os", "machine"),
        "cpu_model" => env["cpu_model"], "cpu_count" => env["cpu_count"], "ruby_platform" => env.dig("ruby", "platform"),
        "native_library_sha256" => data.dig("native_library", "sha256"),
        "manifest_sha256" => data.dig("inputs", "manifest_sha256") }
    end

    # { "path#stage" => { sha256:, samples: [ns...] } } for stages that were measured.
    def workloads
      @workloads ||= data["fixtures"].grep(Hash).select { |f| f["status"] == "ok" }.each_with_object({}) do |fixture, all|
        (fixture["stages"] || {}).each do |stage, body|
          samples = samples_of(fixture, stage, body)
          all["#{fixture['path']}##{stage}"] = { sha256: fixture["sha256"], samples: samples } if samples
        end
      end
    end

    private

    def samples_of(fixture, stage, body)
      samples = body.is_a?(Hash) ? body["samples_ns"] : nil
      return nil if samples.nil? || samples.empty?
      return samples if samples.all?(Numeric)

      raise Malformed, "#{label}: #{fixture['path']}##{stage} has non-numeric samples"
    end
  end

  # Produces the verdict document.
  class Comparison
    def initialize(baselines, candidate, policy)
      @baselines = baselines
      @candidate = candidate
      @policy = policy
    end

    def call
      mismatches = identity_mismatches
      results = mismatches.empty? ? workload_results : []
      { "policy_status" => @policy.data["status"], "identity_mismatches" => mismatches, "workloads" => results,
        "summary" => results.map { |r| r["verdict"] }.tally }
    end

    private

    def identity_mismatches
      reference = @baselines.first.identity
      (@baselines.drop(1) + [@candidate]).flat_map do |report|
        reference.filter_map do |key, value|
          { "field" => key, "baseline" => value, report.label => report.identity[key] } unless report.identity[key] == value
        end
      end
    end

    def workload_results
      @baselines.first.workloads.keys.sort.map { |name| judge(name) }
    end

    def judge(name)
      base = @baselines.map { |b| b.workloads[name] }
      cand = @candidate.workloads[name]
      return result(name, "incomparable", "missing from a baseline or the candidate") if cand.nil? || base.any?(&:nil?)
      return result(name, "incomparable", "fixture sha256 differs") if ([cand] + base).map { |w| w[:sha256] }.uniq.size > 1

      measure(name, base, cand)
    end

    def measure(name, base, cand)
      medians = base.map { |w| CheckRegression.median(w[:samples]) }
      base_median = CheckRegression.median(medians)
      cand_median = CheckRegression.median(cand[:samples])
      base_p95 = CheckRegression.p95(base.flat_map { |w| w[:samples] })
      stats = { "baseline_median_ns" => base_median, "candidate_median_ns" => cand_median,
                "ratio" => ((cand_median / base_median) - 1).round(4),
                "p95_ratio" => ((CheckRegression.p95(cand[:samples]) / base_p95) - 1).round(4) }
      reason = inconclusive_reason(base, cand, medians, base_median)
      return result(name, "inconclusive", reason, stats) if reason
      return result(name, "ok", "within alert ratio", stats) if stats["ratio"] <= @policy.alert_ratio

      alert(name, stats, cand_median - base_median)
    end

    def alert(name, stats, delta_ns)
      floor = @policy.floor_ns(name)
      return result(name, "inconclusive", "absolute floor uncalibrated", stats) if floor.nil?
      return result(name, "alert", "below absolute floor", stats.merge("blocking_eligible" => false)) if delta_ns < floor

      result(name, "alert", "exceeds alert ratio and absolute floor; needs independent rerun",
             stats.merge("blocking_eligible" => true))
    end

    def inconclusive_reason(base, cand, medians, base_median)
      return "fewer than #{@policy.min_samples} samples" if ([cand] + base).any? { |w| w[:samples].size < @policy.min_samples }
      return "fewer than #{@policy.min_baseline_runs} baseline runs" if base.size < @policy.min_baseline_runs
      return "noise bound uncalibrated" if @policy.noise_bound.nil?

      spread = (medians.max - medians.min) / base_median
      "baseline spread #{spread.round(4)} exceeds noise bound #{@policy.noise_bound}" if spread > @policy.noise_bound
    end

    def result(name, verdict, reason, stats = {})
      { "workload" => name, "verdict" => verdict, "reason" => reason }.merge(stats)
    end
  end

  def self.load_json(path)
    JSON.parse(File.read(path))
  rescue JSON::ParserError, SystemCallError => e
    raise Malformed, "#{path}: #{e.message}"
  end

  def self.exit_status(verdicts, policy)
    return 3 if verdicts["identity_mismatches"].any? || verdicts["summary"].key?("incomparable")
    return 0 unless policy.blocking?

    blocked = verdicts["workloads"].any? { |w| w["verdict"] == "inconclusive" || w["blocking_eligible"] }
    blocked ? 1 : 0
  end

  def self.run(argv, out: $stdout, err: $stderr)
    baselines = []
    options = { policy: DEFAULT_POLICY }
    parser = OptionParser.new do |o|
      o.banner = "Usage: check_regression.rb --baseline FILE [--baseline FILE ...] --candidate FILE [--policy FILE] [--output FILE]"
      o.on("--baseline FILE", "Baseline report; repeat for repeated baseline runs") { |v| baselines << v }
      o.on("--candidate FILE", "Candidate report") { |v| options[:candidate] = v }
      o.on("--policy FILE", "Policy file (default bench/performance-policy.json)") { |v| options[:policy] = v }
      o.on("--output FILE", "Also write the verdict JSON here") { |v| options[:output] = v }
    end
    parser.parse!(argv.dup)
    raise Malformed, "--baseline and --candidate are required" if baselines.empty? || options[:candidate].nil?

    policy = Policy.new(load_json(options[:policy]))
    reports = baselines.map { |p| Report.new(load_json(p), p) }
    verdicts = Comparison.new(reports, Report.new(load_json(options[:candidate]), options[:candidate]), policy).call
    json = JSON.pretty_generate(verdicts)
    File.write(options[:output], json) if options[:output]
    out.puts json
    exit_status(verdicts, policy)
  rescue Malformed, OptionParser::ParseError => e
    err.puts "check_regression: #{e.message}"
    2
  end
end

exit CheckRegression.run(ARGV) if $PROGRAM_NAME == __FILE__
