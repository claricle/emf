# frozen_string_literal: true

require "spec_helper"

RSpec.describe "SetDibitsToDevice record registration" do
  it "resolves EMR80 and preserves its editable Ruby wire model" do
    header = Emf::Emr::Binary::Header.new(i_type: 1, n_size: 108, d_signature: 0x464D4520).to_binary_s
    record = "#{[80, 80, -1, -2, 3, 4].pack('V2l<4')}#{"\x00" * 52}tail"
    eof = [14, 20, 0, 0, 20].pack("V*")
    input = header + record + eof
    parsed = Emf::Emr::Parser.call(input)
    wire = parsed.records.first.wire
    expect(wire).to be_a(Emf::Emr::Binary::Records::SetDibitsToDevice)
    expect(Emf::Emr::Binary::Records.lookup(80)).to eq(wire.class)
    expect(Emf::Emr::Serializer.call(parsed)).to eq(input)
    wire.rcl_bounds.left = -333
    record[8, 4] = [-333].pack("l<")
    expect(Emf::Emr::Serializer.call(parsed)).to eq(header + record + eof)
  end
end
