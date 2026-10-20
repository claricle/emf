# frozen_string_literal: true

require "spec_helper"
require "rbconfig"
require_relative "../support/fixture_manifest"

# TODO.impl/17: corrupted EMF corpus must not crash or hang the parser.
# Each file, observed in a supervised child, either parses (with errors recorded on the Metafile)
# or raises Emf::FormatError for header-level corruption. Anything else is a failure.
RSpec.describe "EMF corrupted-resilience" do
  # Provisional: the committed ceiling comes from the corpus measurement
  # (macOS: native peak 195 MiB, Ruby ~957 MiB for the full pipeline on 002112).
  rss_limit_bytes = 2048 * 1024 * 1024
  wall_seconds = 60
  acceptable = %w[parsed recovered format_error]

  def runner(**options)
    FixtureManifest::Runner.new(**options)
  end

  def ruby(code)
    [RbConfig.ruby, "-e", code]
  end

  Dir.glob(File.join(Emf::SpecSupport::FixturePath.fixture("emf-corrupted"), "*.emf")).each do |path|
    it "does not crash or hang on #{File.basename(path)}" do
      observation = runner(rss_limit_bytes: rss_limit_bytes, timeout: wall_seconds).call(path)

      expect(acceptable).to include(observation["outcome"]), "#{File.basename(path)}: #{observation.inspect}"
    end
  end

  it "handles empty input cleanly" do
    expect { Emf.parse("".b) }.to raise_error(Emf::FormatError)
  end

  it "handles 3-byte input cleanly" do
    expect { Emf.parse("abc".b) }.to raise_error(Emf::FormatError)
  end

  describe "supervised observation" do
    it "fails a stalled child as a timeout" do
      observation = runner(rss_limit_bytes: rss_limit_bytes, timeout: 1, command: ruby("sleep 30")).call("x")

      expect(observation.dig("safety_failure", "kind")).to eq("timeout")
    end

    it "fails an over-RSS child as rss_exceeded" do
      code = 'a = "x" * (300 * 1024 * 1024); sleep 30'
      observation = runner(rss_limit_bytes: 100 * 1024 * 1024, command: ruby(code)).call("x")

      expect(observation.dig("safety_failure", "kind")).to eq("rss_exceeded")
    end

    it "fails a crashed child as a process_failure" do
      observation = runner(rss_limit_bytes: rss_limit_bytes, command: ruby("exit 3")).call("x")

      expect(observation["safety_failure"]).to include("kind" => "process_failure", "exit_status" => 3)
    end

    it "reports a non-FormatError exception with its class and no accepted outcome" do
      observation = runner(rss_limit_bytes: rss_limit_bytes).call("/nonexistent/missing.emf")

      expect([observation["outcome"], observation.dig("backend_exception", "class")]).to eq([nil, "Errno::ENOENT"])
    end
  end
end
