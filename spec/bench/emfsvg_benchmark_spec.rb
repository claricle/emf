# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require_relative "../../bench/support/emfsvg_benchmark"
require_relative "../support/emfsvg_benchmark_checkout"

RSpec.describe EmfsvgBenchmark::CLI do
  include EmfsvgBenchmarkCheckout

  let(:directory) { Dir.mktmpdir("emfsvg-benchmark") }
  let(:checkout) { File.join(directory, "consumer") }
  let(:revision) { create_emfsvg_checkout(checkout) }
  let(:result_path) { File.join(directory, "result.json") }
  let(:report) { JSON.parse(File.read(result_path)) }
  let(:args) do
    ["--manifest", File.join(ParserBenchmark::ROOT, "spec/fixtures/manifest.json"), "--emfsvg-path", checkout,
     "--revision", revision, "--output", result_path, "--fixture", "spec/fixtures/simple/*", "--iterations", "2",
     "--warmups", "0", "--cold-runs", "1"]
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

  it "rejects an unavailable backend without silently falling back" do
    expect { expect(described_class.new([*args, "--backend", "native"]).run).to eq(2) }.to output(/unsupported backend/).to_stderr
    expect(File).not_to exist(result_path)
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
