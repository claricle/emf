# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/emf_plus_records"
require_relative "../../support/emf_plus_draw_fill"

RSpec.describe "EMF+ drawing and fill records" do
  include Emf::SpecSupport::EmfPlusRecords
  include Emf::SpecSupport::EmfPlusDrawFill

  let(:records) { Emf::EmfPlus::Records }

  def decode(bytes)
    records.decode(Emf::EmfPlus::Parser.call(bytes).first)
  end

  def sample_bytes(sample)
    record(sample[:type], sample[:body], flags: sample[:flags])
  end

  describe "every synthetic sample" do
    draw_fill_samples = Class.new { include Emf::SpecSupport::EmfPlusDrawFill }.new.draw_fill_samples

    draw_fill_samples.each do |sample|
      context "#{sample[:klass]} flags=0x#{sample[:flags].to_s(16)}" do
        let(:bytes) { sample_bytes(sample) }

        it "decodes to its class and re-encodes identically" do
          expect(decode(bytes)).to be_a(records.const_get(sample[:klass]))
          expect(decode(bytes).to_binary).to eq(bytes)
        end

        it "keeps alignment padding so a padded record round-trips" do
          padded = record(sample[:type], sample[:body] + "\0\0\0\0".b, flags: sample[:flags], data_size: sample[:body].bytesize)

          expect(decode(padded).to_binary).to eq(padded)
        end

        it "raises ParseError with offset and record code when the body is a word short" do
          short = record(sample[:type], sample[:body].byteslice(0, sample[:body].bytesize - 4), flags: sample[:flags])

          expect { decode(short) }.to raise_error(Emf::ParseError, /malformed #{sample[:klass]} body/) do |e|
            expect([e.offset, e.record_code]).to eq([0, sample[:type]])
          end
        end
      end
    end
  end

  describe "StrokeFillPath" do
    it "stays Unknown because chapter 2 gives it no layout" do
      expect(decode(record(0x4037, "abcd"))).to be_a(records::Unknown)
    end
  end

  describe Emf::EmfPlus::Records::Clear do
    it "decodes the ARGB colour" do
      clear = decode(record(0x4009, "\x11\x22\x33\x80".b))

      expect(clear.color).to have_attributes(blue: 0x11, green: 0x22, red: 0x33, alpha: 0x80)
    end
  end

  describe "pen-based rectangle records" do
    it "reads compressed DrawRects with the pen index" do
      rects = decode(record(0x400B, u32(2) + s16(1, 2, 3, 4, 5, 6, 7, 8), flags: 0x4003))

      expect(rects).to be_compressed.and have_attributes(pen_id: 3, count: 2)
      expect(rects.rects.map { |r| [r.x, r.y, r.width, r.height] }).to eq([[1, 2, 3, 4], [5, 6, 7, 8]])
    end

    it "reads float DrawRects when C is clear" do
      rects = decode(record(0x400B, u32(1) + f32(1.5, 2.5, 3.5, 4.5), flags: 3))

      expect(rects).not_to be_compressed
      expect(rects.rects.map { |r| [r.x, r.y, r.width, r.height] }).to eq([[1.5, 2.5, 3.5, 4.5]])
    end

    it "reads DrawEllipse" do
      ellipse = decode(record(0x400F, s16(10, 20, 30, 40), flags: 0x4005))

      expect(ellipse).to have_attributes(pen_id: 5)
      expect(ellipse.rect).to have_attributes(x: 10, y: 20, width: 30, height: 40)
    end

    { DrawPie: 0x4011, DrawArc: 0x4012 }.each do |name, type|
      it "reads #{name} angles and rectangle" do
        shape = decode(record(type, f32(45, -90) + f32(1, 2, 3, 4), flags: 6))

        expect(shape).to have_attributes(pen_id: 6, start_angle: 45.0, sweep_angle: -90.0)
        expect(shape.rect).to have_attributes(x: 1.0, height: 4.0)
      end
    end
  end

  describe "point-array records" do
    def pairs(points) = points.map { |p| [p.x.to_f, p.y.to_f] }

    it "reads compressed DrawLines and the L flag" do
      lines = decode(record(0x400D, u32(2) + s16(1, 2, -3, -4), flags: 0x6004))

      expect(lines).to be_compressed.and be_close_shape
      expect(pairs(lines.points)).to eq([[1.0, 2.0], [-3.0, -4.0]])
    end

    it "reads float DrawLines without the L flag" do
      lines = decode(record(0x400D, u32(2) + f32(1, 2, 3, 4), flags: 4))

      expect(lines).not_to be_close_shape
      expect(pairs(lines.points)).to eq([[1.0, 2.0], [3.0, 4.0]])
    end

    it "reads relative points of 7 and 15 bits, ignoring C when P is set" do
      lines = decode(record(0x400D, u32(3) + relative_points, flags: 0x4804))

      expect(lines).to be_relative
      expect(lines.points.map { |p| [p.x.to_i, p.y.to_i] }).to eq([[5, -2], [-3, 63], [256, 1]])
    end

    it "reads DrawBeziers" do
      beziers = decode(record(0x4019, u32(4) + f32(1, 2, 3, 4, 5, 6, 7, 8), flags: 10))

      expect(beziers).to have_attributes(pen_id: 10, count: 4)
      expect(pairs(beziers.points).last).to eq([7.0, 8.0])
    end

    it "reads DrawClosedCurve tension and points" do
      curve = decode(record(0x4017, f32(0.5) + u32(3) + f32(1, 2, 3, 4, 5, 6), flags: 8))

      expect(curve).to have_attributes(pen_id: 8, tension: 0.5, count: 3)
    end

    it "reads DrawCurve offset, segments and compressed points" do
      curve = decode(record(0x4018, f32(0.25) + u32(1, 2, 3) + s16(1, 2, 3, 4, 5, 6), flags: 0x4009))

      expect(curve).to have_attributes(tension: 0.25, start_point_index: 1, num_segments: 2, count: 3)
      expect(pairs(curve.points)).to eq([[1.0, 2.0], [3.0, 4.0], [5.0, 6.0]])
    end
  end

  describe Emf::EmfPlus::Records::DrawPath do
    it "reads the path index from Flags and the pen from the body" do
      draw = decode(record(0x4015, u32(9), flags: 7))

      expect(draw).to have_attributes(path_id: 7, pen_id: 9)
    end
  end

  describe "fill records" do
    let(:argb) { u32(0xFF332211) }

    it "reads a solid colour brush when S is set" do
      fill = decode(record(0x400A, argb + u32(1) + s16(1, 2, 3, 4), flags: 0xC000))

      expect(fill).to be_solid_color.and be_compressed
      expect(fill.brush_color).to have_attributes(alpha: 0xFF, red: 0x33, green: 0x22, blue: 0x11)
      expect(fill.rects.first).to have_attributes(x: 1, width: 3)
    end

    it "reads a brush index when S is clear" do
      fill = decode(record(0x400A, u32(5, 1) + f32(1, 2, 3, 4), flags: 0))

      expect(fill).not_to be_solid_color
      expect(fill).to have_attributes(brush_id: 5, count: 1)
    end

    it "reads FillPolygon relative points" do
      fill = decode(record(0x400C, argb + u32(3) + relative_points, flags: 0x8800))

      expect(fill).to be_solid_color.and be_relative
      expect(fill.points.map { |p| p.x.to_i }).to eq([5, -3, 256])
    end

    it "reads FillEllipse and FillPie rectangles" do
      ellipse = decode(record(0x400E, argb + f32(1, 2, 3, 4), flags: 0x8000))
      pie = decode(record(0x4010, u32(5) + f32(10, 20) + s16(1, 2, 3, 4), flags: 0x4000))

      expect(ellipse.rect).to have_attributes(x: 1.0, y: 2.0, width: 3.0, height: 4.0)
      expect(pie).to have_attributes(start_angle: 10.0, sweep_angle: 20.0, brush_id: 5)
      expect(pie.rect).to have_attributes(width: 3)
    end

    it "reads FillRegion and FillPath object indexes" do
      region = decode(record(0x4013, argb, flags: 0x800B))
      path = decode(record(0x4014, u32(5), flags: 0x000C))

      expect(region).to have_attributes(region_id: 11).and be_solid_color
      expect(path).to have_attributes(path_id: 12, brush_id: 5)
    end

    it "reads FillClosedCurve winding flag, tension and points" do
      curve = decode(record(0x4016, argb + f32(0.5) + u32(3) + s16(1, 2, 3, 4, 5, 6), flags: 0xE000))

      expect(curve).to be_winding.and be_solid_color
      expect(curve).to have_attributes(tension: 0.5, count: 3)
      expect(curve.points.map(&:y)).to eq([2, 4, 6])
    end

    it "reports an alternate fill when W is clear" do
      expect(decode(record(0x4016, u32(1) + f32(0) + u32(3) + s16(1, 2, 3, 4, 5, 6), flags: 0x4000))).not_to be_winding
    end
  end

  describe "against the corpus" do
    drawing_and_fill = 0x4009..0x4019
    # Parsing every fixture takes minutes (some corrupt ones are slow); only files
    # carrying the "EMF+" comment signature can hold EMF+ records.
    fixtures = Dir[File.expand_path("../../fixtures/{emf,emf-ea,simple}/*.emf", __dir__)].select do |path|
      File.binread(path).include?("EMF+")
    end

    it "finds EMF+ fixtures to check" do
      expect(fixtures).not_to be_empty
    end

    fixtures.each do |path|
      context File.basename(path) do
        let(:frames) do
          Emf::EmfPlus::Parser.call(Emf.parse(File.binread(path)).emf_plus).select { |f| drawing_and_fill.cover?(f.type) }
        end

        it "decodes every drawing and fill record typed and re-encodes it identically" do
          typed = frames.map { |frame| records.decode(frame) }

          expect(typed.grep(records::Unknown)).to be_empty
          expect(typed.map(&:to_binary)).to eq(frames.map { |frame| Emf::EmfPlus::Serializer.call([frame]) })
        end
      end
    end
  end
end
