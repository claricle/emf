# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emf::Emr::Binary::FastFill, "nested struct build" do
  types = Emf::Binary::Types
  bindata_writer = BinData::Base.instance_method(:to_binary_s)

  let(:pen) { Emf::Emr::Binary::Records::CreatePen }
  let(:clip) { Emf::Emr::Binary::Records::IntersectClipRect }
  let(:brush) { Emf::Emr::Binary::Records::CreateBrushIndirect }

  # The construction BinData itself performs, the reference for equality.
  def expect_same_as_bindata(klass, attrs, writer)
    wire = klass.new(**attrs)
    reference = klass.new(attrs.dup)
    expect(wire.snapshot).to eq(reference.snapshot)
    expect(wire.to_binary_s).to eq(writer.bind_call(reference))
    expect(wire.num_bytes).to eq(reference.num_bytes)
    wire
  end

  it "builds nested fields from hashes" do
    wire = expect_same_as_bindata(pen, { ih_pen: 3, pen_style: 5, width: { x: 7, y: -2 },
                                         color: { red: 1, green: 2, blue: 3, reserved: 0 } }, bindata_writer)
    expect(wire.width.x).to eq(7)
    expect(wire.color.blue).to eq(3)
  end

  it "builds nested fields from structs of the expected class" do
    attrs = { left: 1, top: 2, right: 3, bottom: 4 }
    wire = expect_same_as_bindata(clip, { rcl_clip: types::RectL.new(attrs) }, bindata_writer)
    expect(wire.rcl_clip.bottom).to eq(4)
  end

  it "copies values from a struct without sharing its field objects" do
    source = types::PointL.new(x: 9, y: 8)
    wire = pen.new(width: source)
    source.x.assign(0)
    expect(wire.width.x).to eq(9)
  end

  it "leaves unnamed nested leaves clear in a partial hash" do
    wire = expect_same_as_bindata(pen, { pen_style: 1, width: { y: 6 }, color: { blue: 9 } }, bindata_writer)
    expect(wire.width.x).to eq(0)
    expect(wire.color.red).to eq(0)
  end

  it "skips nil nested values like BinData" do
    expect_same_as_bindata(pen, { width: { x: nil, y: 4 } }, bindata_writer)
  end

  it "builds a ColorRef struct beside scalar fields" do
    attrs = { style: 1, color: types::ColorRef.new(red: 4, green: 5, blue: 6, reserved: 0), hatch: 2 }
    expect_same_as_bindata(brush, attrs, bindata_writer)
  end

  it "falls back to BinData for a struct of another class" do
    expect_same_as_bindata(pen, { width: types::SizeL.new(cx: 5, cy: 6) }, bindata_writer)
  end

  it "falls back to BinData for string keys and unknown keys" do
    expect_same_as_bindata(pen, { width: { "x" => 5, "y" => 6 } }, bindata_writer)
    expect_same_as_bindata(pen, { width: { x: 5, bogus: 6 } }, bindata_writer)
  end

  it "raises as BinData does for a value of the wrong type" do
    expect { pen.new(width: 5) }.to raise_error(StandardError)
    expect { pen.new({ width: 5 }) }.to raise_error(StandardError)
  end
end
