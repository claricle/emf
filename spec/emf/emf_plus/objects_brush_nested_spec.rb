# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/emf_plus_records"

RSpec.describe Emf::EmfPlus::Objects::Brush, "nested objects" do
  include Emf::SpecSupport::EmfPlusRecords

  let(:version) { [0xDBC01002].pack("V") }
  let(:argb) { [1, 2, 3, 4].pack("C4") }
  let(:path) { version + [2, 0].pack("VV") + [1.5, 2.5, 3.0, 4.0].pack("e4") + [0x00, 0x81].pack("C2") + "\0\0".b }
  let(:bitmap_header) { [2, 2, 8, 0x26200A, 0].pack("l<l<l<VV") }
  let(:image) { version + [1].pack("V") + bitmap_header + ("\x07" * 16).b }
  let(:metafile_image) { version + [2].pack("V") + [3, 4].pack("VV") + "WXYZ".b }
  let(:bad_image) { version + [1].pack("V") + "short".b }

  def decode(data)
    padded = data + ("\0" * (-data.bytesize % 4))
    frame = Emf::EmfPlus::Parser.call(record(0x4008, padded, flags: 1 << 8, data_size: data.bytesize)).first
    Emf::EmfPlus::Objects.decode(Emf::EmfPlus::ObjectChain::LogicalObject.new([Emf::EmfPlus::Records.decode(frame)]))
  end

  def brush_bytes(type, *parts) = version + [type].pack("V") + parts.join.b

  def path_gradient(boundary)
    brush_bytes(3, [1, 2].pack("Vl<") + argb + [1.5, 2.5].pack("e2"), [1].pack("V") + argb, [boundary.bytesize].pack("l<") + boundary)
  end

  def texture(image_bytes) = brush_bytes(2, [0, 3].pack("Vl<"), image_bytes)

  describe "a path gradient boundary path" do
    subject(:brush) { decode(path_gradient(path)) }

    it "decodes the points and types" do
      expect(brush.boundary_path.path).to have_attributes(points: [[1.5, 2.5], [3.0, 4.0]], point_count: 2)
      expect(brush.boundary_path.path.point_types.map(&:raw)).to eq([0x00, 0x81])
    end

    it "round-trips" do
      expect(brush.to_binary).to eq(path_gradient(path))
    end

    it "re-serializes an edited point with the right size" do
      brush.boundary_path.path.body.points.float_points[0].x = 9.0
      edited = decode(brush.to_binary)

      expect(edited.boundary_path.path.points.first).to eq([9.0, 2.5])
      expect(edited.boundary_path.boundary_path_size).to eq(path.bytesize)
    end
  end

  describe "a malformed boundary path" do
    subject(:brush) { decode(path_gradient("PATHBYTES".b + ("\0" * 3))) }

    it "keeps the raw bytes and round-trips" do
      expect(brush.boundary_path).to have_attributes(path: nil, boundary_path_data: "PATHBYTES\0\0\0".b)
      expect(brush.to_binary).to eq(path_gradient("PATHBYTES".b + ("\0" * 3)))
    end
  end

  describe "a texture brush image" do
    it "decodes a bitmap" do
      brush = decode(texture(image))

      expect(brush.image).to be_a(Emf::EmfPlus::Objects::Image)
      expect([brush.image.image_type, brush.image.bitmap.width, brush.image.bitmap.height]).to eq([1, 2, 2])
      expect(brush.to_binary).to eq(texture(image))
    end

    it "decodes a metafile" do
      brush = decode(texture(metafile_image))

      expect([brush.image.image_type, brush.image.metafile.metafile_data.to_s]).to eq([2, "WXYZ"])
      expect(brush.to_binary).to eq(texture(metafile_image))
    end

    it "re-serializes an edited bitmap field" do
      brush = decode(texture(image))
      brush.image.bitmap.width = 4

      expect(decode(brush.to_binary).image.bitmap.width).to eq(4)
    end

    it "keeps raw bytes when the image does not parse" do
      brush = decode(texture(bad_image))

      expect(brush.image).to eq(bad_image)
      expect(brush.to_binary).to eq(texture(bad_image))
    end
  end
end
