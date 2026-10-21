# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emf::Binary::KeywordNew do
  bindata_new = BinData::Base.method(:new)
  types = Emf::Binary::Types

  {
    types::PointL => { x: -1, y: 2 },
    types::PointS => { x: -1, y: 2 },
    types::SizeL => { cx: 5, cy: 6 },
    types::RectL => { left: 1, top: -2, right: 3, bottom: 4 },
    types::RectS => { left: 1, top: -2, right: 3, bottom: 4 },
    types::ColorRef => { red: 1, green: 2, blue: 3, reserved: 4 }
  }.each do |klass, attrs|
    describe klass.name.split("::").last do
      it "matches BinData's keyword construction in class, snapshot and bytes" do
        built = klass.new(**attrs)
        expected = bindata_new.unbind.bind_call(klass, attrs)
        expect(built).to be_an_instance_of(klass)
        expect(built.snapshot).to eq(expected.snapshot)
        expect(built.to_binary_s).to eq(expected.to_binary_s)
        expect(built.num_bytes).to eq(expected.num_bytes)
      end

      it "returns an independent object and leaves unset fields at default" do
        built = klass.new(**attrs.first(1).to_h)
        built.public_send(attrs.keys.first).assign(99)
        expect(klass.new(**attrs).public_send(attrs.keys.first).value).to eq(attrs.values.first)
        expect(klass.new(**attrs.first(1).to_h).snapshot).to eq(bindata_new.unbind.bind_call(klass, attrs.first(1).to_h).snapshot)
      end
    end
  end

  it "leaves other call shapes and unknown keys to BinData" do
    point = types::PointL
    expect(point.new.snapshot).to eq(x: 0, y: 0)
    expect(point.new({ x: 3 }).snapshot).to eq(x: 3, y: 0)
    expect(point.new(z: 1).snapshot).to eq(x: 0, y: 0)
  end
end
