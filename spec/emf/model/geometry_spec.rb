# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emf::Model::Geometry do
  describe Emf::Model::Geometry::Point do
    it "translates via wire" do
      point = described_class.new(x: 10, y: 20)
      wire = point.to_wire
      expect(wire.x).to eq(10)
      expect(described_class.from_wire(wire)).to eq(point)
    end

    it "has value equality" do
      a = described_class.new(x: 1, y: 2)
      b = described_class.new(x: 1, y: 2)
      expect(a).to eq(b)
      expect(a.hash).to eq(b.hash)
    end

    it "translates" do
      point = described_class.new(x: 10, y: 20)
      moved = point.translate(5, -3)
      expect(moved.x).to eq(15)
      expect(moved.y).to eq(17)
    end
  end

  describe Emf::Model::Geometry::Rect do
    it "computes width and height" do
      rect = described_class.new(left: 10, top: 20, right: 110, bottom: 70)
      expect(rect.width).to eq(100)
      expect(rect.height).to eq(50)
    end

    it "knows when it is empty" do
      empty = described_class.new(left: 0, top: 0, right: 0, bottom: 0)
      nonempty = described_class.new(left: 0, top: 0, right: 1, bottom: 1)
      expect(empty).to be_empty
      expect(nonempty).not_to be_empty
    end

    it "contains points" do
      rect = described_class.new(left: 0, top: 0, right: 100, bottom: 100)
      inside = Emf::Model::Geometry::Point.new(x: 50, y: 50)
      outside = Emf::Model::Geometry::Point.new(x: 150, y: 50)
      expect(rect.contains?(inside)).to be true
      expect(rect.contains?(outside)).to be false
    end
  end

  describe Emf::Model::Geometry::Color do
    it "renders hex without alpha when alpha is 255" do
      color = described_class.new(red: 0xFF, green: 0x80, blue: 0x00)
      expect(color.to_hex).to eq("#FF8000")
    end

    it "renders hex with alpha when alpha is below 255" do
      color = described_class.new(red: 0xFF, green: 0x80, blue: 0x00, alpha: 0x80)
      expect(color.to_hex).to eq("#FF800080")
    end

    it "round-trips via wire" do
      color = described_class.new(red: 1, green: 2, blue: 3)
      wire = color.to_wire
      round_tripped = described_class.from_wire(wire)
      expect(round_tripped.red).to eq(1)
      expect(round_tripped.green).to eq(2)
      expect(round_tripped.blue).to eq(3)
    end

    it "exposes preset colors" do
      expect(described_class.black.to_hex).to eq("#000000")
      expect(described_class.white.to_hex).to eq("#FFFFFF")
      expect(described_class.transparent.alpha).to eq(0)
    end
  end

  describe Emf::Model::Geometry::Matrix do
    it "round-trips via wire" do
      m = described_class.new(m11: 1.0, m12: 2.0, m21: 3.0, m22: 4.0, dx: 5.0, dy: 6.0)
      wire = m.to_wire
      expect(described_class.from_wire(wire)).to eq(m)
    end

    it "recognises identity" do
      expect(described_class.identity).to be_identity
      non_identity = described_class.new(m11: 2.0, m12: 0, m21: 0, m22: 1, dx: 0, dy: 0)
      expect(non_identity).not_to be_identity
    end
  end

  describe Emf::Model::Geometry::Size do
    it "round-trips via wire" do
      size = described_class.new(cx: 1920, cy: 1080)
      expect(described_class.from_wire(size.to_wire)).to eq(size)
    end
  end

  describe Emf::Model::Geometry::PointS do
    it "round-trips via wire" do
      pt = described_class.new(x: -5, y: 100)
      expect(described_class.from_wire(pt.to_wire)).to eq(pt)
    end
  end

  describe Emf::Model::Geometry::PointF do
    it "round-trips via wire" do
      pt = described_class.new(x: 1.5, y: -2.25)
      expect(described_class.from_wire(pt.to_wire)).to eq(pt)
    end
  end

  describe Emf::Model::Geometry::RectS do
    it "round-trips via wire" do
      rect = described_class.new(left: 1, top: 2, right: 3, bottom: 4)
      expect(described_class.from_wire(rect.to_wire)).to eq(rect)
    end
  end
end
