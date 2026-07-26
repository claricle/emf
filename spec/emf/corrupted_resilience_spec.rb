# frozen_string_literal: true

require "spec_helper"
require "timeout"

# TODO.impl/17: corrupted EMF corpus must not crash or hang the parser.
# Each file either parses (with errors recorded on the Metafile) or raises
# Emf::FormatError for header-level corruption.
RSpec.describe "EMF corrupted-resilience" do
  corrupted_dir = Emf::SpecSupport::FixturePath.fixture("emf-corrupted")

  Dir.glob(File.join(corrupted_dir, "*.emf")).each do |path|
    it "does not crash or hang on #{File.basename(path)}" do
      bytes = File.read(path, mode: "rb")
      outcome = begin
        Timeout.timeout(5) do
          mf = Emf.parse(bytes)
          mf.errors? || mf.records.empty? ? :parsed_with_errors : :parsed
        rescue Emf::FormatError
          :format_error
        end
      rescue StandardError
        :timeout
      end

      expect(outcome).not_to eq(:timeout), "parser hung on #{File.basename(path)}"
      expect(%i[parsed parsed_with_errors format_error]).to include(outcome)
    end
  end

  it "handles empty input cleanly" do
    expect { Emf.parse("".b) }.to raise_error(Emf::FormatError)
  end

  it "handles 3-byte input cleanly" do
    expect { Emf.parse("abc".b) }.to raise_error(Emf::FormatError)
  end
end
