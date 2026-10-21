# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emf::Emr::Binary::FastFill, "generated build" do
  codes = Emf::Emr::Binary::TypeCodes
  types = Emf::Binary::Types
  bindata_writer = BinData::Base.instance_method(:to_binary_s)
  records = Emf::Emr::Binary::Records

  all_fillers = lambda do
    ids = codes.constants.map { |name| codes.const_get(name) }.uniq
    ids.flat_map { |id| [described_class.for(id), described_class.for_points(id), described_class.for_text(id)] }.compact
  end

  def expect_same_as_bindata(klass, attrs, writer)
    wire = klass.new(**attrs)
    reference = klass.new(attrs.dup)
    expect(wire.snapshot).to eq(reference.snapshot)
    expect(wire.to_binary_s).to eq(writer.bind_call(reference))
    expect(wire.num_bytes).to eq(reference.num_bytes)
    wire
  end

  it "keeps every filler enabled behind the load-time guard" do
    fillers = all_fillers.call
    expect(fillers.count { |f| f.instance_of?(described_class) }).to eq(37)
    expect(fillers.count { |f| f.instance_of?(described_class::PointArrayFill) }).to eq(10)
    expect(fillers.count { |f| f.instance_of?(described_class::TextFill) }).to eq(2)
    fillers.each { |filler| expect { filler.verify! }.not_to raise_error }
  end

  it "defines a generated builder on every filler" do
    all_fillers.call.each do |filler|
      expect(filler.singleton_class.instance_method(:build_attrs).source_location.first).to eq(
        File.expand_path("../../../lib/emf/emr/binary/fast_fill.rb", __dir__)
      )
    end
  end

  it "builds scalar keywords like BinData" do
    expect_same_as_bindata(records::SelectObject, { ih_object: 4 }, bindata_writer)
    expect_same_as_bindata(records::RestoreDc, { saved_dc: -1 }, bindata_writer)
  end

  it "builds nested structs given as the same class" do
    rect = types::RectL.new(left: 1, top: 2, right: 3, bottom: 4)
    wire = expect_same_as_bindata(records::IntersectClipRect, { rcl_clip: rect }, bindata_writer)
    rect.left.assign(99)
    expect(wire.rcl_clip.left).to eq(1)
    expect_same_as_bindata(records::CreatePen,
                           { ih_pen: 1, pen_style: 2, width: types::PointL.new(x: 5, y: 6),
                             color: types::ColorRef.new(red: 1, green: 2, blue: 3, reserved: 0) }, bindata_writer)
  end

  it "builds nested structs given as hashes, nil values and other classes" do
    expect_same_as_bindata(records::CreatePen, { width: { x: 7 }, color: { blue: 9 } }, bindata_writer)
    expect_same_as_bindata(records::CreatePen, { ih_pen: nil, width: { x: nil, y: 4 } }, bindata_writer)
    expect_same_as_bindata(records::CreatePen, { width: types::SizeL.new(cx: 5, cy: 6) }, bindata_writer)
  end

  it "falls back to BinData for an unknown key, without a partial build" do
    filler = described_class.for(codes::SELECTOBJECT)
    expect(filler.build(ih_object: 1, bogus: 2)).to be_nil
    expect(filler.build(bogus: 2)).to be_nil
  end

  it "keeps polygon points and text-out trailing working through build" do
    pts = [{ x: 1, y: 2 }, types::PointL.new(x: 3, y: 4)]
    bounds = types::RectL.new(left: 0, top: 0, right: 3, bottom: 4)
    expect_same_as_bindata(records::Polygon, { rcl_bounds: bounds, cptl: 2, aptl: pts }, bindata_writer)
    expect_same_as_bindata(records::ExtTextOutW, { i_graphics_mode: 1, ex_scale: 1.5, f_options: 0x100,
                                                   trailing: "ab".b }, bindata_writer)
  end
end
