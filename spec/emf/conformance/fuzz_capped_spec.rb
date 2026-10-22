# frozen_string_literal: true

require "spec_helper"
require_relative "support/fuzz_capped"

RSpec.describe Emf::SpecSupport::FuzzCapped do
  it "reads CPU time in the macOS and Linux ps formats" do
    expect(%w[0:05.50 00:00:05 01:02:03 1-00:00:01].map { |text| described_class.cpu_seconds(text) })
      .to eq([5.5, 5.0, 3723.0, 86_401.0])
  end

  it "budgets the child's memory growth, not the memory it shares with a large parent" do
    expect(described_class.over_budget?(10, 0.1)).to be(false)
    expect(described_class.over_budget?(described_class::MAX_GROWTH_KB + 1, 0.1)).to be(true)
    expect(described_class.over_budget?(0, described_class::MAX_CPU_SECONDS + 1)).to be(true)
  end

  it "stops a child whose memory keeps growing" do
    held = []
    expect(described_class.run { loop { held << ("x" * 4_000_000) } }).to eq(:over_budget)
  end

  it "lets a cheap block finish" do
    expect(described_class.run { 1 + 1 }).to eq(:ok)
  end
end
