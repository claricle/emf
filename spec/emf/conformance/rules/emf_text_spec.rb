# frozen_string_literal: true

require "spec_helper"
require_relative "../support/crafted_emf"
require_relative "../support/text_cases"

RSpec.describe "Emf::Conformance text rules" do
  let(:support) { Emf::SpecSupport::TextCases }
  let(:text_ids) { /\Aemf\.(exttextout|smalltextout|polytextout)\.|\Aemf\.opaque\.text_arrays\z/ }

  def fired(bytes)
    Emf::Conformance.check(bytes, profile: :strict).diagnostics.map(&:requirement_id).grep(text_ids).uniq.sort
  end

  it "reports, not raises, an EXTTEXTOUTW too short for its Rectangle and offDx" do
    crafted = Emf::SpecSupport::CraftedEmf
    bytes = crafted.build(records: [crafted.record(84, "\0".b * 52)])
    expect(fired(bytes)).to eq(["emf.exttextout.string_bounds"])
  end

  it "registers exactly the text rules that have a crafted case" do
    registered = Emf::Conformance::Registry.default.map(&:id).grep(text_ids)
    expect(registered).to match_array(support.cases.keys)
  end

  it "leaves every well-formed text record alone, on its own and together" do
    support.clean.each_with_index { |record, i| expect(fired(support.file(record))).to be_empty, "clean record #{i}" }
    expect(fired(support.file(*support.clean))).to be_empty
  end

  it "keeps the clean text file valid under both profiles" do
    bytes = support.file(*support.clean)
    expect(Emf::Conformance.check(bytes, profile: :tolerant).valid?).to be(true)
    expect(Emf::Conformance.check(bytes, profile: :strict).errors).to be_empty
  end

  describe "each rule" do
    Emf::SpecSupport::TextCases.cases.each do |id, (bytes, expected)|
      it "#{id} fires on its crafted file and on nothing else but #{expected - [id]}" do
        expect(fired(bytes)).to eq(expected.sort)
        diagnostic = Emf::Conformance.check(bytes).diagnostics.find { |d| d.requirement_id == id }
        expect(diagnostic.spec_citation).to match(/\AMS-EMF \d+(\.\d+)+\z/)
        expect(diagnostic.offset).to eq(88)
      end
    end
  end

  describe "ETO_PDY" do
    it "requires two Dx values per character" do
      # 3 chars, Dx placed so 3 values fit but 6 do not
      record = support.ext(options: support::PDY)
      short = record.byteslice(0, record.bytesize - 12)
      short[4, 4] = [short.bytesize].pack("V")
      expect(fired(support.file(short))).to eq(%w[emf.exttextout.dx_bounds])
    end
  end

  describe "the ANSI record" do
    it "does not require 16-bit alignment of the string" do
      expect(fired(support.file(support.ext(type: 83, off_string: 77)))).to be_empty
    end

    it "does not check the string as UTF-16" do
      record = support.ext(type: 83)
      record[76, 2] = [0xDF54].pack("v")
      expect(fired(support.file(record))).to be_empty
    end
  end

  describe "a descriptor table that does not fit" do
    it "stops at the table instead of reading past the record" do
      expect(fired(support.file(support.poly(count: 40)))).to eq(%w[emf.opaque.text_arrays])
    end
  end

  describe "tolerant profile" do
    it "reports an unpaired surrogate only as a diagnostic that tolerant mode accepts" do
      report = Emf::Conformance.check(support.file(support.unpaired_surrogate), profile: :tolerant)
      expect(report.valid?).to be(true)
    end

    it "accepts a string outside the record, which readers skip by Size, but strict rejects it" do
      bytes = support.file(support.ext(off_string: 400))
      expect(Emf::Conformance.check(bytes, profile: :tolerant).valid?).to be(true)
      expect(Emf::Conformance.check(bytes, profile: :strict).valid?).to be(false)
    end
  end
end
