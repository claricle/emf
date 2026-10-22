# frozen_string_literal: true

require "spec_helper"
require_relative "support/state_path_cases"

RSpec.describe "Emf::Conformance state and transform rules" do
  cases = Emf::SpecSupport::StatePathCases.state.merge(Emf::SpecSupport::StatePathCases.transform)

  def findings(bytes, id)
    Emf::Conformance.check(bytes, profile: :strict).diagnostics.select { |d| d.requirement_id == id }
  end

  cases.each do |id, files|
    it "#{id}: red on the crafted file, silent on the conforming one" do
      expect(findings(files[:bad], id)).not_to be_empty
      expect(findings(files[:good], id)).to be_empty
    end
  end

  it "registers exactly the state and transform rules these cases cover" do
    registered = Emf::Conformance::Registry.default.map(&:id).grep(/\Aemf\.(state|transform)\./)
    expect(registered).to match_array(cases.keys)
  end

  it "reports the offending record with its citation, offset and type" do
    bytes = Emf::SpecSupport::StatePathCases.file(Emf::SpecSupport::StatePathCases.rec(31, [1, 2, 3, 4]),
                                                  Emf::SpecSupport::StatePathCases.rec(31, [1, 0, 3, 0]))
    diagnostic = findings(bytes, "emf.state.scale_viewport_ext").first
    expect(diagnostic).to have_attributes(spec_citation: "MS-EMF 2.3.11.7", record_index: 2, record_type: 31, offset: 112)
    expect(diagnostic.message).to include("x_denom, y_denom MUST NOT be zero")
  end

  it "names the illuminant when ColorAdjustment has an undefined one" do
    support = Emf::SpecSupport::StatePathCases
    bytes = support.file(Emf::SpecSupport::CraftedEmf.record(23, support.color_adjustment(illuminant: 9)))
    expect(findings(bytes, "emf.state.color_adjustment").map(&:message)).to eq(
      ["ColorAdjustment IlluminantIndex 9 is not in the Illuminant enumeration (0..8)"]
    )
  end

  it "does not inspect the matrix of MWT_IDENTITY, which ignores it" do
    support = Emf::SpecSupport::StatePathCases
    body = support.matrix(Float::NAN, 0, 0, 1, 0, 0) + [1].pack("V")
    expect(findings(support.file(Emf::SpecSupport::CraftedEmf.record(36, body)), "emf.transform.finite_matrix")).to be_empty
  end

  it "waives only the text alignment sweep under the tolerant profile" do
    bytes = cases.fetch("emf.state.text_align")[:bad]
    diagnostic = Emf::Conformance.check(bytes, profile: :tolerant).diagnostics.find { |d| d.requirement_id == "emf.state.text_align" }
    expect(diagnostic.severity).to eq(:warning)
    expect(diagnostic.waiver).to include("test-039")
  end

  it "keeps the RESTOREDC parity variant (absolute positive SavedDC) a strict error" do
    bytes = Emf::SpecSupport::StatePathCases.file(Emf::SpecSupport::StatePathCases.rec(34, [3], pack: "l<"))
    expect(Emf::Conformance.check(bytes, profile: :strict).errors.map(&:requirement_id)).to include("emf.state.restoredc_negative")
  end
end
