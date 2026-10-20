# frozen_string_literal: true

require "digest"
require "json"
require "rbconfig"
require "emf"
require "emf/native"
require "emf/native/loader"
require_relative "process_supervisor"

module NativeThreadAcceptance
  ROOT = File.expand_path("../..", __dir__)
  FIXTURES = %w[emf/test-007.emf wmf/standard-line.wmf wmf/placeable-line.wmf].freeze
  REPETITIONS = 3

  module_function

  def run
    library = ENV.fetch("EMF_TEST_NATIVE_LIBRARY")
    raise "native library missing: #{library}" unless File.file?(library)

    script = 'require "./spec/support/native_thread_acceptance"; puts JSON.generate(NativeThreadAcceptance.exercise)'
    result = ProcessSupervisor.new(wall_seconds: 20, rss_limit_bytes: 512 * 1024 * 1024).call(
      [RbConfig.ruby, "-W0", "-Ilib", "-e", script],
      env: { "EMF_BACKEND" => "native", "EMF_NATIVE_LIBRARY" => library }
    )
    raise "thread acceptance child failed: #{result.to_h.inspect}" unless result.success?

    JSON.parse(result.output)
  end

  def loader
    Emf::Native::Loader.new(ENV.fetch("EMF_NATIVE_LIBRARY"))
  end

  # Each worker exclusively owns its loader and every handle it creates. Only copied Ruby strings escape scopes.
  def capture(native, path, bytes)
    wmf = path.end_with?(".wmf")
    native.public_send(wmf ? :wmf_document : :document, bytes) do |document|
      yield if block_given?
      snapshot = native.public_send(wmf ? :wmf_snapshot : :snapshot, document)
      record = native.record_bytes(document, 0) unless wmf
      [snapshot, record]
    end
  end

  def digest(copies)
    copies.map { |bytes| bytes && Digest::SHA256.hexdigest(bytes) }
  end

  def observed_loader
    native = loader
    frees = Hash.new(0)
    probe = Module.new do
      define_method(:invoke) do |name, *arguments|
        result = super(name, *arguments)
        frees[name.to_s] += 1 if name.to_s.end_with?("_free") && arguments.first != 0
        result
      end
    end
    native.singleton_class.prepend(probe)
    [native, frees]
  end

  def valid_worker(path, ready, start, rejected)
    native, frees = observed_loader
    input = File.binread(File.join(ROOT, "spec/fixtures", path))
    baseline = capture(native, path, input) # Also initializes WMF functions before synchronization.
    observations = Array.new(REPETITIONS) do
      bytes = input.dup
      copies = capture(native, path, bytes) do
        ready << true
        start.pop
        rejected.pop # Keep this document alive until both malformed calls have released their errors.
      end
      bytes.replace("discarded input")
      raise "copied bytes changed after native frees: #{path}" unless copies == baseline

      digest(copies)
    end
    functions = native.instance_variable_get(:@functions)
    { path: path, baseline: digest(baseline), observations: observations, frees: frees,
      gvl_released: functions.values.none?(&:need_gvl?) }
  end

  def malformed_worker(ready, start, rejected)
    native, frees = observed_loader
    messages = Array.new(REPETITIONS) do
      ready << true
      start.pop
      errors = %i[document wmf_document].map do |operation|
        native.public_send(operation, "invalid") { raise "malformed input unexpectedly parsed" }
      rescue Emf::FormatError => e
        [e.class.name, e.message]
      end
      rejected.each { |gate| gate << true }
      errors
    end
    { messages: messages, frees: frees }
  end

  def exercise
    Thread.abort_on_exception = true # Fail the isolated child immediately if a worker cannot reach its barrier.
    ready = Queue.new
    gates = Array.new(FIXTURES.size + 1) { Queue.new }
    rejected = Array.new(FIXTURES.size) { Queue.new }
    workers = FIXTURES.each_with_index.map do |path, index|
      Thread.new { valid_worker(path, ready, gates[index], rejected[index]) }
    end
    workers << Thread.new { malformed_worker(ready, gates.last, rejected) }
    REPETITIONS.times do
      workers.size.times { ready.pop }
      gates.each { |gate| gate << true }
    end
    results = workers.map(&:value) # Propagate every worker failure, including errors after its final barrier.
    { valid: results.take(FIXTURES.size), malformed: results.last, repetitions: REPETITIONS }
  end
end
