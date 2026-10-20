# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require_relative "../../bench/support/native_components_benchmark"
require_relative "../support/fixture_manifest"

RSpec.describe NativeComponentsBenchmark::Components do
  let(:loader) { instance_double(Emf::Native::Loader) }
  let(:snapshot_class) { class_double(Emf::Native::Snapshot) }
  let(:hydrator_class) { class_double(Emf::Native::Hydrator) }
  let(:snapshot) { instance_double(Emf::Native::Snapshot) }
  let(:hydrator) { instance_double(Emf::Native::Hydrator) }
  let(:clock) { double("clock") }
  let(:events) { [] }
  let(:components) { described_class.new(loader: loader, snapshot: snapshot_class, hydrator: hydrator_class, clock: clock) }

  before do
    require "emf/native/loader"
    require "emf/native/snapshot"
    require "emf/native/hydrator"
    allow(clock).to receive(:now).and_return(0, 2, 3, 8, 9, 16, 17, 28, 29, 42, 43)
    allow(loader).to receive(:document).with("input") do |&block|
      events << :parse
      begin
        block.call(:document)
      ensure
        events << :cleanup
      end
    end
    allow(loader).to receive(:snapshot).with(:document) {
      events << :copy
      "copied"
    }
    allow(snapshot_class).to receive(:new).with("copied") {
      events << :decode
      snapshot
    }
    allow(hydrator_class).to receive(:new).with(snapshot, "input").and_return(hydrator)
    allow(hydrator).to receive(:call) {
      events << :hydrate
      :model
    }
  end

  it "assigns adjacent component boundaries and includes cleanup in the total" do
    model, samples = components.call("input")

    expect(model).to eq(:model)
    expect(samples).to eq("parse_handle" => 2, "snapshot_copy" => 5, "snapshot_decode" => 7,
                          "hydration" => 11, "cleanup" => 13, "component_total" => 43)
    expect(events).to eq(%i[parse copy decode hydrate cleanup])
  end

  %i[snapshot decode hydrate].each do |stage|
    it "lets the loader clean up when #{stage} fails and propagates the error" do
      case stage
      when :snapshot then allow(loader).to receive(:snapshot).and_raise("copy failed")
      when :decode then allow(snapshot_class).to receive(:new).and_raise("decode failed")
      when :hydrate then allow(hydrator).to receive(:call).and_raise("hydrate failed")
      end

      expect { components.call("input") }.to raise_error(RuntimeError, /failed/)
      expect(events.last).to eq(:cleanup)
    end
  end

  it "propagates cleanup failures rather than publishing successful samples" do
    allow(loader).to receive(:document) { |&block|
      block.call(:document)
      raise "cleanup failed"
    }

    expect { components.call("input") }.to raise_error(RuntimeError, "cleanup failed")
  end
end

RSpec.describe NativeComponentsBenchmark::CLI do
  let(:directory) { Dir.mktmpdir("native-components") }
  let(:result_path) { File.join(directory, "report.json") }
  let(:manifest) { File.join(ParserBenchmark::ROOT, "spec/fixtures/manifest.json") }
  let(:args) do
    ["--manifest", manifest, "--output", result_path, "--fixture", "spec/fixtures/simple/*", "--iterations", "1",
     "--warmups", "0", "--rss-limit-mb", "512"]
  end
  let(:report) { JSON.parse(File.read(result_path)) }

  after { FileUtils.remove_entry(directory) }

  it "rejects Ruby selection and invalid bounds before launching children" do
    [["--backend", "ruby", /only forced native/], ["--timeout", "61", /within 1..60/],
     ["--iterations", "0", /positive integer/], ["--warmups", "-1", /must be >= 0/],
     ["--cold-runs", "1", /cold runs are not supported/]].each do |flag, value, error|
      expect { expect(described_class.new([*args, flag, value]).run).to eq(2) }.to output(error).to_stderr
    end
    expect(File).not_to exist(result_path)
  end

  it "requires the shared supervisor RSS ceiling" do
    without_rss = args[0...-2]
    expect { expect(described_class.new(without_rss).run).to eq(2) }.to output(/rss-limit-mb is required/).to_stderr
  end

  it "forces native despite caller settings and records an unavailable library with exact hashes" do
    library = File.join(directory, "invalid-library")
    File.binwrite(library, "invalid native library")
    previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
    ENV["EMF_BACKEND"] = "ruby"
    ENV["EMF_NATIVE_LIBRARY"] = library

    expect(described_class.new(args).run).to eq(1)
    expect(report).to include("backend" => "native", "kind" => "emf-native-components")
    expect(report.fetch("native_library")).to include("sha256" => Digest::SHA256.file(library).hexdigest)
    expect(report.fetch("revision")).to include("git_sha", "parser_source_sha256")
    expect(report.fetch("fixtures").first).to include("sha256" => Digest::SHA256.file(
      File.join(ParserBenchmark::ROOT, "spec/fixtures/simple/image1.emf")
    ).hexdigest, "status" => "error")
    expect(report.fetch("failures").first.dig("failure", "class")).to eq("Emf::Native::Unavailable")
    expect(report.dig("method", "stages").keys).to eq(NativeComponentsBenchmark::STAGES.keys)
    expect(ENV.fetch("EMF_BACKEND")).to eq("ruby")
  ensure
    %w[EMF_BACKEND EMF_NATIVE_LIBRARY].each { |key| ENV[key] = previous[key] }
  end
