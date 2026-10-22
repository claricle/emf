# frozen_string_literal: true

require "spec_helper"
require_relative "../support/objects_geometry_cases"

RSpec.describe "Emf::Conformance geometry and region rules" do
  cases = Emf::SpecSupport::ObjectsGeometryCases.geometry_cases

  def diagnostics(bytes, profile) = Emf::Conformance.check(bytes, profile: profile).diagnostics

  def messages(bytes, id) = diagnostics(bytes, :strict).select { |d| d.requirement_id == id }.map(&:message)

  it "registers exactly the geometry and region rule ids it has cases for" do
    registered = Emf::Conformance::Registry.default.map(&:id).grep(/\Aemf\.(geometry|region)\./)
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

  describe "region and gradient records in real files" do
    root = File.expand_path("../../../fixtures", __dir__)
    ids = /\Aemf\.(region\.|geometry\.(gradient|poly_))/

    %w[emf/test-039.emf emf/test-040.emf emf/test-000.emf].each do |name|
      it "stays silent for #{name}, which carries GradientFill, PolyPolygon or EXTSELECTCLIPRGN records" do
        found = Emf::Conformance.check(File.join(root, name), profile: :strict).diagnostics.map(&:requirement_id)
        expect(found.grep(ids)).to be_empty
      end
    end
  end

  describe "region records beyond FILLRGN" do
    let(:kit) { Emf::SpecSupport::ObjectsGeometryCases }

    def ids(bytes) = Emf::Conformance.check(bytes, profile: :strict).diagnostics.map(&:requirement_id)

    it "checks PAINTRGN, INVERTRGN and FRAMERGN region data and fixed parts" do
      bad = kit.region(count: 1, rgn_size: 0)
      paint = kit::CraftedEmf.record(74, kit::BOUNDS + [bad.bytesize].pack("V") + bad)
      invert = kit::CraftedEmf.record(73, kit::BOUNDS + [kit.region.bytesize].pack("V") + kit.region + "\0\0\0\0".b)
      frame = kit::CraftedEmf.record(72, kit::BOUNDS + [kit.region.bytesize, 1, 2, 2].pack("V4") + kit.region)
      expect(ids(kit.build(paint))).to include("emf.region.rects")
      expect(ids(kit.build(invert))).to include("emf.region.size")
      expect(ids(kit.build(frame))).not_to include(match(/\Aemf\.region\./))
    end
  end
end
