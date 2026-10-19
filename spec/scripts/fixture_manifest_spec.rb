# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require_relative "../support/fixture_manifest"

RSpec.describe FixtureManifest do
  let(:root) { File.expand_path("../..", __dir__) }
  let(:inventory) { described_class::Inventory.new(root) }
  let(:manifest) { JSON.parse(File.read(File.join(root, "spec/fixtures/manifest.json"))) }

  it "inventories every existing fixture in deterministic path order without parsing" do
    entries = described_class.fixtures(root)
    expect(entries.size).to eq(229)
    expect(described_class.counts(entries)).to eq(described_class::EXPECTED_COUNTS)
    expect(entries.map { |entry| entry.fetch("path") }).to eq(entries.map { |entry| entry.fetch("path") }.sort)
    expect(entries.first.fetch("sha256")).to eq(Digest::SHA256.file(File.join(root, entries.first.fetch("path"))).hexdigest)
  end

  it "checks the saved capture without starting parser processes" do
    expect(described_class::Runner).not_to receive(:new)
    expect(inventory.check(manifest)).to be(true)
  end

  it "rejects fixture, source, schema, observation and safety drift" do
    mutations = [
      ->(data) { data["fixtures"].first["sha256"] = "changed" },
      ->(data) { data["backend"]["parser_source_sha256"] = "changed" },
      ->(data) { data["schema_version"] = 99 },
      ->(data) { data["fixtures"].first["outcome"] = "unknown" },
      ->(data) { data["fixtures"].first["safety_failure"] = { "kind" => "timeout" } },
      ->(data) { data["fixtures"].pop },
      ->(data) { data["fixtures"].first["backend_exception"] = {} },
      ->(data) { data["fixtures"].first["detected_format"] = "unknown" },
      ->(data) { data["fixtures"].find { |entry| entry["outcome"] == "parsed" }["outcome"] = "format_error" },
      ->(data) { data["fixtures"] = nil },
      ->(data) { data["backend"] = nil }
    ]
    mutations.each do |mutate|
      altered = Marshal.load(Marshal.dump(manifest))
      mutate.call(altered)
      expect(inventory.check(altered)).to be(false)
    end
  end

  it "observes successful parsing, recovery and format rejection through the public parser" do
    parsed = described_class.observe(File.join(root, "spec/fixtures/simple/image1.emf"))
    expect(parsed).to eq("detected_format" => "emf", "outcome" => "parsed")
    recovered = manifest.fetch("fixtures").find { |entry| entry["outcome"] == "recovered" }
    expect(described_class::Runner.new.call(File.join(root, recovered.fetch("path")))).to eq(
      "detected_format" => "emf", "outcome" => "recovered"
    )
    Tempfile.create("invalid-emf") do |file|
      file.write("bad")
      file.flush
      rejected = described_class.observe(file.path)
      expect(rejected).to include("detected_format" => nil, "outcome" => "format_error")
      expect(rejected.fetch("format_error")).to include("class" => "Emf::FormatError", "message" => "input too short (3 bytes)")
    end
  end

  it "records incidental backend exceptions separately from format errors" do
    allow(Emf).to receive(:parse).and_raise(IOError, "backend broke")
    result = described_class.observe(File.join(root, "spec/fixtures/simple/image1.emf"))
    expect(result).to eq("detected_format" => "emf", "outcome" => nil,
                         "backend_exception" => { "class" => "IOError", "message" => "backend broke" })
  end

  it "bounds hanging children, including children that close their output early" do
    ["sleep 10", "$stdout.close; $stderr.close; sleep 10"].each do |code|
      runner = described_class::Runner.new(timeout: 0.15, command: [RbConfig.ruby, "-e", code])
      expect(runner.call("unused")).to include("outcome" => nil, "safety_failure" => { "kind" => "timeout" })
    end
  end

  it "bounds output and distinguishes crashes and invalid child observations" do
    cases = {
      "loop { STDOUT.write('x' * 4096) }" => "output_limit",
      "exit 9" => "process_failure",
      "puts 'not json'" => "invalid_observation"
    }
    cases.each do |code, kind|
      runner = described_class::Runner.new(timeout: 2, output_limit: 1024, command: [RbConfig.ruby, "-e", code])
      expect(runner.call("unused").fetch("safety_failure")).to include("kind" => kind)
    end
  end
end
