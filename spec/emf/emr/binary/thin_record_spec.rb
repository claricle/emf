# frozen_string_literal: true

require "spec_helper"
require_relative "../../../support/wire_build_oracle"

# A record `Klass.new(**attrs)` or a parse returns is thin: the record's bytes
# and offset, no @field_objs. Anything that needs a field makes it in place,
# so the record is the one a caller already holds and every field object it
# hands out is the one every later read answers.
RSpec.describe Emf::Emr::Binary::Record, "thin shell" do
  oracle = WireBuildOracle
  bindata_new = BinData::Base.method(:new).unbind
  reference = ->(klass, attrs) { bindata_new.bind_call(klass, **attrs) }
  field_objs = ->(wire) { wire.instance_variable_get(:@field_objs) }

  def self.short(klass) = klass.name.split("::").last

  oracle.planned_classes.each do |klass|
    context short(klass) do
      let(:full) { oracle.full_attrs(klass) }
      let(:filler) { Emf::Emr::Binary::FastFill.for_class(klass) }
      let(:shells) do
        bytes = reference.call(klass, full).tap { |ref| ref.n_size = ref.num_bytes }.to_binary_s
        { built: klass.new(**full).tap { |wire| wire.n_size = wire.num_bytes }, parsed: filler.call(bytes).first }
      end

      it "holds no field objects until a field is asked for" do
        shells.each_value do |wire|
          expect(field_objs.call(wire)).to be_nil
          expect(wire.to_binary_s).to be_a(String)
          expect(wire.num_bytes).to be_a(Integer)
          wire.lazy_source
          expect(field_objs.call(wire)).to be_nil
        end
      end

      it "makes @field_objs in place on the first read, and keeps the field object" do
        shells.each_value do |wire|
          before = wire.i_type
          expect(field_objs.call(wire)).to be_an(Array)
          expect(wire.i_type).to be(before)
          expect(wire.field_names).to eq(reference.call(klass, full).field_names)
        end
      end

      it "repacks an edit made through a field object read before it" do
        shells.each_value do |wire|
          held = wire.i_type
          expect(wire.n_size).to be(wire.n_size)
          held.assign(0x2A)
          expect(wire.i_type).to be(held)
          expected = reference.call(klass, full).tap do |ref|
            ref.n_size = ref.num_bytes
            ref.i_type = 0x2A
          end
          expect(wire.to_binary_s).to eq(expected.to_binary_s)
          expect(wire.snapshot).to eq(expected.snapshot)
        end
      end

      it "matches a BinData-built record in snapshot and ==, whichever way it is first touched" do
        expected = reference.call(klass, full).tap { |ref| ref.n_size = ref.num_bytes }
        touches = [:snapshot, :inspect, :to_s, :num_bytes, :each_pair, :clear?, ->(w) { w == expected }]
        touches.each do |touch|
          shells.each_value do |wire|
            touch.respond_to?(:call) ? touch.call(wire) : wire.public_send(touch) { nil }
            expect(wire.snapshot).to eq(expected.snapshot)
            expect(wire).to eq(expected)
            expect(wire.to_binary_s).to eq(expected.to_binary_s)
          end
        end
      end

      it "hydrates on assign and clear, keeping identity of the record" do
        wire = klass.new(**full)
        wire.assign(reference.call(klass, full))
        expect(wire.snapshot).to eq(reference.call(klass, full).snapshot)
        other = klass.new(**full)
        other.clear
        expect(other.snapshot).to eq(klass.new.snapshot)
      end
    end
  end
end
