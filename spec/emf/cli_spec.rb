# frozen_string_literal: true

require "spec_helper"
require "open3"

RSpec.describe "exe/emf CLI" do
  let(:exe) { File.expand_path("../../exe/emf", __dir__) }
  let(:fixture) { Emf::SpecSupport::FixturePath.fixture("simple", "image1.emf") }
  let(:corrupted) do
    Dir.glob(Emf::SpecSupport::FixturePath.fixture("emf-corrupted", "*.emf")).first
  end

  def run(*args)
    Open3.capture3("ruby", exe, *args)
  end

  describe "version" do
    it "prints the version" do
      out, _, status = run("version")
      expect(status.exitstatus).to eq(0)
      expect(out).to match(/^emf \d+\.\d+\.\d+/)
    end

    it "also responds to --version and -v" do
      out1, = run("--version")
      out2, = run("-v")
      expect(out1).to eq(out2)
      expect(out1).to match(/^emf \d/)
    end
  end

  describe "help" do
    it "prints usage" do
      out, _, status = run("help")
      expect(status.exitstatus).to eq(0)
      expect(out).to include("Usage:")
      expect(out).to include("emf info FILE")
    end

    it "is the default when no command given" do
      out, = run
      expect(out).to include("Usage:")
    end
  end

  describe "info" do
    it "prints metafile summary" do
      out, _, status = run("info", fixture)
      expect(status.exitstatus).to eq(0)
      expect(out).to include("Format:")
      expect(out).to include("Records:")
      expect(out).to match(/Bounds:/)
    end

    it "exits 2 when FILE is missing" do
      _, err, status = run("info")
      expect(status.exitstatus).to eq(2)
      expect(err).to match(/missing FILE/i)
    end
  end

  describe "validate" do
    it "exits 0 on a clean fixture" do
      out, _, status = run("validate", fixture)
      expect(status.exitstatus).to eq(0)
      expect(out).to match(/OK:/)
    end
  end

  describe "round-trip" do
    it "confirms byte-identical round-trip" do
      out, _, status = run("round-trip", fixture)
      expect(status.exitstatus).to eq(0)
      expect(out).to match(/byte-identical/i)
    end
  end

  describe "stats" do
    it "produces a record-type histogram" do
      out, _, status = run("stats", fixture)
      expect(status.exitstatus).to eq(0)
      expect(out).to include("Total:")
      expect(out).to include("WireAdapter")
    end
  end

  describe "dump" do
    it "produces a record-by-record dump" do
      out, _, status = run("dump", fixture)
      expect(status.exitstatus).to eq(0)
      expect(out).to include("Metafile format=")
      expect(out).to include("Header:")
    end
  end

  describe "unknown command" do
    it "exits 1 with a helpful message" do
      _, err, status = run("bogus-command")
      expect(status.exitstatus).to eq(1)
      expect(err).to match(/unknown command/i)
    end
  end
end
