# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Emf::Conformance over the fixture corpus" do
  root = File.expand_path("../../fixtures", __dir__)
  corrupted = Dir[File.join(root, "emf-corrupted/*.emf")]
  valid = Dir[File.join(root, "{emf,simple}/*.emf")]
  # The parser itself rejects these two (corrupted EMR_HEADER), so there is no model to check.
  unparseable = %w[bad_corrupted_2014-12-02-215338.emf bad_corrupted_2014-12-02-215428.emf]
  # 140817 (SELECTOBJECT) is undetectable from the stream (manifest emf.select_object.corpus_corruption).
  pending_record_rules = %w[bad_corrupted_2014-12-07-140817.emf]

  def check(path, profile) = Emf::Conformance.check(path, profile: profile)

  it "has the expected corpus" do
    expect(corrupted.size).to eq(21)
    expect(valid.size).to be >= 187
  end

  (corrupted + valid).reject { |path| unparseable.include?(File.basename(path)) }.each do |path|
    it "tolerant: #{File.basename(path)} is valid with zero errors" do
      report = check(path, :tolerant)
      expect(report.errors.map(&:message)).to be_empty
      expect(report.valid?).to be(true)
    end
  end

  corrupted.reject { |path| unparseable.include?(File.basename(path)) || pending_record_rules.include?(File.basename(path)) }.each do |path|
    it "strict: #{File.basename(path)} gets a named diagnostic" do
      report = check(path, :strict)
      expect(report.errors).not_to be_empty
      expect(report.errors.map(&:requirement_id)).to all(match(/\A(emf|emfplus)\.[a-z_0-9.]+\z/))
    end
  end

  unparseable.each do |name|
    it "#{name} is reported as unparseable under both profiles" do
      Emf::Conformance::Profile::ALL.each_key do |profile|
        expect(check(File.join(root, "emf-corrupted", name), profile).errors.map(&:requirement_id)).to eq(["emf.parse.unparseable"])
      end
    end
  end

  # Producer-wide findings that fire on these files too but don't name the corruption.
  let(:incidental) { %w[emf.object.pen_cosmetic_width] }

  it "has no rule naming the corruption yet in the two files that need one (flips when a later chunk lands)" do
    pending_record_rules.each do |name|
      ids = check(File.join(root, "emf-corrupted", name), :strict).diagnostics.map(&:requirement_id)
      expect(ids - incidental).to eq([]), name
    end
  end

  it "names the null EXTTEXTOUTW string of bad_corrupted_2016-02-02-210039.emf" do
    ids = check(File.join(root, "emf-corrupted", "bad_corrupted_2016-02-02-210039.emf"), :strict).diagnostics.map(&:requirement_id)
    expect(ids - incidental).to eq(%w[emf.exttextout.string_encoding])
  end

  it "strict: the valid fixtures fail only on documented producer deviations" do
    ids = valid.flat_map { |path| check(path, :strict).errors.map(&:requirement_id) }.uniq
    documented = Emf::Conformance::Registry.default.select(&:tolerant_reason).map(&:id)
    expect(ids - documented).to be_empty
    expect(ids).to include("emf.eof.size_last", "emf.header.records")
  end
end
