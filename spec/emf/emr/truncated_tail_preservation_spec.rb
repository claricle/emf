# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/emf_plus_generated_fixtures"

RSpec.describe Emf::Emr::Parser, "terminal record preservation" do
  {
    "2014-12-13-132605" => [4195, 90_865, ["EOFError: End of file reached",
                                           "truncated record at offset 4195 (claimed 2041956497, got 90857)"]],
    "2017-02-11-230400" => [2776, 190_688, ["truncated record at offset 2776 (claimed 4587520, got 190680)"]]
  }.each do |name, (offset, length, diagnostics)|
    it "retains the entire truncated terminal record in #{name}" do
      bytes = Emf::SpecSupport::FixturePath.read_fixture("emf-corrupted", "bad_corrupted_#{name}.emf")
      source = Emf.parse(bytes)

      expect(source.errors.map(&:message)).to eq(diagnostics)
      expect(source.trailing.bytesize).to eq(length)
      expect(source.trailing).to eq(bytes.byteslice(offset..))
      expect(Emf.serialize(source)).to eq(bytes)
      expect(Emf.serialize(source.emf_plus_stream.to_metafile)).to eq(bytes)
    end
  end

  it "retains an invalid size and the unparsed remainder without changing its diagnostic" do
    tail = [70, 4].pack("V2") + "unparsed".b
    fixtures = Emf::SpecSupport::EmfPlusGeneratedFixtures
    bytes = fixtures.header_bytes(88 + tail.bytesize, 2) + tail
    source = Emf.parse(bytes)

    expect(source.errors.map(&:message)).to eq(["record nSize 4 < 8 bytes (offset 88)"])
    expect(source.records).to be_empty
    expect(source.trailing).to eq(tail)
    expect(Emf.serialize(source)).to eq(bytes)
  end

  it "keeps complete records and the normal EOF suffix byte-identical" do
    fixtures = Emf::SpecSupport::EmfPlusGeneratedFixtures
    bytes = fixtures.single_comment(fixtures.typed_record(:Clear)) + "after EOF".b
    source = Emf.parse(bytes)

    expect(source.errors).to be_empty
    expect(source.records.last.wire).to be_a(Emf::Emr::Binary::Records::Eof)
    expect(source.trailing).to eq("after EOF".b)
    expect(Emf.serialize(source)).to eq(bytes)
  end
end
