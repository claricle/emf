# frozen_string_literal: true

require "spec_helper"
require "yaml"

module WmfSpec
  W = Emf::Model::Wmf
  R = W::Records
end

RSpec.describe "Emf::Conformance WMF rules" do
  manifest = YAML.load_file(File.expand_path("../../../lib/emf/conformance/manifest/wmf.yml", __dir__))
  seeds = Dir[File.expand_path("../../../emf-rs/fuzz/seeds/wmf-resilience/*.wmf", __dir__)]
  fixtures = Dir[File.expand_path("../fixtures/wmf/*.wmf", __dir__)]
  profiles = %i[strict tolerant].freeze

  def placeable(**over)
    fields = { handle: 0, left: 0, top: 0, right: 10, bottom: 10, inch: 96, checksum: nil }.merge(over)
    fields[:checksum] ||= Emf::Conformance::WmfFramingRules.checksum(WmfSpec::W::PlaceableHeader.new(**fields, checksum: 0))
    WmfSpec::W::PlaceableHeader.new(**fields)
  end

  def header(placeable: nil, **over)
    WmfSpec::W::Header.new(type: 1, version: 0x300, size_words: 12, number_of_objects: 16, max_record_words: 3,
                           number_of_members: 0, placeable: placeable, **over)
  end

  def model(records = [], header: self.header, trailing: "")
    all = records + (records.last.is_a?(WmfSpec::R::Eof) ? [] : [WmfSpec::R::Eof.new(offset: 100)])
    Emf::Model::Metafile.new(format: :wmf, header: header, records: all, trailing: trailing)
  end

  def diagnostics(metafile, profile: :strict) = Emf::Conformance.check(metafile, profile: profile).diagnostics

  def ids(metafile, **opts) = diagnostics(metafile, **opts).map(&:requirement_id)

  def ids_for(path, profile) = Emf::Conformance.check(path, profile: profile).diagnostics.map(&:requirement_id)

  def point(x, y) = WmfSpec::R::PointS.new(x: x, y: y)

  def rect(klass, **extra) = klass.new(left: 0, top: 0, right: 1, bottom: 1, **extra)

  let(:cases) do
    {
      "wmf.header.type" => model(header: header(type: 3)),
      "wmf.header.version" => model(header: header(version: 0x200)),
      "wmf.header.size" => model(header: header(size_words: 4)),
      "wmf.header.number_of_members" => model(header: header(number_of_members: 2)),
      "wmf.placeable.handle" => model(header: header(type: 2, placeable: placeable(handle: 5))),
      "wmf.placeable.checksum" => model(header: header(placeable: placeable(checksum: 1))),
      "wmf.eof.missing" => Emf::Model::Metafile.new(format: :wmf, header: header,
                                                    records: [WmfSpec::R::MoveTo.new(x: 1, y: 1, offset: 18)]),
      "wmf.eof.not_last" => Emf::Model::Metafile.new(format: :wmf, header: header,
                                                     records: [WmfSpec::R::Eof.new(offset: 18),
                                                               WmfSpec::R::MoveTo.new(x: 1, y: 1, offset: 24),
                                                               WmfSpec::R::Eof.new(offset: 30)]),
      "wmf.eof.trailing_bytes" => model(trailing: "xx"),
      "wmf.record.unknown_function" => model([WmfSpec::R::UnknownRecord.new(type_id: 0x7777, raw_bytes: "\x03\x00\x00\x00\x77\x77".b,
                                                                            offset: 18)]),
      "wmf.enum.bk_mode" => model([WmfSpec::R::SetBkMode.new(mode: 9, offset: 18)]),
      "wmf.enum.map_mode" => model([WmfSpec::R::SetMapMode.new(mode: 0, offset: 18)]),
      "wmf.enum.poly_fill_mode" => model([WmfSpec::R::SetPolyFillMode.new(mode: 3, offset: 18)]),
      "wmf.enum.rop2" => model([WmfSpec::R::SetRop2.new(mode: 17, offset: 18)]),
      "wmf.enum.stretch_blt_mode" => model([WmfSpec::R::SetStretchBltMode.new(mode: 5, offset: 18)]),
      "wmf.enum.ext_flood_fill_mode" => model([WmfSpec::R::ExtFloodFill.new(mode: 2, color: 0, y: 0, x: 0, offset: 18)]),
      "wmf.enum.brush_style" => model([WmfSpec::R::CreateBrushIndirect.new(brush_style: 10, color_ref: 0, brush_hatch: 0, offset: 18)]),
      "wmf.enum.color_usage" => model([WmfSpec::R::DibCreatePatternBrush.new(style: 5, color_usage: 3, target: "".b, offset: 18)]),
      "wmf.enum.hatch_style" => model([WmfSpec::R::CreateBrushIndirect.new(brush_style: 2, color_ref: 0, brush_hatch: 6, offset: 18)]),
      "wmf.enum.pen_style" => model([WmfSpec::R::CreatePenIndirect.new(pen_style: 9, width_x: 1, width_y: 0, color_ref: 0, offset: 18)]),
      "wmf.flags.text_align" => model([WmfSpec::R::SetTextAlign.new(alignment: 0x0004, offset: 18)]),
      "wmf.flags.layout" => model([WmfSpec::R::SetLayout.new(layout: 0x10, reserved: 0, offset: 18)]),
      "wmf.array.point_count" => model([WmfSpec::R::Polygon.new(points: [point(0, 0)], offset: 18)]),
      "wmf.array.polygon_empty" => model([WmfSpec::R::Polygon.new(points: [], offset: 18)]),
      "wmf.array.polypolygon_counts" => model([WmfSpec::R::PolyPolygon.new(points: [point(0, 0)], points_per_polygon: [3], offset: 18)]),
      "wmf.record.layout_size" => model([WmfSpec::R::SetRelAbs.new(suffix: "\0\0".b, offset: 18)]),
      "wmf.fixed.raster_operation" => model([WmfSpec::R::PatBlt.new(raster_operation: 0x01F00021, height: 1, width: 1, y_left: 0, x_left: 0,
                                                                    offset: 18)]),
      "wmf.fixed.colorref_reserved" => model([WmfSpec::R::SetBkColor.new(color_ref: 0x03000000, offset: 18)]),
      "wmf.fixed.colorref_palette" => model([WmfSpec::R::SetBkColor.new(color_ref: 0x02000000, offset: 18)]),
      "wmf.fixed.point_range" => model([WmfSpec::R::Polyline.new(points: [point(0, 0), point(40_000, 0)], offset: 18)])
    }
  end

  let(:clean) do
    model([WmfSpec::R::SetBkMode.new(mode: 2, offset: 18), WmfSpec::R::SetMapMode.new(mode: 8, offset: 24),
           WmfSpec::R::SetTextAlign.new(alignment: 0x011F, offset: 30),
           WmfSpec::R::CreatePenIndirect.new(pen_style: 0x1206, width_x: 1, width_y: 0, color_ref: 0, offset: 36),
           WmfSpec::R::CreateBrushIndirect.new(brush_style: 2, color_ref: 0, brush_hatch: 5, offset: 50),
           WmfSpec::R::Polygon.new(points: [point(0, 0), point(1, 1)], offset: 60),
           WmfSpec::R::PolyPolygon.new(points: [point(0, 0), point(1, 1), point(2, 2)], points_per_polygon: [3], offset: 80)],
          header: header(placeable: placeable))
  end

  it "finds the baseline model clean in both profiles" do
    expect(diagnostics(clean)).to be_empty
    expect(diagnostics(clean, profile: :tolerant)).to be_empty
  end

  # Header, framing and record-field rules; object and buffer rules have their own specs.
  own_rules = Emf::Conformance::Registry.default.rules_for(:wmf)
                                        .select { |rule| rule.id.match?(/\Awmf\.(header|placeable|eof|record|enum|flags|fixed|array)\./) }
                                        # declared-size rules are covered in wmf_rejections_spec
                                        .reject { |rule| rule.id.match?(/declared_size|max_record|size_matches_records/) }

  it "accepts a placeable handle on an in-memory (Type 1) metafile" do
    expect(ids(model(header: header(placeable: placeable(handle: 5))))).not_to include("wmf.placeable.handle")
  end

  it "reports a non-zero NumberOfMembers as a SHOULD warning, not an error" do
    diagnostic = diagnostics(model(header: header(number_of_members: 2))).find { |d| d.requirement_id == "wmf.header.number_of_members" }
    expect([diagnostic.severity, diagnostic.message]).to eq([:warning, "WMF header NumberOfMembers is 2, SHOULD be 0"])
  end

  it "has a crafted case for every header, framing and record-field rule" do
    expect(cases.keys).to match_array(own_rules.map(&:id))
  end

  own_rules.each do |rule|
    describe rule.id do
      it "fires on its crafted model with a MS-WMF citation and an offset-bearing finding" do
        diagnostic = diagnostics(cases.fetch(rule.id)).find { |d| d.requirement_id == rule.id }
        expect(diagnostic).not_to be_nil
        expect(diagnostic.spec_citation).to start_with("MS-WMF 2.")
        expect(diagnostic.format).to eq(:wmf)
        expect(diagnostic.message).not_to be_empty
      end

      it "keeps its strict severity strict and downgrades only with a tolerant reason" do
        strict = diagnostics(cases.fetch(rule.id)).find { |d| d.requirement_id == rule.id }
        tolerant = diagnostics(cases.fetch(rule.id), profile: :tolerant).find { |d| d.requirement_id == rule.id }
        expect(strict.severity).to eq(rule.severity)
        expect(tolerant.severity).to eq(rule.tolerant_reason ? :warning : rule.severity)
      end
    end
  end

  it "reports only the rule it targets for each crafted model" do
    cases.each { |id, metafile| expect(ids(metafile)).to eq([id]) }
  end

  it "reports positions that point at the offending record" do
    diagnostic = diagnostics(cases.fetch("wmf.enum.bk_mode")).first
    expect([diagnostic.offset, diagnostic.record_index, diagnostic.record_type]).to eq([18, 1, 0x0102])
  end

  describe "manifest" do
    let(:rows) { manifest }
    let(:statuses) { rows.map { |row| row["status"] }.uniq }

    it "has a row for every registered WMF rule, marked implemented" do
      # wmf.header.unrecognised runs on input the detector rejected, so it registers under :unparseable.
      registered = Emf::Conformance::Registry.default.rules_for(:wmf).map(&:id) + ["wmf.header.unrecognised"]
      implemented = rows.select { |row| row["status"] == "implemented" }.map { |row| row["id"] }
      expect(implemented).to match_array(registered)
    end

    it "uses unique ids, the wmf format and the allowed statuses" do
      expect(rows.map { |row| row["id"] }).to eq(rows.map { |row| row["id"] }.uniq)
      expect(rows.map { |row| row["format"] }.uniq).to eq(["wmf"])
      expect(statuses - %w[implemented not_checkable blocked:model]).to be_empty
    end

    it "gives every non-implemented row a reason and every row a citation" do
      reasons = rows.reject { |row| row["status"] == "implemented" }.map { |row| row["reason"].to_s }
      expect(reasons).to all(satisfy { |reason| !reason.empty? })
      expect(rows.map { |row| row["citation"].to_s }).to all(start_with("MS-WMF"))
    end

    it "maps all 56 rejection reasons to rows; blocked:model is kept for a field the public model lacks, never for a limit" do
      rejects = rows.select { |row| row["id"].start_with?("wmf.reject.") }
      expect(rejects.size).to eq(56)
      blocked = rows.select { |row| row["status"] == "blocked:model" }
      expect(blocked.map { |row| row["id"] }).to eq(%w[wmf.header.header_size wmf.placeable.reserved])
      expect(blocked.map { |row| row["reason"] }).to all(match(/does not retain/))
      unreachable = rejects.select { |row| row["status"] == "not_checkable" }.map { |row| row["id"] }
      expect(unreachable).to eq(%w[wmf.reject.r0101 wmf.reject.r0203 wmf.reject.r0301 wmf.reject.r0302 wmf.reject.r0303
                                   wmf.reject.r0305 wmf.reject.r0401 wmf.reject.r0404 wmf.reject.r0406 wmf.reject.r1003
                                   wmf.reject.r1702 wmf.reject.r1801])
    end
  end

  describe "fixtures and seeds" do
    drift_seeds = %w[file-size.wmf max-record.wmf placeable-checksum.wmf negative-text-count.wmf].freeze
    (fixtures + seeds).each do |path|
      name = File.basename(path)
      metafile = begin
        Emf.parse(File.binread(path))
      rescue Emf::Error
        nil
      end
      if metafile && name.include?("unknown")
        it "#{name} names the unspecified function in strict and is still valid in tolerant" do
          expect(ids_for(path, :strict)).to eq(["wmf.record.unknown_function"])
          tolerant = Emf::Conformance.check(path, profile: :tolerant)
          expect([tolerant.valid?, tolerant.diagnostics.map(&:severity)]).to eq([true, [:warning]])
        end
      elsif drift_seeds.include?(name)
        it "#{name} is recovered: an error in strict, only warnings in tolerant" do
          expect(Emf::Conformance.check(path, profile: :strict).errors).not_to be_empty
          tolerant = Emf::Conformance.check(path, profile: :tolerant)
          expect([tolerant.valid?, tolerant.diagnostics.map(&:severity).uniq]).to eq([true, [:warning]])
        end
      elsif metafile
        it "#{name} is clean in strict and tolerant profiles" do
          expect(Emf::Conformance.check(path, profile: :strict).diagnostics).to be_empty
          expect(Emf::Conformance.check(path, profile: :tolerant).diagnostics).to be_empty
        end
      else
        it "#{name} is rejected by the parser and reported by one error in both profiles" do
          profiles.each do |profile|
            expect(Emf::Conformance.check(path, profile: profile).errors.size).to eq(1)
          end
        end
      end
    end
  end
end
