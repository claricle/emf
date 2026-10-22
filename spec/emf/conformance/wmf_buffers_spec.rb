# frozen_string_literal: true

require "spec_helper"
require "yaml"

RSpec.describe "Emf::Conformance WMF buffer rules" do
  let(:records) { Emf::Model::Wmf::Records }
  let(:rule_ids) { Emf::Conformance::Registry.default.rules_for(:wmf).map(&:id).grep(/\Awmf\.(bitmap|text|palette|region|escape)\./) }

  def header
    Emf::Model::Wmf::Header.new(type: 1, version: 0x300, size_words: 12, number_of_objects: 16, max_record_words: 3,
                                number_of_members: 0, placeable: nil)
  end

  def model(*list)
    Emf::Model::Metafile.new(format: :wmf, header: header, records: list + [records::Eof.new(offset: 200)])
  end

  def ids(metafile, profile: :strict) = Emf::Conformance.check(metafile, profile: profile).diagnostics.map(&:requirement_id)

  def dib(width: 1, size: 40, pixels: 4)
    [size, width, 1, 1, 24, 0, pixels, 0, 0, 0, 0].pack("Vl<2v2V2l<2V2") + ("\x00".b * pixels)
  end

  def blit(klass, bitmap, **extra)
    klass.new(raster_operation: 0xCC0020, source_y: 0, source_x: 0, height: 1, width: 1, destination_y: 0, destination_x: 0,
              bitmap: bitmap, offset: 18, **extra)
  end

  def segment(data, count: 1, remaining: 0, total: nil, checksum: nil, offset: 18, type_id: 0x0626)
    total ||= data.bytesize + remaining
    body = [Emf::Wmf::EmbeddedEmf::COMMENT_IDENTIFIER, 1, 0x10000, checksum || Emf::Wmf::EmbeddedEmf.checksum(data), 0, count,
            data.bytesize, remaining, total].pack("V3vV5") + data
    pad = body.bytesize.odd? ? "\x00".b : nil
    records::Escape.new(escape_function: 0x000F, data: body, padding: pad, offset: offset, type_id: type_id)
  end

  def palette(klass, entries, **extra)
    klass.new(start: 0x0300, entries: entries.map { |c| records::PaletteEntry.new(red: c, green: 0, blue: 0, flags: 0) }, offset: 18,
              **extra)
  end

  let(:scan) { records::RegionScan.new(top: 0, bottom: 1, lines: [records::RegionScanLine.new(left: 0, right: 1)]) }

  def wide_scan
    lines = Array.new(33_000) { records::RegionScanLine.new(left: 0, right: 1) }
    records::RegionScan.new(top: 0, bottom: 1, lines: lines)
  end

  def region(scans)
    records::CreateRegion.new(next_in_chain: 0, object_count: 1, scans: scans, offset: 18,
                              bounds: records::RegionBounds.new(left: 0, top: 0, right: 1, bottom: 1))
  end

  let(:cases) do
    {
      "wmf.bitmap.dib_layout" => model(blit(records::DibBitBlt, dib(width: 5000))),
      "wmf.bitmap.bitmap16_layout" => model(blit(records::BitBlt, "\x00".b * 4)),
      "wmf.text.length" => model(records::TextOut.new(text: "abc".b, padding: "".b, x: 0, y: 0, offset: 18)),
      "wmf.text.spacing_count" => model(records::ExtTextOut.new(text: "ab".b, padding: "".b, x: 0, y: 0, dx: [1], offset: 18)),
      "wmf.text.rectangle_options" => model(records::ExtTextOut.new(text: "ab".b, padding: "".b, x: 0, y: 0, options: 2, offset: 18)),
      "wmf.palette.entry_count" => model(records::ResizePalette.new(entry_count: 70_000, offset: 18)),
      "wmf.palette.entry_fields" => model(palette(records::SetPalEntries, [300])),
      "wmf.palette.start" => model(palette(records::CreatePalette, [1], start: 0x0200)),
      "wmf.region.scan_counts" => model(region([wide_scan])),
      "wmf.region.size" => model(region(Array.new(3000) { scan })),
      "wmf.escape.byte_count" => model(records::Escape.new(escape_function: 0x0099, data: "abc".b, padding: nil, offset: 18)),
      "wmf.escape.embedded_emf.segment" => model(segment("abcd".b).tap { |r| r.data.setbyte(0, 0) }),
      "wmf.escape.embedded_emf.sequence" => model(segment("abcd".b, count: 2, remaining: 4, total: 8)),
      "wmf.escape.embedded_emf.checksum" => model(segment("abcd".b, checksum: 1))
    }
  end

  it "covers every buffer rule with a crafted case" do
    expect(cases.keys).to match_array(rule_ids)
  end

  it "has a crafted case that fires exactly its own rule in strict" do
    cases.each { |id, metafile| expect(ids(metafile)).to eq([id]) }
  end

  it "downgrades only rules with a tolerant reason" do
    cases.each do |id, metafile|
      rule = Emf::Conformance::Registry.default[id]
      found = Emf::Conformance.check(metafile, profile: :tolerant).diagnostics
      severity = found.map(&:severity).first
      expect([id, found.map(&:requirement_id)]).to eq([id, [id]])
      expect([id, severity]).to eq([id, rule.tolerant_reason ? :warning : :error])
    end
  end

  it "cites MS-WMF and locates the offending record" do
    diagnostic = Emf::Conformance.check(cases.fetch("wmf.palette.entry_count")).diagnostics.first
    expect(diagnostic.spec_citation).to start_with("MS-WMF 2.3.4.3 META_CREATEPALETTE")
    expect([diagnostic.offset, diagnostic.record_index, diagnostic.record_type]).to eq([18, 1, 0x0139])
  end

  it "finds well-formed buffers clean in both profiles" do
    good = model(blit(records::DibBitBlt, dib), records::TextOut.new(text: "ab".b, padding: "".b, x: 0, y: 0, offset: 30),
                 records::ExtTextOut.new(text: "ab".b, padding: "".b, x: 0, y: 0, dx: [1, 2], offset: 40),
                 palette(records::CreatePalette, [1, 2]), region([scan]), segment("abcd".b, offset: 60))
    %i[strict tolerant].each { |profile| expect(ids(good, profile: profile)).to eq([]) }
  end

  it "reads a multi-segment embedded EMF stream as clean" do
    first = segment("abcd".b, count: 2, remaining: 4, total: 8, checksum: Emf::Wmf::EmbeddedEmf.checksum("abcdefgh".b))
    second = segment("efgh".b, count: 2, remaining: 0, total: 8, checksum: Emf::Wmf::EmbeddedEmf.checksum("abcdefgh".b), offset: 100)
    expect(ids(model(first, second))).to eq([])
  end

  it "preserves opaque escape subtypes without any finding" do
    opaque = [records::Escape.new(escape_function: 0x7777, data: "xyz".b, padding: "\x00".b, offset: 18),
              records::Escape.new(escape_function: 0x0011, data: "xyzw".b, padding: nil, offset: 30),
              records::UnknownRecord.new(type_id: 0x0626, raw_bytes: "\x03\x00\x00\x00\x26\x06".b, offset: 40)]
    expect(ids(model(*opaque)).grep(/escape/)).to eq([])
  end

  it "ignores a non-embedded escape in the embedded EMF rules" do
    escape = records::Escape.new(escape_function: 0x0099, data: "ab".b, padding: nil, offset: 18)
    expect(ids(model(escape))).to eq([])
  end

  it "marks the declared-size comparison implemented and opaque subtypes not checkable in the manifest" do
    rows = YAML.load_file(File.expand_path("../../../lib/emf/conformance/manifest/wmf.yml", __dir__)).to_h { |row| [row["id"], row] }
    expect(rows.fetch("wmf.buffer.declared_size")["status"]).to eq("implemented")
    expect(rows.fetch("wmf.escape.opaque_subtype")["status"]).to eq("not_checkable")
    expect(rows.values_at(*rule_ids).map { |row| row["status"] }.uniq).to eq(["implemented"])
  end

  describe "fixtures and valid seeds" do
    paths = Dir[File.expand_path("../fixtures/wmf/*.wmf", __dir__)] +
            Dir[File.expand_path("../../../emf-rs/fuzz/seeds/wmf-resilience/*.wmf", __dir__)]
    paths.each do |path|
      it "#{File.basename(path)} has no buffer findings in tolerant" do
        found = begin
          Emf::Conformance.check(path, profile: :tolerant).diagnostics.map(&:requirement_id)
        rescue Emf::Error
          []
        end
        expect(found.grep(/\Awmf\.(bitmap|text|palette|region|escape)\./)).to eq([])
      end
    end
  end
end
