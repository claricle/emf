# frozen_string_literal: true

require "spec_helper"
require_relative "support/emf_plus_builder"

Emf::Conformance::Registry.default # loads the rule files that define EmfPlusFieldsB

# Field-domain checks for Path, Region, Font, StringFormat and ImageAttributes objects (MS-EMFPLUS 2.2.1.x),
# exercised through EmfPlusFieldsB.findings_for and through a temporary rule that stands in for the shared
# "emfplus.object.fields" rule.
RSpec.describe Emf::Conformance::EmfPlusFieldsB do
  let(:build) { Emf::SpecSupport::EmfPlusBuilder }
  let(:version) { [0xDBC01002].pack("V") }
  let(:path_type) { Emf::EmfPlus::Objects::PATH }

  def object_of(type, data)
    bytes = build.stream(build.object(type, 1, data))
    Emf.parse(bytes).emf_plus_stream.objects.lookup(1, at: 99)
  end

  def findings(type, data) = described_class.findings_for(object_of(type, data))

  def image_attributes(wrap: 0, clamp: 0) = version + [0, wrap, 0xFF000000, clamp, 0].pack("V5")

  def path(types, flags: 0)
    version + [types.size, flags].pack("V2") + types.each_index.map { |i| build.float(i, i) }.join + types.pack("C*")
  end

  def font(unit: 2, style: 0, name: "Arial")
    version + build.float(12) + [unit, style, 0, name.length].pack("V4") + name.encode("UTF-16LE").b
  end

  def string_format(align: 0, line: 0, digit: 0, hotkey: 0, trim: 0, flags: 0)
    version + [flags, 0, align, line, digit, 0].pack("V6") + build.float(0) + [hotkey].pack("l<") +
      build.float(0, 0, 1) + [trim, 0, 0].pack("Vl<l<")
  end

  def region(count, *nodes) = version + [count].pack("V") + nodes.join

  describe "ImageAttributes (the Codex reproducer)" do
    it "reports WrapMode and ObjectClamp 99" do
      expect(findings(8, image_attributes(wrap: 99, clamp: 99))).to eq(
        ["EmfPlusImageAttributes WrapMode 99 is outside 0..4", "EmfPlusImageAttributes ObjectClamp 99 is outside 0..1"]
      )
    end

    it "keeps every defined WrapMode and both clamp values" do
      (0..4).each { |wrap| expect(findings(8, image_attributes(wrap: wrap, clamp: wrap & 1))).to be_empty }
    end
  end

  describe "Path" do
    it "accepts Start, Line and Bezier with DashMode, PathMarker and CloseSubpath flags" do
      expect(findings(path_type, path([0x00, 0x01, 0x03, 0x03, 0x83, 0x31]))).to be_empty
    end

    it "reports an undefined point type" do
      expect(findings(path_type, path([0x00, 0x02]))).to eq(["EmfPlusPath PathPointType 2 is not Start (0), Line (1) or Bezier (3)"])
    end

    it "reports an undefined point flag bit" do
      expect(findings(path_type, path([0x00, 0x41]))).to eq(
        ["EmfPlusPath PathPointType flags 0x4 hold bits other than DashMode, PathMarker and CloseSubpath"]
      )
    end

    it "checks run-length point types" do
      data = version + [2, 0x0800].pack("V2") + [1, 1, 2, 2].pack("c4") + [0x42, 0x02].pack("C2")
      expect(findings(path_type, data)).to eq(["EmfPlusPath PathPointType 2 is not Start (0), Line (1) or Bezier (3)"])
    end
  end

  describe "Region" do
    let(:empty) { [0x10000002].pack("V") }
    let(:infinite) { [0x10000003].pack("V") }

    it "accepts a single terminal node and a two-child tree" do
      expect(findings(4, region(0, empty))).to be_empty
      expect(findings(4, region(2, [2].pack("V") + empty + infinite))).to be_empty
    end

    it "reports a RegionNodeCount that disagrees with the node tree" do
      expect(findings(4, region(2, empty))).to eq(["EmfPlusRegion RegionNodeCount 2 declares 3 nodes but the node tree holds 1"])
    end
  end

  describe "Font" do
    it "accepts a pixel font with combined style flags" do
      expect(findings(6, font(unit: 3, style: 0xF))).to be_empty
    end

    it "reports SizeUnit and FontStyleFlags outside their domains" do
      expect(findings(6, font(unit: 9, style: 0x10))).to eq(
        ["EmfPlusFont SizeUnit 9 is outside 0..6",
         "EmfPlusFont FontStyleFlags 0x10 sets undefined bits"]
      )
    end
  end

  describe "StringFormat" do
    it "accepts the maximum of every enumeration and the defined flags" do
      data = string_format(align: 2, line: 2, digit: 3, hotkey: 2, trim: 5, flags: 0x80007C27)
      expect(findings(7, data)).to be_empty
    end

    it "reports each out-of-domain enumeration and unknown flag bits" do
      data = string_format(align: 3, line: 4, digit: 4, hotkey: 3, trim: 6, flags: 0x8)
      expect(findings(7, data).size).to eq(6)
      expect(findings(7, data).first).to eq("EmfPlusStringFormat StringAlignment 3 is outside 0..2")
    end
  end

  it "ignores objects it does not own" do
    expect(findings(1, [0, 0xFF000000].pack("V2"))).to eq([])
  end

  describe "through a rule" do
    let(:registry) do
      Emf::Conformance::Registry.new.tap do |registry|
        registry.register(id: "emfplus.object.fields", formats: [:emf_plus], citation: "MS-EMFPLUS 2.2.1", kind: :fields) do |context|
          stream = context.metafile.emf_plus_stream
          Emf::Conformance::EmfPlusSupport.records(context).flat_map do |located|
            logical = Emf::Conformance::EmfPlusPayloads.completed_object(stream, located)
            next [] unless logical

            described_class.findings_for(logical).map { |message| Emf::Conformance::EmfPlusSupport.finding(located, message) }
          end
        end
      end
    end

    def valid_ids(bytes, profile)
      Emf::Conformance.check(bytes, profile: profile, registry: registry).diagnostics.map(&:requirement_id)
    end

    it "makes strict reject the Codex reproducer and keeps a valid object clean" do
      bad = build.stream(build.object(8, 1, image_attributes(wrap: 99, clamp: 99)))
      good = build.stream(build.object(8, 1, image_attributes(wrap: 4, clamp: 1)))
      expect(valid_ids(bad, :strict)).to include("emfplus.object.fields")
      expect(valid_ids(good, :strict)).not_to include("emfplus.object.fields")
    end
  end

  it "reports the Codex ImageAttributes reproducer through the registered emfplus.object.fields rule" do
    data = [0xDBC01002, 0, 99, 0xff000000, 99, 0].pack("V6")
    report = Emf::Conformance.check(build.stream(build.record(0x4008, flags: Emf::EmfPlus::Objects::IMAGE_ATTRIBUTES << 8, body: data)),
                                    profile: :tolerant)
    expect(report.errors.map(&:message)).to contain_exactly(/WrapMode 99 is outside 0\.\.4/, /ObjectClamp 99 is outside 0\.\.1/)
  end
end
