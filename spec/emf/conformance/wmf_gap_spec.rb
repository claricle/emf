# frozen_string_literal: true

require "spec_helper"
require_relative "support/gap_wmf"
require_relative "support/record_inventories"

# The records that coverage_gaps.yml used to list as "deferred": each now has an implemented rule or a
# not_checkable row. Every case is crafted bytes parsed through the public entry point.
RSpec.describe "Emf::Conformance WMF gap records" do
  gap = Emf::SpecSupport::GapWmf
  codes = Emf::SpecSupport::RecordInventories::WMF_RECORD_TYPES

  def zeros(count) = Array.new(count, 0)

  # name => parameter words of the exact layout (MS-WMF 2.3.3 and 2.3.5)
  layouts = {
    "META_FLOODFILL" => 4, "META_SETPIXEL" => 4, "META_PATBLT" => 6, "META_EXCLUDECLIPRECT" => 4,
    "META_INTERSECTCLIPRECT" => 4, "META_OFFSETCLIPRGN" => 2, "META_REALIZEPALETTE" => 0, "META_SETBKCOLOR" => 2,
    "META_SETMAPPERFLAGS" => 2, "META_SETRELABS" => 0, "META_SETTEXTCHAREXTRA" => 1, "META_SETTEXTCOLOR" => 2,
    "META_SETTEXTJUSTIFICATION" => 2
  }

  describe "wmf.record.layout_size" do
    layouts.each do |name, words|
      it "#{name}: accepts #{words} parameter words and flags one surplus word" do
        # PatBlt's first two words are its RasterOperation; PATCOPY keeps wmf.fixed.raster_operation quiet.
        params = name == "META_PATBLT" ? [*gap.dword(0x00F00021), *zeros(words - 2)] : zeros(words)
        exact = gap.file(gap.record(codes.fetch(name), *params))
        expect(gap.ids(exact)).to eq([])
        extra = gap.file(gap.record(codes.fetch(name), *params, 0))
        expect(gap.ids(extra)).to eq(["wmf.record.layout_size"])
        expect(gap.ids(extra, profile: :tolerant)).to eq(["wmf.record.layout_size"])
        expect(gap.report(extra, profile: :tolerant)).to be_valid
      end
    end

    it "reports the META_SETRELABS case from the review: a self-consistent 4-word record" do
      diagnostic = gap.report(gap.file(gap.record(0x0105, 7))).diagnostics.first
      expect([diagnostic.requirement_id, diagnostic.record_type, diagnostic.record_index]).to eq(["wmf.record.layout_size", 0x0105, 1])
      expect(diagnostic.message).to include("SETRELABS", "4 words", "layout is 3 words", "no parameters")
    end

    it "states the layout size for a record that has parameters" do
      message = gap.report(gap.file(gap.record(0x0201, 0, 0, 0))).diagnostics.first.message
      expect(message).to include("SETBKCOLOR", "6 words", "layout is 5 words", "2 surplus bytes")
      expect(message).not_to include("no parameters")
    end
  end

  describe "fixed-size records of wmf.record.declared_size" do
    fixed = { "META_ARC" => 8, "META_CHORD" => 8, "META_ELLIPSE" => 4, "META_PIE" => 8, "META_RECTANGLE" => 4,
              "META_ROUNDRECT" => 6, "META_LINETO" => 2, "META_MOVETO" => 2, "META_SETWINDOWORG" => 2,
              "META_SETWINDOWEXT" => 2, "META_SETVIEWPORTORG" => 2, "META_SETVIEWPORTEXT" => 2,
              "META_OFFSETWINDOWORG" => 2, "META_OFFSETVIEWPORTORG" => 2 }
    fixed.each do |name, words|
      it "#{name}: accepts #{words} parameter words and rejects a longer or shorter record" do
        expect(gap.ids(gap.file(gap.record(codes.fetch(name), *zeros(words))))).to eq([])
        expect(gap.ids(gap.file(gap.record(codes.fetch(name), *zeros(words + 1))))).to eq(["wmf.reject.r0501"])
        expect(gap.ids(gap.file(gap.record(codes.fetch(name), *zeros(words - 1))))).to eq(["wmf.reject.r0501"])
      end
    end

    it "is the row that claims them, next to the rule" do
      row = Emf::Conformance::Manifest.rows.find { |entry| entry.id == "wmf.record.declared_size" }
      expect(row.record_types).to match_array(fixed.keys)
    end
  end

  describe "wmf.fixed.raster_operation" do
    it "flags a PatBlt RasterOperation above the 24-bit ternary code and accepts PATCOPY" do
      patblt = ->(rop) { gap.file(gap.record(codes.fetch("META_PATBLT"), *gap.dword(rop), 1, 1, 0, 0)) }
      expect(gap.ids(patblt.call(0x00F00021))).to eq([])
      expect(gap.ids(patblt.call(0x01F00021))).to eq(["wmf.fixed.raster_operation"])
      expect(gap.report(patblt.call(0x01F00021)).diagnostics.first.message).to include("0x01F00021")
    end

    it "flags a 24-bit code whose low word is not the one its operation index specifies" do
      patblt = ->(rop) { gap.file(gap.record(codes.fetch("META_PATBLT"), *gap.dword(rop), 1, 1, 0, 0)) }
      expect(gap.ids(patblt.call(0x00123456))).to eq(["wmf.fixed.raster_operation"])
      expect(gap.report(patblt.call(0x00123456)).diagnostics.first.message).to include("0x00120868")
      expect(gap.ids(patblt.call(0x00000042))).to eq([])
      expect(gap.ids(patblt.call(0x00FF0062))).to eq([])
    end

    it "checks the six operations whose spec entries are oddly formatted (SPXPDXA, DSNA, SPDNOX, DPSDNOAX, DPSONO, PSDNOA)" do
      patblt = ->(rop) { gap.file(gap.record(codes.fetch("META_PATBLT"), *gap.dword(rop), 1, 1, 0, 0)) }
      [0x00180D59, 0x00220326, 0x00390604, 0x007A1E29, 0x00AB0889, 0x00D00E0A].each do |rop|
        expect(gap.ids(patblt.call(rop))).to eq([])
        expect(gap.ids(patblt.call(rop & 0x00FF0000))).to eq(["wmf.fixed.raster_operation"])
      end
    end
  end

  describe "wmf.fixed.colorref_reserved" do
    { "META_SETBKCOLOR" => [], "META_SETTEXTCOLOR" => [], "META_FLOODFILL" => [0, 0], "META_SETPIXEL" => [0, 0] }.each do |name, tail|
      it "#{name}: flags a non-zero Reserved byte and accepts zero" do
        file = ->(color) { gap.file(gap.record(codes.fetch(name), *gap.dword(color), *tail)) }
        expect(gap.ids(file.call(0x00FFAA55))).to eq([])
        expect(gap.ids(file.call(0x02FFAA55))).to eq(["wmf.fixed.colorref_reserved"])
        expect(gap.report(file.call(0x02FFAA55)).diagnostics.first.message).to include("Reserved byte 0x02")
      end
    end
  end

  describe "wmf.flags.text_align domains" do
    align = ->(value) { gap.file(gap.record(codes.fetch("META_SETTEXTALIGN"), value, 0)) }

    {
      0x0004 => "horizontal bits 0x4", 0x0005 => "horizontal bits 0x4", 0x0010 => "vertical bits 0x10",
      0x0014 => "horizontal bits 0x4", 0x0116 => "vertical bits 0x10", 0x8000 => "outside the TextAlignmentMode flags"
    }.each do |value, fragment|
      it "flags 0x#{value.to_s(16).rjust(4, '0')} (#{fragment})" do
        diagnostics = gap.report(align.call(value)).diagnostics
        expect(diagnostics.map(&:requirement_id)).to eq(["wmf.flags.text_align"])
        expect(diagnostics.first.message).to include(fragment)
        expect(gap.report(align.call(value), profile: :tolerant)).to be_valid
      end
    end

    [0x0000, 0x0001, 0x0002, 0x0006, 0x0008, 0x0018, 0x000F, 0x0100, 0x0119, 0x010E].uniq.each do |value|
      it "accepts 0x#{value.to_s(16).rjust(4, '0')}" do
        expect(gap.ids(align.call(value))).to eq([])
      end
    end
  end

  describe "META_ESCAPE_ENHANCED_METAFILE" do
    # Escape 0x000F with an empty embedded EMF stream: 34 metadata bytes, Checksum = ~XOR of no words.
    def escape(identifier: 0x43464D57)
      data = [identifier, 1, 0x00010000, 0xFFFF, 0, 1, 0, 0, 0].pack("V3vV5")
      Emf::SpecSupport::GapWmf.record(0x0626, 0x000F, data.bytesize, *data.unpack("v*"))
    end

    it "is covered by the implemented embedded_emf rows and the rules fire on a bad Comment Identifier" do
      expect(gap.ids(gap.file(escape))).to eq([])
      expect(gap.ids(gap.file(escape(identifier: 1)))).to include("wmf.escape.embedded_emf.segment")
      rows = Emf::Conformance::Manifest.rows.select { |row| row.record_types.include?("META_ESCAPE_ENHANCED_METAFILE") }
      expect(rows.map(&:id)).to match_array(%w[wmf.escape.embedded_emf.segment wmf.escape.embedded_emf.sequence
                                               wmf.escape.embedded_emf.checksum])
      expect(rows.map(&:status).uniq).to eq(["implemented"])
    end
  end

  describe "the coverage gate" do
    it "has no coverage_gaps.yml and no WMF or EMF+ type covered only by a deferred row" do
      expect(File).not_to exist(File.join(Emf::Conformance::Manifest::DIR, "coverage_gaps.yml"))
      rows = Emf::Conformance::Manifest.rows
      %w[wmf emf_plus].each do |format|
        covering = rows.select { |row| row.format == format && row.status != "deferred" }.flat_map(&:record_types)
        deferred = rows.select { |row| row.format == format && row.status == "deferred" }.flat_map(&:record_types)
        expect((deferred - covering).select { |type| type.start_with?("META_", "EmfPlus") }).to eq([])
      end
    end
  end
end