end

RSpec.describe NativeComponentsBenchmark::Run do
  let(:directory) { Dir.mktmpdir("native-components-run") }
  let(:result_path) { File.join(directory, "report.json") }
  let(:options) do
    ParserBenchmark::Options.new(
      **ParserBenchmark::CLI::DEFAULTS,
      backend: "native", cold_runs: 0,
      manifest: File.join(ParserBenchmark::ROOT, "spec/fixtures/manifest.json"),
      output: result_path, fixtures: ["spec/fixtures/simple/*"], rss_limit_bytes: 1024
    )
  end
  let(:runner) { described_class.new(options, []) }

  after { FileUtils.remove_entry(directory) }

  %w[timeout rss_exceeded].each do |kind|
    it "propagates supervised #{kind} without partial timings" do
      allow(runner).to receive(:child).and_return("safety_failure" => { "kind" => kind })

      expect(runner.run).to eq(1)
      report = JSON.parse(File.read(result_path))
      expect(report.fetch("failures").first).to include("failure" => { "kind" => kind })
      expect(report.fetch("fixtures").first).not_to have_key("stages")
    end
  end
end

RSpec.describe NativeComponentsBenchmark::Worker do
  around do |example|
    previous = ENV.fetch("EMF_BACKEND", nil)
    example.run
  ensure
    ENV["EMF_BACKEND"] = previous
  end

  let(:path) { File.join(ParserBenchmark::ROOT, "spec/fixtures/simple/image1.emf") }
  let(:bytes) { File.binread(path) }
  let(:worker) { described_class.new(path: path, sha256: Digest::SHA256.hexdigest(bytes), iterations: 1, warmups: 0, backend: "native") }
  let(:components) { instance_double(NativeComponentsBenchmark::Components) }
  let(:durations) { NativeComponentsBenchmark::STAGES.keys.reject { |stage| stage == "public_parse" }.to_h { |stage| [stage, 10] } }
  let(:events) { [] }

  before do
    require "emf/native/loader"
    require "emf/native/snapshot"
    require "emf/native/hydrator"
    require "emf/native/library_path"
    allow(Emf::Native).to receive(:backend)
    allow(Emf::Native::Loader).to receive(:new)
    allow(NativeComponentsBenchmark::Components).to receive(:new).and_return(components)
    allow(components).to receive(:call).with(bytes) do
      model = Emf::Emr::Parser.call(bytes)
      events << :cleanup
      [model, durations]
    end
    allow(Emf).to receive(:parse) { |input| Emf::Emr::Parser.call(input) }
    allow(Emf).to receive(:serialize) do |model|
      events << :serialize
      Emf::Emr::Serializer.call(model)
    end
  end

  it "verifies fixture and public baseline parity and a surviving wire edit after cleanup" do
    result = worker.call

    expect(result.fetch("status")).to eq("ok")
    expect(result.fetch("validity")).to include("round_trip_identical" => true, "public_native_ruby_parity" => true)
    expect(result.fetch("mutation")).to include("output_changed" => true, "before" => 8, "reparsed_value" => 1)
    expect(result.dig("stages", "hydration", "samples_ns")).to eq([10])
    expect(events.first(2)).to eq(%i[cleanup serialize])
    expect(File.binread(path)).to eq(bytes)
  end

  it "rejects component output mismatch rather than publishing samples" do
    allow(Emf).to receive(:serialize).and_return("wrong output")

    expect(worker.call).to include("status" => "error", "error" => include("class" => "ParserBenchmark::InputMismatch"))
  end
end
