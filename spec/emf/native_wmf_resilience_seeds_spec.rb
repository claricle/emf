# frozen_string_literal: true

require_relative "../../script/support/wmf_resilience_seeds"
require_relative "../support/native_wmf_bridge"

RSpec.describe "Native WMF resilience seeds" do
  include_context "native WMF bridge"

  let(:seeds) { WmfResilienceSeeds.build }
  let(:valid_seeds) { seeds.select { |seed| seed.fetch("expected_outcome") == "parsed" } }
  let(:bad_placeable_checksum) do
    seeds.find { |seed| seed.fetch("name") == "placeable-checksum" }
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

  it "rejects the malformed placeable checksum without Ruby parser fallback" do
    expect(bad_placeable_checksum.fetch("expected_outcome")).to eq("rejected")
    expect(bad_placeable_checksum.fetch("placeable")).to be(true)
    expect(Emf::Wmf::Parser).not_to receive(:call)

    expect { Emf.parse(bad_placeable_checksum.fetch("bytes")) }.to raise_error(Emf::Error)
  end
end
