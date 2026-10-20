# frozen_string_literal: true

require_relative "parser_benchmark"

# Diagnostic decomposition of the existing EMF adapter using its public loader
# block, which retains ownership of document cleanup even when hydration fails.
module NativeComponentsBenchmark
  SCRIPT = File.join(ParserBenchmark::ROOT, "bench/native_components.rb")
  STAGES = {
    "parse_handle" => "Loader.document entry to block entry: native parse, FFI and document handle setup",
    "snapshot_copy" => "Loader.snapshot: native snapshot creation, ABI buffer copy into Ruby and buffer cleanup",
    "snapshot_decode" => "Snapshot.new: decode the copied snapshot in Ruby",
    "hydration" => "Hydrator.call: construct the Ruby model with lazy wires",
    "cleanup" => "Loader.document block exit to return: document cleanup and block unwinding",
    "component_total" => "Cached-loader document entry through cleanup, including component instrumentation",
    "public_parse" => "Emf.parse(bytes): forced native selection/loading, format detection and complete adapter parse"
  }.freeze

  BOUNDARIES = [
    "Components use a cached loader initialized outside timing; public_parse separately includes backend selection/loading.",
    "parse_handle is not a pure Rust kernel measurement. snapshot_copy includes native snapshot creation, FFI copy and buffer free.",
    "cleanup includes block unwinding; component_total includes instrumentation overhead. Do not add public_parse to components.",
    "No serialization kernel is measured: the native adapter delegates serialization to Ruby. Ruby allocations exclude Rust allocations.",
    "Only EMF/EMF+ Loader.document snapshots are supported; WMF fixtures fail explicitly."
  ].freeze

  class Components
    def initialize(loader:, snapshot:, hydrator:, clock: ParserBenchmark::Clock)
      @loader = loader
      @snapshot = snapshot
      @hydrator = hydrator
      @clock = clock
    end

    def call(bytes)
      samples = {}
      cleanup_started = nil
      started = @clock.now
      model = @loader.document(bytes) do |document|
        samples["parse_handle"] = @clock.now - started
        copied = time(samples, "snapshot_copy") { @loader.snapshot(document) }
        snapshot = time(samples, "snapshot_decode") { @snapshot.new(copied) }
        time(samples, "hydration") { @hydrator.new(snapshot, bytes).call }
      ensure
        cleanup_started = @clock.now
      end
      samples["cleanup"] = @clock.now - cleanup_started
      samples["component_total"] = @clock.now - started
      [model, samples]
    end

    private

    def time(samples, stage)
      started = @clock.now
      value = yield
      samples[stage] = @clock.now - started
      value
    end
  end

  class Worker < ParserBenchmark::WarmWorker
    private

    def validity
      raise ParserBenchmark::UsageError, "component snapshots support EMF/EMF+ only" unless Emf.detect_format(@bytes) == :emf

      Emf::Native.backend # Load and validate native dependencies; never fall back.
      @components = Components.new(loader: Emf::Native::Loader.new(Emf::Native::LibraryPath.new.call),
                                   snapshot: Emf::Native::Snapshot, hydrator: Emf::Native::Hydrator)
      model, = @components.call(@bytes) # Document cleanup has completed before any consumer.
      output = Emf.serialize(model)
      native = Emf.serialize(Emf.parse(@bytes))
      ruby = Emf::Emr::Serializer.call(Emf::Emr::Parser.call(@bytes))
      unless output == @bytes && output == native && output == ruby && model.errors.empty?
        raise ParserBenchmark::InputMismatch, "component model differs from fixture or public native/Ruby baseline"
      end

      @mutation = ParserBenchmark::WireMutation.new(model)
      if @mutation.supported?
        @mutation.apply(model)
        @mutation.verify(Emf.serialize(model), @bytes)
      end
      { "record_count" => model.records.size, "parse_error_count" => model.errors.size, "format" => model.format.to_s,
        "round_trip_identical" => true, "public_native_ruby_parity" => true, "consumers_after_document_cleanup" => true }
    end

    def trial
      GC.start
      _, durations = @components.call(@bytes)
      results = durations.transform_values { |ns| { "ns" => ns } }
      measure(results, "public_parse") { Emf.parse(@bytes) }
      results
    end

    def collect(samples)
      STAGES.keys.to_h { |stage| [stage, { "samples_ns" => samples.map { |sample| sample.fetch(stage).fetch("ns") } }] }
    end
  end

  class CLI < ParserBenchmark::CLI
    def initialize(argv)
      super(["--backend", "native", "--cold-runs", "0", *argv])
    end

    def run
      options = parse(@argv)
      options.worker ? run_worker(options) : Run.new(options, @argv).run
    rescue ParserBenchmark::UsageError, OptionParser::ParseError => e
      warn "bench/native_components.rb: #{e.message}"
      2
    end

    private

    def parse(argv)
      super.tap do |options|
        raise ParserBenchmark::UsageError, "only forced native backend is supported" unless options.backend == "native"
        raise ParserBenchmark::UsageError, "cold runs are not supported" unless options.cold_runs.zero?
        raise ParserBenchmark::UsageError, "only warm component workers are supported" if options.worker == "cold"
      end
    end

    def run_worker(options)
      output = $stdout.dup
      $stdout.reopen(File::NULL, "w")
      $stderr.reopen(File::NULL, "w")
      worker = Worker.new(path: options.path, sha256: options.sha256, iterations: options.iterations,
                          warmups: options.warmups, backend: "native")
      output.write(JSON.generate(worker.call))
      output.close
      0
    end
  end

  class Run < ParserBenchmark::Run
    private

    def build_report(selected)
      fixtures = selected.map { |entry| measure_fixture(entry) }
      { "schema_version" => ParserBenchmark::SCHEMA_VERSION, "kind" => "emf-native-components", "backend" => "native",
        "generated_at" => Time.now.utc.iso8601, "command" => ["ruby", "bench/native_components.rb", *@argv],
        **ParserBenchmark::Provenance.new(@manifest).to_h, "native_library" => library_identity,
        "inputs" => inputs(selected), "method" => method_description, "fixtures" => fixtures,
        "failures" => fixtures.reject { |fixture| fixture["status"] == "ok" }.map { |fixture| fixture.slice("path", "status", "failure") } }
    end

    def library_identity
      previous = ENV.fetch("EMF_NATIVE_LIBRARY", nil)
      require "emf"
      require_relative "../../lib/emf/native/library_path"
      path = Emf::Native::LibraryPath.new.call
      ENV["EMF_NATIVE_LIBRARY"] = path if path
      ParserBenchmark::BackendDescription.new("native").native_library
    rescue Emf::Native::Unavailable => e
      { "identity_error" => e.message }
    ensure
      ENV["EMF_NATIVE_LIBRARY"] = previous if defined?(previous)
    end

    def child(args, path)
      ParserBenchmark.runner(@options, self.class::OUTPUT_LIMIT,
                             [RbConfig.ruby, "-I", File.join(ParserBenchmark::ROOT, "lib"), SCRIPT, *args]).call(path)
    end

    def stage_report(data)
      { "samples_ns" => data.fetch("samples_ns"), "summary_ns" => ParserBenchmark::Stats.summarize(data.fetch("samples_ns")) }
    end

    def method_description
      super.merge("stages" => STAGES, "inseparable_boundaries" => BOUNDARIES,
                  "gc_policy" => "GC.start before each component_total and public_parse, outside timing; GC enabled inside",
                  "file_io" => "Excluded: fixture bytes read once per child; validation and mutation are outside timing",
                  "allocations" => "No per-component allocation samples: instrumentation would perturb these short adjacent boundaries")
    end
  end
end
