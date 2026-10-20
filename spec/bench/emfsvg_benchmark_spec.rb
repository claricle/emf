# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "bundler"
require_relative "../../bench/support/emfsvg_benchmark"
require_relative "../support/emfsvg_benchmark_checkout"
require_relative "../support/fixture_manifest"

RSpec.describe EmfsvgBenchmark::CLI do
  include EmfsvgBenchmarkCheckout

  before(:context) do
    @manifest_directory = Dir.mktmpdir("emfsvg-manifest")
    @manifest_path = File.join(@manifest_directory, "manifest.json")
    entries = FixtureManifest.fixtures(ParserBenchmark::ROOT).map do |entry|
      entry.merge("detected_format" => entry.fetch("expected_format") == "wmf" ? "wmf" : "emf",
                  "outcome" => "parsed")
    end
    manifest = {
      "schema_version" => FixtureManifest::SCHEMA_VERSION,
      "capture" => FixtureManifest::CAPTURE_METADATA,
      "backend" => { "name" => "ruby", "bindata_version" => Gem.loaded_specs.fetch("bindata").version.to_s,
                     "parser_source_sha256" => FixtureManifest.source_sha256(ParserBenchmark::ROOT) },
      "counts" => FixtureManifest.counts(entries), "fixtures" => entries
    }
    File.write(@manifest_path, JSON.generate(manifest))
  end

  after(:context) { FileUtils.remove_entry(@manifest_directory) }

  let(:directory) { Dir.mktmpdir("emfsvg-benchmark") }
  let(:checkout) { File.join(directory, "consumer") }
  let(:revision) { create_emfsvg_checkout(checkout) }
  let(:result_path) { File.join(directory, "result.json") }
  let(:report) { JSON.parse(File.read(result_path)) }
  let(:args) do
    ["--manifest", @manifest_path, "--emfsvg-path", checkout,
     "--revision", revision, "--output", result_path, "--fixture", "spec/fixtures/simple/*", "--iterations", "2",
     "--warmups", "0", "--cold-runs", "1", "--rss-limit-mb", "512"]
  end

  after { FileUtils.remove_entry(directory) }

  it "measures actual conversion calls and records exact input, golden, dependency and source identities" do
    expect(described_class.new(args).run).to eq(0)
    fixture = report.fetch("fixtures").fetch(0)
    expect(fixture.fetch("validity")).to include("golden_identical" => true)
    expect(fixture.fetch("resolved_sources")).to eq("emf" => File.join(ParserBenchmark::ROOT, "lib/emf.rb"),
                                                    "emfsvg" => File.realpath(File.join(checkout, "lib/emfsvg.rb")))
    expect(fixture.fetch("gems")).to include("bindata")
    expect(fixture.fetch("stages").keys).to eq(%w[from_bytes from_file])
    fixture.fetch("stages").each_value { |stage| expect(stage.fetch("samples_ns")).to contain_exactly(be_positive, be_positive) }
    expect(report.fetch("consumer")).to include("git_sha" => revision, "dependency_override" => File.join(ParserBenchmark::ROOT, "lib"))
    golden = File.join(checkout, "spec/fixtures/golden/image1.svg")
    expect(report.fetch("golden_inventory")).to contain_exactly(include("sha256" => Digest::SHA256.file(golden).hexdigest))
    expect(report.dig("cold_load", "runs", 0)).to include("status" => "ok", "require_emfsvg_ns" => be_positive)
    expect(report.fetch("slowest_measured_case")).to include("stage" => "from_file", "issue_15_fixture_identified" => false)
  end

  def with_option(arguments, name, value)
    arguments.dup.tap { |a| a[a.index(name) + 1] = value }
  end

  it "requires an RSS ceiling and records it beside the child timeout" do
    without = args.each_slice(2).to_h.except("--rss-limit-mb").to_a.flatten
    expect { expect(described_class.new(without).run).to eq(2) }.to output(/--rss-limit-mb is required/).to_stderr
    expect(described_class.new(args).run).to eq(0)
    expect(report.fetch("method")).to include("child_timeout_seconds" => 60, "child_rss_limit_bytes" => 512 * 1024 * 1024)
  end

  it "reports a conversion child over the RSS ceiling as an rss_exceeded failure" do
    expect(described_class.new(with_option(args, "--rss-limit-mb", "1")).run).to eq(1)
    expect(report.fetch("fixtures").fetch(0)).to include("status" => "failed", "failure" => include("kind" => "rss_exceeded"))
    expect(report.fetch("slowest_measured_case")).to be_nil
  end

  it "reports warm conversions that outrun the deadline as a timeout without partial timings" do
    expect(described_class.new([*with_option(args, "--iterations", "100000000"), "--timeout", "1"]).run).to eq(1)
    fixture = report.fetch("fixtures").fetch(0)
    expect(fixture).to include("status" => "failed", "failure" => include("kind" => "timeout"))
    expect(fixture).not_to have_key("stages")
  end

  it "rejects a --timeout above the supervisor cap" do
    expect { expect(described_class.new([*args, "--timeout", "61"]).run).to eq(2) }.to output(/--timeout must be within 1..60/).to_stderr
    expect(File).not_to exist(result_path)
  end

  it "records golden drift as a failed conversion and preserves the golden" do
    arguments = args
    golden = File.join(checkout, "spec/fixtures/golden/image1.svg")
    File.write(golden, "changed golden")
    system("git", "add", ".", chdir: checkout, out: File::NULL)
    system("git", "-c", "user.name=Benchmark", "-c", "user.email=benchmark@example.test", "commit", "-qm", "change", chdir: checkout)
    arguments[arguments.index("--revision") + 1] = Open3.capture2("git", "rev-parse", "HEAD", chdir: checkout).first.strip

    expect(described_class.new(arguments).run).to eq(1)
    expect(report.fetch("failures")).to include(include("failure" => include("message" => /differs from golden/)))
    expect(report.fetch("failures").size).to eq(2)
    expect(report.fetch("failures").select { |failure| failure["stage"] == "cold_load" })
      .to contain_exactly(include("run" => 0, "failure" => include("message" => /differs from golden/)))
    expect(File.read(golden)).to eq("changed golden")
    expect(report.fetch("slowest_measured_case")).to be_nil
  end

  it "keeps isolated bundle dependencies available to unbundled warm and cold workers" do
    arguments = args
    consumer_home = File.join(directory, "consumer-gems")
    consumer_dependency = Gem::Specification.new do |gem|
      gem.name = "benchmark_consumer_dependency"
      gem.version = "1.0.0"
      gem.summary = "Dependency outside the parser bundle"
      gem.authors = ["Benchmark"]
    end
    consumer_lib = File.join(consumer_home, "gems", consumer_dependency.full_name, "lib")
    FileUtils.mkdir_p([consumer_lib, File.join(consumer_home, "specifications")])
    File.write(File.join(consumer_lib, "benchmark_consumer_dependency.rb"), "BENCHMARK_CONSUMER_DEPENDENCY = true\n")
    File.write(File.join(consumer_home, "specifications", "#{consumer_dependency.full_name}.gemspec"), consumer_dependency.to_ruby)
    consumer_source = File.join(checkout, "lib/emfsvg.rb")
    File.write(consumer_source, "require \"benchmark_consumer_dependency\"\n#{File.read(consumer_source)}")
    system("git", "add", ".", chdir: checkout, out: File::NULL)
    system("git", "-c", "user.name=Benchmark", "-c", "user.email=benchmark@example.test", "commit", "-qm", "dependency", chdir: checkout)
    arguments[arguments.index("--revision") + 1] = Open3.capture2("git", "rev-parse", "HEAD", chdir: checkout).first.strip
    bundle_path = File.join(directory, "bundle")
    gem_home = File.join(bundle_path, "ruby", RbConfig::CONFIG.fetch("ruby_version"))
    dependency = Gem.loaded_specs.fetch("bindata")
    FileUtils.mkdir_p([File.join(gem_home, "gems"), File.join(gem_home, "specifications")])
    FileUtils.cp_r(dependency.full_gem_path, File.join(gem_home, "gems"))
    FileUtils.cp(dependency.loaded_from, File.join(gem_home, "specifications"))
    gemfile = File.join(directory, "Gemfile")
    File.write(gemfile, "source \"https://rubygems.org\"\ngem \"bindata\", \"=#{dependency.version}\"\n")
    bundler_setup = File.join(File.dirname(Bundler.method(:setup).source_location.first), "bundler/setup.rb")
    environment = Bundler.unbundled_env.merge("BUNDLE_GEMFILE" => gemfile, "BUNDLE_PATH" => bundle_path,
                                              "GEM_HOME" => File.join(directory, "empty"),
                                              "GEM_PATH" => consumer_home, "RUBYOPT" => "-rbundler/setup",
                                              "BUNDLER_SETUP" => bundler_setup)
    ENV.keys.grep(/\ABUNDLER_ORIG_/).each { |key| environment[key] = nil }

    output, status = Open3.capture2e(environment, RbConfig.ruby, "-I", File.join(ParserBenchmark::ROOT, "lib"),
                                     EmfsvgBenchmark::SCRIPT, *arguments)

    expect(status.exitstatus).to eq(0), "#{output}\n#{report.fetch('failures').inspect}"
    workers = [report.fetch("fixtures").fetch(0), report.dig("cold_load", "runs", 0)]
    workers.each do |worker|
      expect(worker.fetch("status")).to eq("ok")
      expect(worker.fetch("gems")).to include("bindata" => dependency.version.to_s)
      expect(worker.fetch("gems")).to include("benchmark_consumer_dependency" => "1.0.0")
      expect(worker.fetch("gems")).not_to include("bundler")
      expect(worker.fetch("validity")).to include("golden_identical" => true)
    end
  end

  it "reports gem path details when loading the consumer fails" do
    consumer_lib = File.join(directory, "consumer", "lib")
    FileUtils.mkdir_p(consumer_lib)
    File.write(File.join(consumer_lib, "emfsvg.rb"), "require \"missing_consumer_dependency\"\n")
    $LOAD_PATH.unshift(consumer_lib)

    result = EmfsvgBenchmark::Worker.new(checkout: nil, path: "unused", sha256: "unused",
                                         iterations: 1, warmups: 0).call

    expect(result.fetch("status")).to eq("error")
    expect(result.dig("error", "class")).to eq("LoadError")
    expect(result.dig("error", "message")).to include("missing_consumer_dependency")
    expect(result.dig("error", "runtime")).to include(
      "ruby_version" => RUBY_VERSION,
      "gem_dir" => Gem.dir,
      "gem_path" => Gem.path.first(20),
      "bundler_version" => Bundler::VERSION
    )
  ensure
    $LOAD_PATH.delete(consumer_lib) if consumer_lib
  end

  it "rejects an unknown backend without silently falling back" do
    expect { expect(described_class.new([*args, "--backend", "unknown"]).run).to eq(2) }.to output(/unsupported backend/).to_stderr
    expect(File).not_to exist(result_path)
  end

  it "forces native in warm and cold conversions and fails instead of using the ambient Ruby backend" do
    arguments = [*args, "--backend", "native"]
    golden = File.join(checkout, "spec/fixtures/golden/image1.svg")
    expected = File.binread(golden)
    with_emf_backend_environment(backend: "ruby", library: File.join(directory, "missing-library")) do
      expect(described_class.new(arguments).run).to eq(1)
      expect(report.fetch("backend")).to eq("native")
      expect(report.fetch("failures")).to contain_exactly(
        include("failure" => include("class" => "Emf::Native::Unavailable")),
        include("stage" => "cold_load", "run" => 0, "failure" => include("class" => "Emf::Native::Unavailable"))
      )
      expect(report.fetch("slowest_measured_case")).to be_nil
      expect(report.dig("native_library", "path")).to eq(ENV.fetch("EMF_NATIVE_LIBRARY"))
      expect(report.dig("method", "inseparable_boundaries").join).to include("ABI", "hydration", "Rust allocations")
    end
    expect(File.binread(golden)).to eq(expected)
    expect(Open3.capture2("git", "status", "--porcelain", chdir: checkout).first).to eq("")
  end

  it "records an invalid native library identity and preserves both conversion failures" do
    arguments = [*args, "--backend", "native"]
    library = File.join(directory, "invalid-library")
    File.binwrite(library, "not a native library")
    with_emf_backend_environment(backend: "ruby", library: library) do
      expect(described_class.new(arguments).run).to eq(1)
      expect(report.fetch("native_library")).to include(
        "path" => library, "resolved_path" => File.realpath(library),
        "sha256" => Digest::SHA256.file(library).hexdigest, "size_bytes" => File.size(library)
      )
      expect(report.fetch("failures").size).to eq(2)
      expect(report.fetch("failures").map { |failure| failure.dig("failure", "class") })
        .to eq(["Emf::Native::Unavailable", "Emf::Native::Unavailable"])
    end
  end

  it "forces Ruby in warm and cold conversions despite an unavailable ambient native backend" do
    arguments = [*args, "--backend", "ruby"]
    with_emf_backend_environment(backend: "native", library: File.join(directory, "missing-library")) do
      expect(described_class.new(arguments).run).to eq(0)
      expect(report.fetch("backend")).to eq("ruby")
      expect(report.fetch("native_library")).to be_nil
      expect(report.fetch("fixtures").fetch(0).fetch("validity")).to include("golden_identical" => true)
      expect(report.dig("cold_load", "runs", 0)).to include("status" => "ok", "validity" => include("golden_identical" => true))
      expect(report.dig("method", "inseparable_boundaries")).to eq([])
    end
  end

  it "rejects a different consumer revision" do
    expect { expect(described_class.new([*args, "--revision", "0" * 40]).run).to eq(2) }.to output(/revision differs/).to_stderr
    expect(File).not_to exist(result_path)
  end

  it "rejects tracked consumer changes" do
    arguments = args
    File.write(File.join(checkout, "lib/emfsvg.rb"), "changed")
    expect { expect(described_class.new(arguments).run).to eq(2) }.to output(/tracked changes/).to_stderr
    expect(File).not_to exist(result_path)
  end
end
