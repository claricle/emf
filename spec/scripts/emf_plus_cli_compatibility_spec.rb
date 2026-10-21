# frozen_string_literal: true

require "spec_helper"
require_relative "../support/emf_plus_cli_compatibility"

RSpec.describe "EMF+ CLI compatibility" do
  let(:root) { File.expand_path("../..", __dir__) }
  let(:current_cli) { File.join(root, "exe/emf") }
  let(:reference_cli) { EmfPlusCliCompatibility.reference_cli(root, directory) }
  let(:directory) { Dir.mktmpdir("emf-plus-cli-") }
  let(:evidence) { ENV.fetch("EMF_PLUS_CLI_EVIDENCE", directory) }

  after { FileUtils.remove_entry(directory) }

  fixtures = Dir.glob(File.expand_path("../fixtures/**/*.emf", __dir__)).select do |path|
    File.binread(path).include?("EMF+".b)
  end

  it "covers the historical 23 valid and four corrupted EMF+ fixtures" do
    expect(fixtures.size).to eq(27)
    expect(fixtures.count { |path| path.include?("/emf-corrupted/") }).to eq(4)
  end

  commands = %w[info dump]
  fixtures.each do |fixture|
    commands.each do |command|
      it "preserves #{command} output and exit for #{fixture.split('/fixtures/').last}" do
        FileUtils.mkdir_p(evidence)
        stem = File.join(evidence, "cli-#{File.basename(fixture, '.emf')}-#{command}")
        previous = EmfPlusCliCompatibility.capture_cli(root, reference_cli, command, fixture, "#{stem}-previous")
        current = EmfPlusCliCompatibility.capture_cli(root, current_cli, command, fixture, "#{stem}-current")

        aggregate_failures do
          expect(previous.fetch(:status)).to eq("exited"), "reference CLI limited or signaled; evidence: #{stem}"
          expect(current.fetch(:status)).to eq("exited"), "current CLI limited or signaled; evidence: #{stem}"
          expect(current.fetch(:exit_code)).to eq(previous.fetch(:exit_code))
          expect(current.fetch(:stdout)).to eq(previous.fetch(:stdout))
          expect(current.fetch(:stderr)).to eq(previous.fetch(:stderr))
          expect(current.fetch(:stdout)).to include("EMF+:      present (") if command == "info"
        end
      end
    end
  end
end
