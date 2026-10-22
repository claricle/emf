# frozen_string_literal: true

require "spec_helper"
require_relative "../support/emf_plus_builder"

RSpec.describe "EMF+ ellipse size rule" do
  let(:build) { Emf::SpecSupport::EmfPlusBuilder }
  let(:compressed) { [0, 0, 10, 10].pack("s<4") }
  let(:full) { build.rect_f }
  let(:brush) { [0xFF0000FF].pack("V") }

  def found(bytes, profile: :strict) = build.diagnostics(bytes, "emfplus.draw.ellipse_size", profile: profile)

  # [name, type, Flags without C, body prefix, Size and DataSize with C set, with C clear]
  [
    ["DrawEllipse", 0x400F, 0x0000, "".b, [0x14, 0x08], [0x1C, 0x10]],
    ["FillEllipse", 0x400E, 0x8000, [0xFF0000FF].pack("V"), [0x18, 0x0C], [0x20, 0x14]]
  ].each do |name, type, flags, prefix, (size_c, data_c), (size_f, data_f)|
    describe name do
      it "accepts the compressed (Size #{size_c}, DataSize #{data_c}) and full (Size #{size_f}, DataSize #{data_f}) layouts" do
        expect(found(build.stream(build.record(type, flags: flags | 0x4000, body: prefix + compressed)))).to be_empty
        expect(found(build.stream(build.record(type, flags: flags, body: prefix + full)))).to be_empty
      end

      it "flags the padded compressed layout (DataSize #{data_c + 4}, Size #{size_c + 4}; C bit allows #{data_c}, #{size_c})" do
        bytes = build.stream(build.record(type, flags: flags | 0x4000, body: prefix + compressed + ("\0" * 4)))
        expect(found(bytes).map(&:message)).to contain_exactly(
          a_string_including("C bit set", "Size is #{size_c + 4}", "DataSize is #{data_c + 4}")
        )
      end

      it "leaves a Size that disagrees with DataSize to emfplus.stream.framing, which stops the walk before this rule" do
        bytes = build.stream(build.record(type, flags: flags, body: prefix + full, size: size_c))
        expect(found(bytes)).to be_empty
        expect(build.diagnostics(bytes, "emfplus.stream.framing")).not_to be_empty
      end

      it "flags RectF data under a set C bit (Size and DataSize of the full layout)" do
        bytes = build.stream(build.record(type, flags: flags | 0x4000, body: prefix + full))
        expect(found(bytes).first.message).to include("C bit set", "Size is #{size_f}", "DataSize is #{data_f}")
      end

      it "stays an error in the tolerant profile" do
        bytes = build.stream(build.record(type, flags: flags | 0x4000, body: prefix + full))
        expect(found(bytes, profile: :tolerant).map(&:severity)).to eq([:error])
      end
    end
  end

  it "ignores the other drawing records" do
    bytes = build.stream(build.record(0x400A, flags: 0x8000, body: build.counted_body("FillRects", 1)))
    expect(found(bytes)).to be_empty
  end
end
