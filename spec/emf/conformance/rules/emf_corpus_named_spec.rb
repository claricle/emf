# frozen_string_literal: true

require "spec_helper"
require_relative "../support/crafted_emf"

RSpec.describe "Emf::Conformance rules naming the Raw-record corruptions of the corrupted corpus" do
  craft = Emf::SpecSupport::CraftedEmf

  def ids(bytes, profile: :strict) = Emf::Conformance.check(bytes, profile: profile).diagnostics.map(&:requirement_id)

  def finding(bytes, id) = Emf::Conformance.check(bytes).diagnostics.find { |d| d.requirement_id == id }

  describe "emf.record.fixed_size_raw" do
    let(:short_icm) { craft.build(records: [craft.record(98, "".b)]) } # SETICMMODE, Size 8 (stated 12)
    let(:short_layout) { craft.build(records: [craft.record(17, "".b)]) } # SETMAPMODE, Size 8 (fields need 12)

    it "fires on a SETICMMODE kept as a raw record because its Size is 8, at the record's offset" do
      expect(Emf.parse(short_icm).records.first.wire).not_to be_a(Emf::Emr::Binary::Record)
      found = finding(short_icm, "emf.record.fixed_size_raw")
      expect([found.offset, found.spec_citation]).to eq([craft::HEADER_SIZE, "MS-EMF 2.3.11"])
      expect(found.message).to include("SETICMMODE", "Size is 8", "states 12")
    end

    it "is the only state-size rule that fires: the decoded-wire rules skip a raw record (old-red)" do
      expect(ids(short_icm).grep(/\Aemf\.state\./)).to be_empty
    end

    it "uses the layout size for a record with no stated Size" do
      expect(finding(short_layout, "emf.record.fixed_size_raw").message).to include("SETMAPMODE", "fixed fields occupy 12")
    end

    it "stays silent on well-formed records, and a decodable wrong Size is left to emf.state.fixed_size" do
      expect(ids(craft.build(records: [craft.record(98, [1].pack("V"))]))).to be_empty
      oversized = craft.build(records: [craft.record(98, [1, 0].pack("V2"))])
      expect(ids(oversized)).to include("emf.state.fixed_size")
      expect(ids(oversized)).not_to include("emf.record.fixed_size_raw")
    end

    it "is a tolerant warning with the recovery waiver" do
      diagnostic = Emf::Conformance.check(short_icm, profile: :tolerant).diagnostics.find { |d| d.requirement_id == "emf.record.fixed_size_raw" }
      expect([diagnostic.severity, diagnostic.waiver]).to eq([:warning, Emf::Conformance::CorpusNamedRules::RECOVERED])
    end
  end

  describe "emf.record.exttextout_fixed_part" do
    # Size 60: Chars 0, ETO_NO_RECT (0x100) set so no Rectangle follows.
    let(:minimal_text) { craft.build(records: [craft.record(84, ("\0".b * 44) + [0x100].pack("V") + ("\0".b * 4))]) }

    it "fires on an EXTTEXTOUTW whose Size 12 cannot hold the EmrText object" do
      found = finding(craft.build(records: [craft.record(84, "\0\0\0\0".b)]), "emf.record.exttextout_fixed_part")
      expect([found.offset, found.spec_citation]).to eq([craft::HEADER_SIZE, "MS-EMF 2.2.5"])
      expect(found.message).to include("EMR_EXTTEXTOUTW", "Size 12", "60-byte")
    end

    it "is the only text rule that fires on it: the buffer rules need a body (old-red)" do
      text = craft.build(records: [craft.record(84, "\0\0\0\0".b)])
      expect(ids(text).grep(/\Aemf\.(exttextout|record\.exttextout)/)).to eq(["emf.record.exttextout_fixed_part"])
    end

    it "covers the ANSI record too" do
      expect(ids(craft.build(records: [craft.record(83, "\0\0\0\0".b)]))).to include("emf.record.exttextout_fixed_part")
    end

    it "stays silent on the smallest well-formed record (Size 60, empty string, no Rectangle)" do
      expect(ids(minimal_text)).to be_empty
    end
  end
end
