# frozen_string_literal: true

require "spec_helper"
require "rbconfig"

RSpec.describe "Native visitor output parity" do
  let(:library) do
    ENV.fetch("EMF_TEST_NATIVE_LIBRARY") do
      extension = RbConfig::CONFIG.fetch("host_os").include?("darwin") ? "dylib" : "so"
      File.expand_path("../../../emf-rs/target/debug/libemf_ffi.#{extension}", __dir__)
    end
  end

  around do |example|
    previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
    ENV["EMF_NATIVE_LIBRARY"] = library
    example.run
  ensure
    %w[EMF_BACKEND EMF_NATIVE_LIBRARY].each { |key| ENV[key] = previous[key] }
  end

  before do
    skip "build emf-ffi or set EMF_TEST_NATIVE_LIBRARY" unless File.file?(library)
  end

  # Force both public entry points: native mode raises instead of silently
  # falling back to Ruby when the library is unavailable.
  let(:ruby_metafile) do
    ENV["EMF_BACKEND"] = "ruby"
    Emf.parse(bytes)
  end

  let(:native_metafile) do
    ENV["EMF_BACKEND"] = "native"
    Emf.parse(bytes)
  end

  [
    ["simple/image1.emf", :emf_plus],
    ["emf/test-007.emf", :emf],
    ["emf/test-038.emf", :emf_plus],
    ["wmf/standard-line.wmf", :wmf],
    ["wmf/placeable-line.wmf", :wmf]
  ].each do |fixture, expected_format|
    context "with #{fixture}" do
      let(:bytes) { Emf::SpecSupport::FixturePath.read_fixture(fixture).freeze }

      before do
        expect(ruby_metafile.format).to eq(expected_format)
        expect(native_metafile.format).to eq(expected_format)
        expect(ruby_metafile.errors).to be_empty
        expect(native_metafile.errors).to be_empty
        expect(ruby_metafile.records.size).to be > 1
        expect(native_metafile.records.size).to eq(ruby_metafile.records.size)
      end

      it "renders identical record-by-record dumps" do
        ruby_dump = Emf::Visitors::Dump.new.visit_all(ruby_metafile)
        native_dump = Emf::Visitors::Dump.new.visit_all(native_metafile)

        expect(ruby_dump.lines.size).to eq(ruby_metafile.records.size + 2)
        expect(ruby_dump.to_s).to include("Metafile format=#{expected_format}")
        expect(ruby_dump.to_s).to include("type_id=")
        expect(native_dump.lines).to eq(ruby_dump.lines)
        expect(native_dump.to_s).to eq(ruby_dump.to_s)
      end

      it "renders identical statistics and record-class histograms" do
        ruby_stats = Emf::Visitors::Stats.new.visit_all(ruby_metafile)
        native_stats = Emf::Visitors::Stats.new.visit_all(native_metafile)

        expect(ruby_stats.total).to eq(ruby_metafile.records.size)
        expect(ruby_stats.histogram.values.sum).to eq(ruby_stats.total)
        expect(ruby_stats.to_s).to include("Total: #{ruby_stats.total}")
        expect(native_stats.total).to eq(ruby_stats.total)
        expect(native_stats.histogram).to eq(ruby_stats.histogram)
        expect(native_stats.to_s).to eq(ruby_stats.to_s)
      end
    end
  end
end
