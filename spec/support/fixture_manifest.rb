# frozen_string_literal: true

require "bindata"
require "digest"
require "json"
require "io/wait"
require "rbconfig"

module FixtureManifest
  SCHEMA_VERSION = 1
  EXPECTED_COUNTS = { "emf" => 186, "emf-ea" => 21, "simple" => 1, "emf-corrupted" => 21 }.freeze

  module_function

  def fixtures(root)
    Dir.glob(File.join(root, "spec/fixtures/**/*.emf"), sort: false).sort.map do |path|
      { "path" => path.delete_prefix("#{root}/"), "sha256" => Digest::SHA256.file(path).hexdigest,
        "size_bytes" => File.size(path), "expected_format" => "emf" }
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
    require "emf"
    bytes = File.binread(path)
    detected = Emf.detect_format(bytes).to_s
    metafile = Emf.parse(bytes)
    { "detected_format" => detected, "outcome" => metafile.errors? ? "recovered" : "parsed" }
  rescue Emf::FormatError => e
    { "detected_format" => detected, "outcome" => "format_error", "format_error" => exception(e) }
  rescue StandardError => e
    { "detected_format" => detected, "outcome" => nil, "backend_exception" => exception(e) }
  end

  def exception(error)
    { "class" => error.class.name, "message" => error.message.byteslice(0, 2048).encode("UTF-8", invalid: :replace, undef: :replace) }
  end

  class Runner
    def initialize(timeout: 5, output_limit: 16_384, command: nil)
      @timeout = timeout
      @output_limit = output_limit
      @command = command || [RbConfig.ruby, "-I", File.expand_path("../../lib", __dir__), __FILE__, "--observe"]
    end

    def call(path)
      reader, writer = IO.pipe
      pid = Process.spawn(*@command, path, out: writer, err: writer, pgroup: true)
      writer.close
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + @timeout
      output = read_output(reader, deadline)
      status = wait_status(pid, deadline)
      return failure("process_failure", "exit_status" => status.exitstatus, "signal" => status.termsig) unless status.success?

      JSON.parse(output)
    rescue ReadFailure => e
      failure(e.message)
    rescue JSON::ParserError
      failure("invalid_observation")
    ensure
      writer&.close unless writer&.closed?
      reader&.close
      reap(pid) if pid
    end

    private

    class ReadFailure < StandardError; end

    def read_output(reader, deadline)
      output = +""
      loop do
        remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
        raise ReadFailure, "timeout" if remaining <= 0 || !reader.wait_readable(remaining)

        chunk = reader.read_nonblock(4096, exception: false)
        return output if chunk.nil?
        next if chunk == :wait_readable

        output << chunk
        raise ReadFailure, "output_limit" if output.bytesize > @output_limit
      end
    end

    def wait_status(pid, deadline)
      loop do
        result = Process.wait2(pid, Process::WNOHANG)
        return result.last if result
        raise ReadFailure, "timeout" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

        sleep 0.01
      end
    end

    def failure(kind, details = {})
      { "detected_format" => nil, "outcome" => nil, "safety_failure" => { "kind" => kind }.merge(details) }
    end

    def reap(pid)
      Process.kill("KILL", -pid)
      Process.wait(pid)
    rescue Errno::ESRCH, Errno::ECHILD
      nil
    end
  end

  class Inventory
    def initialize(root)
      @root = File.expand_path(root)
    end

    def generate
      entries = FixtureManifest.fixtures(@root)
      verify_counts(entries)
      runner = Runner.new
      {
        "schema_version" => SCHEMA_VERSION,
        "backend" => { "name" => "ruby", "ruby_version" => RUBY_VERSION,
                       "bindata_version" => Gem.loaded_specs.fetch("bindata").version.to_s,
                       "parser_source_sha256" => FixtureManifest.source_sha256(@root) },
        "counts" => FixtureManifest.counts(entries),
        "fixtures" => entries.map { |entry| entry.merge(runner.call(File.join(@root, entry.fetch("path")))) }
      }
    end

    def check(manifest)
      return false unless valid_structure?(manifest)

      entries = FixtureManifest.fixtures(@root)
      verify_counts(entries)
      return false unless current_backend?(manifest)
      return false unless manifest["counts"] == FixtureManifest.counts(entries)

      saved = manifest.fetch("fixtures")
      metadata = saved.map { |entry| entry.slice("path", "sha256", "size_bytes", "expected_format") }
      metadata == entries && saved.all? { |entry| valid_observation?(entry) }
    end

    private

    def valid_structure?(manifest)
      manifest.is_a?(Hash) && manifest["backend"].is_a?(Hash) &&
        manifest["fixtures"].is_a?(Array) && manifest["fixtures"].all?(Hash)
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
