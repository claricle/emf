# frozen_string_literal: true

require "spec_helper"
require_relative "../support/emf_plus_builder"

RSpec.describe "EMF+ drawing geometry rules" do
  let(:build) { Emf::SpecSupport::EmfPlusBuilder }

  def found(bytes, id, profile: :strict) = build.diagnostics(bytes, id, profile: profile)

  describe "emfplus.draw.count" do
    # [name, type, minimum count, Flags (0x8000 = solid-colour brush for the Fill records)]
    [
      ["DrawLines", 0x400D, 2], ["DrawBeziers", 0x4019, 4], ["DrawClosedCurve", 0x4017, 3], ["DrawCurve", 0x4018, 2],
      ["FillPolygon", 0x400C, 3, 0x8000], ["FillClosedCurve", 0x4016, 3, 0x8000],
      ["DrawRects", 0x400B, 1], ["FillRects", 0x400A, 1, 0x8000]
    ].each do |name, type, minimum, flags = 0|
      it "#{name}: flags #{minimum - 1} and accepts #{minimum}" do
        bad = build.stream(build.record(type, flags: flags, body: build.counted_body(name, minimum - 1)))
        expect(found(bad, "emfplus.draw.count").first.message).to include("#{name} has #{minimum - 1}", "at least #{minimum}")
        expect(found(build.stream(build.record(type, flags: flags, body: build.counted_body(name, minimum))),
                     "emfplus.draw.count")).to be_empty
      end
    end

    it "DrawImagePoints needs exactly 3 points" do
      image = lambda do |count|
        build.stream(build.record(0x401B, body: [0, 2].pack("V2") + build.rect_f + [count].pack("V") + build.points(count)))
      end
      [2, 4].each { |count| expect(found(image.call(count), "emfplus.draw.count").first.message).to include("exactly 3") }
      expect(found(image.call(3), "emfplus.draw.count")).to be_empty
    end

    it "counts compressed points the same way" do
      compressed = build.stream(build.record(0x400D, flags: 0x4000, body: [1].pack("V") + [0, 0].pack("s2")))
      expect(found(compressed, "emfplus.draw.count").first.message).to include("DrawLines has 1 points")
    end
  end

  describe "emfplus.draw.image_source_unit" do
    it "flags DrawImage and DrawImagePoints with a SrcUnit other than pixel, and accepts pixel" do
      image = ->(unit) { build.stream(build.record(0x401A, body: [0, unit].pack("V2") + build.rect_f + build.rect_f)) }
      expect(found(image.call(0), "emfplus.draw.image_source_unit").first.message).to include("SrcUnit is 0")
      expect(found(image.call(2), "emfplus.draw.image_source_unit")).to be_empty
      points = build.record(0x401B, body: [0, 4].pack("V2") + build.rect_f + [3].pack("V") + build.points(3))
      expect(found(build.stream(points), "emfplus.draw.image_source_unit").first.message).to include("DrawImagePoints")
      expect(found(image.call(0), "emfplus.draw.image_source_unit", profile: :tolerant).first.severity).to eq(:warning)
    end
  end
end
