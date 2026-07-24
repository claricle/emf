# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emf::Model::Metafile do
  let(:header) { Struct.new(:bounds).new(Rect.new(0, 0, 100, 100)) }
  let(:rect_const) { Emf::Model::Geometry::Rect }

  it "freezes records and errors on construction" do
    mf = described_class.new(format: :emf, header: nil, records: [])
    expect(mf.records).to be_frozen
    expect(mf.errors).to be_frozen
  end

  it "reports ok? when no errors" do
    ok = described_class.new(format: :emf, header: nil, records: [])
    bad = described_class.new(format: :emf, header: nil, records: [],
                              errors: [Emf::ParseError.new(offset: 0, record_code: 1, message: "x")])
    expect(ok).to be_ok
    expect(bad).not_to be_ok
    expect(bad).to be_errors
  end

  it "iterates records via Enumerable" do
    a = Struct.new(:n).new(1)
    b = Struct.new(:n).new(2)
    mf = described_class.new(format: :emf, header: nil, records: [a, b])
    expect(mf.map(&:n)).to eq([1, 2])
  end
end
