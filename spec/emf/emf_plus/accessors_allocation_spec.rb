# frozen_string_literal: true

require "spec_helper"

RSpec.describe "EMF+ BinData field accessors" do
  let(:metafile) { Emf.parse(File.binread(File.join(__dir__, "../../fixtures/emf/test-109.emf"))) }
  let(:frames) { Emf::EmfPlus::Parser.from_metafile(metafile, errors: []) }
  let(:records) { Emf::EmfPlus::Records.decode_all(frames) }

  it "defines no singleton methods on a record body or its fields" do
    body = records.find { |r| r.body.respond_to?(:field_names) && r.body.field_names.any? }.body
    expect(body.singleton_methods).to be_empty
    expect(body.send(body.field_names.first).singleton_methods).to be_empty
  end

  it "defines no singleton methods on an object body" do
    logical = Emf::EmfPlus::ObjectChain.call(records).find { |e| e.is_a?(Emf::EmfPlus::ObjectChain::LogicalObject) }
    body = logical.body.body
    expect(body.singleton_methods).to be_empty
    expect(body.send(body.field_names.first).singleton_methods).to be_empty
  end

  it "defines no singleton methods on an effect body" do
    metafile = Emf.parse(File.binread(File.join(__dir__, "../../fixtures/emf/test-038.emf")))
    frames = Emf::EmfPlus::Parser.from_metafile(metafile, errors: [])
    record = Emf::EmfPlus::Records.decode_all(frames).find { |r| r.respond_to?(:effect) && r.effect.respond_to?(:body) }
    body = record.effect.body
    expect(body.singleton_methods).to be_empty
    expect(body.send(body.field_names.first).singleton_methods).to be_empty
  end

  it "defines no singleton methods on a primitive instance" do
    point = Emf::EmfPlus::Records::Primitives::Point.new(x: 1, y: 2)
    expect(point.x).to eq(1)
    expect(point.singleton_methods).to be_empty
  end

  it "keeps the accessors working for assignment and presence" do
    point = Emf::EmfPlus::Records::Primitives::Point.new
    point.x = 7
    expect([point.x, point.x?]).to eq([7, true])
  end

  it "re-encodes every record to its frame bytes" do
    expect(records.map(&:to_binary).join.b).to eq(frames.map(&:to_binary).join.b)
  end
end
