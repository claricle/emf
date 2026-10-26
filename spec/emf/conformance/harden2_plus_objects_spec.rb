# frozen_string_literal: true

require "spec_helper"
require_relative "support/emf_plus_payload_builder"

# Preservation pins for the EMF+ object-reference rules (MS-EMFPLUS 2.3.5.1, 2.1.1.22): valid streams stay clean.
RSpec.describe "EMF+ object rules, valid streams" do
  let(:build) { Emf::SpecSupport::EmfPlusBuilder }
  let(:payload) { Emf::SpecSupport::EmfPlusPayloadBuilder }
  let(:pen) { [0xDBC01002].pack("V") + [0, 0, 2, 1.0].pack("VVVe") + [0xDBC01002, 0, 0xFF112233].pack("V3") }
  let(:lines) { ->(id) { build.record(0x400D, flags: id, body: [2].pack("V") + build.float(0, 0, 5, 5)) } }

  def ids(bytes) = Emf::Conformance.check(bytes).diagnostics.map(&:requirement_id).grep(/\Aemfplus\.object\.(empty|wrong|id|optional)/)

  it "accepts slot 63 and a redefinition with the same type" do
    expect(ids(build.stream(build.object(2, 63, pen), lines.call(63), build.object(2, 63, pen), lines.call(63)))).to be_empty
  end

  it "accepts a continued image whose last chunk keeps the C flag, split across two comments" do
    data = payload.bitmap_image
    flags = 0x8000 | (5 << 8) | 4
    first = build.record(0x4008, flags: flags, body: [data.bytesize].pack("V") + data[0, 20])
    last = build.record(0x4008, flags: flags, body: [data.bytesize].pack("V") + data[20..])
    draw = build.record(0x401A, flags: 4, body: [0xFFFFFFFF, 2].pack("V2") + build.rect_f + build.rect_f)
    bytes = Emf::SpecSupport::CraftedEmf.build(records: [build.comment(build.header, first), build.comment(last, draw, build.eof)])
    expect(ids(bytes)).to be_empty.or eq(["emfplus.object.optional_id_range"])
    expect(ids(bytes)).not_to include("emfplus.object.empty_slot", "emfplus.object.wrong_type")
  end

  it "still flags a redefined slot of another type at the later draw" do
    stream = build.stream(build.object(2, 1, pen), build.object(1, 1, [0, 0xFF000000].pack("V2")), lines.call(1))
    expect(ids(stream)).to eq(["emfplus.object.wrong_type"])
  end
end
