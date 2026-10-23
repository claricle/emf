# frozen_string_literal: true

require "spec_helper"
require_relative "support/emf_plus_builder"

# The tolerant waiver covers only the body-less SetPageTransform (Size 12, DataSize 0) that LibreOffice writes.
RSpec.describe "EMF+ SetPageTransform and fixed-size tolerance" do
  plus = Emf::SpecSupport::EmfPlusBuilder
  fixed = "emfplus.record.fixed_size"
  bodyless = "emfplus.record.page_transform_bodyless"

  def severities(bytes, id, profile) = Emf::SpecSupport::EmfPlusBuilder.diagnostics(bytes, id, profile: profile).map(&:severity)

  it "reports a body-less SetPageTransform once, as a tolerant warning under its own id" do
    stream = plus.stream(plus.record(0x4030, flags: 1))
    expect(severities(stream, bodyless, :strict)).to eq([:error])
    expect(severities(stream, bodyless, :tolerant)).to eq([:warning])
    expect(severities(stream, fixed, :strict)).to be_empty
    expect(severities(stream, fixed, :tolerant)).to be_empty
  end

  it "keeps an oversized SetPageTransform a tolerant error under fixed_size" do
    stream = plus.stream(plus.record(0x4030, flags: 1, body: plus.float(1, 2)))
    expect(severities(stream, fixed, :tolerant)).to eq([:error])
    expect(severities(stream, bodyless, :tolerant)).to be_empty
  end

  it "keeps an undersized record of another type a tolerant error under fixed_size" do
    stream = plus.stream(plus.record(0x4025)) # Save without its 4-byte index
    expect(severities(stream, fixed, :strict)).to eq([:error])
    expect(severities(stream, fixed, :tolerant)).to eq([:error])
    expect(severities(stream, bodyless, :tolerant)).to be_empty
  end
end
