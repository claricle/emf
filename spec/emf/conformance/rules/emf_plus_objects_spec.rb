# frozen_string_literal: true

require "spec_helper"
require_relative "../support/emf_plus_builder"

RSpec.describe "EMF+ object-reference and state rules" do
  let(:build) { Emf::SpecSupport::EmfPlusBuilder }
  let(:comment_offset) { 88 }

  def found(bytes, id, profile: :strict) = build.diagnostics(bytes, id, profile: profile)

  # DrawLines with 2 points that references pen `id` in the object-id byte of Flags.
  def draw_lines(id) = build.record(0x400D, flags: id, body: [2].pack("V") + build.float(0, 0, 5, 5))

  # A decodable EmfPlusPen (MS-EMFPLUS 2.2.1.7): solid 1px pen over a solid brush.
  let(:pen) do
    version = [0xDBC01002].pack("V")
    version + [0, 0, 2, 1.0].pack("VVVe") + version + [0].pack("V") + [1, 2, 3, 4].pack("C4")
  end

  describe "object references" do
    it "accepts a pen defined earlier" do
      bytes = build.stream(build.object(2, 3, pen), draw_lines(3))
      expect(Emf::Conformance.check(bytes).diagnostics.map(&:requirement_id)).to be_empty
    end

    it "flags a reference to an empty slot at the referring record, and a definition after the draw" do
      diagnostic = found(build.stream(draw_lines(3)), "emfplus.object.empty_slot").first
      expect(diagnostic.message).to include("DrawLines pen reference 3")
      expect([diagnostic.offset, diagnostic.record_type]).to eq([comment_offset, 0x400D])
      late = build.stream(draw_lines(3), build.object(2, 3))
      expect(found(late, "emfplus.object.empty_slot").size).to eq(1)
    end

    it "flags a reference to an object of another type" do
      diagnostic = found(build.stream(build.object(1, 3), draw_lines(3)), "emfplus.object.wrong_type").first
      expect(diagnostic.message).to include("pen reference 3", "different type")
    end

    it "flags an ObjectID above 63" do
      expect(found(build.stream(draw_lines(200)), "emfplus.object.id_range").first.message).to include("reference 200")
    end

    it "reports each wrong reference of a record under its own rule only" do
      bytes = build.stream(draw_lines(7))
      expect(Emf::Conformance.check(bytes).diagnostics.map(&:requirement_id)).to eq(["emfplus.object.empty_slot"])
    end
  end

  describe "emfplus.object.effect_missing" do
    let(:effect_draw) do
      build.record(0x401B, flags: 0x2000, body: [0, 2].pack("V2") + build.rect_f + [3].pack("V") + build.points(3))
    end
    let(:effect) { build.record(0x4038, body: ("\0" * 16).b + [0].pack("V")) }

    it "flags an effect draw with no SerializableObject before it, and accepts one directly before" do
      diagnostic = found(build.stream(effect_draw), "emfplus.object.effect_missing").first
      expect([diagnostic.offset, diagnostic.record_type]).to eq([comment_offset, 0x401B])
      expect(found(build.stream(effect, effect_draw), "emfplus.object.effect_missing")).to be_empty
    end
  end

  describe "state matching" do
    def save(index) = build.record(0x4025, body: [index].pack("V"))

    def restore(index) = build.record(0x4026, body: [index].pack("V"))

    it "flags a Restore with no Save, and a repeated Restore" do
      expect(found(build.stream(restore(0)), "emfplus.state.restore_unmatched").first.message).to include("StackIndex 0")
      expect(found(build.stream(save(0), restore(0), restore(0)), "emfplus.state.restore_unmatched").size).to eq(1)
    end

    it "accepts nested saves and a restore that pops several levels" do
      nested = build.stream(save(0), save(1), restore(1), restore(0))
      expect(found(nested, "emfplus.state.restore_unmatched")).to be_empty
      skipping = build.stream(save(0), save(1), restore(0), restore(1))
      expect(found(skipping, "emfplus.state.restore_unmatched").size).to eq(1)
    end

    it "matches EndContainer against either begin-container record, on its own stack" do
      begin_container = build.record(0x4027, flags: 2, body: build.rect_f + build.rect_f + [5].pack("V"))
      no_params = build.record(0x4028, body: [6].pack("V"))
      end_container = ->(index) { build.record(0x4029, body: [index].pack("V")) }
      ok = build.stream(begin_container, no_params, end_container.call(6), end_container.call(5))
      expect(found(ok, "emfplus.state.end_container_unmatched")).to be_empty
      expect(found(build.stream(save(5), end_container.call(5)), "emfplus.state.end_container_unmatched").size).to eq(1)
    end
  end
end
