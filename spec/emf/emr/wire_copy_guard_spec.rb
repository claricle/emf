# frozen_string_literal: true

require "spec_helper"

# FastFill leans on BinData internals (@field_objs, @parent, get_parameter,
# clone vs dup) verified on one BinData release while the gemspec allows
# more. Each filler self-checks when built and is left out when BinData does
# not behave as assumed, so callers fall back to plain BinData.
RSpec.describe Emf::Emr::Binary::FastFill, "internals guard" do
  fast = described_class
  codes = Emf::Emr::Binary::TypeCodes
  records = Emf::Emr::Binary::Records
  all_types = codes.constants.map { |name| codes.const_get(name) }.uniq
  fixed_types = all_types.select { |id| fast.for(id) }
  point_types = [codes::POLYGON, codes::POLYLINE]
  bindata_writer = BinData::Base.instance_method(:to_binary_s)

  let(:victim) { records.lookup(codes::SETBKMODE) }
  let(:bystander) { records.lookup(codes::SETMAPMODE) }
  let(:fixture) { File.binread(File.expand_path("../../fixtures/emf/test-000.emf", __dir__)) }

  # Rebuild the lookup tables as the file does at load, under whatever
  # simulated BinData change the example installed.
  def rebuild_tables(fast, codes, records, types)
    by_type = types.to_h { |id| [id, fast.guarded(records.lookup(id))] }.compact
    stub_const("Emf::Emr::Binary::FastFill::BY_TYPE", by_type)
    stub_const("Emf::Emr::Binary::FastFill::BY_CLASS", by_type.values.to_h { |f| [f.wire_class, f] })
    point_fill = described_class::PointArrayFill
    points = [codes::POLYGON, codes::POLYLINE].to_h { |id| [id, point_fill.guarded(records.lookup(id))] }.compact
    stub_const("Emf::Emr::Binary::FastFill::POINT_ARRAY_BY_TYPE", points)
    stub_const("Emf::Emr::Binary::FastFill::POINT_ARRAY_BY_CLASS", points.values.to_h { |f| [f.wire_class, f] })
  end

  def disable_all
    stub_const("Emf::Emr::Binary::FastFill::BY_TYPE", {})
    stub_const("Emf::Emr::Binary::FastFill::BY_CLASS", {})
    stub_const("Emf::Emr::Binary::FastFill::POINT_ARRAY_BY_TYPE", {})
    stub_const("Emf::Emr::Binary::FastFill::POINT_ARRAY_BY_CLASS", {})
  end

  def strip_field_objs(klass)
    allow(klass).to receive(:new).and_wrap_original do |original, *args, **kwargs|
      original.call(*args, **kwargs).tap do |wire|
        wire.remove_instance_variable(:@field_objs) if args.empty? && kwargs.empty?
      end
    end
  end

  def share_template(klass)
    allow(Emf::Emr::Binary::WireCopy).to receive(:call).and_wrap_original do |original, template, parent|
      template.is_a?(klass) ? template : original.call(template, parent)
    end
  end

  it "passes the self-check for every enabled class on the installed BinData" do
    expect(fixed_types.size).to eq(37)
    fillers = fixed_types.map { |id| fast.for(id) } + point_types.map { |id| fast.for_points(id) }
    expect(fillers).to all(be_a(described_class))
    expect(fillers.size).to eq(39)
    expect(fillers.map(&:verify!)).to eq(fillers)
  end

  it "builds each filler through the guard" do
    fixed = fixed_types.map { |id| fast.guarded(records.lookup(id)) }
    points = point_types.map { |id| described_class::PointArrayFill.guarded(records.lookup(id)) }
    expect(fixed + points).to all(be_a(described_class))
  end

  {
    "a missing @field_objs" => :strip_field_objs,
    "a template copy that shares the template" => :share_template
  }.each do |change, installer|
    describe "when BinData shows #{change}" do
      before { send(installer, victim) }

      it "disables that class only" do
        expect(fast.guarded(victim)).to be_nil
        expect(fast.guarded(bystander)).to be_a(described_class)
      end

      it "leaves parse, serialize and keyword construction equal to BinData" do
        rebuild_tables(fast, codes, records, fixed_types)
        expect(fast.for(codes::SETBKMODE)).to be_nil
        expect(fast.for(codes::SETMAPMODE)).not_to be_nil
        expect(fast.for_class(victim)).to be_nil

        bytes = Emf.serialize(Emf.parse(fixture))
        expect(bytes).to eq(fixture)

        built = victim.new(bk_mode: 1)
        reference = victim.new({ bk_mode: 1 })
        expect(built.snapshot).to eq(reference.snapshot)
        expect(built.to_binary_s).to eq(bindata_writer.bind_call(reference))
      end
    end
  end

  it "falls back to BinData for every class when the tables are empty" do
    expected = Emf.serialize(Emf.parse(fixture))
    disable_all
    expect(Emf.serialize(Emf.parse(fixture))).to eq(expected)
    expect(expected).to eq(fixture)
  end

  it "disables a point-array class whose internals changed" do
    strip_field_objs(records.lookup(codes::POLYGON))
    point_fill = described_class::PointArrayFill
    expect(point_fill.guarded(records.lookup(codes::POLYGON))).to be_nil
    expect(point_fill.guarded(records.lookup(codes::POLYLINE))).to be_a(point_fill)
  end

  it "disables a class whose template copy differs from a fresh instance" do
    allow(Emf::Emr::Binary::WireCopy).to receive(:call).and_wrap_original do |original, template, parent|
      original.call(template, parent).tap do |copy|
        copy.instance_variable_get(:@field_objs).last.assign(99) if copy.is_a?(victim)
      end
    end
    expect(fast.guarded(victim)).to be_nil
    expect(fast.guarded(bystander)).to be_a(described_class)
  end
end
