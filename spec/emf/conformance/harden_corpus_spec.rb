# frozen_string_literal: true

require "spec_helper"
require_relative "support/crafted_emf"
require_relative "support/emf_plus_builder"

# Tolerant-mode findings from files written by real producers outside the repository corpus (vectory's svg2emf,
# ps2emf and eps2emf output, LibreOffice's emfio and graphicfilter test files). Each case copies the minimal
# pattern into crafted bytes; no external file is committed.
RSpec.describe "Emf::Conformance real-producer deviations" do
  crafted = Emf::SpecSupport::CraftedEmf
  plus = Emf::SpecSupport::EmfPlusBuilder

  def severities(bytes, id, profile)
    Emf::Conformance.check(bytes, profile: profile).diagnostics.select { |d| d.requirement_id == id }.map(&:severity).uniq
  end

  # Both profiles report the finding; only the tolerant one downgrades it to a warning.
  def downgraded(bytes, id)
    expect(severities(bytes, id, :strict)).to eq([:error])
    expect(severities(bytes, id, :tolerant)).to eq([:warning])
    expect(Emf::Conformance.check(bytes, profile: :tolerant)).to be_valid
  end

  describe "emf.object.handle_range" do
    brush = crafted.record(39, [1, 0, 0, 0].pack("V4"))
    pen = crafted.record(38, [2, 0, 1, 0, 0].pack("V5"))
    select_object = ->(handle) { crafted.record(37, [handle].pack("V")) }

    # vectory's converters write Handles=1 and then create and select objects 1 and 2.
    vectory = crafted.build(records: [brush, select_object.call(1), pen, select_object.call(2)], n_handles: 1)

    it "is a strict error and a tolerant warning for the Handles=1 pattern vectory's converters write" do
      expect(Emf::Conformance.check(vectory).errors.map(&:requirement_id)).to include("emf.object.handle_range")
      downgraded(vectory, "emf.object.handle_range")
    end

    it "stays silent when the header Handles count covers every index" do
      covered = crafted.build(records: [brush, select_object.call(1), pen, select_object.call(2)], n_handles: 3)
      expect(severities(covered, "emf.object.handle_range", :strict)).to be_empty
    end

    it "stays silent for a stock object index under Handles=1" do
      stock = crafted.build(records: [select_object.call(0x80000005)], n_handles: 1)
      expect(severities(stock, "emf.object.handle_range", :strict)).to be_empty
    end
  end

  describe "EMF+ records written by LibreOffice's test producers" do
    clip_region = ->(id) { plus.record(0x4034, flags: id) }

    it "downgrades a SetClipRegion naming a never-defined region slot (graphicfilter fdo38580-3)" do
      downgraded(plus.stream(clip_region.call(3)), "emfplus.object.optional_empty_slot")
    end

    it "downgrades DrawString's 0xFFFFFFFF StringFormatId (TestDrawStringTransparent)" do
      body = [0xFF000000, 0xFFFFFFFF, 1].pack("V3") + plus.float(0, 0, 10, 10) + "a\0".b
      stream = plus.stream(plus.record(0x401C, flags: 0x8000, body: body))
      expect(severities(stream, "emfplus.object.optional_id_range", :strict)).to eq([:error])
      expect(severities(stream, "emfplus.object.optional_id_range", :tolerant)).to eq([:warning])
    end

    it "downgrades a body-less SetPageTransform (TestAlignRtlReading, tdf93750)" do
      downgraded(plus.stream(plus.record(0x4030, flags: 1)), "emfplus.record.page_transform_bodyless")
    end

    it "keeps accepting a SetPageTransform with its scale" do
      whole = plus.stream(plus.record(0x4030, flags: 2, body: plus.float(1)))
      expect(severities(whole, "emfplus.record.fixed_size", :strict)).to be_empty
    end

    it "keeps an out-of-range SetClipRegion region id an error in tolerant mode (MS-EMFPLUS 2.3.1.5: 0..63)" do
      stream = plus.stream(clip_region.call(200))
      expect(severities(stream, "emfplus.object.id_range", :tolerant)).to eq([:error])
      expect(severities(stream, "emfplus.object.optional_id_range", :tolerant)).to be_empty
    end

    it "still reports a region reference to an object of another type as an error in tolerant mode" do
      stream = plus.stream(plus.object(1, 3), clip_region.call(3))
      expect(severities(stream, "emfplus.object.wrong_type", :tolerant)).to eq([:error])
    end
  end
end
