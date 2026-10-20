# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Emf::Emr::Parser fixed-layout record with surplus nSize bytes" do
  def header_bytes
    bytes = File.binread(Emf::SpecSupport::FixturePath.fixture("simple", "image1.emf"))
    bytes.byteslice(0, bytes.byteslice(4, 4).unpack1("V"))
  end

  def eof_bytes
    [14, 20, 0, 16, 20].pack("V5")
  end

  def move_to_ex(n_size, surplus)
    [27, n_size, 3, 4].pack("V4") + surplus
  end

  def synthetic(surplus: "\xAA\xBB\xCC\xDD\x01\x02\x03\x04".b)
    header_bytes + move_to_ex(16 + surplus.bytesize, surplus) + eof_bytes
  end

  def round_trip(bytes)
    first = Emf.serialize(Emf.parse(bytes))
    [first, Emf.serialize(Emf.parse(first))]
  end

  describe "synthetic EMF" do
    let(:bytes) { synthetic }
    let(:metafile) { Emf.parse(bytes) }

    it "keeps the typed record and its surplus bytes without a ParseError" do
      record = metafile.records.first
      expect(metafile.errors).to be_empty
      expect(record.wire).to be_a(Emf::Emr::Binary::Records::MoveToEx)
      expect(record.suffix).to eq("\xAA\xBB\xCC\xDD\x01\x02\x03\x04".b)
      expect(record.wire.n_size).to eq(24)
    end

    it "keeps the suffix and nSize when a typed field is edited" do
      record = metafile.records.first
      record.wire.origin.x = 99
      expect(Emf.serialize(metafile)).to eq(header_bytes + [27, 24, 99, 4].pack("V4") + "\xAA\xBB\xCC\xDD\x01\x02\x03\x04".b + eof_bytes)
    end

    it "recomputes nSize from layout plus suffix when a variable layout grows" do
      polyline = [4, 40, 0, 0, 0, 0, 1, 7, 8].pack("V9") + "tail".b
      parsed = Emf.parse(header_bytes + polyline + eof_bytes)
      wire = parsed.records.first.wire
      wire.cptl = 2
      wire.aptl << { x: 9, y: 10 }
      expected = [4, 48, 0, 0, 0, 0, 2, 7, 8, 9, 10].pack("V11") + "tail".b
      expect(parsed.errors).to be_empty
      expect(Emf.serialize(parsed)).to eq(header_bytes + expected + eof_bytes)
    end

    it "preserves the record bytes verbatim" do
      expect(Emf.serialize(metafile)).to eq(bytes)
    end

    it "is idempotent over parse -> serialize -> parse -> serialize" do
      first, second = round_trip(bytes)
      expect(second).to eq(first)
    end

    it "has an empty suffix when nSize equals the layout" do
      expect(Emf.parse(synthetic(surplus: "".b)).records.first.suffix).to be_empty
    end
  end

  %w[bad_corrupted_2014-12-02-215339 bad_corrupted_2014-12-13-132605].each do |name|
    it "round-trips #{name} idempotently" do
      bytes = File.binread(Emf::SpecSupport::FixturePath.fixture("emf-corrupted", "#{name}.emf"))
      first, second = round_trip(bytes)
      expect(second).to eq(first)
    end
  end

  it "serializes bad_corrupted_2014-12-02-215339 back to its original bytes" do
    bytes = File.binread(Emf::SpecSupport::FixturePath.fixture("emf-corrupted", "bad_corrupted_2014-12-02-215339.emf"))
    expect(Emf.serialize(Emf.parse(bytes))).to eq(bytes)
  end
end
