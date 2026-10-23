# frozen_string_literal: true

require "spec_helper"
require_relative "support/emf_plus_builder"

# Only optional references (StringFormatId, ImageAttributesID, a clip Region) may be absent. A missing mandatory
# reference (pen, brush, path, font, image, fill region) stays an error in the tolerant profile too.
RSpec.describe "EMF+ mandatory versus optional object references" do
  plus = Emf::SpecSupport::EmfPlusBuilder

  def severities(bytes, id, profile)
    Emf::Conformance.check(bytes, profile: profile).diagnostics.select { |d| d.requirement_id == id }.map(&:severity).uniq
  end

  def draw_lines(id)
    builder = Emf::SpecSupport::EmfPlusBuilder
    builder.record(0x400D, flags: id, body: [2].pack("V") + builder.float(0, 0, 5, 5))
  end

  def draw_string(format_id, font: false)
    body = [0xFF000000, format_id, 1].pack("V3") + Emf::SpecSupport::EmfPlusBuilder.float(0, 0, 10, 10) + "a\0".b
    draw = Emf::SpecSupport::EmfPlusBuilder.record(0x401C, flags: 0x8000, body: body)
    return Emf::SpecSupport::EmfPlusBuilder.stream(draw) unless font

    Emf::SpecSupport::EmfPlusBuilder.stream(Emf::SpecSupport::EmfPlusBuilder.object(6, 0), draw)
  end

  it "keeps a never-defined pen an error in both profiles" do
    stream = plus.stream(draw_lines(3))
    expect(severities(stream, "emfplus.object.empty_slot", :strict)).to eq([:error])
    expect(severities(stream, "emfplus.object.empty_slot", :tolerant)).to eq([:error])
    expect(severities(stream, "emfplus.object.optional_empty_slot", :tolerant)).to be_empty
  end

  it "keeps an out-of-range pen an error in both profiles" do
    stream = plus.stream(draw_lines(200))
    expect(severities(stream, "emfplus.object.id_range", :strict)).to eq([:error])
    expect(severities(stream, "emfplus.object.id_range", :tolerant)).to eq([:error])
    expect(severities(stream, "emfplus.object.optional_id_range", :tolerant)).to be_empty
  end

  it "downgrades DrawString's 0xFFFFFFFF StringFormatId to a tolerant warning under the optional id" do
    stream = draw_string(0xFFFFFFFF)
    expect(severities(stream, "emfplus.object.optional_id_range", :strict)).to eq([:error])
    expect(severities(stream, "emfplus.object.optional_id_range", :tolerant)).to eq([:warning])
    expect(severities(stream, "emfplus.object.id_range", :tolerant)).to be_empty
  end

  it "downgrades a never-defined StringFormatId slot under the optional empty-slot id" do
    stream = draw_string(5, font: true)
    expect(severities(stream, "emfplus.object.optional_empty_slot", :tolerant)).to eq([:warning])
    expect(severities(stream, "emfplus.object.empty_slot", :tolerant)).to be_empty
  end
end
