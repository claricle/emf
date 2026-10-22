# frozen_string_literal: true

require "spec_helper"
require_relative "support/crafted_emf"
require_relative "support/emf_plus_builder"
require_relative "support/emf_plus_payload_builder"
require_relative "support/text_cases"
require_relative "support/deferred_cases"

# One diagnostic per defect: where two rules used to report the same defect, only the more specific one fires.
RSpec.describe "Emf::Conformance rule overlap" do
  let(:craft) { Emf::SpecSupport::CraftedEmf }
  let(:plus) { Emf::SpecSupport::EmfPlusBuilder }
  let(:payload) { Emf::SpecSupport::EmfPlusPayloadBuilder }

  def emf(type, body) = craft.build(records: [craft.record(type, body.b)])

  def report(input) = Emf::Conformance.check(input, profile: :strict)

  def ids(input, only: /\Aemf(plus)?\./) = report(input).diagnostics.map(&:requirement_id).grep(only)

  describe "EMF state and opaque records" do
    it "reports a short SETCOLORADJUSTMENT as emf.state.fixed_size only" do
      expect(ids(emf(23, ""))).to eq(%w[emf.state.fixed_size])
    end

    it "reports a short POLYTEXTOUTA as emf.opaque.text_arrays only" do
      expect(ids(emf(96, ""))).to eq(%w[emf.opaque.text_arrays])
    end

    it "reports a decoded SETICMPROFILEA, SETICMPROFILEW and SETLINKEDUFIS shortfall by the state rule only" do
      [[112, [0, 10, 0]], [113, [0, 10, 0]], [119, [5, 0, 0]]].each do |type, fields|
        id = type == 119 ? "emf.state.linked_ufis_bounds" : "emf.state.profile_bounds"
        expect(ids(emf(type, fields.pack("V*")))).to eq([id]), "record #{type}"
      end
    end

    it "keeps the opaque bounds rule for a record whose wire is Raw" do
      input = Emf.parse(emf(112, [0, 10, 0].pack("V3")))
      record = input.records.first
      raw = Emf::Emr::Binary::Records::Raw.read(craft.record(112, [0, 10, 0].pack("V3")))
      allow(record).to receive(:wire).and_return(raw)
      expect(ids(input)).to eq(%w[emf.opaque.payload_bounds])
    end

    it "reports a PIXELFORMAT below its layout as emf.opaque.fixed_size only, and an oversized one as the layout warning only" do
      expect(ids(emf(104, ""))).to eq(%w[emf.opaque.fixed_size])
      oversized = report(emf(104, [40, 1].pack("v2") + ("\0" * 40)))
      expect(oversized.diagnostics.map { |d| [d.requirement_id, d.severity] }).to eq([["emf.state.layout_size", :warning]])
    end

    it "keeps emf.state.fixed_size (decoded) and emf.record.fixed_size_raw (Raw) mutually exclusive" do
      decoded = emf(57, [1, 0].pack("V2")) # Size 16 where 12 is stated: decodes
      raw = emf(98, "".b) # SETICMMODE, Size 8: kept as a raw record
      expect(ids(decoded, only: /fixed_size/)).to eq(%w[emf.state.fixed_size])
      expect(ids(raw, only: /fixed_size/)).to eq(%w[emf.record.fixed_size_raw])
    end
  end

  describe "bitmap, text and recovery" do
    it "reports a packed bitmap ColorUsed shortfall as emf.bitmap.color_table only" do
      input = Emf::SpecSupport::DeferredCases.bitmap_cases.fetch("emf.bitmap.color_table").first
      expect(ids(input)).to eq(%w[emf.bitmap.color_table])
    end

    it "reports a Raw EXTTEXTOUTW with a wild Chars through the text rules, not the recovery rule" do
      text = Emf::SpecSupport::TextCases
      body = [0, 0, 99, 99, 1, 0, 0].pack("l<4V3") + text.descriptor(chars: 100_000, off_string: 76, off_dx: 100) + "abcd".b
      input = emf(84, body)
      expect(Emf.parse(input).errors.map(&:message)).to include(a_string_matching(/declares more entries than nSize allows/))
      found = ids(input, only: /\Aemf\.(exttextout|record)\./)
      expect(found).to include("emf.exttextout.string_bounds")
      expect(found).not_to include("emf.record.array_exceeds_size")
    end

    it "keeps the recovery rule when no text rule names the Raw record" do
      input = craft.build(records: [craft.record(4, ("\0" * 16).b + [100_000].pack("V"))])
      expect(ids(input, only: /\Aemf\.record\./)).to eq(%w[emf.record.array_exceeds_size])
    end
  end

  describe "EMF+" do
    def plus_ids(*records) = ids(plus.stream(*records), only: /\Aemfplus\.(record|draw|stream|object\.effect)/)

    it "reports an unaligned DataSize as data_size_alignment only" do
      expect(plus_ids(payload.draw_string(text: "abc"))).to eq(%w[emfplus.record.data_size_alignment])
    end

    it "reports a bad DrawEllipse DataSize as ellipse_size only" do
      bad = plus.record(0x400F, flags: 0x4000, body: [0, 0, 10, 10].pack("s<4") + ("\0" * 4))
      expect(plus_ids(bad)).to eq(%w[emfplus.draw.ellipse_size])
    end

    it "reports an undecodable DrawDriverString by the formula rule, not body_bounds or the stream rule" do
      expect(plus_ids(payload.driver_string(count: 4, glyph_count: 50))).to eq(%w[emfplus.draw.driver_string])
    end

    it "reports an effect draw without its effect as effect_missing only" do
      expect(plus_ids(payload.draw_image_points(flags: 0x2000))).to eq(%w[emfplus.object.effect_missing])
    end

    it "still names a missing effect when the E-flag DrawImagePoints body does not decode" do
      truncated = plus.record(0x401B, flags: 0x2000, body: "\0".b * 4)
      expect(plus_ids(truncated)).to include("emfplus.object.effect_missing")
    end
  end
end
