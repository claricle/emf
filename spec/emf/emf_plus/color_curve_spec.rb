# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/emf_plus_records"

# MS-EMFPLUS Appendix A note <10> ("Windows produces corrupt records when the
# ColorCurve effect is used", ch05-appendix-a-product-behavior.md:77) gives no
# corrupt shape, so the decoder tolerates any block that is not a full
# 12-byte CurveAdjustment/CurveChannel/AdjustmentIntensity body.
RSpec.describe Emf::EmfPlus::Effects::ColorCurve do
  full = [3, 2, -9].pack("VVl<")
  let(:guid) { "dd6a0022-58e4-4a67-9d9b-d48eb881a53d" }

  def decode(buffer)
    serializable = Struct.new(:object_guid, :buffer, :offset, :type).new(guid, buffer, 0, 0x4008)
    Emf::EmfPlus::Effects.decode(serializable)
  end

  it "decodes out-of-range enum values and intensity without rejecting them" do
    buffer = [0xFFFF, 0xFFFF, -100_000].pack("VVl<")

    expect(decode(buffer)).to have_attributes(curve_adjustment: 0xFFFF, curve_channel: 0xFFFF, adjustment_intensity: -100_000)
  end

  [0, 4, 8, 11].each do |size|
    it "keeps a #{size}-byte block raw" do
      raw = full.byteslice(0, size)

      expect(decode(raw)).to be_a(Emf::EmfPlus::Effects::Opaque).and have_attributes(to_binary: raw)
    end
  end
end
