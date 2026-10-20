# frozen_string_literal: true

require "spec_helper"
require "emf/native"

RSpec.describe "native float32 NaN payload bits" do
  let(:library) { ENV.fetch("EMF_TEST_NATIVE_LIBRARY", nil) }
  let(:header) { Emf::Emr::Binary::Header.new(i_type: 1, n_size: 108, d_signature: 0x464D4520, n_version: 0x10000).to_binary_s }
  let(:eof) { [14, 20, 0, 0, 20].pack("V*") }
  let(:signalling) { 0x7FA00001 }
  let(:infinity_like) { 0x7F800001 }
  let(:negative) { 0xFFC12345 }
  let(:one_and_a_half) { [1.5].pack("e") }

  def bits(*values) = values.pack("V*")

  def text_out(type)
    [type, 60, -1, 2, 40, 60].pack("V2l<4") + bits(2, signalling, negative) + [3, 4].pack("l<2") + bits(0, 0, 0x110, 0)
  end

  # name, record bytes, accessor path and record offset of each float leaf
  def cases
    xform = %i[m11 m12 m21 m22 dx dy].each_with_index.map { |name, i| [[:xform, name], 8 + (i * 4)] }
    nans = [signalling, infinity_like, negative, 0x3FC00000, signalling, negative]
    scales = [[[:ex_scale], 28], [[:ey_scale], 32]]
    {
      "SetWorldTransform" => [bits(35, 32, *nans), xform],
      "ModifyWorldTransform" => [bits(36, 36, *nans, 1), xform],
      "AngleArc" => [bits(41, 28, 1, 2, 3, signalling, negative), [[[:start_angle], 20], [[:sweep_angle], 24]]],
      "SetMiterLimit" => [bits(58, 12, negative), [[[:miter_limit], 8]]],
      "ExtTextOutW" => [text_out(84), scales],
      "ExtTextOutA" => [text_out(83), scales],
      "SmallTextOut" => [bits(108, 44, 1, 2, 3, 0x12, 1, signalling, negative) + "\x91\x00opaque".b, scales]
    }
  end

  def wire_leaf(wire, path)
    path.inject(wire) { |node, name| node.public_send(name) }
  end

  around do |example|
    previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
    ENV["EMF_BACKEND"] = "native"
    ENV["EMF_NATIVE_LIBRARY"] = library
    example.run
  ensure
    %w[EMF_BACKEND EMF_NATIVE_LIBRARY].each { |key| ENV[key] = previous[key] }
  end

  before do
    skip "set EMF_TEST_NATIVE_LIBRARY to run native specs" if library.nil?
    # A configured but wrong path must not look like a pass.
    expect(File.file?(library)).to be(true), "EMF_TEST_NATIVE_LIBRARY is not a file: #{library}"
  end

  it "keeps untouched NaN bits when a record is materialized without edits" do
    cases.each do |name, (record, leaves)|
      input = "#{header}#{record}#{eof}"
      wire = Emf.parse(input).records.first.wire
      expect(wire.to_binary_s).to eq(record), name
      leaves.each do |path, offset|
        expect(wire_leaf(wire, path).value).to be_a(Float), name
        expect(wire_leaf(wire, path).value.nan?).to eq(record.byteslice(offset, 4).unpack1("e").nan?), name
      end
    end
  end

  it "keeps untouched NaN bits through serialization after another field is edited, and honours an explicit assignment" do
    cases.each do |name, (record, leaves)|
      parsed = Emf.parse("#{header}#{record}#{eof}")
      wire = parsed.records.first.wire
      path, offset = leaves.first
      wire_leaf(wire, path).assign(1.5)
      expected = record.dup
      expected[offset, 4] = one_and_a_half
      expect(wire_leaf(wire, path).value).to eq(1.5), name
      expect(wire.to_binary_s).to eq(expected), name
      expect(Emf.serialize(parsed)).to eq("#{header}#{expected}#{eof}"), name
    end
  end
end
