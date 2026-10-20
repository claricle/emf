# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Emf::Emr::Binary::Record field accessors" do
  let(:record_class) { Emf::Emr::Binary::Records::LineTo }
  let(:bytes) { [36, 16, 3, -4].pack("VVl<l<") }

  it "defines no per-instance singleton methods" do
    record = record_class.read(bytes)

    expect(record.singleton_methods).to be_empty
  end

  it "keeps reader, writer and presence accessors working" do
    record = record_class.read(bytes)
    record.origin.x = 9

    expect(record.origin.y).to eq(-4)
    expect(record.origin?).to be(true)
    expect(record.to_binary_s).to eq([36, 16, 9, -4].pack("VVl<l<"))
  end

  it "replaces a nested field through the writer" do
    record = record_class.read(bytes)
    record.origin = { x: 1, y: 2 }

    expect(record.to_binary_s).to eq([36, 16, 1, 2].pack("VVl<l<"))
  end

  it "allocates fewer objects per record than per-instance accessors did" do
    fixture = Emf::SpecSupport::FixturePath.read_fixture("emf", "test-000.emf")
    Emf::Emr::Parser.call(fixture)
    GC.start
    before = GC.stat(:total_allocated_objects)
    metafile = Emf::Emr::Parser.call(fixture)
    per_record = (GC.stat(:total_allocated_objects) - before) / metafile.records.size

    expect(per_record).to be < 180
  end
end
