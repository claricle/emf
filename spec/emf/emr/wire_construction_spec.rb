# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emf::Emr::Binary::Record do
  codes = Emf::Emr::Binary::TypeCodes
  fast = Emf::Emr::Binary::FastFill
  enabled = codes.constants.map { |name| codes.const_get(name) }.uniq.select { |id| fast.for(id) }
  bindata_writer = BinData::Base.instance_method(:to_binary_s)

  # Attribute hash giving every leaf a distinct value of its own kind.
  def attrs_for(wire, seed, nested: :hash)
    wire.field_names.to_h do |name|
      field = wire.public_send(name)
      next [name, leaf_value(field, seed + name.size)] unless field.respond_to?(:field_names)

      inner = attrs_for(field, seed + 1)
      [name, nested == :hash ? inner : field.class.new(inner)]
    end
  end

  def leaf_value(field, seed)
    case field
    when Emf::Binary::Float32Le then seed + 0.5
    when BinData::Int32le then -seed
    when BinData::Uint8 then seed % 256
    else seed + 0x01020304
    end
  end

  it "covers every enabled type" do
    expect(enabled.size).to eq(37)
  end

  enabled.each do |type|
    describe "type #{type}" do
      let(:klass) { fast.for(type).wire_class }
      let(:full) { attrs_for(klass.new, 3) }
      let(:partial) { full.slice(*full.keys.last(2)) }

      def reference(klass, attrs)
        klass.new(attrs.dup)
      end

      it "equals the BinData-built object for full attributes" do
        wire = klass.new(**full)
        expect(wire.snapshot).to eq(reference(klass, full).snapshot)
        expect(wire.class).to eq(klass)
      end

      it "equals the BinData-built object for nested BinData values" do
        nested = attrs_for(klass.new, 3, nested: :struct)
        expect(klass.new(**nested).snapshot).to eq(reference(klass, nested).snapshot)
      end

      it "keeps BinData defaults for omitted keys" do
        expect(klass.new(**partial).snapshot).to eq(reference(klass, partial).snapshot)
        expect(klass.new(**partial).snapshot).to eq(klass.new.snapshot.merge(partial)) if partial.values.none?(Hash)
      end

      it "writes the bytes BinData writes" do
        wire = klass.new(**full)
        expected = bindata_writer.bind_call(reference(klass, full))
        expect(wire.to_binary_s).to eq(expected)
        expect(wire.to_binary_s.encoding).to eq(Encoding::BINARY)
        expect(wire.num_bytes).to eq(expected.bytesize)
      end

      it "reads, writes and reassigns fields like a BinData object" do
        wire = klass.new(**full)
        wire.n_size = 77
        expected = reference(klass, full)
        expected.n_size = 77
        expect(wire.n_size).to eq(77)
        expect(wire.to_binary_s).to eq(bindata_writer.bind_call(expected))
        expect(klass.read(wire.to_binary_s).snapshot).to eq(wire.snapshot)
      end

      it "gives each call an independent object" do
        first = klass.new(**partial)
        second = klass.new(**partial)
        first.n_size = 99
        expect(second.n_size).not_to eq(99)
        expect(klass.new.n_size).to eq(0)
        expect(klass.new(**partial).snapshot).to eq(second.snapshot)
      end

      it "links nested fields to their parent like BinData" do
        wire = klass.new(**full)
        expect(wire.parent).to be_nil
        nested = wire.field_names.map { |name| wire.public_send(name) }.select { |f| f.respond_to?(:field_names) }
        expect(nested).to all(satisfy { |child| child.parent.equal?(wire) })
      end

      it "ignores nil values and unknown keys like BinData" do
        attrs = partial.merge(bogus: 1, full.keys.first => nil)
        expect(klass.new(**attrs).snapshot).to eq(reference(klass, attrs).snapshot)
      end

      it "rejects an invalid value like BinData" do
        name = full.keys.find { |key| !full[key].is_a?(Hash) }
        expect { klass.new(**{ name => "x" }) }.to raise_error(ArgumentError)
        expect { reference(klass, { name => "x" }) }.to raise_error(ArgumentError)
      end
    end
  end

  describe "other call shapes" do
    let(:klass) { Emf::Emr::Binary::Records::SelectObject }

    it "builds with no attributes" do
      expect(klass.new.snapshot).to eq(i_type: 0, n_size: 0, ih_object: 0)
    end

    it "builds keyword calls from the FastFill template and writes with its pack" do
      filler = fast.for_class(klass)
      allow(filler).to receive(:build).and_call_original
      allow(filler).to receive(:pack).and_call_original
      wire = klass.new(ih_object: 5)
      wire.to_binary_s
      expect(filler).to have_received(:build).with({ ih_object: 5 })
      expect(filler).to have_received(:pack).with(wire)
    end

    it "builds from a positional hash" do
      expect(klass.new({ ih_object: 5 }).snapshot).to eq(i_type: 0, n_size: 0, ih_object: 5)
    end

    it "builds with a parent" do
      parent = klass.new
      expect(klass.new({ ih_object: 5 }, {}, parent).parent).to equal(parent)
    end

    it "keeps variable-length records on BinData" do
      points = Array.new(3) { |i| Emf::Binary::Types::PointL.new(x: i, y: -i) }
      rect = Emf::Binary::Types::RectL.new(left: 1, top: 2, right: 3, bottom: 4)
      poly = Emf::Emr::Binary::Records::Polygon.new(i_type: 3, rcl_bounds: rect, cptl: 3, aptl: points)
      expect(poly.to_binary_s.bytesize).to eq(8 + 16 + 4 + 24)
      expect(poly.aptl[2].y).to eq(-2)
      expect(poly.to_binary_s).to eq(bindata_writer.bind_call(poly))
    end

    it "keeps the float layouts on the BinData writer" do
      wire = Emf::Emr::Binary::Records::SetWorldTransform.new(i_type: 35, xform: { m11: 1.5, m22: -2.0 })
      expect(wire.to_binary_s).to eq(bindata_writer.bind_call(wire))
      expect(wire.xform.snapshot).to include(m11: 1.5, m22: -2.0)
    end
  end
end
