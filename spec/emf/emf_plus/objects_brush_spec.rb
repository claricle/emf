# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/emf_plus_records"

RSpec.describe Emf::EmfPlus::Objects::Brush do
  include Emf::SpecSupport::EmfPlusRecords

  let(:version) { [0xDBC01002].pack("V") }
  let(:matrix) { [1.0, 0.0, 0.0, 1.0, 5.0, 6.0].pack("e6") }
  let(:argb) { [1, 2, 3, 4].pack("C4") }

  def logical(data)
    padded = data + ("\0" * (-data.bytesize % 4))
    frame = Emf::EmfPlus::Parser.call(record(0x4008, padded, flags: 1 << 8, data_size: data.bytesize)).first
    Emf::EmfPlus::ObjectChain::LogicalObject.new([Emf::EmfPlus::Records.decode(frame)])
  end

  def brush(type, *parts) = version + [type].pack("V") + parts.join.b

  def decode(data) = Emf::EmfPlus::Objects.decode(logical(data))

  shared_examples "a lossless brush" do
    it { is_expected.to be_a(described_class) }

    it "re-encodes to the original ObjectData" do
      expect(subject.to_binary).to eq(data)
    end
  end

  subject(:body) { decode(data) }

  context "with a solid color" do
    let(:data) { brush(0, argb) }

    it "decodes the color" do
      expect(body).to have_attributes(version: 0xDBC01002, brush_type: 0)
      expect(body.data.solid_color).to have_attributes(blue: 1, green: 2, red: 3, alpha: 4)
    end

    it_behaves_like "a lossless brush"
  end

  context "with a hatch" do
    let(:data) { brush(1, [7].pack("V"), argb, "\x09\x08\x07\x06".b) }

    it "decodes style and colors" do
      expect([body.data.hatch_style, body.data.fore_color.red, body.data.back_color.alpha]).to eq([7, 3, 6])
    end

    it_behaves_like "a lossless brush"

    it "rejects truncated data" do
      expect { decode(data.byteslice(0, 16)) }.to raise_error(Emf::ParseError, /malformed Brush/)
    end
  end

  context "with a texture" do
    let(:head) { ->(flags) { [flags, 3].pack("Vl<") } }

    context "without optional data" do
      let(:data) { brush(2, head.call(0)) }

      it "has neither transform nor image" do
        expect([body.data.wrap_mode, body.transform, body.image]).to eq([3, nil, nil])
      end

      it_behaves_like "a lossless brush"
    end

    context "with transform and image bytes" do
      let(:data) { brush(2, head.call(2), matrix, "IMAGEDATA".b) }

      it "decodes the transform and keeps the image bytes" do
        expect([body.transform.dx, body.image]).to eq([5.0, "IMAGEDATA".b])
      end

      it_behaves_like "a lossless brush"
    end

    context "with an image and no transform" do
      let(:data) { brush(2, head.call(0x100), "IMG!".b) }

      it_behaves_like "a lossless brush"
    end

    it "rejects a transform flag without room for the matrix" do
      expect { decode(brush(2, head.call(2), "\0" * 8)) }.to raise_error(Emf::ParseError, /transform needs 24/)
    end
  end

  context "with a linear gradient" do
    let(:rect) { [0.0, 1.0, 10.0, 20.0].pack("e4") }
    let(:head) { ->(flags) { [flags, 1].pack("Vl<") + rect + argb + "\x0A\x0B\x0C\x0D".b + [0, 0].pack("V2") } }
    let(:colors) { [2].pack("V") + [0.0, 1.0].pack("e2") + argb + argb }
    let(:factors) { [2].pack("V") + [0.0, 1.0].pack("e2") + [0.25, 0.75].pack("e2") }

    context "without optional data" do
      let(:data) { brush(4, head.call(0)) }

      it "decodes the fixed fields" do
        expect(body.data).to have_attributes(wrap_mode: 1, reserved1: 0)
        expect([body.data.rect_f.width, body.data.start_color.blue, body.data.end_color.blue]).to eq([10.0, 1, 10])
      end

      it_behaves_like "a lossless brush"
    end

    context "with transform and preset colors" do
      let(:data) { brush(4, head.call(0x6), matrix, colors) }

      it "decodes both" do
        expect([body.transform.dy, body.blend_colors.position_count, body.blend_colors.blend_colors[1].alpha]).to eq([6.0, 2, 4])
      end

      it_behaves_like "a lossless brush"
    end

    context "with horizontal blend factors" do
      let(:data) { brush(4, head.call(0x8), factors) }

      it "decodes the factors" do
        expect([body.blend_factors_h.blend_factors.to_a, body.blend_factors_v]).to eq([[0.25, 0.75], nil])
      end

      it_behaves_like "a lossless brush"
    end

    context "with vertical blend factors" do
      let(:data) { brush(4, head.call(0x10), factors) }

      it "decodes the vertical pattern" do
        expect([body.blend_factors_v.position_count, body.blend_factors_h]).to eq([2, nil])
      end

      it_behaves_like "a lossless brush"
    end

    context "with both factor patterns" do
      let(:other) { [3].pack("V") + [0.0, 0.5, 1.0].pack("e3") + [0.0, 0.5, 1.0].pack("e3") }
      let(:data) { brush(4, head.call(0x18), factors, other) }

      it "reads the vertical pattern first, as the spec table lists it" do
        expect([body.blend_factors_v.position_count, body.blend_factors_h.position_count]).to eq([2, 3])
      end

      it_behaves_like "a lossless brush"
    end

    it "rejects a blend count larger than the data without allocating it" do
      huge = [0x7FFFFFFF].pack("V") + [0.0, 1.0].pack("e2")

      expect { decode(brush(4, head.call(0x4), huge)) }.to raise_error(Emf::ParseError, /blend_colors of 2147483647 entries/)
    end
  end

  context "with a path gradient" do
    let(:head) { ->(flags) { [flags, 2].pack("Vl<") + argb + [1.5, 2.5].pack("e2") } }
    let(:surround) { [2].pack("V") + argb + argb }
    let(:points) { [2].pack("l<") + [1.0, 2.0, 3.0, 4.0].pack("e4") }
    let(:path) { "PATHBYTES".b + "\0\0\0".b }
    let(:boundary_path) { [path.bytesize].pack("l<") + path }
    let(:colors) { [2].pack("V") + [0.0, 1.0].pack("e2") + argb + argb }
    let(:factors) { [2].pack("V") + [0.0, 1.0].pack("e2") + [0.25, 0.75].pack("e2") }
    let(:focus) { [2].pack("V") + [0.2, 0.3].pack("e2") }

    context "with a point boundary and no optional data" do
      let(:data) { brush(3, head.call(0), surround, points) }

      it "decodes center, surrounding colors and points" do
        expect(body.data.center_point_f).to have_attributes(x: 1.5, y: 2.5)
        expect([body.surrounding_colors.surrounding_color.size, body.boundary_points.boundary_point_count]).to eq([2, 2])
        expect(body.boundary_points.boundary_point_data[1].y).to eq(4.0)
      end

      it_behaves_like "a lossless brush"
    end

    context "with a path boundary" do
      let(:data) { brush(3, head.call(1), surround, boundary_path) }

      it "keeps the nested path bytes" do
        expect([body.boundary_path.boundary_path_data, body.boundary_points]).to eq([path, nil])
      end

      it_behaves_like "a lossless brush"
    end

    context "with every optional field" do
      let(:data) { brush(3, head.call(0x47), surround, boundary_path, matrix, colors, focus) }

      it "decodes transform, colors and focus scales" do
        expect(body.data.brush_data_flags).to eq(0x47)
        expect([body.transform.dx, body.blend_colors.position_count, body.focus_scales.focus_scale_y.round(2)]).to eq([5.0, 2, 0.3])
      end

      it_behaves_like "a lossless brush"
    end

    context "with blend factors" do
      let(:data) { brush(3, head.call(0x8), surround, points, factors) }

      it "decodes the horizontal factors" do
        expect(body.blend_factors_h.blend_factors.to_a).to eq([0.25, 0.75])
      end

      it_behaves_like "a lossless brush"
    end

    it "rejects a surrounding color count larger than the data" do
      huge = [0x7FFFFFFF].pack("V") + argb

      expect { decode(brush(3, head.call(0), huge)) }.to raise_error(Emf::ParseError, /surrounding_colors of 2147483647/)
    end

    it "rejects a negative boundary point count" do
      expect { decode(brush(3, head.call(0), surround, [-1].pack("l<"))) }.to raise_error(Emf::ParseError, /negative/)
    end

    it "rejects a boundary point count larger than the data" do
      expect { decode(brush(3, head.call(0), surround, [0x1000000].pack("l<") + ("\0" * 8))) }
        .to raise_error(Emf::ParseError, /boundary_points of 16777216/)
    end

    it "rejects a boundary path size larger than the data" do
      expect { decode(brush(3, head.call(1), surround, [0x7FFFFFF0].pack("l<") + ("\0" * 8))) }
        .to raise_error(Emf::ParseError, /boundary_path of 2147483632/)
    end

    it "rejects a negative boundary path size" do
      expect { decode(brush(3, head.call(1), surround, [-4].pack("l<"))) }.to raise_error(Emf::ParseError, /negative/)
    end

    it "rejects a focus scale flag without room" do
      expect { decode(brush(3, head.call(0x40), surround, points, "\0" * 4)) }.to raise_error(Emf::ParseError, /focus_scales needs 12/)
    end
  end

  context "with an unknown brush type" do
    let(:data) { brush(9, "ABCD".b) }

    it "keeps the data raw" do
      expect(body.unknown_data).to eq("ABCD".b)
    end

    it_behaves_like "a lossless brush"
  end

  context "with alignment padding after solid data" do
    let(:data) { brush(0, argb, "\0\0".b) }

    it_behaves_like "a lossless brush"
  end

  describe "against the corpus" do
    # The byte check skips parsing the fixtures with no EMF+ comment; parsing them all costs minutes.
    fixtures = Dir[File.expand_path("../../fixtures/{emf,emf-ea,simple}/*.emf", __dir__)].select do |path|
      File.binread(path).include?("EMF+") && Emf.parse(File.binread(path)).emf_plus
    rescue Emf::Error
      false
    end
    objects = fixtures.flat_map do |path|
      records = Emf::EmfPlus::Records.decode_all(Emf::EmfPlus::Parser.call(Emf.parse(File.binread(path)).emf_plus))
      Emf::EmfPlus::ObjectChain.call(records).grep(Emf::EmfPlus::ObjectChain::LogicalObject)
                               .select { |l| l.object_type == 1 }
    end

    it "decodes every Brush object typed and byte-identical" do
      per_type = objects.map { |l| l.body.brush_type }.tally
      warn "corpus Brush: #{objects.size} objects by brush type #{per_type}"

      expect(objects.map(&:body)).to all(be_a(described_class))
      expect(objects.map { |l| l.body.to_binary }).to eq(objects.map(&:data))
    end
  end
end
