# frozen_string_literal: true

require "spec_helper"
require_relative "support/gap_wmf"
require_relative "support/record_inventories"
require_relative "support/bitmap_misc_cases"

RSpec.describe "Emf::Conformance hardening: cross-file fixes" do
  gap = Emf::SpecSupport::GapWmf
  codes = Emf::SpecSupport::RecordInventories::WMF_RECORD_TYPES
  emf_support = Emf::SpecSupport::BitmapMiscCases

  it "ignores META_SETLAYOUT Reserved, which MS-WMF 2.3.5.16 says MUST be ignored" do
    file = gap.file(gap.record(codes.fetch("META_SETLAYOUT"), 0, 1))
    expect(gap.ids(file)).to eq([])
  end

  define_method(:severities) do |file, id, profile|
    gap.report(file, profile: profile).diagnostics.select { |d| d.requirement_id == id }.map(&:severity)
  end

  [0x01, 0x02].each do |byte|
    it format("reports a palette-style ColorRef (0x%<byte>02X) as colorref_palette: strict error, tolerant warning", byte: byte) do
      file = gap.file(gap.record(codes.fetch("META_SETBKCOLOR"), *gap.dword((byte << 24) | 5)))
      expect(gap.ids(file)).to eq(["wmf.fixed.colorref_palette"])
      expect(severities(file, "wmf.fixed.colorref_palette", :strict)).to eq([:error])
      expect(severities(file, "wmf.fixed.colorref_palette", :tolerant)).to eq([:warning])
      expect(severities(file, "wmf.fixed.colorref_reserved", :tolerant)).to eq([])
    end
  end

  it "keeps a non-palette Reserved byte (0x03) an error in the tolerant profile too" do
    file = gap.file(gap.record(codes.fetch("META_SETBKCOLOR"), *gap.dword(0x03_00_00_05)))
    expect(gap.ids(file)).to eq(["wmf.fixed.colorref_reserved"])
    expect(severities(file, "wmf.fixed.colorref_reserved", :strict)).to eq([:error])
    expect(severities(file, "wmf.fixed.colorref_reserved", :tolerant)).to eq([:error])
  end

  it "keeps a non-palette EMF ColorRef Reserved byte (0x03) an error in the tolerant profile, and palette bytes a warning" do
    bitmap = ->(byte) { Emf::Conformance.check(emf_support.file(emf_support.bitmap(116, fields: { 43 => ["C", byte] })), profile: :tolerant) }
    expect(bitmap.call(3).diagnostics.map { |d| [d.requirement_id, d.severity] }).to eq([["emf.bitmap.colorref_reserved", :error]])
    expect(bitmap.call(2).diagnostics.map { |d| [d.requirement_id, d.severity] }).to eq([["emf.bitmap.colorref_palette", :warning]])
  end
end
