# frozen_string_literal: true

require "spec_helper"
require_relative "support/emf_plus_builder"

RSpec.describe "EMF+ hardening audit" do
  let(:build) { Emf::SpecSupport::EmfPlusBuilder }
  let(:effect_draw) do
    build.record(0x401B, flags: 0x2000, body: [0, 2].pack("V2") + build.rect_f + [3].pack("V") + build.points(3))
  end
  let(:effect) { build.record(0x4038, body: ("\0" * 16).b + [0].pack("V")) }
  let(:between) { build.record(0x402B, body: "") }

  def found(bytes) = build.diagnostics(bytes, "emfplus.object.effect_missing", profile: :strict)

  # MS-EMFPLUS 2.3.4.9: the Effect "MUST have been specified in an earlier" SerializableObject record.
  it "accepts an effect draw whose SerializableObject is earlier but not adjacent" do
    expect(found(build.stream(effect, between, effect_draw))).to be_empty
  end

  it "still flags an effect draw with no earlier SerializableObject" do
    expect(found(build.stream(between, effect_draw)).size).to eq(1)
  end

  it "still accepts the adjacent effect" do
    expect(found(build.stream(effect, effect_draw))).to be_empty
  end
end
