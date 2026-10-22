# frozen_string_literal: true

require "spec_helper"
require "yaml"

RSpec.describe "Emf::Conformance WMF object and DC-state rules" do
  r = Emf::Model::Wmf::Records
  ids = %w[wmf.object.capacity wmf.object.select_reference wmf.object.delete_reference wmf.object.palette_reference
           wmf.object.region_reference wmf.object.brush_reference wmf.dc.restore_depth].freeze

  def header(objects)
    Emf::Model::Wmf::Header.new(type: 1, version: 0x300, size_words: 12, number_of_objects: objects, max_record_words: 3,
                                number_of_members: 0, placeable: nil)
  end

  def model(records, objects: 8)
    Emf::Model::Metafile.new(format: :wmf, header: header(objects),
                             records: records + [Emf::Model::Wmf::Records::Eof.new(offset: 200)])
  end

  def findings(metafile, profile: :strict)
    Emf::Conformance.check(metafile, profile: profile).diagnostics.select { |d| d.requirement_id.start_with?("wmf.object.", "wmf.dc.") }
  end

  def found_ids(metafile) = findings(metafile).map(&:requirement_id)

  def pen(offset) = Emf::Model::Wmf::Records::CreatePenIndirect.new(pen_style: 0, width_x: 1, width_y: 0, color_ref: 0, offset: offset)

  def brush(offset)
    Emf::Model::Wmf::Records::CreateBrushIndirect.new(brush_style: 0, color_ref: 0, brush_hatch: 0, offset: offset)
  end

  def palette(offset) = Emf::Model::Wmf::Records::CreatePalette.new(start: 0x300, entries: [], offset: offset)

  def region(offset)
    Emf::Model::Wmf::Records::CreateRegion.new(next_in_chain: 0, object_count: 0, bounds: nil, scans: [], offset: offset)
  end

  let(:cases) do
    {
      "wmf.object.capacity" => model([pen(18), brush(30)], objects: 1),
      "wmf.object.select_reference" => model([pen(18), r::SelectObject.new(object_index: 3, offset: 30)]),
      "wmf.object.delete_reference" => model([pen(18), r::DeleteObject.new(object_index: 0, offset: 30),
                                              r::DeleteObject.new(object_index: 0, offset: 36)]),
      "wmf.object.palette_reference" => model([pen(18), r::SelectPalette.new(object_index: 0, offset: 30)]),
      "wmf.object.region_reference" => model([brush(18), r::InvertRegion.new(object_index: 0, offset: 30)]),
      "wmf.object.brush_reference" => model([region(18), pen(30),
                                             r::FillRegion.new(region_index: 0, brush_index: 1, offset: 40)]),
      "wmf.dc.restore_depth" => model([r::SaveDc.new(offset: 18), r::RestoreDc.new(saved_dc: -2, offset: 24)])
    }
  end

  it "has a crafted case for every WMF object rule" do
    expect(cases.keys).to match_array(ids)
    expect(Emf::Conformance::Registry.default.rules_for(:wmf).map(&:id)).to include(*ids)
  end

  ids.each do |id|
    describe id do
      it "fires once with its MS-WMF citation, record position and strict error" do
        diagnostics = findings(cases.fetch(id))
        expect(diagnostics.map(&:requirement_id)).to eq([id])
        expect(diagnostics.first.spec_citation).to start_with("MS-WMF 2.").or start_with("MS-WMF 3.")
        expect(diagnostics.first.severity).to eq(:error)
        expect(diagnostics.first.record_index).to be_between(2, 3)
      end

      it "downgrades only when the rule carries a tolerant reason" do
        rule = Emf::Conformance::Registry.default[id]
        tolerant = findings(cases.fetch(id), profile: :tolerant).first
        expect(tolerant.severity).to eq(rule.tolerant_reason ? :warning : :error)
      end
    end
  end

  it "reports the offending record, not a neighbour" do
    diagnostic = findings(cases.fetch("wmf.object.select_reference")).first
    expect([diagnostic.offset, diagnostic.record_index, diagnostic.record_type]).to eq([30, 2, 0x012D])
  end

  describe "object table replay" do
    it "hands out the lowest free index and reuses a deleted one" do
      good = model([pen(18), brush(30), r::DeleteObject.new(object_index: 0, offset: 40),
                    palette(46), r::SelectPalette.new(object_index: 0, offset: 60),
                    r::SelectObject.new(object_index: 1, offset: 66)], objects: 2)
      expect(findings(good)).to be_empty
    end

    it "frees capacity on delete and flags the next create only when the table is full" do
      full = model([pen(18), r::DeleteObject.new(object_index: 0, offset: 30), pen(36), pen(48)], objects: 1)
      expect(found_ids(full)).to eq(["wmf.object.capacity"])
      expect(findings(full).first.record_index).to eq(4)
    end

    it "treats NumberOfObjects 0 as a table with no room" do
      expect(found_ids(model([pen(18)], objects: 0))).to eq(["wmf.object.capacity"])
    end

    it "rejects a select after delete and the wrong object type" do
      stale = model([pen(18), r::DeleteObject.new(object_index: 0, offset: 30), r::SelectObject.new(object_index: 0, offset: 36)])
      expect(found_ids(stale)).to eq(["wmf.object.select_reference"])
      wrong = model([pen(18), r::SelectPalette.new(object_index: 0, offset: 30)])
      expect(findings(wrong).first.message).to include("pen object")
    end

    it "lets SelectObject choose a stock object but never lets DeleteObject delete one" do
      stock = model([r::SelectObject.new(object_index: 0x8005, offset: 18)])
      expect(findings(stock)).to be_empty
      expect(found_ids(model([r::DeleteObject.new(object_index: 0x8005, offset: 18)]))).to eq(["wmf.object.delete_reference"])
    end

    it "checks both the region and the brush index of FillRegion and FrameRegion" do
      both = model([pen(18), r::FrameRegion.new(region_index: 0, brush_index: 5, height: 1, width: 1, offset: 30)])
      expect(found_ids(both)).to match_array(%w[wmf.object.region_reference wmf.object.brush_reference])
    end

    it "does not judge opaque records" do
      opaque = r::UnknownRecord.new(type_id: 0x7777, raw_bytes: "\x03\x00\x00\x00\x77\x77".b, offset: 18)
      expect(findings(model([opaque]))).to be_empty
    end
  end

  describe "RestoreDc depth" do
    def restore(*values) = model(values.map.with_index { |v, i| v == :save ? r_save(18 + (i * 6)) : r_restore(v, 18 + (i * 6)) })

    def r_save(offset) = Emf::Model::Wmf::Records::SaveDc.new(offset: offset)

    def r_restore(value, offset) = Emf::Model::Wmf::Records::RestoreDc.new(saved_dc: value, offset: offset)

    it "accepts relative and absolute restores that match a save" do
      expect(findings(restore(:save, :save, -1, 1))).to be_empty
    end

    it "flags zero, an unsaved absolute instance and an over-deep relative restore" do
      expect(found_ids(restore(0))).to eq(["wmf.dc.restore_depth"])
      expect(found_ids(restore(:save, 2))).to eq(["wmf.dc.restore_depth"])
      expect(found_ids(restore(-1))).to eq(["wmf.dc.restore_depth"])
    end
  end

  describe "manifest" do
    manifest = YAML.load_file(File.expand_path("../../../lib/emf/conformance/manifest/wmf.yml", __dir__))

    it "has an implemented row for every rule, each with a MS-WMF citation and record types" do
      ids.each do |id|
        row = manifest.find { |entry| entry["id"] == id }
        expect(row).to include("status" => "implemented", "format" => "wmf")
        expect(row["citation"]).to eq(Emf::Conformance::Registry.default[id].citation)
        expect(row["record_types"]).not_to be_empty
      end
    end

    it "records the scale divisor as not checkable with a reason" do
      row = manifest.find { |entry| entry["id"] == "wmf.state.scale_divisor" }
      expect(row).to include("status" => "not_checkable")
      expect(row["reason"]).not_to be_empty
    end
  end

  describe "fixtures and seeds" do
    root = File.expand_path("../../..", __dir__)
    (Dir[File.join(root, "spec/fixtures/wmf/*.wmf")] + Dir[File.join(root, "emf-rs/fuzz/seeds/wmf-resilience/*.wmf")]).each do |path|
      metafile = begin
        Emf.parse(File.binread(path))
      rescue Emf::Error
        next
      end
      it "#{File.basename(path)} has no object or DC-state finding in either profile" do
        expect(findings(metafile)).to be_empty
        expect(findings(metafile, profile: :tolerant)).to be_empty
      end
    end
  end
end
