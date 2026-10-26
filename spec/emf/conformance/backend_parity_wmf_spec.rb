# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/native_library_context"
require_relative "../../support/conformance_parity"

# Forced-backend full-report parity for WMF, accepted and rejected. The whole
# Report#to_h is compared (so findings W24 adds later are covered), and every case
# must be proved to have gone through the native WMF path, never a silent Ruby one.
RSpec.describe "Emf::Conformance WMF forced-backend parity" do
  include_context "with native library"

  root = File.expand_path("../../..", __dir__)
  seeds = Dir[File.join(root, "emf-rs/fuzz/seeds/wmf-resilience/*.wmf")]
  fixtures = Dir[File.join(root, "spec/fixtures/wmf/*.wmf")]
  files = (seeds + fixtures).to_h { |path| [File.basename(path), File.binread(path)] }
  accepted_seed = ->(name) { name.start_with?("valid-") || fixtures.any? { |f| File.basename(f) == name } }
  base = files.select { |name, _| accepted_seed.call(name) }

  # Deterministic mutations of the accepted files: truncations, single-byte
  # substitutions through the header/first records, and a fixed-seed random set.
  header_offsets = [0, 1, 2, 4, 6, 8, 10, 12, 14, 18, 22, 24, 28, 36].freeze
  backends = %w[ruby native].freeze
  mutations = {}
  base.each do |name, bytes|
    [0, 1, 5, 17, 18, 21, 22, 23, 40, bytes.bytesize - 1, bytes.bytesize - 2, bytes.bytesize - 6].uniq.each do |len|
      mutations["#{name}:trunc#{len}"] = bytes.byteslice(0, len) if len >= 0 && len < bytes.bytesize
    end
    mutations["#{name}:trailing"] = bytes + "\x00\x01\x02".b
    header_offsets.each do |offset|
      next if offset >= bytes.bytesize

      mutated = bytes.b
      mutated.setbyte(offset, mutated.getbyte(offset) ^ 0xFF)
      mutations["#{name}:flip@#{offset}"] = mutated
    end
  end
  rng = Random.new(20_261_021)
  base.each do |name, bytes|
    8.times do |index|
      mutated = bytes.b
      rng.rand(1..3).times { mutated.setbyte(rng.rand(mutated.bytesize), rng.rand(256)) }
      mutations["#{name}:rand#{index}"] = mutated
    end
  end
  mutations["empty"] = "".b
  mutations["garbage"] = "not a metafile at all".b

  profiles = ConformanceParity::PROFILES

  def report(backend, input, profile)
    ConformanceParity.with_backend(backend, library) do
      Emf::Conformance.check(input, profile: profile, now: ConformanceParity::NOW).to_h
    end
  end

  # Counts native-WMF entry points and backend selections for one forced run.
  def native_use(input, backend)
    counts = { backend: 0, wmf: 0 }
    allow(Emf::Native).to(receive(:backend).and_wrap_original { |m| (counts[:backend] += 1) && m.call })
    require "emf/native/wmf_hydrator"
    allow(Emf::Native::WmfHydrator).to(receive(:parse).and_wrap_original { |m, *a| (counts[:wmf] += 1) && m.call(*a) })
    report(backend, input, :tolerant)
    counts
  end

  # Only input the detector classifies as WMF reaches the WMF hydrator; shorter or
  # header-damaged input is handled by the native adapter's generic path.
  def wmf_detected?(bytes)
    %i[wmf_apm wmf_standard].include?(Emf::Detector.call(bytes.b))
  rescue Emf::Error
    false
  end

  # A rejected input reports emf.parse.unparseable, or the named WMF reason or header fault that replaces it.
  def rejected?(report)
    named = %w[emf.parse.unparseable wmf.header.unrecognised]
    report["errors"]["by_requirement"].each_key.any? { |id| named.include?(id) || id.start_with?("wmf.reject.") }
  end

  def compare(corpus, profile)
    corpus.filter_map do |label, bytes|
      difference = ConformanceParity.first_difference(report("ruby", bytes, profile), report("native", bytes, profile))
      "#{label} [#{profile}] first difference at #{difference}" if difference
    end
  end

  it "covers the expected corpus" do
    expect(seeds.size).to eq(16)
    expect(fixtures.size).to eq(2)
    expect(base.size).to eq(10)
    expect(files.size - base.size).to eq(8)
    expect(mutations.size).to be >= 200
  end

  describe "accepted and rejected inputs classify the same on both backends" do
    # file-size.wmf and max-record.wmf carry header drift, and placeable-checksum.wmf and negative-text-count.wmf a
    # recovered checksum and text length; both backends recover from them (tolerant-valid).
    it "accepts exactly the valid and recovered files and rejects the other seeds" do
      recovered = %w[file-size.wmf max-record.wmf placeable-checksum.wmf negative-text-count.wmf]
      files.each do |name, bytes|
        backends.each do |backend|
          expect(rejected?(report(backend, bytes, :tolerant))).to eq(!base.key?(name) && !recovered.include?(name)), "#{name} on #{backend}"
        end
      end
    end

    it "the mutation set exercises both outcomes" do
      outcomes = mutations.values.map { |bytes| rejected?(report("native", bytes, :tolerant)) }
      expect(outcomes.count(true)).to be >= 50
      expect(outcomes.count(false)).to be >= 20
    end
  end

  describe "native backend guard" do
    it "routes every seed and fixture through the native WMF parser and never the Ruby side" do
      files.each do |name, bytes|
        native = native_use(bytes, "native")
        expect(native[:backend]).to be >= 1, "#{name}: Native.backend not selected"
        expect(native[:wmf]).to be >= 1, "#{name}: WmfHydrator not used" if wmf_detected?(bytes)
        ruby = native_use(bytes, "ruby")
        expect(ruby).to eq(backend: 0, wmf: 0), "#{name}: Ruby run touched native"
      end
    end

    it "raises instead of falling back to Ruby when forced native has no library" do
      bytes = files.fetch("standard-line.wmf")
      expect { ConformanceParity.with_backend("native", "") { Emf.parse(bytes) } }
        .to raise_error(Emf::Native::Unavailable)
    end
  end

  profiles.each do |profile|
    files.each do |name, bytes|
      it "#{profile}: #{name} reports identically" do
        difference = ConformanceParity.first_difference(report("ruby", bytes, profile), report("native", bytes, profile))
        expect(difference).to be_nil, "#{name} [#{profile}] first difference at #{difference}"
      end
    end

    it "#{profile}: all #{mutations.size} deterministic mutations report identically" do
      expect(compare(mutations, profile)).to be_empty
    end
  end

  it "the native path is used for every mutation too" do
    unused = mutations.reject do |_, bytes|
      native_use(bytes, "native").then { |c| c[:backend] >= 1 && (c[:wmf] >= 1 || !wmf_detected?(bytes)) }
    end
    expect(unused.keys).to be_empty
  end

  it "most mutations still reach the native WMF hydrator (not only generic rejection)" do
    reaching = mutations.count { |_, bytes| wmf_detected?(bytes) }
    expect(reaching).to be >= 150
  end
end
