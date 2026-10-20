# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/emf_plus_records"

RSpec.describe "EMF+ float32 NaN payload round trip" do
  include Emf::SpecSupport::EmfPlusRecords

  let(:plus) { Emf::EmfPlus }
  let(:version) { [0xDBC01002].pack("V") }
  let(:solid_brush) { version + [0].pack("V") + [1, 2, 3, 4].pack("C4") }

  let(:pen_header) { version + [0, 0x010, 2, 1.5].pack("VVVe") }
  let(:color_matrix_guid) { [0x718F2615, 0x7933, 0x40E3].pack("Vvv") + ["a5115f68fe14dd74"].pack("H*") }

  def bits(*words) = words.pack("V*")

  def decode_all(bytes) = plus::Records.decode_all(plus::Parser.call(bytes))

  [0x7FA00001, 0x7F800001, 0xFFC12345].each do |nan|
    context format("with NaN bits 0x%08x", nan) do
      let(:nan_bytes) { bits(nan) }

      it "keeps them through PointF" do
        wire = bits(nan, 0x3F800000)

        expect(plus::Records::Primitives::PointF.read(wire).to_binary_s).to eq(wire)
      end

      it "keeps them through a SetWorldTransform matrix" do
        wire = record(0x402A, bits(0x3F800000, 0, 0, 0x3F800000, nan, nan))

        expect(decode_all(wire).first.to_binary).to eq(wire)
      end

      it "keeps them through a pen miter limit" do
        data = pen_header + nan_bytes + solid_brush
        wire = record(0x4008, data, flags: 2 << 8, data_size: data.bytesize)

        pen = plus::Objects.decode(plus::ObjectChain::LogicalObject.new(decode_all(wire)))

        expect(pen).to have_attributes(miter_limit: be_nan)
        expect(pen.to_binary).to eq(data)
      end

      it "keeps them through a float array" do
        wire = bits(2, 0x3F800000, nan, nan, 0)

        expect(plus::Records::Primitives::BlendFactors.read(wire).to_binary_s).to eq(wire)
      end

      it "keeps them through the ColorMatrix effect" do
        matrix = ("\0" * 96) + nan_bytes
        body = color_matrix_guid + [matrix.bytesize].pack("V") + matrix
        wire = record(0x4038, body, data_size: body.bytesize)

        expect(decode_all(wire).first.effect.to_binary).to eq(matrix)
      end
    end
  end

  it "still encodes ordinary values exactly" do
    wire = [1.5, -2.25].pack("e2")

    expect(plus::Records::Primitives::PointF.read(wire).to_binary_s).to eq(wire)
  end
end
