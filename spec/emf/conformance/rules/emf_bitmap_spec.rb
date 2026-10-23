# frozen_string_literal: true

require "spec_helper"
require_relative "../support/bitmap_misc_cases"
require_relative "../support/deferred_cases"

RSpec.describe "Emf::Conformance bitmap rules" do
  let(:support) { Emf::SpecSupport::BitmapMiscCases }
  let(:cases) { support.bitmap_cases.merge(Emf::SpecSupport::DeferredCases.bitmap_cases) }

  def fired(bytes, profile: :strict)
    Emf::Conformance.check(bytes, profile: profile).diagnostics.map(&:requirement_id).grep(/\Aemf\.bitmap\./).uniq.sort
  end

  it "registers every bitmap rule with a crafted case" do
    registered = Emf::Conformance::Registry.default.map(&:id).grep(/\Aemf\.bitmap\./)
    expect(registered).to match_array(cases.keys)
  end

  it "leaves a well-formed record of every bitmap type alone" do
    support::FIXED.each_key do |type|
      expect(fired(support.file(support.bitmap(type)))).to be_empty, "type #{type}"
    end
  end

  it "keeps the clean bitmaps valid under both profiles" do
    bytes = support.file(*support.clean_bitmaps)
    expect(Emf::Conformance.check(bytes, profile: :tolerant).valid?).to be(true)
    expect(Emf::Conformance.check(bytes, profile: :strict).errors).to be_empty
  end

  describe "each rule" do
    Emf::SpecSupport::BitmapMiscCases.bitmap_cases.merge(Emf::SpecSupport::DeferredCases.bitmap_cases).each do |id, (bytes, expected)|
      it "#{id} fires on its crafted file and on nothing else but #{expected - [id]}" do
        expect(fired(bytes)).to eq(expected.sort)
        diagnostic = Emf::Conformance.check(bytes).diagnostics.find { |d| d.requirement_id == id }
        expect(diagnostic.spec_citation).to match(/\AMS-(EMF|WMF) \d+(\.\d+)+\z/)
        expect(diagnostic.offset).to eq(88)
      end
    end
  end

  describe "across the bitmap record types" do
    Emf::SpecSupport::BitmapMiscCases::FIXED.each_key do |type|
      it "type #{type}: a BMI that runs past the record is reported at that record" do
        at = Emf::SpecSupport::BitmapMiscCases::BUFFERS.fetch(type) + 4
        bytes = support.file(support.bitmap(type, fields: support.u32(at, 9000)))
        diagnostic = Emf::Conformance.check(bytes).diagnostics.find { |d| d.requirement_id == "emf.bitmap.bmi_range" }
        expect([diagnostic.record_type, diagnostic.offset]).to eq([type, 88])
      end
    end
  end

  describe "header and length detail" do
    it "reads a 12-byte core header and checks its stride" do
      core = [12, 2, 2, 1, 24].pack("VvvvV")[0, 12]
      expect(fired(support.file(support.bitmap(76, header: core, pixels: "\x11".b * 16)))).to be_empty
      expect(fired(support.file(support.bitmap(76, header: core, pixels: "\x11".b * 8)))).to eq(%w[emf.bitmap.bits_length])
    end

    it "requires a compressed bitmap's cbBits to equal ImageSize" do
      rle = support.bmi(bit_count: 8, compression: 1, image_size: 16) + ("\0".b * 1024)
      expect(fired(support.file(support.bitmap(76, header: rle)))).to be_empty
      expect(fired(support.file(support.bitmap(76,
                                               header: support.bmi(bit_count: 8, compression: 1,
                                                                   image_size: 9) + ("\0".b * 1024))))).to eq(%w[emf.bitmap.bits_length])
    end

    it "rejects a top-down bitmap that is compressed" do
      expect(fired(support.file(support.bitmap(76,
                                               header: support.bmi(height: -2, bit_count: 8, compression: 1,
                                                                   image_size: 16) + ("\0".b * 1024)))))
        .to eq(%w[emf.bitmap.bmi_compression])
    end

    it "limits EMR_SETDIBITSTODEVICE bits to the cScans lines it carries" do
      one_line = support.bitmap(80, fields: support.u32(72, 1), pixels: "\x11".b * 8)
      expect(fired(support.file(one_line))).to be_empty
    end

    it "rejects an AlphaFormat outside 0 and 1, and accepts AC_SRC_ALPHA on a 32-bit source" do
      expect(fired(support.file(support.bitmap(114, fields: { 43 => ["C", 5] })))).to eq(%w[emf.bitmap.alpha_format])
      ok = support.bitmap(114, fields: { 43 => ["C", 1] }, header: support.bmi(bit_count: 32), pixels: "\x11".b * 16)
      expect(fired(support.file(ok))).to be_empty
    end

    it "downgrades only the rule with a tolerant reason" do
      bytes = support.cases.fetch("emf.bitmap.record_size").first
      severities = Emf::Conformance.check(bytes, profile: :tolerant).diagnostics.to_h { |d| [d.requirement_id, d.severity] }
      expect(severities["emf.bitmap.record_size"]).to eq(:warning)
      expect(Emf::Conformance.check(support.cases.fetch("emf.bitmap.usage").first, profile: :tolerant).errors.map(&:requirement_id))
        .to include("emf.bitmap.usage")
    end
  end

  describe "colour table, ColorRef and BitmapV5 detail" do
    let(:deferred) { Emf::SpecSupport::DeferredCases }

    it "leaves well-formed colour tables, ColorRefs and V5 headers alone, including a padded BMI buffer" do
      deferred.clean_bitmaps.each_with_index do |record, i|
        expect(fired(support.file(record))).to be_empty, "clean bitmap #{i}"
      end
    end

    it "accepts a BMI buffer longer than the table ColorUsed names, but not a shorter one" do
      long = deferred.bitmap(header: deferred.bmi(bit_count: 1, color_used: 2) + deferred.table(65))
      expect(fired(support.file(long))).to be_empty
      expect(fired(support.file(deferred.bitmap(header: deferred.bmi(bit_count: 4, color_used: 3) + deferred.table(2)))))
        .to eq(%w[emf.bitmap.color_table])
    end

    it "counts a BI_BITFIELDS BitmapInfoHeader's three masks out of the colour table" do
      masks = deferred.bmi(bit_count: 16, compression: 3, color_used: 2) + deferred.table(3)
      expect(fired(support.file(deferred.bitmap(header: masks, pixels: "\x11".b * 8)))).to eq(%w[emf.bitmap.color_table])
    end

    it "does not hold an unpacked bitmap to ColorUsed" do
      header = deferred.bmi(bit_count: 1, color_used: 2) + deferred.table(1)
      gap = support.bitmap(76, header: header, fields: support.u32(92, 100 + header.bytesize + 4),
                               buffer: header + ("\0".b * 4) + support.bits)
      expect(fired(support.file(gap))).to eq(%w[emf.bitmap.color_table_length])
    end

    it "keeps colour table size an error under strict and a warning for the length rule" do
      table = Emf::Conformance.check(deferred.bitmap_cases.fetch("emf.bitmap.color_table").first, profile: :strict)
      length = Emf::Conformance.check(deferred.bitmap_cases.fetch("emf.bitmap.color_table_length").first, profile: :strict)
      expect(table.errors.map(&:requirement_id)).to include("emf.bitmap.color_table")
      expect(length.diagnostics.find { |d| d.requirement_id == "emf.bitmap.color_table_length" }.severity).to eq(:warning)
      expect(length.errors.map(&:requirement_id)).not_to include("emf.bitmap.color_table_length")
    end

    it "downgrades an oversized ColorUsed to a warning when tolerant" do
      diagnostic = Emf::Conformance.check(deferred.bitmap_cases.fetch("emf.bitmap.color_table").first, profile: :tolerant)
                                   .diagnostics.find { |d| d.requirement_id == "emf.bitmap.color_table" }
      expect(diagnostic.severity).to eq(:warning)
    end

    it "checks the Reserved byte of TransparentColor and of PlgBlt's BkColorSrc" do
      expect(fired(support.file(support.bitmap(116, fields: { 43 => ["C", 3] })))).to eq(%w[emf.bitmap.colorref_reserved])
      expect(fired(support.file(support.bitmap(116, fields: { 79 => ["C", 3] })))).to eq(%w[emf.bitmap.colorref_reserved])
      expect(fired(support.file(support.bitmap(79, fields: { 91 => ["C", 3] })))).to eq(%w[emf.bitmap.colorref_reserved])
      expect(fired(support.file(support.bitmap(116, fields: { 43 => ["C", 1] })))).to eq(%w[emf.bitmap.colorref_palette])
      expect(fired(support.file(support.bitmap(79, fields: { 91 => ["C", 2] })))).to eq(%w[emf.bitmap.colorref_palette])
      expect(fired(support.file(support.bitmap(76, fields: { 76 => ["C", 0xFF], 77 => ["C", 0xFF], 78 => ["C", 0xFF] })))).to be_empty
    end

    it "leaves XformSrc alone: the specification states no requirement for its values" do
      nan = [Float::NAN].pack("e")
      expect(fired(support.file(support.bitmap(76, fields: { 52 => ["a4", nan] })))).to be_empty
    end

    it "accepts each GamutMappingIntent value in a V5 header" do
      [1, 2, 4, 8].each { |intent| expect(fired(support.file(deferred.bitmap(header: deferred.v5_header(intent))))).to be_empty }
    end
  end

  describe "the corrupted fixture with an oversized bitmap" do
    let(:path) { File.expand_path("../../../fixtures/emf-corrupted/bad_corrupted_2016-02-02-225639.emf", __dir__) }

    it "gets named strict diagnostics from the bitmap rules" do
      expect(Emf::Conformance.check(path, profile: :strict).diagnostics.map(&:requirement_id))
        .to include("emf.bitmap.bmi_range", "emf.bitmap.bmi_header_size")
    end
  end
end
