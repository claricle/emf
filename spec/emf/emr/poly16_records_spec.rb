# frozen_string_literal: true

require "spec_helper"

RSpec.describe "16-bit point array records" do
  records = Emf::Emr::Binary::Records
  codes = Emf::Emr::Binary::TypeCodes
  fill = Emf::Emr::Binary::FastFill
  bindata_writer = BinData::Base.instance_method(:to_binary_s)
  rect_l = Emf::Binary::Types::RectL
  point_s = Emf::Binary::Types::PointS
  counts = [0, 1, 3]

  types = {
    "Polygon16" => codes::POLYGON16, "Polyline16" => codes::POLYLINE16,
    "PolyBezier16" => codes::POLYBEZIER16, "PolyBezierTo16" => codes::POLYBEZIERTO16,
    "PolylineTo16" => codes::POLYLINETO16
  }

  def record_bytes(type, points, bounds: [-5, 6, 7, -8], extra: "".b, count: points.size)
    body = [type, 0, *bounds, count].pack("VVl<4V") + points.flatten.pack("s<*") + extra
    body[4, 4] = [body.bytesize].pack("V")
    body
  end

  types.each do |name, type|
    describe name do
      let(:klass) { records.lookup(type) }
      let(:filler) { fill.for_points(type) }
      let(:points) { [[1, -2], [32_767, -32_768], [0, 9]] }

      it "is filled by the point array filler" do
        expect(filler).to be_a(fill::PointArrayFill)
        expect(fill.for_class(klass)).to equal(filler)
      end

      counts.each do |count|
        it "parses #{count} points like BinData, with the same bytes and suffix" do
          bytes = record_bytes(type, points.first(count), extra: "tail".b)
          wire, suffix = filler.call(bytes)
          reference = klass.read(bytes)

          expect(wire.snapshot).to eq(reference.snapshot)
          expect(wire.num_bytes).to eq(reference.num_bytes)
          expect(suffix).to eq("tail".b)
          expect(wire.to_binary_s).to eq(bindata_writer.bind_call(reference))
          expect(wire.apts.size).to eq(count)
        end
      end

      it "leaves a count that overruns the record to BinData" do
        bytes = record_bytes(type, points.first(1), count: 4)
        expect(filler.call(bytes)).to be_nil
        expect { klass.read(bytes) }.to raise_error(EOFError)
      end

      it "gives editable points that do not share state" do
        wire, = filler.call(record_bytes(type, points))
        other, = filler.call(record_bytes(type, points))
        reference = klass.read(record_bytes(type, points))
        [wire, reference].each do |w|
          w.apts[0].x = 40
          w.apts << { x: 3, y: 4 }
          w.cpts = 4
        end

        expect(wire.snapshot).to eq(reference.snapshot)
        expect(wire.to_binary_s).to eq(bindata_writer.bind_call(reference))
        expect(other.apts[0].x.value).to eq(1)
        expect(klass.new.apts.size).to eq(0)
      end

      it "builds from consumer-shaped attributes like BinData" do
        wire_points = points.map { |x, y| point_s.new(x: x, y: y) }
        attrs = { i_type: type, rcl_bounds: rect_l.new(left: 1, top: 2, right: 3, bottom: 4),
                  cpts: 3, apts: wire_points }
        built = klass.new(**attrs)
        reference = klass.new(attrs.dup)

        expect(built.snapshot).to eq(reference.snapshot)
        expect(built.to_binary_s).to eq(bindata_writer.bind_call(reference))

        hashes = klass.new(cpts: 2, apts: [{ x: 1, y: 2 }, { x: 3, y: 4 }])
        expect(hashes.snapshot).to eq(klass.new({ cpts: 2, apts: [{ x: 1, y: 2 }, { x: 3, y: 4 }] }).snapshot)
      end

      it "serializes an out-of-range point as BinData does" do
        wire = klass.new(cpts: 1, apts: [{ x: 40_000, y: 1 }])
        expect(wire.to_binary_s).to eq(bindata_writer.bind_call(wire))
        wire.apts[0].x.instance_variable_set(:@value, 1.5)
        expect(filler.pack(wire)).to be_nil
      end
    end
  end

  it "parses and re-serializes test-031 with every 16-bit point record equal to BinData" do
    bytes = File.binread(File.expand_path("../../fixtures/emf/test-031.emf", __dir__))
    parsed = Emf.parse(bytes)
    expect(Emf.serialize(parsed)).to eq(bytes)
    classes = types.values.map { |t| records.lookup(t) }
    pointed = parsed.records.select { |r| classes.include?(r.wire_class) }.map(&:wire)
    expect(pointed.size).to be > 1000
    pointed.first(500).each do |wire|
      reference = wire.class.read(wire.to_binary_s)
      expect(wire.snapshot).to eq(reference.snapshot)
    end
  end
end
