# frozen_string_literal: true

require "spec_helper"
require_relative "../../../support/wire_build_oracle"

# The generated `pack` takes the common call shape (every field but n_size,
# nested structs and points as Hashes or as instances) in one boolean chain.
# Whatever shape arrives, the bytes must be BinData's, and a shape the chain
# does not take must give the interpreter's answer.
RSpec.describe Emf::Emr::Binary::PackPlan, "exact shape" do
  oracle = WireBuildOracle
  bindata_new = BinData::Base.method(:new).unbind

  bytes_of = lambda do |klass, attrs|
    wire = bindata_new.bind_call(klass, **attrs)
    wire.n_size = wire.num_bytes
    wire.to_binary_s
  end
  field_or = ->(value, field) { value.is_a?(Hash) ? field : value }
  # The same attributes with nested structs and points as the instances a
  # BinData-built record holds.
  instances_of = lambda do |klass, attrs|
    wire = bindata_new.bind_call(klass, **attrs)
    attrs.to_h do |name, value|
      field = wire.public_send(name)
      [name, value.is_a?(Array) ? field.to_a : field_or.call(value, field)]
    end
  end

  oracle.planned_classes.each do |klass|
    context klass.name.split("::").last do
      let(:plan) { Emf::Emr::Binary::FastFill.for_class(klass).pack_plan }
      let(:full) { oracle.full_attrs(klass) }

      it "packs Hash attributes to BinData's bytes, without the interpreter" do
        allow(plan).to receive(:pack_interpreted).and_call_original
        expect(plan.pack(full)).to eq(bytes_of.call(klass, full))
        expect(plan).not_to have_received(:pack_interpreted)
      end

      it "packs struct and point instances to BinData's bytes, without the interpreter" do
        allow(plan).to receive(:pack_interpreted).and_call_original
        attrs = instances_of.call(klass, full)
        expect(plan.pack(attrs)).to eq(bytes_of.call(klass, full))
        expect(plan).not_to have_received(:pack_interpreted)
      end

      it "leaves n_size as given with size: false" do
        expect(plan.pack(full, size: false).unpack1("V", offset: 4)).to eq(0)
        expect(plan.pack(full.merge(n_size: 9), size: false).unpack1("V", offset: 4)).to eq(9)
      end

      it "answers as the interpreter does for values and keys the chain does not take" do
        nested = full.find { |_, value| value.is_a?(Hash) }
        variants = [full.merge(i_type: -1), full.merge(i_type: 2**32), full.merge(i_type: 1.5), full.merge(i_type: nil),
                    full.merge(bogus: 1), full.merge(n_size: 5), full.except(:i_type)]
        variants << full.merge(nested[0] => nested[1].merge(bogus: 1)) if nested
        variants << full.merge(nested[0] => nested[1].except(nested[1].keys.first)) if nested
        variants << full.merge(nested[0] => nested[1].merge(nested[1].keys.first => 2**40)) if nested
        variants.each do |attrs|
          expect(plan.pack(attrs)).to eq(plan.pack_interpreted(attrs)), attrs.inspect
        end
      end
    end
  end

  describe "a point array" do
    let(:klass) { oracle.planned_classes.find { |candidate| oracle.point_names(candidate) } }
    let(:plan) { Emf::Emr::Binary::FastFill.for_class(klass).pack_plan }
    let(:array) { oracle.point_names(klass).first }
    let(:count) { oracle.point_names(klass).last }
    let(:full) { oracle.full_attrs(klass) }

    it "declines a count that is not the number of points, as the interpreter does" do
      attrs = full.merge(count => full.fetch(array).size + 1)
      expect(plan.pack(attrs)).to be_nil
      expect(plan.pack_interpreted(attrs)).to be_nil
    end

    it "declines points that are out of range or malformed, as the interpreter does" do
      [[{ x: 2**40, y: 1 }], [{ x: 1 }], [{ x: 1, y: 2, z: 3 }], [{ x: 1.5, y: 2 }], [[1, 2]], [nil]].each do |points|
        attrs = full.merge(array => points, count => points.size)
        expect(plan.pack(attrs)).to eq(plan.pack_interpreted(attrs)), points.inspect
      end
    end

    it "packs no points and many points to BinData's bytes" do
      [0, 1, 300].each do |size|
        points = Array.new(size) { |at| { x: at, y: -at } }
        attrs = full.merge(array => points, count => size)
        expect(plan.pack(attrs)).to eq(bytes_of.call(klass, attrs))
      end
    end
  end
end
