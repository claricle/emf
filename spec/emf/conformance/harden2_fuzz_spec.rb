# frozen_string_literal: true

require "spec_helper"
require_relative "support/emf_plus_builder"
require_relative "support/fuzz_capped"

RSpec.describe "Emf::Conformance.check on hostile input" do
  let(:builder) { Emf::SpecSupport::EmfPlusBuilder }
  let(:valid) { File.binread(File.expand_path("../../fixtures/emf/test-000.emf", __dir__)) }
  let(:types) { (0x4001..0x403A).to_a }
  let(:body_sizes) { [0, 1, 199, 200, 201, 400] }
  let(:brush_data) { [0, 0xFF0000FF].pack("V2") }

  def check(input) = Emf::Conformance.check(input, profile: :tolerant)

  it "reports a non-ASCII-compatible string (UTF-16) as a Report instead of raising" do
    report = check(valid.dup.force_encoding(Encoding::UTF_16LE))
    expect(report.valid?).to eq(check(valid).valid?)
  end

  it "rejects an unsupported input type with an ArgumentError naming the accepted types" do
    [nil, StringIO.new(valid), 42, [valid]].each do |input|
      expect { check(input) }.to raise_error(ArgumentError, /expected a String, Pathname or Emf::Model::Metafile, got #{input.class}/)
    end
  end

  it "keeps treating an ASCII-compatible path string as a path" do
    path = File.expand_path("../../fixtures/emf/test-000.emf", __dir__)
    expect(check(path).to_h(timestamp: false)).to eq(check(valid).to_h(timestamp: false).merge("filename" => path))
  end

  it "returns a Report for every EMF+ record type with boundary bodies and framing" do
    rng = Random.new(37)
    inputs = types.flat_map do |t|
      body_sizes.map { |len| builder.stream(builder.record(t, flags: rng.rand(65_536), body: rng.bytes(len))) } +
        [builder.stream(builder.record(t, body: rng.bytes(20), data_size: 0xFFFFFFFF)),
         builder.stream(builder.record(t, body: rng.bytes(20), size: 4)),
         builder.stream(builder.record(t, body: rng.bytes(20), size: 0xFFFFFFF0))]
    end
    expect(inputs.map { |bytes| check(bytes) }).to all(be_a(Emf::Conformance::Report))
  end

  it "returns a Report for multi-record, cross-comment and truncated EMF+ streams" do
    rng = Random.new(38)
    inputs = Array.new(60) do
      recs = Array.new(rng.rand(1..8)) { builder.record(types.sample(random: rng), body: rng.bytes(rng.rand(0..220))) }
      cut = recs.last[0, rng.rand(1...recs.last.bytesize)]
      [builder.stream(*recs), builder.stream(*recs[0..-2], cut),
       Emf::SpecSupport::CraftedEmf.build(records: [builder.comment(builder.header, *recs), builder.comment(cut)])]
    end.flatten
    expect(inputs.map { |bytes| check(bytes) }).to all(be_a(Emf::Conformance::Report))
  end

  it "returns valid:false Reports for every prefix of a valid file" do
    reports = (0..120).map { |n| check(valid[0, n]) }
    expect(reports).to all(be_a(Emf::Conformance::Report))
    expect(reports.first.valid?).to be(false)
  end

  it "survives deep EMF+ container nesting and a full object table within the CPU and memory cap" do
    objects = (0..63).map { |i| builder.object(1, i, brush_data) }
    saves = Array.new(5000) { builder.record(0x4025, body: [1].pack("V")) }
    nested = builder.stream(*saves)
    outcomes = [builder.stream(*objects), nested].map { |bytes| Emf::SpecSupport::FuzzCapped.run { check(bytes) } }
    expect(outcomes).to eq(%i[ok ok])
  end
end
