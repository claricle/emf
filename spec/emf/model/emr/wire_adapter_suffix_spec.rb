# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emf::Model::Emr::Records::WireAdapter, ".suffix_of" do
  let(:wire) { Struct.new(:num_bytes).new(8) }

  it "returns one shared frozen empty string when the layout consumes the record" do
    first = described_class.suffix_of("12345678".b, wire)
    second = described_class.suffix_of("abcdefgh".b, wire)

    expect(first).to eq("".b).and be_frozen
    expect(first.encoding).to eq(Encoding::BINARY)
    expect(first).to equal(second)
  end

  it "returns the trailing bytes beyond the layout, frozen and binary" do
    suffix = described_class.suffix_of("12345678XYZ".b, wire)

    expect(suffix).to eq("XYZ".b).and be_frozen
    expect(suffix.encoding).to eq(Encoding::BINARY)
  end

  it "returns empty when the layout is larger than the record" do
    expect(described_class.suffix_of("1234".b, wire)).to eq("".b)
  end
end
