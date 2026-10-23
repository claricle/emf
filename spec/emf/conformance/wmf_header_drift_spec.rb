# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/native_library_context"
require_relative "../../support/wmf_header_drift"

RSpec.describe "Emf::Conformance on WMF header Size and MaxRecord drift" do
  include WmfHeaderDrift

  backends = %w[ruby native].freeze
  profiles = %i[strict tolerant].freeze
  env_keys = %w[EMF_BACKEND EMF_NATIVE_LIBRARY].freeze

  def check(bytes, profile) = Emf::Conformance.check(bytes, profile: profile)

  def summary(bytes, profile)
    report = check(bytes, profile)
    [report.valid?, report.diagnostics.map { |d| [d.requirement_id, d.severity] }]
  end

  # Inkscape writes a Size that runs past the data; ImageMagick writes a MaxRecord that is not the largest record.
  {
    "an Inkscape-shaped Size past the data" => [6, 24 + 11, "wmf.header.size_matches_records"],
    "an ImageMagick-shaped MaxRecord" => [12, 6, "wmf.header.max_record"]
  }.each do |name, (offset, value, rule)|
    it "is invalid strict and valid tolerant for #{name}, with #{rule} downgraded to a warning" do
      bytes = drifted(pristine, offset, value)
      strict = summary(bytes, :strict)
      tolerant = summary(bytes, :tolerant)
      expect(strict.first).to be(false)
      expect(strict.last).to include([rule, :error])
      expect(tolerant.first).to be(true)
      expect(tolerant.last).to include([rule, :warning])
      expect(tolerant.last.map(&:last).uniq).to eq([:warning])
    end

    it "gives the same report on both backends for #{name}" do
      library = ENV.fetch("EMF_TEST_NATIVE_LIBRARY", nil)
      skip "set EMF_TEST_NATIVE_LIBRARY to run native specs" if library.nil?
      bytes = drifted(pristine, offset, value)
      reports = backends.map do |backend|
        previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
        ENV["EMF_BACKEND"] = backend
        ENV["EMF_NATIVE_LIBRARY"] = library
        profiles.map { |profile| summary(bytes, profile) }
      ensure
        env_keys.each { |key| ENV[key] = previous[key] }
      end
      expect(reports.first).to eq(reports.last)
    end
  end

  it "reports a consistent header clean" do
    valid, diagnostics = summary(pristine, :strict)
    expect(valid).to be(true)
    expect(diagnostics.map(&:first)).not_to include("wmf.header.size", "wmf.header.size_matches_records", "wmf.header.max_record")
  end
end
