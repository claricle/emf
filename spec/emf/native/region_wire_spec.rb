# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/region_records"

RSpec.describe "region wire layouts" do
  include RegionRecords

  it "reads bounds before the brush and omits the nonexistent invert and paint brush" do
    (71..75).each do |type|
      bytes = region_record(type)
      wire = Emf::Emr::Binary::Records.lookup(type).read(bytes)
      expect(wire.rgn_data.rectangles.first.left.to_i).to eq(-0x80000000)
      expect(wire.cb_rgn_data.to_i).to eq(52)
      expect(wire.rcl_bounds.left.to_i).to eq(-1) unless type == 75
      expect(wire).not_to respond_to(:ih_brush) if (73..74).cover?(type)
      expect(wire.to_binary_s).to eq(bytes)
    end
  end
end
