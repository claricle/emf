# frozen_string_literal: true

require "spec_helper"
require_relative "support/crafted_emf"
require_relative "support/emf_plus_builder"
require_relative "support/gap_wmf"
require_relative "support/fuzz_capped"
require_relative "support/record_inventories"

# The lens reports malformed records; it never raises on input the parser accepted.
RSpec.describe "Emf::Conformance robustness" do
  let(:crafted) { Emf::SpecSupport::CraftedEmf }
  let(:profiles) { %i[strict tolerant] }

  def check(type, body) = Emf::Conformance.check(crafted.build(records: [crafted.record(type, body)]), profile: :strict)

  {
    "RESTOREDC with no SavedDC" => [34, ""],
    "SELECTOBJECT with no ihObject" => [37, ""],
    "EXTTEXTOUTW too short for its Rectangle and offDx" => [84, "\0".b * 52],
    "CREATECOLORSPACE with no LogColorSpace" => [99, ""],
    "SETCOLORSPACE with a truncated body" => [100, ""]
  }.each do |label, (type, body)|
    it "reports, not raises, on a #{label}" do
      expect { check(type, body) }.not_to raise_error
    end
  end

  it "never raises on any EMF record type with a short zero-filled body the parser accepts" do
    crashes = (1..122).to_a.product([0, 4, 8, 16, 40, 60]).filter_map do |type, length|
      bytes = crafted.build(records: [crafted.record(type, "\0".b * length)])
      Emf.parse(bytes)
      Emf::Conformance.check(bytes, profile: :strict)
      nil
    rescue Emf::Error
      nil
    rescue StandardError => e
      "type #{type} length #{length}: #{e.class}: #{e.message}"
    end
    expect(crashes).to be_empty
  end

  # The per-metafile caches are WeakMaps whose values are weak too: a collection between the store and the read
  # used to leave nil. The stand-in forgets every value the moment it is stored.
  {
    "BitmapRules" => "emf.bitmap.positive_extent",
    "TextRules" => "emf.polytextout.dx",
    "CommentEscapeRules" => "emf.opaque.payload_bounds"
  }.each do |rules_name, id|
    it "#{rules_name} survives its cache entry being collected right after the store" do
      bytes = crafted.build(records: [crafted.record(37, "\0".b * 4)])
      Emf::Conformance.check(bytes, profile: :strict)
      rules = Emf::Conformance.const_get(rules_name)
      forgetful = Class.new do
        def [](_key) = nil

        def []=(_key, value)
          value
        end
      end
      stub_const("Emf::Conformance::#{rules_name}::CACHE", forgetful.new)
      context = Emf::Conformance::Context.new(metafile: Emf.parse(bytes), bytes: bytes)
      expect(rules.findings(context, id)).to eq([])
    end
  end

  # Parser bugs, not lens bugs: reading these EMF+ records through Emf.parse(...).emf_plus_stream allocates
  # without bound on a huge count field. The random sweep skips them (the repros are in the PR notes).
  parser_count_bombs = [0x400A, 0x400B, 0x400C, 0x400D, 0x4016, 0x4017, 0x4018, 0x4019, 0x401B, 0x4036].freeze

  it "reports a SetTSGraphics palette whose PaletteCount exceeds its bytes, without decoding it" do
    plus = Emf::SpecSupport::EmfPlusBuilder
    palette = [0, 0xFFFFFFF0].pack("V2") + ("\0".b * 4)
    body = ("\0".b * 36) + palette
    bytes = plus.stream(plus.record(0x4039, flags: 1, body: body))
    outcome = Emf::SpecSupport::FuzzCapped.run { Emf::Conformance.check(bytes, profile: :strict) }
    expect(outcome).to eq(:ok)
    ids = Emf::Conformance.check(bytes, profile: :strict).diagnostics.map(&:requirement_id)
    expect(ids).to include("emfplus.terminal.graphics_palette")
  end

  it "never raises on any EMF+ record type with a zero-filled or seeded random body of many sizes and flags" do
    plus = Emf::SpecSupport::EmfPlusBuilder
    rng = Random.new(37)
    crashes = (0x4001..0x403A).to_a.product([0, 4, 8, 16, 40, 60], [0, 0xFFFF, 0x8001]).filter_map do |type, length, flags|
      bodies = ["\0".b * length]
      bodies << Array.new(length) { rng.rand(256) }.pack("C*") unless parser_count_bombs.include?(type)
      bodies.product(profiles).each { |body, profile| Emf::Conformance.check(plus.stream(plus.record(type, flags: flags, body: body)), profile: profile) }
      nil
    rescue Emf::Error
      nil
    rescue StandardError => e
      "EMF+ type #{format('0x%04X', type)} length #{length} flags #{flags}: #{e.class}: #{e.message}"
    end
    expect(crashes).to be_empty
  end

  it "never raises on any WMF record function with zero-filled or seeded random parameter words" do
    wmf = Emf::SpecSupport::GapWmf
    rng = Random.new(37)
    functions = Emf::SpecSupport::RecordInventories::WMF_RECORD_TYPES.values
    crashes = functions.product([0, 1, 2, 4, 8, 12]).filter_map do |function, count|
      word_sets = [Array.new(count, 0), Array.new(count) { rng.rand(65_536) }]
      word_sets.product(profiles).each { |words, profile| Emf::Conformance.check(wmf.file(wmf.record(function, *words)), profile: profile) }
      nil
    rescue Emf::Error
      nil
    rescue StandardError => e
      "WMF function #{format('0x%04X', function)} words #{count}: #{e.class}: #{e.message}"
    end
    expect(crashes).to be_empty
  end
end
