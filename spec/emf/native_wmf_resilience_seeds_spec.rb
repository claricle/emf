# frozen_string_literal: true

require_relative "../../script/support/wmf_resilience_seeds"
require_relative "../support/native_wmf_bridge"

RSpec.describe "Native WMF resilience seeds" do
  include_context "native WMF bridge"

  let(:seeds) { WmfResilienceSeeds.build }
  let(:valid_seeds) { seeds.select { |seed| seed.fetch("expected_outcome") == "parsed" } }
  let(:rejected_seeds) { seeds.select { |seed| seed.fetch("expected_outcome") == "rejected" } }
  let(:expected_rejected_seed_names) do
    %w[
      header-size file-size max-record zero-record missing-eof negative-text-count
      placeable-checksum bitmap-short-record
    ]
  end

  it "parses and byte-preserves every generated valid seed through the native bridge" do
    expect(valid_seeds.length).to eq(8)
    combinations = valid_seeds.map { |seed| [seed.fetch("family"), seed.fetch("placeable")] }
    expect(combinations.sort_by { |family, placeable| [family, placeable ? 1 : 0] })
      .to eq(%w[bitmap geometry text unknown].product([false, true]).sort_by { |family, placeable| [family, placeable ? 1 : 0] })
    expect(Emf::Wmf::Parser).not_to receive(:call)

    valid_seeds.each do |seed|
      parsed = Emf.parse(seed.fetch("bytes"))

      expect(parsed.format).to eq(:wmf), seed.fetch("name")
      expect(Emf.serialize(parsed)).to eq(seed.fetch("bytes")), seed.fetch("name")
    end
  end

  it "rejects every generated malformed seed without fallback and recovers" do
    expect(rejected_seeds.map { |seed| seed.fetch("name") }).to match_array(expected_rejected_seed_names)
    expect(Emf::Wmf::Parser).not_to receive(:call)

    valid_bytes = valid_seeds.first.fetch("bytes")
    rejected_seeds.each do |seed|
      expect(seed.fetch("expected_outcome")).to eq("rejected"), seed.fetch("name")
      expect do
        Emf.parse(seed.fetch("bytes"))
      end.to raise_error(Emf::Error), seed.fetch("name")

      recovered = Emf.parse(valid_bytes)
      expect(Emf.serialize(recovered)).to eq(valid_bytes), "after #{seed.fetch('name')}"
    end
  end

  it "raises the Ruby parser's error class, offset and record code for every malformed seed" do
    rejected_seeds.each do |seed|
      name = seed.fetch("name")
      ruby_error = capture_error { Emf::Wmf::Parser.call(seed.fetch("bytes")) }
      native_error = capture_error { Emf.parse(seed.fetch("bytes")) }

      expect(ruby_error).to be_a(Emf::Error), name
      expect(native_error.class).to eq(ruby_error.class), "#{name}: native #{native_error.class} vs Ruby #{ruby_error.class}"
      next unless ruby_error.is_a?(Emf::ParseError)

      expect([native_error.offset, native_error.record_code]).to eq([ruby_error.offset, ruby_error.record_code]), name
    end
  end

  it "distinguishes record failures (ParseError) from header failures (FormatError)" do
    classes = rejected_seeds.to_h { |seed| [seed.fetch("name"), capture_error { Emf.parse(seed.fetch("bytes")) }.class] }

    expect(classes.select { |_, klass| klass == Emf::ParseError }.keys)
      .to match_array(%w[zero-record missing-eof negative-text-count bitmap-short-record])
    expect(classes.reject { |_, klass| klass == Emf::ParseError }.values.uniq).to eq([Emf::FormatError])
  end

  def capture_error
    yield
    nil
  rescue Emf::Error => e
    e
  end
end
