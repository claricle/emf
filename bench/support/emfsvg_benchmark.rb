# frozen_string_literal: true

require_relative "parser_benchmark"

module EmfsvgBenchmark
  PINNED_REVISION = "101356dcf673841fda0693076131bca7a0f34948"
  STAGES = { "from_bytes" => "Emfsvg.from_bytes(bytes): parse and SVG rendering, excluding file IO",
             "from_file" => "Emfsvg.from_file(path): file read, parse and SVG rendering" }.freeze
  SCRIPT = File.expand_path("../emfsvg.rb", __dir__)

  class Checkout
    attr_reader :path, :revision

    def initialize(path, revision)
      raise ParserBenchmark::UsageError, "EMFSVG_PATH or --emfsvg-path is required" unless path

      @path = File.realpath(path)
      @revision = revision
      raise ParserBenchmark::UsageError, "emfsvg revision differs from #{revision}" unless git("rev-parse", "HEAD") == revision
      unless git("status", "--porcelain", "--untracked-files=no") == ""
        raise ParserBenchmark::UsageError, "emfsvg checkout has tracked changes"
      end
    rescue Errno::ENOENT => e
      raise ParserBenchmark::UsageError, e.message
    end

    def to_h
      { "path" => path, "git_sha" => revision, "git_tracked_changes" => "",
        "source_sha256" => FixtureManifest.source_sha256(path), "dependency_override" => File.join(ParserBenchmark::ROOT, "lib"),
        "golden_spec" => "spec/golden_spec.rb", "golden_spec_sha256" => digest("spec/golden_spec.rb") }
    end

    def golden(entry)
      File.join(path, "spec/fixtures/golden", "#{File.basename(entry.fetch('path'), '.emf')}.svg")
    end

    private

    def digest(relative)
      Digest::SHA256.file(File.join(path, relative)).hexdigest
    end

    def git(*args)
      IO.popen(["git", *args], chdir: path, err: File::NULL, &:read).strip
    end
  end

  class Worker < ParserBenchmark::WarmWorker
    def initialize(checkout:, cold: false, **options)
      super(**options)
      @checkout = checkout
      @cold = cold
    end

    def call
      ENV["EMF_BACKEND"] = @backend
      started = ParserBenchmark::Clock.now
      require "emfsvg"
      loaded_ns = ParserBenchmark::Clock.now - started
      loaded = { "emf" => Emf.method(:parse).source_location.first, "emfsvg" => Emfsvg.method(:from_bytes).source_location.first }
      verify_sources(loaded)
      @bytes = File.binread(@path)
      raise ParserBenchmark::InputMismatch, "sha256 differs from the manifest" unless Digest::SHA256.hexdigest(@bytes) == @sha256

      expected = File.binread(@checkout.golden("path" => @path))
      @expected = expected
      first = trial
      result = { "status" => "ok", "resolved_sources" => loaded,
                 "gems" => Gem.loaded_specs.transform_values { |spec| spec.version.to_s },
                 "validity" => { "golden_identical" => true, "svg_sha256" => Digest::SHA256.hexdigest(expected),
                                 "svg_size_bytes" => expected.bytesize } }
      return result.merge("require_emfsvg_ns" => loaded_ns, "first_call" => first) if @cold

      @warmups.times { trial }
      memory = [ParserBenchmark::Memory.sample]
      samples = Array.new(@iterations) { trial.tap { memory << ParserBenchmark::Memory.sample } }
      stages = STAGES.keys.to_h do |stage|
        [stage, { "samples_ns" => samples.map { |s| s.fetch(stage).fetch("ns") },
                  "allocated_objects" => samples.map { |s| s.fetch(stage).fetch("allocated_objects") } }]
      end
      result.merge("stages" => stages, "memory" => memory_report(memory))
    rescue LoadError => e
      { "status" => "error", "error" => error_payload(e).merge("runtime" => load_error_runtime) }
    rescue StandardError => e
      { "status" => "error", "error" => error_payload(e) }
    end

    private

    def error_payload(error)
      { "class" => error.class.name, "message" => error.message.byteslice(0, 2048).scrub }
    end

    def load_error_runtime
      { "ruby_version" => RUBY_VERSION, "gem_dir" => Gem.dir.byteslice(0, 512).scrub,
        "gem_path" => Gem.path.first(20).map { |path| path.byteslice(0, 512).scrub },
        "bundler_version" => defined?(Bundler::VERSION) ? Bundler::VERSION : nil }
    end

    def verify_sources(loaded)
      expected = { "emf" => File.join(ParserBenchmark::ROOT, "lib/emf.rb"), "emfsvg" => File.join(@checkout.path, "lib/emfsvg.rb") }
      return if loaded.all? { |name, path| File.realpath(path) == File.realpath(expected.fetch(name)) }

      raise ParserBenchmark::InputMismatch, "resolved gem sources differ from the selected checkouts"
    end

    def trial
      result = {}
      STAGES.each_key do |stage|
        svg = measure(result, stage) { stage == "from_bytes" ? Emfsvg.from_bytes(@bytes) : Emfsvg.from_file(@path) }
        raise ParserBenchmark::InputMismatch, "#{stage} output differs from golden" unless svg.b == @expected.b
      end
      result
    end
  end

  class Run < ParserBenchmark::Run
    def initialize(options, argv, checkout)
      super(options, argv)
      @checkout = checkout
    end

    private

    def select_fixtures
      selected = super
      missing = selected.reject { |entry| File.file?(@checkout.golden(entry)) }
      raise ParserBenchmark::UsageError, "missing golden for #{missing.first.fetch('path')}" unless missing.empty?

      selected
    end

    def build_report(selected)
      report = super
      report.merge("kind" => "emfsvg-conversion-baseline", "command" => [RbConfig.ruby, "bench/emfsvg.rb", *@argv],
                   "consumer" => @checkout.to_h,
                   "golden_inventory" => selected.map do |entry|
                     golden = @checkout.golden(entry)
                     { "fixture" => entry.fetch("path"), "path" => golden.delete_prefix("#{@checkout.path}/"),
                       "sha256" => Digest::SHA256.file(golden).hexdigest, "size_bytes" => File.size(golden) }
                   end)
    end

    def measure_fixture(entry)
      result = child(["--worker", "warm", "--sha256", entry.fetch("sha256"), "--iterations", @options.iterations.to_s,
                      "--warmups", @options.warmups.to_s], File.expand_path(entry.fetch("path"), ParserBenchmark::ROOT))
      identity = entry.slice("path", "sha256", "size_bytes", "outcome")
      return identity.merge("status" => "failed", "failure" => result["safety_failure"]) if result["safety_failure"]
      return identity.merge("status" => "error", "failure" => result["error"]) unless result["status"] == "ok"

      identity.merge(result.slice("status", "validity", "memory", "resolved_sources", "gems"),
                     "stages" => result.fetch("stages").transform_values { |data| stage_report(data) })
    end

    def child(args, path)
      gem_paths = Gem.path
      gem_paths += Bundler.unbundled_env.fetch("GEM_PATH", "").split(File::PATH_SEPARATOR) if defined?(Bundler)
      command = ["env", "-u", "BUNDLER_SETUP", "GEM_PATH=#{gem_paths.uniq.join(File::PATH_SEPARATOR)}",
                 RbConfig.ruby, "-I", File.join(ParserBenchmark::ROOT, "lib"), "-I", File.join(@checkout.path, "lib"), SCRIPT,
                 "--emfsvg-path", @checkout.path, "--revision", @checkout.revision, "--backend", @options.backend, *args]
      supervised = ParserBenchmark.runner(@options, self.class::OUTPUT_LIMIT, command)
      defined?(Bundler) ? Bundler.with_unbundled_env { supervised.call(path) } : supervised.call(path)
    end

    def cold_load(selected)
      smallest = selected.min_by { |entry| entry.fetch("size_bytes") }
      runs = Array.new(@options.cold_runs) do
        child(["--worker", "cold", "--sha256", smallest.fetch("sha256")], File.join(ParserBenchmark::ROOT, smallest.fetch("path")))
      end
      { "fixture" => smallest.fetch("path"), "runs" => runs,
        "note" => "Fresh processes; require_emfsvg_ns includes emf and dependencies, first_call includes autoloads." }
    end

    def method_description
      boundaries = []
      if @options.backend == "native"
        boundaries = @backend_description.inseparable_boundaries.first(1)
        boundaries << "Backend selection and native adapter loading occur inside each conversion; " \
                      "Ruby allocated_objects excludes Rust allocations."
      end
      super.merge("stages" => STAGES, "inseparable_boundaries" => boundaries,
                  "file_io" => "from_bytes excludes file IO; from_file includes the file read",
                  "golden_policy" => "Exact bytes checked after each timed region; mismatches fail the fixture. No golden is rewritten.",
                  "dependencies" => "Children retain configured and unbundled gem directories outside Bundler; " \
                                    "both checkout lib paths are forced and source locations verified. " \
                                    "Gem versions are reported; gemspec constraints are not resolved.")
    end

    def slowest_case(fixtures)
      best = fixtures.select { |fixture| fixture["status"] == "ok" }.max_by do |fixture|
        fixture.dig("stages", "from_file", "summary_ns", "median")
      end
      return nil unless best

      best.slice("path", "sha256", "size_bytes").merge(
        "stage" => "from_file", "median_ns" => best.dig("stages", "from_file", "summary_ns", "median"),
        "issue_15_fixture_identified" => false
      )
    end

    def summarize(report)
      puts "Wrote #{@options.output}: #{report['fixtures'].size} fixtures, #{report['failures'].size} failures"
    end
  end

  class CLI < ParserBenchmark::CLI
    def run
      options = parse(@argv)
      @checkout = Checkout.new(@consumer_path || ENV.fetch("EMFSVG_PATH", nil), @revision || PINNED_REVISION)
      options.worker ? run_worker(options) : Run.new(options, @argv, @checkout).run
    rescue ParserBenchmark::UsageError, OptionParser::ParseError => e
      warn "bench/emfsvg.rb: #{e.message}"
      2
    end

    private

    def parser(options)
      super.tap do |opts|
        opts.banner = "Usage: EMFSVG_PATH=/path/to/emfsvg ruby bench/emfsvg.rb " \
                      "--manifest FILE --backend ruby --output FILE --rss-limit-mb MB"
        opts.on("--emfsvg-path PATH", "Pinned emfsvg checkout (or EMFSVG_PATH)") { |value| @consumer_path = value }
        opts.on("--revision SHA", "Expected emfsvg commit (default #{PINNED_REVISION})") { |value| @revision = value }
      end
    end

    def run_worker(options)
      output = $stdout.dup
      $stdout.reopen(File::NULL, "w")
      $stderr.reopen(File::NULL, "w")
      worker = Worker.new(checkout: @checkout, cold: options.worker == "cold", path: options.path,
                          sha256: options.sha256, iterations: options.iterations, warmups: options.warmups, backend: options.backend)
      output.write(JSON.generate(worker.call))
      output.close
      0
    end
  end
end
