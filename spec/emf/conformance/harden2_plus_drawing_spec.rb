# frozen_string_literal: true

require "spec_helper"
require_relative "support/emf_plus_builder"

# Final-pass audit of the EMF+ drawing and framing rules: valid float, compressed and
# relative-point drawing records must raise none of them.
RSpec.describe "EMF+ drawing and framing rules on valid records" do
  let(:build) { Emf::SpecSupport::EmfPlusBuilder }
  let(:rule_ids) do
    %w[emfplus.draw.count emfplus.draw.ellipse_size emfplus.draw.image_source_unit emfplus.record.fixed_size
       emfplus.record.data_size emfplus.record.data_size_alignment emfplus.record.body_bounds emfplus.header.signature
       emfplus.eof.placement]
  end
  let(:c) { 0x4000 }
  let(:p_flag) { 0x0800 }

  def hits(*records) = Emf::Conformance.check(build.stream(*records), profile: :strict).errors.map(&:requirement_id) & rule_ids

  def points_for(flags, count)
    if flags.anybits?(p_flag) then ([5, 0x81, 0x10] * count).pack("C*")[0, count * 3] # mixed 7- and 15-bit coordinates
    elsif flags.anybits?(c) then Array.new(count) { |i| [i, i] }.flatten.pack("s<*")
    else build.points(count)
    end
  end

  # [name, type, minimum count]
  counted = [["DrawBeziers", 0x4019, 4], ["DrawLines", 0x400D, 2], ["FillPolygon", 0x400C, 3]].freeze
  flag_values = [0, 0x4000, 0x0800].freeze
  fill_brush = [0xFF0000FF].pack("V").freeze

  counted.each do |name, type, min|
    flag_values.each do |flag|
      it "accepts #{name} with flags 0x#{flag.to_s(16)} and the minimum count" do
        body = (name.start_with?("Fill") ? fill_brush : "".b) + [min].pack("V") +
               points_for(flag, min)
        body += "\0" * (-body.bytesize % 4) # DataSize is 32-bit aligned (MS-EMFPLUS 2.3.3)
        expect(hits(build.record(type, flags: flag, body: body))).to be_empty
      end
    end
  end

  it "accepts DrawRects and FillRects with one rectangle, float and compressed" do
    float_rect = build.rect_f
    small_rect = [0, 0, 10, 10].pack("s<4")
    expect(hits(build.record(0x400B, body: [1].pack("V") + float_rect),
                build.record(0x400B, flags: 0x4000, body: [1].pack("V") + small_rect),
                build.record(0x400A, flags: 0x8000, body: [0xFF0000FF, 1].pack("V2") + float_rect),
                build.record(0x400A, flags: 0xC000, body: [0xFF0000FF, 1].pack("V2") + small_rect))).to be_empty
  end

  it "accepts ellipses at their stated sizes" do
    expect(hits(build.record(0x400F, body: build.rect_f), build.record(0x400F, flags: 0x4000, body: [0, 0, 5, 5].pack("s<4")),
                build.record(0x400E, body: [1].pack("V") + build.rect_f),
                build.record(0x400E, flags: 0x4000, body: [1].pack("V") + [0, 0, 5, 5].pack("s<4")))).to be_empty
  end

  it "accepts DrawImage and DrawImagePoints with UnitPixel" do
    src = [0, 2].pack("V2") + build.rect_f
    expect(hits(build.record(0x401A, body: src + build.rect_f),
                build.record(0x401A, flags: 0x4000, body: src + [0, 0, 5, 5].pack("s<4")),
                build.record(0x401B, body: src + [3].pack("V") + build.points(3)),
                build.record(0x401B, flags: 0x4000, body: src + [3].pack("V") + [0, 0, 1, 1, 2, 2].pack("s<6")))).to be_empty
  end

  it "still flags a one-point DrawLines" do
    body = [1].pack("V") + build.points(1)
    expect(hits(build.record(0x400D, body: body))).to include("emfplus.draw.count")
  end
end
