# frozen_string_literal: true

require "spec_helper"
require_relative "support/emf_plus_builder"

# Final-pass audit of the EMF+ state and property rules: waiver scoping and restore-stack bookkeeping.
RSpec.describe "EMF+ state and property hardening" do
  plus = Emf::SpecSupport::EmfPlusBuilder

  def idx(type, index) = Emf::SpecSupport::EmfPlusBuilder.record(type, body: [index].pack("V"))

  def severities(bytes, id, profile) = Emf::SpecSupport::EmfPlusBuilder.diagnostics(bytes, id, profile: profile).map(&:severity)

  describe "tolerant waiver scope" do
    # old-red: one waiver on emfplus.property.enum turned every invalid enum into a tolerant warning
    {
      "SmoothingMode 7" => [0x401E, 7 << 1],
      "TextRenderingHint 6" => [0x401F, 6],
      "InterpolationMode 8" => [0x4021, 8],
      "PixelOffsetMode 5" => [0x4022, 5],
      "CompositingMode 2" => [0x4023, 2],
      "CombineMode 6" => [0x4032, 6 << 8]
    }.each do |name, (type, flags)|
      it "keeps #{name} an error under tolerant" do
        body = type == 0x4032 ? plus.rect_f : "".b
        stream = plus.stream(plus.record(type, flags: flags, body: body))
        expect(severities(stream, "emfplus.property.enum", :tolerant)).to eq([:error])
      end
    end

    it "still waives CompositingQuality 0 (and any invalid value) as a tolerant warning only" do
      [0, 6].each do |value|
        stream = plus.stream(plus.record(0x4024, flags: value))
        expect(severities(stream, "emfplus.property.compositing_quality", :strict)).to eq([:error])
        expect(severities(stream, "emfplus.property.compositing_quality", :tolerant)).to eq([:warning])
      end
    end
  end

  describe "valid enum values" do
    it "accepts every defined value of every property record in both profiles" do
      records = []
      (0..5).each { |v| records << plus.record(0x401E, flags: (v << 1) | 1) << plus.record(0x401F, flags: v) }
      (0..7).each { |v| records << plus.record(0x4021, flags: v) }
      (0..4).each { |v| records << plus.record(0x4022, flags: v) }
      (0..1).each { |v| records << plus.record(0x4023, flags: v) }
      (1..5).each { |v| records << plus.record(0x4024, flags: v) }
      stream = plus.stream(*records)
      %i[strict tolerant].each do |profile|
        ids = Emf::Conformance.check(stream, profile: profile).diagnostics.map(&:requirement_id)
        expect(ids.grep(/emfplus\.property/)).to be_empty
      end
    end
  end

  describe "save/restore and container stacks" do
    it "accepts nested saves, containers and a restore of an older state" do
      stream = plus.stream(idx(0x4025, 0), idx(0x4028, 0), idx(0x4025, 1), idx(0x4029, 0), idx(0x4026, 0),
                           idx(0x4025, 5), idx(0x4026, 5))
      expect(Emf::Conformance.check(stream, profile: :strict).diagnostics.map(&:requirement_id).grep(/emfplus\.state/)).to be_empty
    end

    it "reports a restore skipped over by an older restore, and an unmatched index, once each" do
      stream = plus.stream(idx(0x4025, 0), idx(0x4025, 1), idx(0x4026, 0), idx(0x4026, 1), idx(0x4026, 9))
      expect(severities(stream, "emfplus.state.restore_unmatched", :strict)).to eq([:error])
      expect(severities(stream, "emfplus.state.restore_unknown_state", :strict)).to eq([:error])
    end

    it "handles a reused index after its pop" do
      stream = plus.stream(idx(0x4025, 2), idx(0x4026, 2), idx(0x4025, 2), idx(0x4026, 2))
      expect(Emf::Conformance.check(stream, profile: :strict).diagnostics.map(&:requirement_id).grep(/emfplus\.state/)).to be_empty
    end

    it "does not scan the whole stack for restores that match nothing" do
      count = 3000
      saves = Array.new(count) { |i| idx(0x4025, i) }
      restores = Array.new(count) { |i| idx(0x4026, 0x7fff0000 + i) }
      stream = plus.stream(*saves, *restores)
      metafile = Emf.parse(stream)
      context = Struct.new(:metafile, :records).new(metafile, metafile.records)
      scans = 0
      allow_any_instance_of(Array).to(receive(:rindex).and_wrap_original { |m, *a| (scans += 1) && m.call(*a) })
      Emf::Conformance::EmfPlusState.unmatched(context, [Emf::EmfPlus::Records::Save], Emf::EmfPlus::Records::Restore,
                                               "EmfPlusRestore", "EmfPlusSave")
      expect(scans).to be < 10
    end
  end
end
