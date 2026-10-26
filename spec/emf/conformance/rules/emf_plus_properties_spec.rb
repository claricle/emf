# frozen_string_literal: true

require "spec_helper"
require_relative "../support/emf_plus_builder"

RSpec.describe "EMF+ property, clip and page-unit rules" do
  let(:build) { Emf::SpecSupport::EmfPlusBuilder }

  def found(bytes, id, profile: :strict) = build.diagnostics(bytes, id, profile: profile)

  def stream_of(type, flags) = build.stream(build.record(type, flags: flags))

  describe "emfplus.property.enum" do
    # [name, type, flags for the first value outside the enumeration, flags for the last allowed value]
    [
      ["SetAntiAliasMode SmoothingMode", 0x401E, 6 << 1, (5 << 1) | 1],
      ["SetTextRenderingHint", 0x401F, 6, 5],
      ["SetInterpolationMode", 0x4021, 8, 7],
      ["SetPixelOffsetMode", 0x4022, 5, 4],
      ["SetCompositingMode", 0x4023, 2, 1]
    ].each do |name, type, bad, good|
      it "#{name}: flags #{bad} and accepts #{good}" do
        expect(found(stream_of(type, bad), "emfplus.property.enum").size).to eq(1)
        expect(found(stream_of(type, good), "emfplus.property.enum")).to be_empty
      end
    end

    it "checks the CombineMode of the clip records" do
      clip = ->(flags) { build.stream(build.record(0x4032, flags: flags, body: build.rect_f)) }
      expect(found(clip.call(6 << 8), "emfplus.property.enum").first.message).to include("CombineMode value 6")
      expect(found(clip.call(5 << 8), "emfplus.property.enum")).to be_empty
    end

    it "is a warning under tolerant with the producer reason in the waiver" do
      expect(found(stream_of(0x4024, 6), "emfplus.property.compositing_quality").size).to eq(1)
      expect(found(stream_of(0x4024, 5), "emfplus.property.compositing_quality")).to be_empty
      diagnostic = found(stream_of(0x4024, 0), "emfplus.property.compositing_quality", profile: :tolerant).first
      expect(diagnostic.severity).to eq(:warning)
      expect(diagnostic.waiver).to include("CompositingQuality 0")
    end
  end

  describe "emfplus.property.text_contrast" do
    it "flags values outside 1000..2200 and accepts the ends" do
      expect(found(stream_of(0x4020, 999), "emfplus.property.text_contrast").first.message).to include("999")
      expect(found(stream_of(0x4020, 2201), "emfplus.property.text_contrast").size).to eq(1)
      [1000, 2200].each { |ok| expect(found(stream_of(0x4020, ok), "emfplus.property.text_contrast")).to be_empty }
    end
  end

  describe "page unit" do
    let(:page) { ->(unit) { build.stream(build.record(0x4030, flags: unit, body: build.float(1))) } }

    it "flags a PageUnit outside UnitType" do
      expect(found(page.call(7), "emfplus.transform.page_unit").first.message).to include("PageUnit 7")
      expect(found(page.call(6), "emfplus.transform.page_unit")).to be_empty
    end

    it "warns (never errors) on UnitTypeWorld and UnitTypeDisplay, for SetPageTransform and BeginContainer" do
      expect(found(page.call(0), "emfplus.transform.page_unit_discouraged").first.severity).to eq(:warning)
      expect(found(page.call(1), "emfplus.transform.page_unit_discouraged").size).to eq(1)
      expect(found(page.call(2), "emfplus.transform.page_unit_discouraged")).to be_empty
      container = build.stream(build.record(0x4027, flags: 1, body: build.rect_f + build.rect_f + [1].pack("V")))
      expect(found(container, "emfplus.transform.page_unit_discouraged").first.message).to include("BeginContainer")
    end
  end
end
