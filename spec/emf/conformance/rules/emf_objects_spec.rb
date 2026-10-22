# frozen_string_literal: true

require "spec_helper"
require_relative "../support/objects_geometry_cases"

RSpec.describe "Emf::Conformance object rules" do
  cases = Emf::SpecSupport::ObjectsGeometryCases.object_cases
  cases_module = Emf::SpecSupport::ObjectsGeometryCases

  def diagnostics(bytes, profile) = Emf::Conformance.check(bytes, profile: profile).diagnostics

  def messages(bytes, id) = diagnostics(bytes, :strict).select { |d| d.requirement_id == id }.map(&:message)

  it "registers exactly the object rule ids it has cases for" do
    registered = Emf::Conformance::Registry.default.map(&:id).grep(/\Aemf\.object\./)
    expect(registered).to match_array(cases.keys)
  end

  cases.each do |id, pair|
    describe id do
      it "is silent on the closest conforming stream" do
        expect(diagnostics(pair.fetch(:good), :strict).map(&:requirement_id)).not_to include(id)
      end

      it "fires on the broken stream, citing the spec, at the offending record" do
        found = diagnostics(pair.fetch(:bad), :strict).select { |d| d.requirement_id == id }
        expect(found).not_to be_empty
        expect(found.first.spec_citation).to match(/\AMS-EMF \d+(\.\d+)+\z/)
        expect(found.first.record_index).to be_positive
      end

      it "is downgraded to a warning under tolerant exactly when the rule carries a reason" do
        rule = Emf::Conformance::Registry.default[id]
        severity = diagnostics(pair.fetch(:bad), :tolerant).find { |d| d.requirement_id == id }.severity
        expect(severity).to eq(rule.tolerant_reason ? :warning : :error)
      end
    end
  end

  describe "handle rules name the clause they break" do
    it "rejects SELECTOBJECT 0 but accepts the stock objects" do
      expect(messages(cases_module.build(cases_module.rec(37, 0)), "emf.object.index_zero").first).to include("index 0")
      expect(messages(cases_module.build(cases_module.rec(37, 0x8000000D)), "emf.object.handle_range")).to be_empty
    end

    it "rejects deleting every stock index but not the unassigned 0x80000009" do
      stock = (0x80000000..0x80000013).to_a - [0x80000009]
      stock.each do |h|
        expect(messages(cases_module.build(cases_module.rec(40, h)), "emf.object.delete_stock").size).to eq(1), format("%#x", h)
      end
      expect(messages(cases_module.build(cases_module.rec(40, 0x80000009)), "emf.object.delete_stock")).to be_empty
    end

    it "treats a handle at nHandles as out of range and one below it as fine" do
      expect(messages(cases_module.build(cases_module.rec(37, 8)), "emf.object.handle_range").size).to eq(1)
      expect(messages(cases_module.build(cases_module.rec(37, 7)), "emf.object.handle_range")).to be_empty
    end

    it "flags use after delete, and a deleted handle that was re-created is live again" do
      stream = cases_module.build(cases_module.brush(2), cases_module.rec(40, 2), cases_module.rec(37, 2))
      expect(messages(stream, "emf.object.lifecycle").size).to eq(1)
      recreated = cases_module.build(cases_module.brush(2), cases_module.rec(40, 2), cases_module.brush(2), cases_module.rec(37, 2))
      expect(messages(recreated, "emf.object.lifecycle")).to be_empty
    end

    it "only allows DEFAULT_PALETTE as a stock operand of SELECTPALETTE" do
      expect(messages(cases_module.build(cases_module.rec(48, 0x8000000F)), "emf.object.handle_range")).to be_empty
      expect(messages(cases_module.build(cases_module.rec(48, 0x80000007)), "emf.object.handle_range").size).to eq(1)
    end
  end

  describe "RESIZEPALETTE bounds" do
    it "accepts 1 and 0x400 entries and rejects 0 and 0x401" do
      [[1, 0], [0x400, 0], [0, 1], [0x401, 1]].each do |count, bad|
        stream = cases_module.build(cases_module.palette(1), cases_module.rec(51, 1, count))
        expect(messages(stream, "emf.object.palette_entries").size).to eq(bad), count.to_s
      end
    end
  end

  describe "colour space handles" do
    let(:created) { cases_module::CraftedEmf.record(99, [2].pack("V") + ("\0" * 328).b) }

    it "tracks CREATECOLORSPACE through SETCOLORSPACE and DELETECOLORSPACE" do
      ok = cases_module.build(created, cases_module.rec(100, 2), cases_module.rec(101, 2))
      expect(messages(ok, "emf.object.lifecycle")).to be_empty
      reused = cases_module.build(created, cases_module.rec(101, 2), cases_module.rec(100, 2))
      expect(messages(reused, "emf.object.lifecycle").size).to eq(1)
      expect(messages(cases_module.build(cases_module.rec(100, 3)), "emf.object.lifecycle").size).to eq(1)
    end
  end
end
