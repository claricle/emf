# frozen_string_literal: true

require "spec_helper"
require "timeout"
require_relative "../../support/emf_plus_records"

RSpec.describe "EMF+ Path and Region objects" do
  include Emf::SpecSupport::EmfPlusRecords

  let(:version) { [0xDBC01002].pack("V") }
  let(:path_class) { Emf::EmfPlus::Objects::Path }
  let(:region_class) { Emf::EmfPlus::Objects::Region }

  def decode(type, data)
    padded = data + ("\0" * (-data.bytesize % 4))
    frame = Emf::EmfPlus::Parser.call(record(0x4008, padded, flags: type << 8, data_size: data.bytesize)).first
    Emf::EmfPlus::Objects.decode(Emf::EmfPlus::ObjectChain::LogicalObject.new([Emf::EmfPlus::Records.decode(frame)]))
  end

  def path_data(count, flags, points, types) = version + [count, flags].pack("VV") + points + types

  shared_examples "a lossless object" do
    it "re-encodes to the original ObjectData" do
      expect(subject.to_binary).to eq(data)
    end
  end

  describe Emf::EmfPlus::Objects::Path do
    subject(:body) { decode(3, data) }

    context "with float points" do
      let(:data) { path_data(2, 0, [1.5, 2.5, 3.0, 4.0].pack("e4"), [0x00, 0x81].pack("C2")) + "\0\0".b }

      it "decodes points, types and keeps the padding" do
        expect([body, body.points, body.point_types.map(&:raw), body.trailing])
          .to match([be_a(path_class), [[1.5, 2.5], [3.0, 4.0]], [0x00, 0x81], "\0\0".b])
      end

      it { expect(body.version).to eq(0xDBC01002) }
      it_behaves_like "a lossless object"
    end

    context "with compressed points (C flag)" do
      let(:data) { path_data(2, 0x4000, [10, -20, 30, 40].pack("s<4"), [0x00, 0x01].pack("C2")) + "\0\0".b }

      it "reads int16 points" do
        expect([body.compressed?, body.relative?, body.points]).to eq([true, false, [[10, -20], [30, 40]]])
      end

      it_behaves_like "a lossless object"
    end

    context "with relative points and RLE types (R flag)" do
      let(:points) { [0x05, 0x7E].pack("C2") + [0x81, 0x2C, 0x03].pack("C3") }
      let(:data) { path_data(2, 0x0800 | 0x4000, points, [0x42, 0x03, 0x01, 0x00].pack("C4")) }

      it "reads 7 and 15 bit coordinates and ignores C" do
        expect([body.relative?, body.compressed?, body.points.map { |pt| pt.map(&:to_i) }]).to eq([true, false, [[5, -2], [300, 3]]])
      end

      it "reads the runs until the points are covered" do
        expect(body.point_types.map { |t| [t.bezier?, t.run_count, t.point_type.raw] }).to eq([[false, 2, 3]])
      end

      it_behaves_like "a lossless object"
    end

    context "with a bezier run followed by a line run" do
      let(:data) do
        path_data(3, 0x0800, [1, 1, 2, 2, 3, 3].pack("C6"), [0x81, 0x03, 0x02, 0x01].pack("C4"))
      end

      it "decodes both runs" do
        expect(body.point_types.map { |t| [t.bezier?, t.run_count] }).to eq([[true, 1], [false, 2]])
      end

      it_behaves_like "a lossless object"
    end

    it "accepts an empty path" do
      empty = path_data(0, 0, "".b, "".b)

      expect(decode(3, empty).to_binary).to eq(empty)
    end

    it "raises ParseError for a count larger than the data, without allocating it" do
      huge = path_data(0x7FFFFFFF, 0, "".b, "".b)

      expect { decode(3, huge) }.to raise_error(Emf::ParseError, /2147483647 path points/)
    end

    it "raises ParseError for a relative count larger than the data" do
      huge = path_data(0x7FFFFFFF, 0x0800, "".b, "".b)

      expect { decode(3, huge) }.to raise_error(Emf::ParseError, /malformed Path/)
    end

    it "raises ParseError when RLE runs do not cover the points" do
      short = path_data(5, 0x0800, "\x01\x01".b * 5, [0x41, 0x03].pack("C2"))

      expect { decode(3, short) }.to raise_error(Emf::ParseError, /malformed Path/)
    end

    it "stops on endless zero-length runs at the end of the data" do
      zeros = path_data(1, 0x0800, "\x01\x01".b, "\x40\x01".b * 1000)

      expect { Timeout.timeout(5) { decode(3, zeros) } }.to raise_error(Emf::ParseError, /malformed Path/)
    end

    it "raises ParseError on a truncated header" do
      expect { decode(3, version + [1].pack("V")) }.to raise_error(Emf::ParseError, /malformed Path/)
    end
  end

  describe Emf::EmfPlus::Objects::Region do
    subject(:body) { decode(4, data) }

    let(:rect) { [0x10000000, 1.0, 2.0, 3.0, 4.0].pack("Ve4") }
    let(:path_bytes) { path_data(2, 0x4000, [1, 2, 3, 4].pack("s<4"), [0, 1].pack("C2")) + "\0\0".b }
    let(:path_node) { [0x10000001, path_bytes.bytesize].pack("Vl<") + path_bytes }

    def region(count, nodes) = version + [count].pack("V") + nodes
    def combine(type, left, right) = [type].pack("V") + left + right

    context "with a rectangle node" do
      let(:data) { region(0, rect) }

      it "decodes the rectangle" do
        expect([body.node_count, body.root.type, body.root.data.width]).to eq([0, 0x10000000, 3.0])
      end

      it_behaves_like "a lossless object"
    end

    context "with Empty and Infinite nodes" do
      it "round-trips both" do
        [0x10000002, 0x10000003].each do |type|
          data = region(0, [type].pack("V"))

          expect(decode(4, data)).to have_attributes(to_binary: data, root: have_attributes(type: type, data: nil))
        end
      end
    end

    context "with a path node" do
      let(:data) { region(0, path_node) }

      it "decodes the path and keeps its padding inside the length" do
        expect([body.root.data.path.point_count, body.root.data.padding]).to eq([2, "\0\0".b])
      end

      it_behaves_like "a lossless object"
    end

    context "with combining nodes" do
      let(:data) { region(4, combine(2, combine(1, rect, path_node), [0x10000003].pack("V"))) }

      it "decodes the tree" do
        expect([body.root.node_count, body.root.data.left.type, body.root.data.left.data.right.type]).to eq([5, 1, 0x10000001])
      end

      it_behaves_like "a lossless object"
    end

    (1..5).each do |type|
      it "reads combine type #{type} as a node with two children" do
        data = region(2, combine(type, rect, rect))

        expect(decode(4, data)).to have_attributes(to_binary: data, root: be_combining)
      end
    end

    it "keeps bytes after the root node in trailing" do
      data = region(0, rect) + "\1\2\3\4".b

      expect(decode(4, data)).to have_attributes(to_binary: data, trailing: "\1\2\3\4".b)
    end

    it "accepts the deepest allowed nesting" do
      nested = rect
      Emf::EmfPlus::Records::Primitives::RegionNode::MAX_DEPTH.times { nested = combine(2, nested, [0x10000002].pack("V")) }
      data = region(0, nested)

      expect(decode(4, data).to_binary).to eq(data)
    end

    it "raises ParseError past the depth limit, quickly" do
      nested = rect
      (Emf::EmfPlus::Records::Primitives::RegionNode::MAX_DEPTH + 1).times { nested = combine(2, nested, [0x10000002].pack("V")) }

      expect { Timeout.timeout(5) { decode(4, region(0, nested)) } }.to raise_error(Emf::ParseError, /nested deeper than/)
    end

    it "raises ParseError for an unknown node type" do
      expect { decode(4, region(0, [0x77].pack("V"))) }.to raise_error(Emf::ParseError, /unknown RegionNodeDataType 0x77/)
    end

    it "raises ParseError for a path length larger than the data, without allocating it" do
      expect { decode(4, region(0, [0x10000001, 0x7FFFFFFF].pack("Vl<"))) }
        .to raise_error(Emf::ParseError, /RegionNodePath of 2147483647 bytes/)
    end

    it "raises ParseError for a negative path length" do
      expect { decode(4, region(0, [0x10000001, -4].pack("Vl<"))) }.to raise_error(Emf::ParseError, /negative RegionNodePathLength/)
    end

    it "raises ParseError for a path that overruns its length" do
      expect { decode(4, region(0, [0x10000001, 8].pack("Vl<") + path_bytes)) }.to raise_error(Emf::ParseError, /malformed Region/)
    end

    it "raises ParseError on a truncated child" do
      expect { decode(4, region(2, [2].pack("V") + rect)) }.to raise_error(Emf::ParseError, /malformed Region/)
    end

    it "raises ParseError without a RegionNodeCount" do
      expect { decode(4, version) }.to raise_error(Emf::ParseError, /malformed Region/)
    end
  end

  describe "against the corpus" do
    typed = { 3 => Emf::EmfPlus::Objects::Path, 4 => Emf::EmfPlus::Objects::Region }
    # The byte check skips parsing the fixtures with no EMF+ comment; parsing them all costs minutes.
    fixtures = Dir[File.expand_path("../../fixtures/{emf,emf-ea,simple}/*.emf", __dir__)].select do |path|
      File.binread(path).include?("EMF+") && Emf.parse(File.binread(path)).emf_plus
    rescue Emf::Error
      false
    end
    objects = fixtures.flat_map do |path|
      records = Emf::EmfPlus::Records.decode_all(Emf::EmfPlus::Parser.call(Emf.parse(File.binread(path)).emf_plus))
      Emf::EmfPlus::ObjectChain.call(records).grep(Emf::EmfPlus::ObjectChain::LogicalObject).select { |l| typed.key?(l.object_type) }
    end

    typed.each do |object_type, klass|
      it "decodes every #{klass.name.split('::').last} object typed and byte-identical" do
        own = objects.select { |l| l.object_type == object_type }
        warn "corpus #{klass.name.split('::').last}: #{own.size} objects"

        expect(own).not_to be_empty
        expect(own.map(&:body)).to all(be_a(klass))
        expect(own.map { |l| l.body.to_binary }).to eq(own.map(&:data))
      end
    end

    it "exercises float and compressed paths" do
      paths = objects.select { |l| l.object_type == 3 }.map(&:body)
      kinds = paths.map { |p| [p.relative?, p.compressed?] }.tally
      warn "corpus Path branches [relative, compressed]: #{kinds}"

      expect(kinds.keys).to include([false, false], [false, true])
    end
  end
end
