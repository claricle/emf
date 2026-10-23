# frozen_string_literal: true

require "spec_helper"
require_relative "../../../support/wire_build_oracle"

# `Klass.new(**attrs)` serves a packed shell for a planned class. It must be
# the record BinData's own constructor makes, before and after edits.
RSpec.describe Emf::Emr::Binary::Record, ".new with a pack plan" do
  oracle = WireBuildOracle
  bindata_new = BinData::Base.method(:new).unbind

  reference = ->(klass, attrs) { bindata_new.bind_call(klass, **attrs) }
  view = lambda do |wire|
    [wire.class, wire.snapshot.to_s, wire.num_bytes, wire.to_binary_s, wire.n_size.snapshot, wire.i_type.snapshot,
     oracle::BINDATA_WRITER.bind_call(wire)]
  end
  outcome = ->(&block) { oracle.outcome(&block) }

  def self.short(klass) = klass.name.split("::").last

  oracle.planned_classes.each do |klass|
    context short(klass) do
      let(:full) { oracle.full_attrs(klass) }

      it "is a shell of the class, equal to BinData's record" do
        wire = klass.new(**full)
        expect(wire).to be_an_instance_of(klass)
        expect(wire.lazy_source).not_to be_nil
        expect(view.call(wire)).to eq(view.call(reference.call(klass, full)))
        expect(wire).to eq(reference.call(klass, full))
      end

      it "keeps the given or default n_size until it is assigned" do
        [full, full.merge(n_size: 77), { i_type: 5 }].each do |attrs|
          expect(klass.new(**attrs).lazy_source).not_to be_nil
          expect(klass.new(**attrs).n_size.snapshot).to eq(reference.call(klass, attrs).n_size.snapshot)
          expect(klass.new(**attrs).to_binary_s).to eq(reference.call(klass, attrs).to_binary_s)
        end
      end

      it "reflects n_size = num_bytes in the bytes without making any field" do
        wire = klass.new(**full)
        wire.n_size = wire.num_bytes
        expect(wire.lazy_source.last).to be(false)
        expect(wire.instance_variable_get(:@field_objs)).to be_nil
        expected = reference.call(klass, full).tap { |ref| ref.n_size = ref.num_bytes }
        expect(wire.to_binary_s).to eq(expected.to_binary_s)
        expect(view.call(wire)).to eq(view.call(expected))
      end

      it "serves an assigned n_size to a later read and to the bytes" do
        wire = klass.new(**full)
        wire.n_size = 4242
        expect(wire.lazy_source.last).to be(false)
        expect(wire.n_size.snapshot).to eq(4242)
        expect(wire.to_binary_s.unpack1("V", offset: 4)).to eq(4242)
        expected = reference.call(klass, full).tap { |ref| ref.n_size = 4242 }
        expect(view.call(wire)).to eq(view.call(expected))
      end

      it "writes nothing for an n_size the bytes hold, and never touches bytes a to_binary_s copy shares" do
        wire = klass.new(**full)
        bytes = wire.to_binary_s
        size = bytes.unpack1("V", offset: 4)
        bytes.setbyte(4, size.succ & 0xFF)
        wire.n_size = size
        expect(wire.to_binary_s.unpack1("V", offset: 4)).to eq(size)
        expect(wire.lazy_source.last).to be(false)
        wire.n_size = size + 1
        expect(wire.to_binary_s.unpack1("V", offset: 4)).to eq(size + 1)
        expect(wire.n_size.snapshot).to eq(size + 1)
      end

      it "leaves an n_size that is not a uint32 Integer to BinData" do
        expect(klass.new(**full).lazy_source).not_to be_nil
        [-1, 2**32, "9", nil, 4.0, 4.5, 1e10].each do |value|
          assign = lambda do |record|
            record.n_size = value
            [record.n_size.snapshot, record.to_binary_s]
          end
          expect(outcome.call { assign.call(klass.new(**full)) }).to eq(outcome.call { assign.call(reference.call(klass, full)) })
        end
      end

      it "re-packs after any edit" do
        wire = klass.new(**full)
        other = reference.call(klass, full)
        expect(wire.lazy_source).not_to be_nil
        [wire, other].each do |record|
          record.n_size = record.num_bytes
          record.i_type = 99
          field = record.public_send(record.field_names.last)
          field.assign(field.snapshot)
        end
        expect(view.call(wire)).to eq(view.call(other))
      end
    end
  end

  it "is the same as BinData's constructor for random attributes, errors included" do
    random = Random.new(15)
    oracle.planned_classes.each do |klass|
      60.times do
        attrs = oracle.random_attrs(klass, random)
        next if attrs.empty?

        actual = outcome.call { view.call(klass.new(**attrs)) }
        expect(actual).to eq(outcome.call { view.call(reference.call(klass, attrs)) }), "#{klass} #{attrs.inspect}"
      end
    end
  end

  it "packs, or declines, exactly as the interpreted plan does, with and without n_size" do
    random = Random.new(31)
    sizes = [true, false]
    oracle.planned_classes.each do |klass|
      plan = Emf::Emr::Binary::FastFill.for_class(klass).pack_plan
      80.times do
        attrs = oracle.random_attrs(klass, random)
        sizes.each do |size|
          expect(plan.pack(attrs, size: size)).to eq(plan.pack_interpreted(attrs, size: size)), "#{klass} #{attrs.inspect}"
        end
      end
    end
  end
end
