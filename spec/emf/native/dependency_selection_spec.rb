# frozen_string_literal: true

require "spec_helper"
require "json"
require "open3"
require "rbconfig"

RSpec.describe "Backend selection without Fiddle" do
  let(:script) do
    <<~SCRIPT
      require "json"
      $fiddle_attempts = 0
      $ruby_parser_calls = 0
      module Kernel
        alias dependency_selection_require require

        def require(path)
          if path == "fiddle"
            $fiddle_attempts += 1
            raise LoadError, "simulated missing fiddle"
          end
          dependency_selection_require(path)
        end
      end
      require "emf"
      module RubyParserCalls
        def call(...)
          $ruby_parser_calls += 1
          super
        end
      end
      Emf::Emr::Parser.singleton_class.prepend(RubyParserCalls)
      bytes = File.binread("spec/fixtures/simple/image1.emf")
      begin
        parsed = Emf.parse(bytes)
        result = { format: parsed.format, round_trip: Emf.serialize(parsed) == bytes }
      rescue StandardError => error
        result = { error: error.class.name, message: error.message }
      end
      puts JSON.generate(result.merge(fiddle_attempts: $fiddle_attempts, ruby_parser_calls: $ruby_parser_calls))
    SCRIPT
  end
  let(:result) do
    stdout, stderr, status = Open3.capture3(
      { "EMF_BACKEND" => backend, "EMF_NATIVE_LIBRARY" => "/unused/dependency-selection-library" },
      RbConfig.ruby, "-Ilib", "-e", script
    )
    expect(status.success?).to be(true), stderr
    expect(stderr).to eq("")
    JSON.parse(stdout)
  end

  context "when Ruby is forced" do
    let(:backend) { "ruby" }

    it "round trips without attempting to load Fiddle" do
      expect(result).to eq("format" => "emf_plus", "round_trip" => true,
                           "fiddle_attempts" => 0, "ruby_parser_calls" => 1)
    end
  end

  context "with automatic selection" do
    let(:backend) { "auto" }

    it "falls back for both parsing and serialization when Fiddle cannot load" do
      expect(result).to eq("format" => "emf_plus", "round_trip" => true,
                           "fiddle_attempts" => 2, "ruby_parser_calls" => 1)
    end
  end

  context "when native is forced" do
    let(:backend) { "native" }

    it "reports dependency unavailability without calling the Ruby parser" do
      expect(result).to eq("error" => "Emf::Native::Unavailable",
                           "message" => "native backend dependencies could not load: simulated missing fiddle",
                           "fiddle_attempts" => 1, "ruby_parser_calls" => 0)
    end
  end
end
