# frozen_string_literal: true

require "spec_helper"
require "emf/resource_limits"
require_relative "../support/resource_contract"
require_relative "../support/resource_budget_fixtures"

RSpec.describe "Ruby resource admission performance" do
  include Emf::SpecSupport::ResourceContract
  include Emf::SpecSupport::ResourceBudgetFixtures

  around { |example| with_resource_backend("ruby") { example.run } }

  it "parses ordinary records without a separate budget record walk" do
    bytes = minimal_resource_emf + (resource_record(33, 8) * 4096) + resource_record(14, 20)
    expect(Emf::ResourceBudget).not_to receive(:check!)

    parsed = Emf.parse(bytes)
    expect(parsed.records.length).to eq(4097)
    expect(parsed.errors).to be_empty
    expect(Emf.serialize(parsed)).to eq(bytes)
  end

  it "keeps trailing PolyText bytes outside admission after EOF" do
    tail = budget_poly_text.byteslice(88..)
    bytes = minimal_resource_emf + resource_record(14, 20) + tail
    expect(Emf::ResourceBudget).not_to receive(:check!)

    expect(Emf.parse(bytes).trailing).to eq(tail)
  end

  it "performs exact admission once when the parser encounters PolyText" do
    record = budget_poly_text.byteslice(88..)
    bytes = minimal_resource_emf + record + record
    expect(Emf::ResourceBudget).to receive(:check!).once.and_call_original

    expect(Emf.serialize(Emf.parse(bytes))).to eq(bytes)
  end

  it "rejects overlapping PolyText charges before decoding the Ruby record" do
    count = 1024
    chars = 100_000
    fixed = 32 + (count * 24)
    descriptor = [0, 0, chars, fixed + 8, 0x100, 0].pack("V6")
    payload = ("\0" * 28) + [count].pack("V") + (descriptor * count) + ("a" * chars)
    bytes = minimal_resource_emf + [96, payload.bytesize + 8].pack("V2") + payload
    expected = begin
      Emf::ResourceBudget.check!(bytes)
    rescue Emf::ResourceLimitError => e
      [e.resource, e.limit, e.actual]
    end
    expect(expected.first).to eq(:work_units)
    expect(Emf::Emr::Parser).not_to receive(:read_record_at)

    expect { Emf.parse(bytes) }.to raise_error(Emf::ResourceLimitError) { |error|
      expect([error.resource, error.limit, error.actual]).to eq(expected)
    }
  end
end
