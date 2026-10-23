# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/native_library_context"
require_relative "../../support/conformance_parity"

# One Ruby rule set, two parser backends: the full normalized report must be
# identical. Only the clock is normalized (pinned `now:`); the filename is the
# same on both sides because both runs receive the same path.
RSpec.describe "Emf::Conformance forced-backend parity" do
  include_context "with native library"

  root = File.expand_path("../../fixtures", __dir__)
  corpus = Dir[File.join(root, "{emf,emf-ea,simple,emf-corrupted}/*.emf")]
  profiles = ConformanceParity::PROFILES

  def report(backend, input, profile)
    ConformanceParity.with_backend(backend, library) do
      Emf::Conformance.check(input, profile: profile, now: ConformanceParity::NOW).to_h
    end
  end

  def native_calls(input, profile)
    calls = 0
    allow(Emf::Native).to receive(:backend).and_wrap_original do |original|
      calls += 1
      original.call
    end
    report("native", input, profile)
    calls
  end

  # Wire sources only the native hydrator creates (Native::LazyWire, Native::FilledWire). The Ruby parser has its
  # own byte-backed source (Emr::FilledRecord), so counting any source would no longer tell the backends apart.
  def native_sources(backend, bytes)
    ConformanceParity.with_backend(backend, library) do
      Emf.parse(bytes).records.count { |record| record.instance_variable_get(:@wire_source).class.name.to_s.start_with?("Emf::Native::") }
    end
  end

  def expect_parity(label, input, profile)
    ruby = report("ruby", input, profile)
    native = report("native", input, profile)
    difference = ConformanceParity.first_difference(ruby, native)
    expect(difference).to be_nil, "#{label} [#{profile}] first difference at #{difference}"
    ruby
  end

  it "covers the expected corpus" do
    expect(corpus.size).to be >= 208
    expect(corpus.grep(/emf-ea/).size).to eq(21)
    expect(corpus.grep(/emf-corrupted/).size).to eq(21)
  end

  describe "native backend guard" do
    it "is actually selected by the check on the native side and never on the Ruby side" do
      path = corpus.grep(/simple/).first
      expect(native_calls(path, :strict)).to be >= 1

      calls = 0
      allow(Emf::Native).to receive(:backend).and_wrap_original do |original|
        calls += 1
        original.call
      end
      report("ruby", path, :strict)
      expect(calls).to eq(0)
    end

    it "hydrates native-only wire sources, which the Ruby backend never produces" do
      bytes = File.binread(corpus.grep(/simple/).first)
      expect(native_sources("native", bytes)).to be_positive
      expect(native_sources("ruby", bytes)).to eq(0)
    end

    # Conformance.check rescues Emf::Error into an "unparseable" report, so the
    # unavailable-library case is proved on Emf.parse (no silent Ruby fallback).
    it "raises instead of falling back to Ruby when forced native has no library" do
      expect { ConformanceParity.with_backend("native", "") { Emf.parse(File.binread(corpus.first)) } }
        .to raise_error(Emf::Native::Unavailable)
    end
  end

  profiles.each do |profile|
    corpus.each do |path|
      it "#{profile}: #{path.delete_prefix("#{root}/")} reports identically" do
        expect_parity(path.delete_prefix("#{root}/"), path, profile)
      end
    end
  end

  describe "native used for every corpus file" do
    it "hydrates native wire sources for each parseable file with records" do
      unlazy = corpus.select do |path|
        bytes = File.binread(path)
        records = ConformanceParity.with_backend("ruby", library) { Emf.parse(bytes).records.size }
        records.positive? && native_sources("native", bytes).zero?
      rescue Emf::Error
        false
      end
      expect(unlazy).to be_empty
    end
  end

  describe "Raw and recovery inputs" do
    # The parser itself rejects these two (corrupted EMR_HEADER).
    unparseable = %w[bad_corrupted_2014-12-02-215338.emf bad_corrupted_2014-12-02-215428.emf]
    simple = corpus.grep(/simple/).first
    raw_bytes = ConformanceParity.with_raw_record(File.binread(simple))
    recovered = corpus.grep(/emf-corrupted/).reject { |path| unparseable.include?(File.basename(path)) }

    it "the synthetic input really parses to a Raw record on both backends" do
      %w[ruby native].each do |backend|
        classes = ConformanceParity.with_backend(backend, library) do
          Emf.parse(raw_bytes).records.map { |record| record.wire.class.name.split("::").last }
        end
        expect(classes).to include("Raw"), "#{backend} produced no Raw record"
      end
    end

    profiles.each do |profile|
      it "#{profile}: a Raw record inserted into #{File.basename(simple)} reports identically (bytes input)" do
        expect_parity("raw-record bytes", raw_bytes, profile)
      end

      it "#{profile}: a truncated file reports identically (bytes input)" do
        bytes = File.binread(simple)
        expect_parity("truncated bytes", bytes.byteslice(0, bytes.bytesize - 13), profile)
      end

      it "#{profile}: a zero-length input reports identically" do
        expect_parity("empty bytes", "", profile)
      end
    end

    it "the corrupted fixtures include recovery (parse errors) on both backends" do
      counts = %w[ruby native].map do |backend|
        recovered.count do |path|
          ConformanceParity.with_backend(backend, library) { Emf.parse(File.binread(path)).errors? }
        end
      end
      expect(counts.first).to be_positive
      expect(counts.last).to eq(counts.first)
    end

    it "the two unparseable fixtures give the same tolerant result as the Ruby backend" do
      (corpus.grep(/emf-corrupted/) - recovered).each do |path|
        report = expect_parity(File.basename(path), path, :tolerant)
        expect(report["errors"]["by_requirement"]).to eq("emf.parse.unparseable" => 1)
      end
    end
  end
end
