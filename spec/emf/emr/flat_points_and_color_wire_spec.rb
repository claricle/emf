# frozen_string_literal: true

require "spec_helper"

RSpec.describe "record build fast paths" do
  codes = Emf::Emr::Binary::TypeCodes
  records = Emf::Emr::Binary::Records
  bindata_writer = BinData::Base.instance_method(:to_binary_s)

  describe "Color#to_wire" do
    let(:color) { Emf::Model::Geometry::Color.new(red: 1, green: 2, blue: 3, alpha: 9) }
    let(:reference) { Emf::Binary::Types::ColorRef.new(red: 1, green: 2, blue: 3, reserved: 9) }

    it "matches ColorRef.new in class, snapshot and bytes" do
      wire = color.to_wire
      expect(wire).to be_an_instance_of(Emf::Binary::Types::ColorRef)
      expect(wire.snapshot).to eq(reference.snapshot)
      expect(wire.to_binary_s).to eq(reference.to_binary_s)
    end

    it "returns an independent object each call" do
      first = color.to_wire
      first.red.assign(200)
      expect(color.to_wire.red.value).to eq(1)
    end
  end

  describe "PointArrayFill flat points" do
    let(:klass) { records.lookup(codes::POLYLINE) }
    let(:filler) { Emf::Emr::Binary::FastFill.for_points(codes::POLYLINE) }

    def lazy?(wire)
      !wire.aptl.instance_variable_get(:@flat_points).nil?
    end

    let(:fields) { { cptl: 3, aptl: [{ x: 3, y: -4 }, { x: -5, y: 6 }, { x: 2_147_483_647, y: 0 }] } }

    it "serializes without building BinData points and matches BinData" do
      wire = filler.build(fields)
      expect(lazy?(wire)).to be(true)
      expected = klass.new(fields)
      expect(wire.to_binary_s).to eq(bindata_writer.bind_call(expected))
      expect(lazy?(wire)).to be(true)
    end

    it "builds the same elements when first touched" do
      wire = filler.build(fields)
      expected = klass.new(fields)
      expect(wire.snapshot).to eq(expected.snapshot)
      expect(lazy?(wire)).to be(false)
      expect(wire.aptl.first.send(:parent)).to equal(wire.aptl)
      expect(wire.num_bytes).to eq(expected.num_bytes)
    end

    it "keeps clear?, assign and push equal to BinData" do
      wire = filler.build(fields)
      expect(wire.aptl.clear?).to be(false)
      wire.aptl.assign([{ x: 1, y: 2 }])
      expect(lazy?(wire)).to be(false)
      expect(wire.aptl.snapshot).to eq([{ x: 1, y: 2 }])
      other = filler.build(fields)
      other.aptl.push({ x: 7, y: 8 })
      expect(other.aptl.length).to eq(4)
    end

    it "does not share state between built records or with the template" do
      first = filler.build(fields)
      second = filler.build(fields)
      first.aptl.first.x.assign(99)
      expect(second.aptl.first.x.value).to eq(3)
      expect(filler.build(fields).aptl.first.x.value).to eq(3)
    end

    it "falls back to elements for non-integer coordinates" do
      wire = filler.build(cptl: 1, aptl: [{ x: 1.5, y: 2 }])
      expect(lazy?(wire)).to be(false)
    end

    it "packs out-of-range coordinates through BinData" do
      wire = filler.build(cptl: 1, aptl: [{ x: 2**40, y: 1 }])
      expect(filler.pack(wire)).to be_nil
    end
  end
end
