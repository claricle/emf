# frozen_string_literal: true

require "spec_helper"
require_relative "support/state_path_cases"

RSpec.describe "Emf::Conformance path bracket, clipping and DC depth rules" do
  support = Emf::SpecSupport::StatePathCases
  cases = support.path_clip

  def findings(bytes, id)
    Emf::Conformance.check(bytes, profile: :strict).diagnostics.select { |d| d.requirement_id == id }
  end

  cases.each do |id, files|
    it "#{id}: red on the crafted file, silent on the conforming one" do
      expect(findings(files[:bad], id)).not_to be_empty
      expect(findings(files[:good], id)).to be_empty
    end
  end

  it "registers exactly the path, clip and DC rules these cases cover" do
    registered = Emf::Conformance::Registry.default.map(&:id).grep(/\Aemf\.(path|clip|dc)\./)
    expect(registered).to match_array(cases.keys)
  end

  it "points an unclosed bracket at its BEGINPATH" do
    diagnostic = findings(support.file(support.rec(59)), "emf.path.unclosed").first
    expect(diagnostic).to have_attributes(offset: 88, record_index: 1, record_type: 59, spec_citation: "MS-EMF 2.3.10")
  end

  it "reports a nested BEGINPATH once and keeps the first bracket open" do
    bytes = support.file(support.rec(59), support.rec(59), support.rec(60))
    expect(findings(bytes, "emf.path.begin_nested").map(&:record_index)).to eq([2])
    expect(findings(bytes, "emf.path.unclosed")).to be_empty
  end

  it "accepts ENDPATH-less ABORTPATH and an ABORTPATH after a closed bracket" do
    bytes = support.file(support.rec(59), support.rec(68), support.rec(68))
    expect(findings(bytes, "emf.path.end_unopened")).to be_empty
  end

  it "counts restored states: -1 after one SAVEDC is fine, a second -1 is too deep" do
    ok = support.file(support.rec(33), support.rec(34, [-1], pack: "l<"))
    deep = support.file(support.rec(33), support.rec(34, [-1], pack: "l<"), support.rec(34, [-1], pack: "l<"))
    expect(findings(ok, "emf.dc.restore_depth")).to be_empty
    expect(findings(deep, "emf.dc.restore_depth").map(&:record_index)).to eq([3])
  end

  it "leaves a positive SavedDC to the sign rule instead of guessing its depth" do
    bytes = support.file(support.rec(34, [1], pack: "l<"))
    expect(findings(bytes, "emf.dc.restore_depth")).to be_empty
  end

  it "waives the depth rule under the tolerant profile with its measured reason" do
    diagnostic = Emf::Conformance.check(cases.fetch("emf.dc.restore_depth")[:bad], profile: :tolerant).diagnostics
                                 .find { |d| d.requirement_id == "emf.dc.restore_depth" }
    expect(diagnostic.severity).to eq(:warning)
  end
end
