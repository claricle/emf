# frozen_string_literal: true

require "json"
require "open3"
require "stringio"
require "tmpdir"

require "spec_helper"

load File.expand_path("../../script/downstream_native_goldens", __dir__)

RSpec.describe DownstreamNativeGoldens do
  let(:tmp) { Dir.mktmpdir("downstream-spec") }
  let(:emf_root) { File.realpath(File.expand_path("../..", __dir__)) }
  let(:library) { File.join(tmp, "libemf_ffi.so").tap { |path| File.write(path, "x") } }
  let(:emfsvg) { File.join(tmp, "emfsvg") }
  let(:err) { StringIO.new }
  let(:out) { StringIO.new }

  after { FileUtils.remove_entry(tmp) }

  def build_consumer(dirty: false)
    FileUtils.mkdir_p(File.join(emfsvg, "lib"))
    File.write(File.join(emfsvg, "Gemfile"), "")
    File.write(File.join(emfsvg, "tracked.txt"), "a")
    git = ["git", "-C", emfsvg, "-c", "user.name=t", "-c", "user.email=t@example.com"]
    system("git", "-C", emfsvg, "init", "-q", exception: true)
    system(*git, "add", ".", exception: true)
    system(*git, "commit", "-q", "-m", "x", exception: true)
    File.write(File.join(emfsvg, "tracked.txt"), "b") if dirty
    IO.popen(["git", "-C", emfsvg, "rev-parse", "HEAD"], &:read).strip
  end

  def args(revision, *extra)
    ["--emfsvg", emfsvg, "--revision", revision, "--native-library", library, "--output", File.join(tmp, "out.json"), *extra]
  end

  # Stands in for rspec: writes the JSON report and probe record a real child would.
  def executor(rspec_status: 0, failures: 0, emf_path: File.join(emf_root, "lib", "emf.rb"), classes: nil, files: nil)
    lambda do |argv, env:, log:, **|
      backend = env.fetch("EMF_BACKEND")
      selected = classes || { DownstreamNativeGoldens::SELECTED_CLASS.fetch(backend) => 3 }
      names = files || %w[spec/golden_spec.rb spec/round_trip_spec.rb spec/round_trip_golden_spec.rb]
      File.write(argv[argv.index("--out") + 1], JSON.generate(
                                                  "summary" => { "example_count" => 3, "failure_count" => failures, "pending_count" => 1,
                                                                 "errors_outside_of_examples_count" => 0 },
                                                  "examples" => names.map { |name| { "file_path" => "./#{name}" } }
                                                ))
      File.write(env.fetch("DOWNSTREAM_PROBE_OUT"), JSON.generate(
                                                      "emf_path" => emf_path, "requested_backend" => backend,
                                                      "native_library" => env["EMF_NATIVE_LIBRARY"], "selections" => selected
                                                    ))
      File.write(log, "log")
      rspec_status
    end
  end

  def run_main(argv, **executor_options)
    described_class.main(argv, executor: executor(**executor_options), out: out, err: err)
  end

  describe "argument handling" do
    it "requires --emfsvg" do
      expect(described_class.main([], out: out, err: err)).to eq(2)
      expect(err.string).to include("--emfsvg is required")
    end

    it "rejects unexpected arguments and unknown backends" do
      expect(described_class.main(%w[--emfsvg /nope stray], out: out, err: err)).to eq(2)
      expect(described_class.main(%w[--backend java], out: out, err: err)).to eq(2)
    end

    it "requires an existing native library for the native backend only" do
      revision = build_consumer
      expect(described_class.main(["--emfsvg", emfsvg, "--revision", revision], out: out, err: err)).to eq(2)
      expect(err.string).to include("--native-library is required")
      expect(run_main(["--emfsvg", emfsvg, "--revision", revision, "--backend", "ruby"])).to eq(0)
    end

    it "exits 2 when the consumer is not at the pinned revision or has tracked edits" do
      revision = build_consumer
      expect(run_main(args("0" * 40))).to eq(2)
      expect(err.string).to include("is not the pinned")
      File.write(File.join(emfsvg, "tracked.txt"), "edited golden")
      expect(run_main(args(revision))).to eq(2)
      expect(err.string).to include("tracked modifications")
    end
  end

  describe "a verified run" do
    it "passes both backends, records selections and writes the summary" do
      revision = build_consumer

      expect(run_main(args(revision))).to eq(0)

      summary = JSON.parse(File.read(File.join(tmp, "out.json")))
      expect(summary).to include("passed" => true)
      expect(summary.fetch("backends").transform_values { |b| b.fetch("selections").keys }).to eq(
        "ruby" => ["Emf::Backend::Ruby"], "native" => ["Emf::Native::Adapter"]
      )
      expect(summary.dig("backends", "ruby", "pending")).to eq(1)
      expect(summary.dig("backends", "native", "native_library_sha256")).to match(/\A\h{64}\z/)
    end

    it "mirrors the consumer next to this checkout when ../emf is not it" do
      revision = build_consumer
      seen = []
      probing = lambda do |argv, **kwargs|
        seen << [kwargs.fetch(:chdir), File.realpath(File.join(kwargs.fetch(:chdir), "..", "emf")),
                 File.realpath(File.join(kwargs.fetch(:chdir), "lib"))]
        executor.call(argv, **kwargs)
      end

      described_class.main(args(revision, "--backend", "ruby"), executor: probing, out: out, err: err)

      chdir, sibling, lib = seen.first
      expect(chdir).not_to eq(File.realpath(emfsvg))
      expect(sibling).to eq(emf_root)
      expect(lib).to eq(File.realpath(File.join(emfsvg, "lib")))
    end
  end

  describe "failure propagation" do
    it "fails when rspec reports a failing example even if it exited zero" do
      expect(run_main(args(build_consumer), failures: 1)).to eq(1)
      expect(err.string).to include("1 failing examples")
    end

    it "fails on a nonzero rspec exit" do
      expect(run_main(args(build_consumer), rspec_status: 1)).to eq(1)
      expect(err.string).to include("rspec exited 1")
    end

    it "fails when the child produced no report or probe" do
      silent = ->(_argv, **) { 0 }
      status = described_class.main(args(build_consumer), executor: silent, out: out, err: err)

      expect(status).to eq(1)
      expect(err.string).to include("rspec JSON report missing", "probe record missing")
    end

    it "fails when a requested spec file contributed no examples" do
      expect(run_main(args(build_consumer), files: ["spec/golden_spec.rb"])).to eq(1)
      expect(err.string).to include("round_trip_spec.rb contributed no examples")
    end

    it "does not report the first backend's failure as a pass for the run" do
      revision = build_consumer
      mixed = lambda do |argv, **kwargs|
        executor(failures: kwargs.fetch(:env).fetch("EMF_BACKEND") == "native" ? 2 : 0).call(argv, **kwargs)
      end

      status = described_class.main(args(revision), executor: mixed, out: out, err: err)

      expect(status).to eq(1)
      expect(out.string).to include("ruby: PASS", "native: FAIL")
      expect(JSON.parse(File.read(File.join(tmp, "out.json")))).to include("passed" => false)
    end
  end

  describe "backend selection check" do
    it "fails when native was requested but the Ruby backend was used" do
      status = run_main(args(build_consumer, "--backend", "native"), classes: { "Emf::Backend::Ruby" => 4 })

      expect(status).to eq(1)
      expect(err.string).to include("backends selected [\"Emf::Backend::Ruby\"], expected only Emf::Native::Adapter")
    end

    it "fails when no selection was observed" do
      expect(run_main(args(build_consumer), classes: {})).to eq(1)
      expect(err.string).to include("no backend selection was observed")
    end

    it "fails when a different emf than this checkout was loaded" do
      expect(run_main(args(build_consumer), emf_path: "/gems/emf-0.1.0/lib/emf.rb")).to eq(1)
      expect(err.string).to include("loaded emf \"/gems/emf-0.1.0/lib/emf.rb\"")
    end

    it "fails when the native library the child saw is not the one supplied" do
      other = lambda do |argv, env:, **rest|
        executor.call(argv, env: env.merge("EMF_NATIVE_LIBRARY" => "/elsewhere.so"), **rest)
      end

      status = described_class.main(args(build_consumer, "--backend", "native"), executor: other, out: out, err: err)

      expect(status).to eq(1)
      expect(err.string).to include("native library was \"/elsewhere.so\"")
    end
  end

  describe "child environment" do
    it "pins EMF_BACKEND per run and withholds the native library from the Ruby run" do
      revision = build_consumer
      envs = {}
      capture = lambda do |argv, **kwargs|
        envs[kwargs.fetch(:env).fetch("EMF_BACKEND")] = [kwargs.fetch(:env), argv]
        executor.call(argv, **kwargs)
      end

      described_class.main(args(revision), executor: capture, out: out, err: err)

      expect(envs.keys).to eq(%w[ruby native])
      expect(envs.dig("ruby", 0)).to include("EMF_NATIVE_LIBRARY" => nil)
      expect(envs.dig("native", 0, "EMF_NATIVE_LIBRARY")).to eq(File.realpath(library))
      expect(envs.dig("native", 1)).to include("-I", File.join(emf_root, "lib"))
    end
  end
end
