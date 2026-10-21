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

  describe "shared nested primitives" do
    it "defines no per-instance singleton methods on any Types class" do
      Emf::Binary::Types.constants.each do |name|
        expect(Emf::Binary::Types.const_get(name).new.singleton_methods)
          .to be_empty, "#{name} has singleton accessors"
      end
    end

    it "keeps PointL readers, writers and presence accessors working" do
      point = Emf::Binary::Types::PointL.read([3, -4].pack("l<l<"))
      point.x = 9

      expect([point.x, point.y, point.x?]).to eq([9, -4, true])
      expect(point.to_binary_s).to eq([9, -4].pack("l<l<"))
    end

    it "keeps array-of-record fields working" do
      palette = Emf::Binary::Types::LogPalette.read([0x300, 1, 1, 2, 3, 4].pack("v2C4"))

      expect(palette.pal_pal_entry[0].pe_blue).to eq(4)
    end
  end
end
