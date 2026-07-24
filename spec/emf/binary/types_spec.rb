# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emf::Binary::Types do
  describe Emf::Binary::Types::PointL do
    it "round-trips a known point" do
      bytes = [10, 0, 0, 0, 20, 0, 0, 0].pack("C*")
      parsed = described_class.read(bytes)
      expect(parsed.x).to eq(10)
      expect(parsed.y).to eq(20)
      expect(parsed.to_binary_s).to eq(bytes)
    end

    it "handles negative coordinates" do
      buf = [-1, -2].pack("l<2")
      parsed = described_class.read(buf)
      expect(parsed.x).to eq(-1)
      expect(parsed.y).to eq(-2)
      expect(parsed.to_binary_s).to eq(buf)
    end
  end

  describe Emf::Binary::Types::PointS do
    it "round-trips" do
      bytes = [10, 0, 20, 0].pack("C*")
      parsed = described_class.read(bytes)
      expect(parsed.x).to eq(10)
      expect(parsed.y).to eq(20)
      expect(parsed.to_binary_s).to eq(bytes)
    end
  end

  describe Emf::Binary::Types::ColorRef do
    it "round-trips an RGB triple" do
      bytes = [0xFF, 0x80, 0x00, 0x00].pack("C*")
      parsed = described_class.read(bytes)
      expect(parsed.red).to eq(255)
      expect(parsed.green).to eq(128)
      expect(parsed.blue).to eq(0)
      expect(parsed.to_binary_s).to eq(bytes)
    end
  end

  describe Emf::Binary::Types::RectL do
    it "round-trips" do
      bytes = [1, 2, 3, 4].pack("l<4")
      parsed = described_class.read(bytes)
      expect(parsed.left).to eq(1)
      expect(parsed.top).to eq(2)
      expect(parsed.right).to eq(3)
      expect(parsed.bottom).to eq(4)
      expect(parsed.to_binary_s).to eq(bytes)
    end
  end

  describe Emf::Binary::Types::XForm do
    it "round-trips a matrix (single-precision floats)" do
      bytes = [1.0, 0.0, 0.0, 1.0, 5.0, 6.0].pack("e6")
      parsed = described_class.read(bytes)
      expect(parsed.m11).to be_within(0.0001).of(1.0)
      expect(parsed.m22).to be_within(0.0001).of(1.0)
      expect(parsed.dx).to be_within(0.0001).of(5.0)
      expect(parsed.dy).to be_within(0.0001).of(6.0)
      expect(parsed.to_binary_s).to eq(bytes)
    end
  end

  describe Emf::Binary::Types::LogPalette do
    it "parses with initial_length derived from header field" do
      entries = [0, 0xFF, 0x00, 0x00, 0, 0x00, 0xFF, 0x00].pack("C*")
      bytes = [0x0300, 2].pack("v2") + entries
      parsed = described_class.read(bytes)
      expect(parsed.pal_num_entries).to eq(2)
      expect(parsed.pal_pal_entry.first.pe_red).to eq(255)
      expect(parsed.pal_pal_entry[1].pe_green).to eq(255)
    end
  end
end
