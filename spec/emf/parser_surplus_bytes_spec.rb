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

    it "reports a ParseError naming offset, type, declared and consumed size" do
      offset = header_bytes.bytesize
      expect(metafile.errors.map(&:message)).to contain_exactly(
        a_string_including("offset #{offset}", "type 27", "nSize 24", "consumed 16")
      )
    end

    it "preserves the record bytes verbatim" do
      expect(Emf.serialize(metafile)).to eq(bytes)
    end

    it "is idempotent over parse -> serialize -> parse -> serialize" do
      first, second = round_trip(bytes)
      expect(second).to eq(first)
    end

    it "does not flag a record whose nSize equals its layout" do
      expect(Emf.parse(synthetic(surplus: "".b)).errors).to be_empty
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
