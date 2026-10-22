# frozen_string_literal: true

# The Ruby parser keeps a fixed-layout or point-array record as its bytes and
# makes the BinData wire only when `#wire` is asked for.
RSpec.describe Emf::Emr::FilledRecord do
  let(:bytes) { File.binread(File.expand_path("../../fixtures/emf/test-000.emf", __dir__)) }
  let(:records) { Emf::Emr::Parser.call(bytes).records }

  def lazy?(record)
    record.instance_variable_get(:@wire).nil?
  end

  def eager_wire(record)
    Emf::Emr::Binary::Records.lookup(record.type_id).read(record.to_binary_s)
  end

  it "leaves most records without a wire after the parse" do
    expect(records.count { |record| lazy?(record) }).to be > records.size / 2
  end

  it "names the wire class of a record without making its wire" do
    record = records.find { |candidate| lazy?(candidate) }
    expect(record.wire_class).to eq(eager_wire(record).class)
    expect(lazy?(record)).to be(true)
  end

  it "serializes the parse back to the input bytes" do
    expect(Emf.serialize(Emf::Emr::Parser.call(bytes))).to eq(bytes)
  end

  it "makes the wire a BinData read of the record's bytes would make" do
    records.select { |record| lazy?(record) }.each do |record|
      expect(record.wire.snapshot).to eq(eager_wire(record).snapshot)
      expect(record.suffix).to eq(Emf::Model::Emr::Records::WireAdapter.suffix_of(record.to_binary_s, record.wire))
    end
  end

  it "serializes an edit made through the wire" do
    record = records.find { |candidate| lazy?(candidate) && candidate.wire_class.method_defined?(:ih_object) }
    record.wire.ih_object = 0x80000007
    expect(record.to_binary_s.unpack1("V", offset: 8)).to eq(0x80000007)
  end

  it "names the wire class and reads the values of a built record without making its wire" do
    klass = Emf::Emr::Binary::Records::SelectObject
    built = Emf::Model::Emr::Records::WireAdapter.build(klass, ih_object: 7)
    expect(built.wire_class).to eq(klass)
    expect(built.values.ih_object).to eq(7)
    expect(built.instance_variable_get(:@wire)).to be_nil
  end

  context "with a point count that overruns its record" do
    let(:bytes) { File.binread(File.expand_path("../../fixtures/emf/test-001.emf", __dir__)) }
    let(:point_types) { [3, 4, 86, 87] }
    let(:polygon) { records.find { |candidate| point_types.include?(candidate.type_id) } }
    let(:corrupt) do
      bytes.b.tap { |copy| copy[polygon.offset + 24, 4] = [0x10000].pack("V") }.freeze
    end

    it "reports the record and keeps its bytes as a Raw wire" do
      parsed = Emf::Emr::Parser.call(corrupt)
      record = parsed.records.fetch(records.index(polygon))
      expect(parsed.errors.map(&:offset)).to include(polygon.offset)
      expect(record.wire).to be_a(Emf::Emr::Binary::Records::Raw)
    end
  end
end
