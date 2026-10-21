# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emf::Emr::Binary::FastFill::PointArrayFill do
  records = Emf::Emr::Binary::Records
  codes = Emf::Emr::Binary::TypeCodes
  point_l = Emf::Binary::Types::PointL
  rect_l = Emf::Binary::Types::RectL
  bindata_writer = BinData::Base.instance_method(:to_binary_s)
  point_counts = [0, 1, 3]

  def record_bytes(type, points, bounds: [-5, 6, 7, -8], extra: "".b, count: points.size)
    body = [type, 0, *bounds, count, *points.flatten].pack("VVl<4Vl<*") + extra
    body[4, 4] = [body.bytesize].pack("V")
    body
  end

  def allocations
    GC.disable
    before = GC.stat(:total_allocated_objects)
    yield
    GC.stat(:total_allocated_objects) - before
  ensure
    GC.enable
  end

  { "Polygon" => codes::POLYGON, "Polyline" => codes::POLYLINE }.each do |name, type|
    describe name do
      let(:klass) { records.lookup(type) }
      let(:filler) { Emf::Emr::Binary::FastFill.for_points(type) }
      let(:points) { [[1, -2], [2_147_483_647, -2_147_483_648], [0, 9]] }

      it "is filled by the point array filler" do
        expect(filler).to be_a(described_class)
        expect(Emf::Emr::Binary::FastFill.for_class(klass)).to equal(filler)
      end

      point_counts.each do |count|
        it "parses #{count} points like BinData, with the same bytes and suffix" do
          bytes = record_bytes(type, points.first(count), extra: "tail".b)
          wire, suffix = filler.call(bytes)
          reference = klass.read(bytes)

          expect(wire.snapshot).to eq(reference.snapshot)
          expect(wire.num_bytes).to eq(reference.num_bytes)
          expect(suffix).to eq("tail".b)
          expect(wire.to_binary_s).to eq(bindata_writer.bind_call(reference))
          expect(wire.aptl.size).to eq(count)
        end
      end

      it "leaves a count that overruns the record to BinData" do
        bytes = record_bytes(type, points.first(1), count: 4)
        expect(filler.call(bytes)).to be_nil
        expect { klass.read(bytes) }.to raise_error(EOFError)
      end

      it "gives editable points whose parents are the new tree" do
        wire, = filler.call(record_bytes(type, points))
        wire.aptl[0].x = 40
        wire.aptl << { x: 3, y: 4 }
        wire.cptl = 4
        reference = klass.read(record_bytes(type, points))
        reference.aptl[0].x = 40
        reference.aptl << { x: 3, y: 4 }
        reference.cptl = 4

        expect(wire.snapshot).to eq(reference.snapshot)
        expect(wire.to_binary_s).to eq(bindata_writer.bind_call(reference))
        expect(wire.aptl.map { |pt| [pt.x.value, pt.y.value] }.first).to eq([40, -2])
      end

      it "does not share state between parsed records" do
        first, = filler.call(record_bytes(type, points))
        second, = filler.call(record_bytes(type, points))
        first.aptl[0].x = 99
        expect(second.aptl[0].x.value).to eq(1)
        expect(klass.new.aptl.size).to eq(0)
      end

      it "builds from consumer-shaped attributes like BinData" do
        wire_points = points.map { |x, y| point_l.new(x: x, y: y) }
        attrs = { i_type: type, rcl_bounds: rect_l.new(left: 1, top: 2, right: 3, bottom: 4),
                  cptl: 3, aptl: wire_points }
        built = klass.new(**attrs)
        reference = klass.new(attrs.dup)

        expect(built.snapshot).to eq(reference.snapshot)
        expect(built.num_bytes).to eq(reference.num_bytes)
        expect(built.to_binary_s).to eq(bindata_writer.bind_call(reference))
        expect(built.aptl[1].y.value).to eq(-2_147_483_648)
      end

      it "builds from hash points and from an omitted point list" do
        hashes = klass.new(cptl: 2, aptl: [{ x: 1, y: 2 }, { x: 3, y: 4 }])
        expect(hashes.snapshot).to eq(klass.new({ cptl: 2, aptl: [{ x: 1, y: 2 }, { x: 3, y: 4 }] }).snapshot)

        lazy = klass.new(cptl: 2)
        expect(lazy.snapshot).to eq(klass.new({ cptl: 2 }).snapshot)
        expect(klass.new.aptl.size).to eq(0)
      end

      it "falls back to BinData for unexpected point values and unknown keys" do
        expect { klass.new({ cptl: 1, aptl: [[5, 6]] }) }.to raise_error(NoMethodError)
        expect { klass.new(cptl: 1, aptl: [[5, 6]]) }.to raise_error(NoMethodError)
        expect(klass.new(bogus: 1).snapshot).to eq(klass.new({ bogus: 1 }).snapshot)
      end

      it "serializes an out-of-range point as BinData does" do
        wire = klass.new(cptl: 1, aptl: [{ x: 2**40, y: 1 }])
        expect(wire.to_binary_s).to eq(bindata_writer.bind_call(wire))
        wire.aptl[0].x.instance_variable_set(:@value, 1.5)
        expect(filler.pack(wire)).to be_nil
      end

      it "allocates at most half of BinData per parsed record" do
        pts = Array.new(4) { |i| [i, -i] }
        bytes = record_bytes(type, pts)
        filler.call(bytes)
        klass.read(bytes)
        fast = allocations { filler.call(bytes) }
        slow = allocations { klass.read(bytes) }
        expect(fast).to be < slow / 2
      end
    end
  end
end
