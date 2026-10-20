# frozen_string_literal: true

require "json"
require "digest"
require "optparse"

module EmfsvgComparison
  class InvalidReport < StandardError; end

  # Validation is deliberately limited to the downstream schema, not parser reports.
  module Validation
    STAGES = %w[from_bytes from_file].freeze

    def require_value(condition, label)
      raise InvalidReport, label unless condition
    end

    def value(object, key)
      require_value(object.is_a?(Hash) && object.key?(key), "missing #{key}")
      object.fetch(key)
    end

    def string(object, key, pattern = /\S/)
      result = value(object, key)
      require_value(result.is_a?(String) && pattern.match?(result), "invalid #{key}")
      result
    end

    def digest(object, key)
      string(object, key, /\A[0-9a-f]{64}\z/)
    end

    def number(result, label, minimum: 0, positive: false)
      require_value(result.is_a?(Numeric) && result.finite? && result >= minimum && (!positive || result.positive?),
                    "invalid #{label}")
      result
    end

    def array(object, key)
      result = value(object, key)
      require_value(result.is_a?(Array), "invalid #{key}")
      result
    end

    def gems(object)
      versions = value(object, "gems")
      require_value(versions.is_a?(Hash) && !versions.empty?, "invalid gems")
      versions.each { |name, version| require_value(name.is_a?(String) && version.is_a?(String) && !version.empty?, "invalid gems") }
      string(versions, "bindata")
      versions
    end

    def environment
      env = value(data, "environment")
      %w[version engine description platform executable].each { |key| string(value(env, "ruby"), key) }
      %w[sysname nodename release version machine].each { |key| string(value(env, "os"), key) }
      string(env, "host")
      gems(env)
    end

    def input_metadata
      inputs = value(data, "inputs")
      digest(inputs, "manifest_sha256")
      require_value(value(inputs, "manifest_schema_version").is_a?(Integer) && inputs.fetch("manifest_schema_version").positive?,
                    "invalid manifest_schema_version")
      %w[selected_outcomes fixture_globs].each do |key|
        array(inputs, key).each { |item| require_value(item.is_a?(String) && !item.empty?, "invalid #{key}") }
      end
      require_value(!inputs.fetch("selected_outcomes").empty?, "selected_outcomes must not be empty")
      limit = value(inputs, "fixture_limit")
      require_value(limit.nil? || (limit.is_a?(Integer) && limit.positive?), "invalid fixture_limit")
      inputs
    end

    def validity(object, golden)
      valid = value(object, "validity")
      require_value(value(valid, "golden_identical") == true, "golden_identical must be true")
      require_value(digest(valid, "svg_sha256") == golden.fetch("sha256"), "SVG SHA differs from golden")
      require_value(value(valid, "svg_size_bytes") == golden.fetch("size_bytes"), "SVG size differs from golden")
    end

    def worker(object)
      require_value(value(object, "status") == "ok", "worker status must be ok")
      sources = value(object, "resolved_sources")
      %w[emf emfsvg].each { |key| string(sources, key) }
      gems(object)
    end

    def stage(stage, iterations)
      samples = array(stage, "samples_ns")
      require_value(samples.size == iterations, "samples_ns count differs from iterations")
      samples.each { |sample| number(sample, "samples_ns", positive: true) }
      summary = value(stage, "summary_ns")
      count = value(summary, "count")
      require_value(count.is_a?(Integer) && count == iterations, "summary count differs from iterations")
      median = number(value(summary, "median"), "median", positive: true)
      sorted = samples.sort
      expected = (sorted[(iterations - 1) / 2] + sorted[iterations / 2]) / 2.0
      require_value(median == expected, "median differs from samples_ns")
      number(value(stage, "allocated_objects_median"), "allocated_objects_median")
    end
  end

  class Report
    include Validation

    attr_reader :data, :path, :sha256

    def initialize(path, backend)
      @path = File.realpath(path)
      bytes = File.binread(@path)
      @sha256 = Digest::SHA256.hexdigest(bytes)
      @data = JSON.parse(bytes)
      metadata(backend)
      workload
    rescue InvalidReport => e
      raise InvalidReport, "#{backend} report: #{e.message}"
    end

    private

    def metadata(backend)
      require_value(value(data, "schema_version") == 1 && value(data, "kind") == "emfsvg-conversion-baseline", "unsupported schema/kind")
      require_value(value(data, "backend") == backend, "expected #{backend} backend")
      require_value(array(data, "failures").empty?, "failures must be empty")
      revision = value(data, "revision")
      string(revision, "git_sha", /\A[0-9a-f]{40}\z/)
      require_value(value(revision, "git_tracked_changes").is_a?(String), "invalid git_tracked_changes")
      require_value(value(revision, "manifest_matches_sources") == true, "manifest_matches_sources must be true")
      require_value(digest(revision, "manifest_parser_source_sha256") == digest(revision, "parser_source_sha256"),
                    "manifest source mismatch")
      consumer = value(data, "consumer")
      string(consumer, "git_sha", /\A[0-9a-f]{40}\z/)
      %w[source_sha256 golden_spec_sha256].each { |key| digest(consumer, key) }
      %w[path dependency_override golden_spec].each { |key| string(consumer, key) }
      require_value(value(consumer, "git_tracked_changes") == "", "consumer must be clean")
      environment
      method_metadata
      digest(value(data, "native_library"), "sha256") if backend == "native"
    end

    def method_metadata
      method = value(data, "method")
      %w[iterations warmups].each do |key|
        result = value(method, key)
        require_value(result.is_a?(Integer) && result >= (key == "iterations" ? 1 : 0), "invalid #{key}")
      end
      number(value(method, "child_timeout_seconds"), "child_timeout_seconds", positive: true)
      %w[gc_policy isolation file_io golden_policy dependencies].each { |key| string(method, key) }
      string(value(method, "timing"), "clock")
      require_value(value(method.fetch("timing"), "unit") == "nanoseconds", "invalid timing unit")
      STAGES.each { |key| string(value(method, "stages"), key) }
      array(method, "inseparable_boundaries").each { |boundary| require_value(boundary.is_a?(String), "invalid boundary") }
    end

    def workload
      inputs = input_metadata
      fixtures = array(data, "fixtures")
      count = value(inputs, "fixture_count")
      require_value(count.is_a?(Integer) && !fixtures.empty? && count == fixtures.size, "invalid fixture_count")
      inventory = array(data, "golden_inventory")
      require_value(inventory.size == fixtures.size, "golden inventory count mismatch")
      fixtures.zip(inventory).each { |fixture, golden| fixture(fixture, golden) }
      require_value(fixtures.map { |entry| entry.fetch("path") }.uniq.size == fixtures.size, "duplicate fixtures")
      cold(fixtures, inventory)
    end

    def fixture(fixture, golden)
      path = string(fixture, "path")
      digest(fixture, "sha256")
      size = value(fixture, "size_bytes")
      require_value(size.is_a?(Integer) && size >= 0, "invalid fixture size_bytes")
      string(fixture, "outcome")
      require_value(value(golden, "fixture") == path, "golden inventory fixture mismatch")
      string(golden, "path")
      digest(golden, "sha256")
      size = value(golden, "size_bytes")
      require_value(size.is_a?(Integer) && size >= 0, "invalid golden size_bytes")
      worker(fixture)
      validity(fixture, golden)
      STAGES.each { |key| stage(value(value(fixture, "stages"), key), data.fetch("method").fetch("iterations")) }
    end

    def cold(fixtures, inventory)
      cold = value(data, "cold_load")
      index = fixtures.index { |fixture| fixture.fetch("path") == value(cold, "fixture") }
      require_value(!index.nil?, "cold fixture is not selected")
      array(cold, "runs").each do |run|
        worker(run)
        validity(run, inventory.fetch(index))
        number(value(run, "require_emfsvg_ns"), "require_emfsvg_ns", positive: true)
        STAGES.each do |key|
          first = value(value(run, "first_call"), key)
          number(value(first, "ns"), "first_call ns", positive: true)
          number(value(first, "allocated_objects"), "first_call allocated_objects")
        end
      end
    end
  end

  class Comparison
    include Validation

    def initialize(ruby_report, native_report)
      @ruby = ruby_report
      @native = native_report
    end

    def result
      compatible
      {
        schema_version: 1, kind: "emfsvg-conversion-comparison", status: "informational",
        reports: { ruby: { path: @ruby.path, sha256: @ruby.sha256 }, native: { path: @native.path, sha256: @native.sha256 } },
        provenance: @ruby.data.slice("revision", "inputs", "consumer", "environment", "method"),
        native_library: @native.data.fetch("native_library"),
        native_boundaries: @native.data.fetch("method").fetch("inseparable_boundaries"),
        cold_load: { fixture: @ruby.data.fetch("cold_load").fetch("fixture"), runs: @ruby.data.fetch("cold_load").fetch("runs").size },
        fixtures: @ruby.data.fetch("fixtures").zip(@native.data.fetch("fixtures")).map { |ruby, native| ratios(ruby, native) },
        limitations: ["Descriptive ratios only: no calibrated thresholds or speed claim; runs may be concurrent or have few samples.",
                      "Ruby object allocations exclude Rust allocations; this is not total allocation or memory usage."]
      }
    end

    private

    def same(ruby, native, label)
      require_value(ruby == native, "incompatible #{label}")
    end

    def matching_gems(ruby, native)
      same(ruby, native.reject { |name, _| name == "fiddle" && !ruby.key?(name) }, "gem versions")
    end

    def compatible
      ruby = @ruby.data
      native = @native.data
      %w[revision inputs consumer golden_inventory].each { |key| same(ruby.fetch(key), native.fetch(key), key) }
      same(ruby.fetch("environment").except("gems"), native.fetch("environment").except("gems"), "environment")
      matching_gems(ruby.fetch("environment").fetch("gems"), native.fetch("environment").fetch("gems"))
      same(ruby.fetch("method").except("inseparable_boundaries"), native.fetch("method").except("inseparable_boundaries"), "method")
      same(ruby.fetch("cold_load").fetch("fixture"), native.fetch("cold_load").fetch("fixture"), "cold fixture")
      ruby_runs = ruby.fetch("cold_load").fetch("runs")
      native_runs = native.fetch("cold_load").fetch("runs")
      same(ruby_runs.size, native_runs.size, "cold run count")
      ruby.fetch("fixtures").zip(native.fetch("fixtures")).each do |left, right|
        same(left.slice("path", "sha256", "size_bytes", "outcome", "validity"),
             right.slice("path", "sha256", "size_bytes", "outcome", "validity"), "ordered fixture identity")
      end
      (ruby.fetch("fixtures") + ruby_runs).zip(native.fetch("fixtures") + native_runs).each do |left, right|
        same(left.fetch("resolved_sources"), right.fetch("resolved_sources"), "resolved sources")
        matching_gems(left.fetch("gems"), right.fetch("gems"))
      end
    end

    def ratios(ruby, native)
      ruby.slice("path", "sha256", "size_bytes", "outcome", "validity").merge("stages" => STAGES.to_h do |name|
        left = ruby.fetch("stages").fetch(name)
        right = native.fetch("stages").fetch(name)
        baseline = left.fetch("allocated_objects_median")
        timing_ratio = right.fetch("summary_ns").fetch("median").fdiv(left.fetch("summary_ns").fetch("median"))
        allocation_ratio = baseline.zero? ? nil : right.fetch("allocated_objects_median").fdiv(baseline)
        number(timing_ratio, "timing ratio", positive: true)
        number(allocation_ratio, "allocation ratio") unless allocation_ratio.nil?
        [name, {
          ruby_median_ns: left.fetch("summary_ns").fetch("median"), native_median_ns: right.fetch("summary_ns").fetch("median"),
          native_over_ruby_time: timing_ratio,
          ruby_allocated_objects_median: baseline, native_allocated_objects_median: right.fetch("allocated_objects_median"),
          native_over_ruby_allocated_objects: allocation_ratio,
          allocation_ratio_reason: baseline.zero? ? "Ruby baseline allocated_objects_median is zero" : nil
        }]
      end)
    end
  end

  class CLI
    def initialize(arguments)
      @arguments = arguments
    end

    def run
      paths = {}
      parser = OptionParser.new do |options|
        %w[ruby native output].each { |key| options.on("--#{key} PATH") { |path| paths[key] = path } }
      end
      parser.parse!(@arguments)
      raise InvalidReport, "required: --ruby PATH --native PATH --output PATH" unless paths.size == 3 && @arguments.empty?

      reports = %w[ruby native].map { |backend| Report.new(paths.fetch(backend), backend) }
      output = paths.fetch("output")
      if File.exist?(output) && reports.any? { |report| File.identical?(output, report.path) }
        raise InvalidReport, "output must not overwrite an input report"
      end

      result = Comparison.new(*reports).result
      File.write(output, "#{JSON.pretty_generate(result)}\n")
      0
    rescue InvalidReport, JSON::ParserError, OptionParser::ParseError, SystemCallError, TypeError => e
      warn "emfsvg comparison: #{e.message}"
      2
    end
  end
end
