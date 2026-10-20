# frozen_string_literal: true

require_relative "../support/native_wmf_bridge"

RSpec.describe "Native WMF resource limits" do
  include_context "native WMF bridge"

  let(:bytes) { File.binread(File.expand_path("../fixtures/wmf/standard-line.wmf", __dir__)) }

  it "accepts the exact input byte limit and rejects one byte less without Ruby retry" do
    expect(Emf::Wmf::Parser).not_to receive(:call)
    stub_const("Emf::Wmf::Binary::MAX_INPUT_BYTES", bytes.bytesize)

    parsed = Emf.parse(bytes)
    expect(Emf.serialize(parsed)).to eq(bytes)

    stub_const("Emf::Wmf::Binary::MAX_INPUT_BYTES", bytes.bytesize - 1)
    expect { Emf.parse(bytes) }.to raise_error(Emf::FormatError, /input too large/)
  end

  it "counts EOF at the exact record limit and rejects one fewer without Ruby retry" do
    expect(Emf::Wmf::Parser).not_to receive(:call)
    records = Emf.parse(bytes).records.length
    expect(records).to be > 1

    stub_const("Emf::Wmf::Binary::MAX_RECORDS", records)
    parsed = Emf.parse(bytes)
    expect(parsed.records.length).to eq(records)
    expect(parsed.records.last).to be_a(Emf::Model::Wmf::Records::Eof)
    expect(Emf.serialize(parsed)).to eq(bytes)

    stub_const("Emf::Wmf::Binary::MAX_RECORDS", records - 1)
    expect { Emf.parse(bytes) }.to raise_error(Emf::FormatError, /record limit exceeded/)
  end
end
